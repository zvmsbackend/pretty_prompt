///|
test "completion item priority ranks prefix higher than contains" {
  let item = CompletionItem::new("alphabet", filter_text="AlphabetSoup")

  assert_eq(item.get_priority(""), 0)
  assert_eq(item.get_priority("Al"), 4)
  assert_eq(item.get_priority("al"), 3)
  assert_eq(item.get_priority("betS"), 2)
  assert_eq(item.get_priority("bets"), 1)
  assert_eq(item.get_priority("zzz"), -1)
}

///|
test "completion state filter resets selected index when out of range" {
  let state = CompletionState::new(
    [CompletionItem::new("apple"), CompletionItem::new("banana")],
    "",
  )
  state.set_selected_index(1)

  state.filter("app")

  assert_eq(state.items.length(), 1)
  assert_eq(state.items[0].replacement_text, "apple")
  assert_eq(state.selected_index, 0)
}

///|
test "overload and parameter constructors set fields" {
  let param = Parameter::new("x", "first")
  let overload = OverloadItem::new("f(x)", summary="sum", parameters=[param])
  let state = OverloadState::new([overload])

  assert_eq(state.items.length(), 1)
  assert_eq(state.items[0].signature, "f(x)")
  assert_eq(state.items[0].summary, "sum")
  assert_eq(state.items[0].parameters[0].name, "x")

  state.set_selected_index(0)
  assert_eq(state.selected_index, 0)
}

///|
test "kill ring ignores empty and duplicate then cycles" {
  let ring = KillRing::new(max_size=3)

  ring.add("")
  assert_eq(ring.yank(), None)

  ring.add("one")
  ring.add("one")
  ring.add("two")
  ring.add("three")

  assert_eq(ring.yank(), Some("three"))
  assert_eq(ring.yank_pop(), Some("two"))
  assert_eq(ring.yank_pop(), Some("one"))
}

///|
test "selection range works for reversed bounds" {
  let sel = Selection::new(5, 2)

  assert_eq(sel.range(), (2, 5))
  assert_true(sel.contains(3))
  assert_false(sel.contains(5))
}

///|
test "search state mutators update fields" {
  let state = SearchState::new()
  assert_eq(state.query, "")
  assert_eq(state.history_index, -1)

  state.set_query("abc")
  state.set_history_index(7)

  assert_eq(state.query, "abc")
  assert_eq(state.history_index, 7)
}

///|
test "kill ring enforces max size and single-item yank_pop returns none" {
  let ring = KillRing::new(max_size=2)
  ring.add("a")
  ring.add("b")
  ring.add("c")

  // oldest entry should be dropped when exceeding max_size
  assert_eq(ring.yank(), Some("c"))
  assert_eq(ring.yank_pop(), Some("b"))

  let single = KillRing::new(max_size=3)
  single.add("only")
  assert_eq(single.yank_pop(), None)
}

///|
test "selection set_active and forward range" {
  let sel = Selection::new(1, 1)
  sel.set_active(4)
  assert_eq(sel.range(), (1, 4))
  assert_true(sel.contains(2))
}

///|
test "undo manager handles boundaries and redo" {
  let undo = UndoManager::new("", 0)
  assert_true(undo.undo() is None)

  undo.track("a", 1)
  undo.track("ab", 2)
  assert_eq(undo.undo().map(r => r.text), Some("a"))
  assert_eq(undo.redo().map(r => r.text), Some("ab"))
  assert_true(undo.redo() is None)
}

///|
test "undo manager trims oldest entries beyond history limit" {
  let undo = UndoManager::new("", 0)
  for i in 0..<105 {
    undo.track("v\{i}", 1)
  }

  let mut steps = 0
  while undo.undo() is Some(_) {
    steps = steps + 1
  }
  // if trimming happened, undo depth is capped and cannot reach 104 steps.
  assert_true(steps < 104)
}

///|
async test "history previous/next and entry_count work" {
  let log = HistoryLog::new(HistoryConfiguration::new())
  assert_eq(log.navigate_previous("x"), None)

  log.track_submission("alpha")
  log.track_submission("beta")
  assert_eq(log.entry_count(), 2)

  assert_eq(log.navigate_previous(""), Some("beta"))
  assert_eq(log.navigate_previous(""), Some("alpha"))
  assert_eq(log.navigate_next(), Some("beta"))
  assert_eq(log.navigate_next(), Some(""))
  assert_eq(log.navigate_next(), None)
}

///|
async test "history search handles bounds and pattern matching" {
  let log = HistoryLog::new(HistoryConfiguration::new())
  assert_eq(log.navigate_search("a", -1), None)

  log.track_submission("Hello")
  log.track_submission("world")
  log.track_submission("Helium")

  // start index above range should be clamped to tail
  let r1 = log.navigate_search("hel", 99)
  assert_eq(r1.map(v => v.1), Some("Helium"))

  // case-insensitive contains should match
  let r2 = log.navigate_search("ORL", -1)
  assert_eq(r2.map(v => v.1), Some("world"))
}

///|
async test "history track_submission ignores empty and duplicate" {
  let log = HistoryLog::new(HistoryConfiguration::new())
  log.track_submission("")
  log.track_submission("dup")
  log.track_submission("dup")
  assert_eq(log.entry_count(), 1)
}

///|
async test "history saves and loads with max_entries trim" {
  let path = "_build/editing_history_wbtest.log"
  @fs.remove(path) catch {
    _ => ()
  }

  let config = HistoryConfiguration::new(
    persistent_history_filepath=path,
    max_entries=2,
  )
  let writer = HistoryLog::new(config)
  writer.track_submission("one")
  writer.track_submission("two")
  writer.track_submission("three")
  writer.save_persistent_history_full()

  let reader = HistoryLog::new(config)
  reader.load_persistent_history()
  assert_eq(reader.entry_count(), 2)
  assert_eq(reader.navigate_previous(""), Some("three"))

  @fs.remove(path) catch {
    _ => ()
  }
}
