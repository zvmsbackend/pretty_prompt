///|
pub struct CompletionItem {
  replacement_text : String
  display_text : String
  filter_text : String
}

///|
pub fn CompletionItem::new(
  replacement_text : String,
  display_text? : String = replacement_text,
  filter_text? : String = replacement_text,
) -> CompletionItem {
  { replacement_text, display_text, filter_text }
}

///|
pub fn CompletionItem::get_priority(
  self : CompletionItem,
  pattern : String,
) -> Int {
  if pattern == "" {
    return 0
  }
  let pattern_view = pattern
  if self.filter_text.has_prefix(pattern_view) {
    4
  } else if self.filter_text.to_lower().has_prefix(pattern.to_lower()) {
    3
  } else if self.filter_text.contains(pattern_view) {
    2
  } else if self.filter_text.to_lower().contains(pattern.to_lower()) {
    1
  } else {
    -1
  }
}

///|
pub struct CompletionState {
  mut items : Array[CompletionItem]
  mut selected_index : Int
  mut filter_prefix : String
  all_items : Array[CompletionItem]
}

///|
pub fn CompletionState::new(
  items : Array[CompletionItem],
  filter_prefix : String,
) -> CompletionState {
  let state = {
    items: [],
    selected_index: 0,
    filter_prefix: "",
    all_items: items,
  }
  state.filter(filter_prefix)
  state
}

///|
pub fn CompletionState::filter(
  self : CompletionState,
  pattern : String,
) -> Unit {
  self.filter_prefix = pattern
  if pattern is "" {
    self.items = self.all_items.copy()
  } else {
    let filtered = self.all_items.filter_map(item => {
      let priority = item.get_priority(pattern)
      if priority >= 0 {
        Some((item, priority))
      } else {
        None
      }
    })
    filtered.sort_by_key(x => -x.1)
    self.items = filtered.map(x => x.0)
  }
  if self.selected_index >= self.items.length() {
    self.selected_index = 0
  }
}
