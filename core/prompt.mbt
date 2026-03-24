///|
using @ports {trait ClipboardPort, type CancelController}

///|
using @rendering {
  type FormattedString,
  type FormatSpan,
  type ConsoleFormat,
  type Screen,
  type Cell,
  wrap_text,
  get_chars_width,
  get_char_width,
  render_diff,
}

///|
using @editing {
  type HistoryLog,
  type CompletionState,
  type OverloadState,
  type UndoManager,
  type Selection,
  type KillRing,
  type SearchState,
  type UndoRecord,
  type OverloadItem,
}

///|
pub struct Prompt {
  console : &ConsolePort
  clipboard : &ClipboardPort
  configuration : PromptConfiguration
  history : HistoryLog
  cancel_controller : CancelController
  mut completion_state : CompletionState?
  mut last_screen : Screen?
  undo_manager : UndoManager
  mut selection : Selection?
  mut overload_state : OverloadState?
  kill_ring : KillRing
  mut search_state : SearchState?
}

///|
pub async fn Prompt::new(
  console : &ConsolePort,
  clipboard : &ClipboardPort,
  configuration? : PromptConfiguration = PromptConfiguration::default(),
) -> Prompt {
  let cancel_controller = CancelController::new(console)
  let history = HistoryLog::new(configuration.history)
  history.load_persistent_history()
  {
    console,
    clipboard,
    configuration,
    history,
    cancel_controller,
    completion_state: None,
    last_screen: None,
    undo_manager: UndoManager::new("", 0),
    selection: None,
    overload_state: None,
    kill_ring: KillRing::new(max_size=configuration.kill_ring_max_size),
    search_state: None,
  }
}

///|
pub async fn Prompt::read_line(self : Prompt) -> PromptResult {
  self.read_line_with_prompt(self.configuration.prompt)
}

///|
pub async fn Prompt::read_line_with_prompt(
  self : Prompt,
  prompt : FormattedString,
) -> PromptResult {
  self.cancel_controller.set_mode(CaptureAsInput)
  self.console.write(prompt.text)
  let state = InputState::new()
  let key_bindings = self.configuration.key_bindings

  while true {
    if self.cancel_controller.take_cancellation_requested() {
      self.console.write_line("")
      self.cancel_controller.set_mode(AllowCancelSignal)
      return cancel_result()
    }

    let key_presses = read_key_presses(self.console)
    for key_press in key_presses {
      let result = self.process_key_press(
        prompt, state, key_bindings, key_press,
      )
      match result {
        Handled => continue
        NotHandled => ()
        Return(value) => return value
      }
    }
  }
  cancel_result()
}

///|
priv enum KeyProcessingResult {
  Handled
  NotHandled
  Return(PromptResult)
}

///|
priv struct InputState {
  left : Array[Char]
  right : Array[Char]
  mut last_was_yank : Bool
}

///|
fn InputState::new() -> InputState {
  { left: [], right: [], last_was_yank: false }
}

///|
async fn Prompt::process_key_press(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
) -> KeyProcessingResult {
  let info = key_press.console_key_info
  if is_control_c_key(info) {
    return Return(self.cancel_prompt(info))
  }

  if key_press.pasted_text is Some(pasted) {
    self.completion_state = None
    self.overload_state = None
    self.search_state = None
    self.delete_selection(state.left, state.right)
    state.left.push_iter(pasted.iter())
    self.track_undo(state.left, state.right)
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }

  match self.handle_search_mode(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_navigation_modes(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_search_trigger(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_selection_clipboard(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_kill_ring(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_selection_movement_keys(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_undo_redo(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_completion_and_history(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_submit_or_cancel(state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_edit_keys(prompt, state, key_bindings, info) {
    NotHandled => ()
    other => return other
  }
  match self.handle_character_input(prompt, state, info) {
    NotHandled => NotHandled
    other => other
  }
}

///|
fn Prompt::cancel_prompt(
  self : Prompt,
  info : @console.ConsoleKeyInfo,
) -> PromptResult {
  self.completion_state = None
  self.overload_state = None
  self.selection = None
  self.console.write_line("")
  self.cancel_controller.set_mode(AllowCancelSignal)
  PromptResult::cancelled(info)
}

///|
async fn Prompt::handle_search_mode(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if self.search_state is Some(search_state) {
    if key_bindings.reverse_search.matches(info) {
      if self.history.navigate_search(
          search_state.query,
          search_state.history_index - 1,
        )
        is Some(res) {
        search_state.set_history_index(res.0)
        self.set_line_buffers(state.left, state.right, res.1)
      }
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    if key_bindings.dismiss_completion.matches(info) {
      self.search_state = None
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    if key_bindings.submit_prompt.matches(info) {
      self.search_state = None
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    if key_bindings.backward_delete_character.matches(info) {
      if search_state.query.length() > 0 {
        search_state.set_query(
          search_state.query
          .sub(end=search_state.query.length() - 1)
          .to_string(),
        )
        if self.history.navigate_search(search_state.query, -1) is Some(res) {
          search_state.set_history_index(res.0)
          self.set_line_buffers(state.left, state.right, res.1)
        }
      }
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    let ch = info.key_char
    if !ch.is_control() {
      search_state.set_query(search_state.query + ch.to_string())
      if self.history.navigate_search(search_state.query, -1) is Some(res) {
        search_state.set_history_index(res.0)
        self.set_line_buffers(state.left, state.right, res.1)
      }
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    self.search_state = None
  }
  NotHandled
}

///|
async fn Prompt::handle_navigation_modes(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if self.completion_state is Some(_) || self.overload_state is Some(_) {
    if key_bindings.dismiss_completion.matches(info) {
      self.completion_state = None
      self.overload_state = None
      self.render_line(prompt, state.left, state.right)
      state.last_was_yank = false
      return Handled
    }
    if key_bindings.history_previous.matches(info) {
      match self.completion_state {
        Some(s) =>
          s.set_selected_index(
            cycle_previous_index(s.selected_index, s.items.length()),
          )
        None =>
          if self.overload_state is Some(s) {
            s.set_selected_index(
              cycle_previous_index(s.selected_index, s.items.length()),
            )
          }
      }
      self.render_line(prompt, state.left, state.right)
      state.last_was_yank = false
      return Handled
    }
    if key_bindings.history_next.matches(info) {
      match self.completion_state {
        Some(s) =>
          s.set_selected_index(
            cycle_next_index(s.selected_index, s.items.length()),
          )
        None =>
          if self.overload_state is Some(s) {
            s.set_selected_index(
              cycle_next_index(s.selected_index, s.items.length()),
            )
          }
      }
      self.render_line(prompt, state.left, state.right)
      state.last_was_yank = false
      return Handled
    }
    if self.completion_state is Some(s) {
      if key_bindings.submit_prompt.matches(info) ||
        key_bindings.trigger_completion.matches(info) {
        if s.items.length() > 0 {
          let item = s.items[s.selected_index]
          while state.left.length() > 0 &&
                is_word_character(state.left[state.left.length() - 1]) {
            ignore(state.left.pop())
          }
          while state.right.length() > 0 &&
                is_word_character(state.right[state.right.length() - 1]) {
            ignore(state.right.pop())
          }
          state.left.push_iter(item.replacement_text.iter())
          self.track_undo(state.left, state.right)
        }
        self.completion_state = None
        self.render_line(prompt, state.left, state.right)
        state.last_was_yank = false
        return Handled
      }
    }
  }
  NotHandled
}

///|
async fn Prompt::handle_search_trigger(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.reverse_search.matches(info) {
    self.completion_state = None
    self.overload_state = None
    self.search_state = Some(SearchState::new())
    self.render_line(prompt, state.left, state.right)
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::handle_selection_clipboard(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.copy_selection.matches(info) {
    if self.selection is Some(sel) {
      let (start, end) = sel.range()
      let text = line_from_buffers(state.left, state.right)
      let selected_text = text.sub(start~, end~).to_string()
      let _ = self.clipboard.write_text(selected_text) catch { _ => () }
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.cut_selection.matches(info) {
    if self.selection is Some(sel) {
      let (start, end) = sel.range()
      let text = line_from_buffers(state.left, state.right)
      let selected_text = text.sub(start~, end~).to_string()
      let _ = self.clipboard.write_text(selected_text) catch { _ => () }
      self.kill_ring.add(selected_text)
      self.delete_selection(state.left, state.right)
      self.track_undo(state.left, state.right)
      self.render_line(prompt, state.left, state.right)
    }
    state.last_was_yank = false
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::handle_kill_ring(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.kill_line_tail.matches(info) {
    if state.right.length() > 0 {
      let text = String::from_array(state.right.rev())
      self.kill_ring.add(text)
      state.right.clear()
      self.track_undo(state.left, state.right)
      self.render_line(prompt, state.left, state.right)
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.kill_line_head.matches(info) {
    if state.left.length() > 0 {
      let text = String::from_array(state.left)
      self.kill_ring.add(text)
      state.left.clear()
      self.track_undo(state.left, state.right)
      self.render_line(prompt, state.left, state.right)
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.yank.matches(info) {
    if self.kill_ring.yank() is Some(text) {
      self.delete_selection(state.left, state.right)
      state.left.push_iter(text.iter())
      self.track_undo(state.left, state.right)
      self.render_line(prompt, state.left, state.right)
      state.last_was_yank = true
    }
    return Handled
  }
  if key_bindings.yank_pop.matches(info) && state.last_was_yank {
    if self.undo_manager.undo() is Some(record) {
      self.apply_undo_record(state.left, state.right, record)
      if self.kill_ring.yank_pop() is Some(text) {
        state.left.push_iter(text.iter())
        self.track_undo(state.left, state.right)
      }
      self.render_line(prompt, state.left, state.right)
    }
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::handle_selection_movement_keys(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.move_left_selection.matches(info) {
    self.handle_selection_movement(state.left, state.right, -1)
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_right_selection.matches(info) {
    self.handle_selection_movement(state.left, state.right, 1)
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_home_selection.matches(info) {
    self.handle_selection_movement(
      state.left,
      state.right,
      -state.left.length(),
    )
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_end_selection.matches(info) {
    self.handle_selection_movement(
      state.left,
      state.right,
      state.right.length(),
    )
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::handle_undo_redo(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.undo.matches(info) {
    self.completion_state = None
    self.overload_state = None
    self.selection = None
    if self.undo_manager.undo() is Some(record) {
      self.apply_undo_record(state.left, state.right, record)
      self.render_line(prompt, state.left, state.right)
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.redo.matches(info) {
    self.completion_state = None
    self.overload_state = None
    self.selection = None
    if self.undo_manager.redo() is Some(record) {
      self.apply_undo_record(state.left, state.right, record)
      self.render_line(prompt, state.left, state.right)
    }
    state.last_was_yank = false
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::handle_completion_and_history(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.trigger_completion.matches(info) {
    let raw_line = line_from_buffers(state.left, state.right)
    let items = (self.configuration.completer)(raw_line, state.left.length())
    if items.length() > 0 {
      let prefix_chars = state.left
        .rev_iter()
        .take_while(is_word_character)
        .collect()
      self.completion_state = Some(
        CompletionState::new(items, String::from_array(prefix_chars.rev())),
      )
      self.render_line(prompt, state.left, state.right)
    }
    return Handled
  }
  if key_bindings.history_previous.matches(info) {
    self.completion_state = None
    self.selection = None
    if self.history.navigate_previous(
        line_from_buffers(state.left, state.right),
      )
      is Some(entry) {
      self.set_line_buffers(state.left, state.right, entry)
      self.track_undo(state.left, state.right)
      self.render_line(prompt, state.left, state.right)
    }
    return Handled
  }
  if key_bindings.history_next.matches(info) {
    self.completion_state = None
    self.selection = None
    if self.history.navigate_next() is Some(entry) {
      self.set_line_buffers(state.left, state.right, entry)
      self.track_undo(state.left, state.right)
      self.render_line(prompt, state.left, state.right)
    }
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::handle_submit_or_cancel(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.history.reset_navigation()

  if key_bindings.cancel_prompt.matches(info) || is_control_c_key(info) {
    return Return(self.cancel_prompt(info))
  }

  if key_bindings.submit_prompt.matches(info) {
    self.completion_state = None
    self.overload_state = None
    self.selection = None
    let line = line_from_buffers(state.left, state.right)
    self.history.track_submission(line)
    self.console.write_line("")
    self.cancel_controller.set_mode(AllowCancelSignal)
    return Return(PromptResult::submitted(line, info))
  }
  NotHandled
}

///|
async fn Prompt::handle_edit_keys(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.backward_delete_character.matches(info) {
    if self.selection is Some(_) {
      self.delete_selection(state.left, state.right)
    } else if state.left.pop() is Some(_) {
      if self.completion_state is Some(completion_state) {
        update_completion_filter(completion_state, state.left)
      }
    }
    self.track_undo(state.left, state.right)
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.delete_character.matches(info) {
    if self.selection is Some(_) {
      self.delete_selection(state.left, state.right)
    } else {
      ignore(state.right.pop())
    }
    self.track_undo(state.left, state.right)
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_left.matches(info) {
    self.selection = None
    if state.left.pop() is Some(ch) {
      state.right.push(ch)
    }
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_right.matches(info) {
    self.selection = None
    if state.right.pop() is Some(ch) {
      state.left.push(ch)
    }
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_home.matches(info) {
    self.selection = None
    while state.left.pop() is Some(ch) {
      state.right.push(ch)
    }
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_end.matches(info) {
    self.selection = None
    while state.right.pop() is Some(ch) {
      state.left.push(ch)
    }
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::handle_character_input(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  let ch = info.key_char
  if !ch.is_control() {
    self.delete_selection(state.left, state.right)
    state.left.push(ch)
    if self.completion_state is Some(completion_state) {
      update_completion_filter(completion_state, state.left)
    } else if ch == '.' {
      let raw_line = line_from_buffers(state.left, state.right)
      let items = (self.configuration.completer)(raw_line, state.left.length())
      if items.length() > 0 {
        self.completion_state = Some(CompletionState::new(items, ""))
      }
    } else if ch == '(' {
      let raw_line = line_from_buffers(state.left, state.right)
      let overloads = (self.configuration.overload_provider)(
        raw_line,
        state.left.length(),
      )
      if overloads.length() > 0 {
        self.overload_state = Some(OverloadState::new(overloads))
      }
    }
    self.track_undo(state.left, state.right)
    self.render_line(prompt, state.left, state.right)
    state.last_was_yank = false
    return Handled
  }
  state.last_was_yank = false
  NotHandled
}

///|
fn cycle_previous_index(index : Int, length : Int) -> Int {
  if length == 0 {
    0
  } else {
    (index + length - 1) % length
  }
}

///|
fn cycle_next_index(index : Int, length : Int) -> Int {
  if length == 0 {
    0
  } else {
    (index + 1) % length
  }
}

///|
fn Prompt::handle_selection_movement(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
  delta : Int,
) -> Unit {
  let old_pos = left.length()
  if delta < 0 {
    for _ in 0..<-delta {
      if left.pop() is Some(ch) {
        right.push(ch)
      }
    }
  } else {
    for _ in 0..<delta {
      if right.pop() is Some(ch) {
        left.push(ch)
      }
    }
  }
  let new_pos = left.length()
  match self.selection {
    None => self.selection = Some(Selection::new(old_pos, new_pos))
    Some(sel) => {
      sel.set_active(new_pos)
      if sel.anchor == sel.active {
        self.selection = None
      }
    }
  }
}

///|
fn Prompt::delete_selection(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> Unit {
  if self.selection is Some(sel) {
    let (start, end) = sel.range()
    let text = line_from_buffers(left, right)
    let chars = text.to_array()
    left.clear()
    right.clear()
    for i in 0..<start {
      if i < chars.length() {
        left.push(chars[i])
      }
    }
    for i in chars.length()>..end {
      right.push(chars[i])
    }
    self.selection = None
  }
}

///|
fn Prompt::track_undo(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> Unit {
  self.undo_manager.track(line_from_buffers(left, right), left.length())
}

///|
fn Prompt::apply_undo_record(
  _self : Prompt,
  left : Array[Char],
  right : Array[Char],
  record : UndoRecord,
) -> Unit {
  left.clear()
  right.clear()
  let chars = record.text.to_array()
  for i in 0..<record.cursor_pos {
    if i < chars.length() {
      left.push(chars[i])
    }
  }
  for i in chars.length()>..record.cursor_pos {
    right.push(chars[i])
  }
}

///|
fn Prompt::set_line_buffers(
  _self : Prompt,
  left : Array[Char],
  right : Array[Char],
  text : String,
) -> Unit {
  left.clear()
  right.clear()
  left.push_iter(text.iter())
}

///|
fn update_completion_filter(
  state : CompletionState,
  left : Array[Char],
) -> Unit {
  let prefix_chars = left.rev_iter().take_while(is_word_character).collect()
  state.filter(String::from_array(prefix_chars.rev()))
}

///|
fn is_word_character(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_'
}

///|
fn is_control_c_key(info : @console.ConsoleKeyInfo) -> Bool {
  (info.key is C && info.control) || (info.key_char == '\u0003' && info.control)
}

///|
pub fn Prompt::take_execution_cancellation_requested(self : Prompt) -> Bool {
  self.cancel_controller.take_cancellation_requested()
}

///|
pub async fn Prompt::dispose(self : Prompt) -> Unit {
  self.history.save_persistent_history_full()
  self.cancel_controller.dispose()
}

///|
fn line_from_buffers(left : Array[Char], right : Array[Char]) -> String {
  let chars = Array::new(capacity=left.length() + right.length())
  chars.append(left)
  right.rev_each(ch => chars.push(ch))
  String::from_array(chars)
}

///|
async fn Prompt::render_line(
  self : Prompt,
  prompt : FormattedString,
  left : Array[Char],
  right : Array[Char],
) -> Unit {
  let width = self.console.get_buffer_width()
  let max_items = self.configuration.max_completion_items_count

  // 1. Determine Prompt Text & Style
  let active_prompt = match self.search_state {
    Some(s) =>
      FormattedString::new("(reverse-i-search)'\{s.query}': ", spans=[
        FormatSpan::new(0, 18, ConsoleFormat::new(bold=true, foreground=Cyan)),
      ])
    None => prompt
  }
  let active_prompt_width = active_prompt.width()

  // 2. Word Wrapping
  let raw_line = line_from_buffers(left, right)
  let full_text = active_prompt.text + raw_line
  let wrapped = wrap_text(
    full_text,
    active_prompt_width + get_chars_width(left.iter()),
    width,
  )

  // 2. Calculate heights
  let completion_items_count = match self.completion_state {
    Some(state) =>
      if state.items.length() < max_items {
        state.items.length()
      } else {
        max_items
      }
    None => 0
  }
  let overload_items_count = match self.overload_state {
    Some(state) =>
      if state.items.length() < 3 {
        state.items.length()
      } else {
        3
      }
    None => 0
  }
  let height = wrapped.lines.length() +
    completion_items_count +
    overload_items_count
  let new_screen = Screen::new(height, width)

  // 4. Draw Input Lines
  let spans = if self.configuration.use_colors {
    (self.configuration.highlighter)(raw_line)
  } else {
    []
  }
  let sorted_spans = spans.copy()
  sorted_spans.sort_by_key(span => span.start)

  let active_prompt_spans = active_prompt.spans.copy()
  active_prompt_spans.sort_by_key(span => span.start)

  let mut current_text_pos = 0
  for r in 0..<wrapped.lines.length() {
    let line_text = wrapped.lines[r]
    let mut line_col = 0

    for ch in line_text {
      let mut format = ConsoleFormat::default()
      if self.configuration.use_colors {
        if current_text_pos < active_prompt_width {
          // Apply prompt styles
          for span in active_prompt_spans {
            if current_text_pos >= span.start &&
              current_text_pos < span.start + span.length {
              format = span.format
              break
            }
          }
        } else {
          // Apply input text styles
          let i = current_text_pos - active_prompt_width
          for span in sorted_spans {
            if i >= span.start && i < span.start + span.length {
              format = span.format
              break
            }
          }
          if self.selection is Some(sel) {
            if sel.contains(i) {
              format = format.with_background(
                self.configuration.selection_background,
              )
            }
          }
        }
      }

      new_screen.rows[r][line_col] = Cell::new(ch, format)
      let w = get_char_width(ch)
      if w == 2 && line_col + 1 < width {
        new_screen.rows[r][line_col + 1] = Cell::new('\u{0000}', format)
      }
      line_col = line_col + w
      current_text_pos = current_text_pos + 1
    }
  }
  new_screen.set_cursor(wrapped.cursor_row, wrapped.cursor_col)

  // 5. Draw Overloads & Completions
  let mut next_row = wrapped.lines.length()
  if self.overload_state is Some(state) {
    for i in 0..<overload_items_count {
      let item = state.items[i]
      let format = if i == state.selected_index {
        ConsoleFormat::new(bold=true)
      } else {
        ConsoleFormat::default()
      }
      new_screen.draw_string(next_row, 0, "* " + item.signature, format)
      next_row = next_row + 1
    }
  }
  if self.completion_state is Some(state) {
    let start = if state.selected_index < 2 {
      0
    } else {
      state.selected_index - 2
    }
    for i in 0..<completion_items_count {
      let item_index = start + i
      if item_index >= state.items.length() {
        break
      }
      let item = state.items[item_index]
      let is_selected = item_index == state.selected_index
      let format = if is_selected && self.configuration.use_colors {
        ConsoleFormat::new(bold=true, underline=true)
      } else {
        ConsoleFormat::default()
      }
      let prefix = if is_selected { "> " } else { "  " }
      new_screen.draw_string(
        next_row + i,
        0,
        prefix + item.display_text,
        format,
      )
      if is_selected && item.description != "" {
        new_screen.draw_string(
          next_row + i,
          30,
          " │ " + item.description,
          ConsoleFormat::default(),
        )
      }
    }
  }

  // 6. Render Diff
  let base_row = self.console.get_cursor_top()
  let old_screen_val = self.last_screen.unwrap_or_else(() => {
    Screen::new(height, width)
  })
  render_diff(self.console, new_screen, old_screen_val, base_row, 1)
  self.last_screen = Some(new_screen)
}

///|
fn cancel_result() -> PromptResult {
  let key_info = @console.ConsoleKeyInfo::new(
    '\u0003',
    @console.C,
    false,
    false,
    true,
  )
  PromptResult::cancelled(key_info)
}

///|
pub struct PromptResult {
  is_success : Bool
  text : String
  submit_key_info : @console.ConsoleKeyInfo
}

///|
pub fn PromptResult::submitted(
  text : String,
  submit_key_info : @console.ConsoleKeyInfo,
) -> PromptResult {
  { is_success: true, text, submit_key_info }
}

///|
pub fn PromptResult::cancelled(
  submit_key_info : @console.ConsoleKeyInfo,
) -> PromptResult {
  { is_success: false, text: "", submit_key_info }
}
