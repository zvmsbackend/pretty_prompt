///|
pub struct CompletionItem {
  replacement_text : String
  display_text : String
  filter_text : String
  // description : async () -> String // Optional for future extended tips
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
pub struct CompletionState {
  items : Array[CompletionItem]
  mut selected_index : Int
  // The prefix being completed (to support incremental filtering)
  filter_prefix : String
}

///|
pub fn CompletionState::new(
  items : Array[CompletionItem],
  filter_prefix : String,
) -> CompletionState {
  { items, selected_index: 0, filter_prefix }
}
