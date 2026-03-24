///|
struct KeyPressPattern {
  key : @console.ConsoleKey
  shift : Bool
  alt : Bool
  control : Bool
}

///|
pub fn KeyPressPattern::new(
  key : @console.ConsoleKey,
  shift? : Bool = false,
  alt? : Bool = false,
  control? : Bool = false,
) -> KeyPressPattern {
  { key, shift, alt, control }
}

///|
pub fn KeyPressPattern::matches(
  self : KeyPressPattern,
  key_info : @console.ConsoleKeyInfo,
) -> Bool {
  self.key == key_info.key &&
  self.shift == key_info.shift &&
  self.alt == key_info.alt &&
  self.control == key_info.control
}

///|
struct KeyPressPatterns {
  patterns : Array[KeyPressPattern]
}

///|
pub fn KeyPressPatterns::new(
  patterns : Array[KeyPressPattern],
) -> KeyPressPatterns {
  { patterns, }
}

///|
pub fn KeyPressPatterns::single(pattern : KeyPressPattern) -> KeyPressPatterns {
  { patterns: [pattern] }
}

///|
pub fn KeyPressPatterns::empty() -> KeyPressPatterns {
  { patterns: [] }
}

///|
pub fn KeyPressPatterns::has_any(self : KeyPressPatterns) -> Bool {
  self.patterns.length() > 0
}

///|
pub fn KeyPressPatterns::matches(
  self : KeyPressPatterns,
  key_info : @console.ConsoleKeyInfo,
) -> Bool {
  self.patterns.iter().any(pattern => pattern.matches(key_info))
}

///|
pub struct KeyBindings {
  submit_prompt : KeyPressPatterns
  cancel_prompt : KeyPressPatterns
  history_previous : KeyPressPatterns
  history_next : KeyPressPatterns
  backward_delete_character : KeyPressPatterns
  delete_character : KeyPressPatterns
  move_left : KeyPressPatterns
  move_right : KeyPressPatterns
  move_home : KeyPressPatterns
  move_end : KeyPressPatterns
  move_word_left : KeyPressPatterns
  move_word_right : KeyPressPatterns
  backward_delete_word : KeyPressPatterns
  delete_word : KeyPressPatterns
  trigger_completion : KeyPressPatterns
  dismiss_completion : KeyPressPatterns
  undo : KeyPressPatterns
  redo : KeyPressPatterns
  move_left_selection : KeyPressPatterns
  move_right_selection : KeyPressPatterns
  move_home_selection : KeyPressPatterns
  move_end_selection : KeyPressPatterns
  copy_selection : KeyPressPatterns
  cut_selection : KeyPressPatterns
  kill_line_tail : KeyPressPatterns
  kill_line_head : KeyPressPatterns
  yank : KeyPressPatterns
  yank_pop : KeyPressPatterns
  reverse_search : KeyPressPatterns
}

///|
fn default_submit_prompt_patterns() -> KeyPressPatterns {
  KeyPressPatterns::new([
    KeyPressPattern::new(Enter),
    KeyPressPattern::new(Enter, control=true),
    KeyPressPattern::new(Enter, alt=true, control=true),
  ])
}

///|
fn default_cancel_prompt_patterns() -> KeyPressPatterns {
  KeyPressPatterns::single(KeyPressPattern::new(C, control=true))
}

///|
fn default_backward_delete_character_patterns() -> KeyPressPatterns {
  @console.Backspace |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_history_previous_patterns() -> KeyPressPatterns {
  @console.UpArrow |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_history_next_patterns() -> KeyPressPatterns {
  @console.DownArrow |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_delete_character_patterns() -> KeyPressPatterns {
  @console.Delete |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_move_left_patterns() -> KeyPressPatterns {
  @console.LeftArrow |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_move_right_patterns() -> KeyPressPatterns {
  @console.RightArrow |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_move_home_patterns() -> KeyPressPatterns {
  @console.Home |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_move_end_patterns() -> KeyPressPatterns {
  @console.End |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_move_word_left_patterns() -> KeyPressPatterns {
  KeyPressPatterns::new([
    KeyPressPattern::new(LeftArrow, control=true),
    KeyPressPattern::new(B, alt=true),
  ])
}

///|
fn default_move_word_right_patterns() -> KeyPressPatterns {
  KeyPressPatterns::new([
    KeyPressPattern::new(RightArrow, control=true),
    KeyPressPattern::new(F, alt=true),
  ])
}

///|
fn default_backward_delete_word_patterns() -> KeyPressPatterns {
  KeyPressPatterns::new([
    KeyPressPattern::new(W, control=true),
    KeyPressPattern::new(Backspace, alt=true),
  ])
}

///|
fn default_delete_word_patterns() -> KeyPressPatterns {
  KeyPressPatterns::new([
    KeyPressPattern::new(D, alt=true),
    KeyPressPattern::new(Delete, control=true),
  ])
}

///|
fn default_trigger_completion_patterns() -> KeyPressPatterns {
  @console.Tab |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_dismiss_completion_patterns() -> KeyPressPatterns {
  @console.Escape |> KeyPressPattern::new |> KeyPressPatterns::single
}

///|
fn default_undo_patterns() -> KeyPressPatterns {
  @console.Z |> KeyPressPattern::new(control=true) |> KeyPressPatterns::single
}

///|
fn default_redo_patterns() -> KeyPressPatterns {
  @console.Y |> KeyPressPattern::new(control=true) |> KeyPressPatterns::single
}

///|
fn default_move_left_selection_patterns() -> KeyPressPatterns {
  @console.LeftArrow
  |> KeyPressPattern::new(shift=true)
  |> KeyPressPatterns::single
}

///|
fn default_move_right_selection_patterns() -> KeyPressPatterns {
  @console.RightArrow
  |> KeyPressPattern::new(shift=true)
  |> KeyPressPatterns::single
}

///|
fn default_move_home_selection_patterns() -> KeyPressPatterns {
  @console.Home |> KeyPressPattern::new(shift=true) |> KeyPressPatterns::single
}

///|
fn default_move_end_selection_patterns() -> KeyPressPatterns {
  @console.End |> KeyPressPattern::new(shift=true) |> KeyPressPatterns::single
}

///|
fn default_copy_selection_patterns() -> KeyPressPatterns {
  @console.C |> KeyPressPattern::new(control=true) |> KeyPressPatterns::single
}

///|
fn default_cut_selection_patterns() -> KeyPressPatterns {
  @console.X |> KeyPressPattern::new(control=true) |> KeyPressPatterns::single
}

///|
fn default_kill_line_tail_patterns() -> KeyPressPatterns {
  @console.K |> KeyPressPattern::new(control=true) |> KeyPressPatterns::single
}

///|
fn default_kill_line_head_patterns() -> KeyPressPatterns {
  @console.U |> KeyPressPattern::new(control=true) |> KeyPressPatterns::single
}

///|
fn default_yank_patterns() -> KeyPressPatterns {
  @console.Y |> KeyPressPattern::new(control=true) |> KeyPressPatterns::single
}

///|
fn default_yank_pop_patterns() -> KeyPressPatterns {
  @console.Y |> KeyPressPattern::new(alt=true) |> KeyPressPatterns::single
}

///|
fn default_reverse_search_patterns() -> KeyPressPatterns {
  @console.R |> KeyPressPattern::new(control=true) |> KeyPressPatterns::single
}

///|
pub fn KeyBindings::new(
  submit_prompt? : KeyPressPatterns = default_submit_prompt_patterns(),
  cancel_prompt? : KeyPressPatterns = default_cancel_prompt_patterns(),
  history_previous? : KeyPressPatterns = default_history_previous_patterns(),
  history_next? : KeyPressPatterns = default_history_next_patterns(),
  backward_delete_character? : KeyPressPatterns = default_backward_delete_character_patterns(),
  delete_character? : KeyPressPatterns = default_delete_character_patterns(),
  move_left? : KeyPressPatterns = default_move_left_patterns(),
  move_right? : KeyPressPatterns = default_move_right_patterns(),
  move_home? : KeyPressPatterns = default_move_home_patterns(),
  move_end? : KeyPressPatterns = default_move_end_patterns(),
  move_word_left? : KeyPressPatterns = default_move_word_left_patterns(),
  move_word_right? : KeyPressPatterns = default_move_word_right_patterns(),
  backward_delete_word? : KeyPressPatterns = default_backward_delete_word_patterns(),
  delete_word? : KeyPressPatterns = default_delete_word_patterns(),
  trigger_completion? : KeyPressPatterns = default_trigger_completion_patterns(),
  dismiss_completion? : KeyPressPatterns = default_dismiss_completion_patterns(),
  undo? : KeyPressPatterns = default_undo_patterns(),
  redo? : KeyPressPatterns = default_redo_patterns(),
  move_left_selection? : KeyPressPatterns = default_move_left_selection_patterns(),
  move_right_selection? : KeyPressPatterns = default_move_right_selection_patterns(),
  move_home_selection? : KeyPressPatterns = default_move_home_selection_patterns(),
  move_end_selection? : KeyPressPatterns = default_move_end_selection_patterns(),
  copy_selection? : KeyPressPatterns = default_copy_selection_patterns(),
  cut_selection? : KeyPressPatterns = default_cut_selection_patterns(),
  kill_line_tail? : KeyPressPatterns = default_kill_line_tail_patterns(),
  kill_line_head? : KeyPressPatterns = default_kill_line_head_patterns(),
  yank? : KeyPressPatterns = default_yank_patterns(),
  yank_pop? : KeyPressPatterns = default_yank_pop_patterns(),
  reverse_search? : KeyPressPatterns = default_reverse_search_patterns(),
) -> KeyBindings {
  {
    submit_prompt,
    cancel_prompt,
    history_previous,
    history_next,
    backward_delete_character,
    delete_character,
    move_left,
    move_right,
    move_home,
    move_end,
    move_word_left,
    move_word_right,
    backward_delete_word,
    delete_word,
    trigger_completion,
    dismiss_completion,
    undo,
    redo,
    move_left_selection,
    move_right_selection,
    move_home_selection,
    move_end_selection,
    copy_selection,
    cut_selection,
    kill_line_tail,
    kill_line_head,
    yank,
    yank_pop,
    reverse_search,
  }
}

///|
impl Default for KeyBindings with default() {
  KeyBindings::new()
}

///|
pub struct PromptConfiguration {
  prompt : FormattedString
  key_bindings : KeyBindings
  history : HistoryConfiguration
  highlighter : async (String) -> Array[FormatSpan]
  completer : async (String, Int) -> Array[CompletionItem]
  overload_provider : async (String, Int) -> Array[OverloadItem]
  selection_background : AnsiColor
  use_colors : Bool
  max_completion_items_count : Int
  kill_ring_max_size : Int
}

///|
pub fn PromptConfiguration::new(
  prompt? : FormattedString = FormattedString::new("> "),
  key_bindings? : KeyBindings = KeyBindings::default(),
  history? : HistoryConfiguration = HistoryConfiguration::default(),
  highlighter? : async (String) -> Array[FormatSpan] = _ => [],
  completer? : async (String, Int) -> Array[CompletionItem] = (_, _) => [],
  overload_provider? : async (String, Int) -> Array[OverloadItem] = (_, _) => [],
  selection_background? : AnsiColor = Blue,
  use_colors? : Bool = true,
  max_completion_items_count? : Int = 5,
  kill_ring_max_size? : Int = 20,
) -> PromptConfiguration {
  {
    prompt,
    key_bindings,
    history,
    highlighter,
    completer,
    overload_provider,
    selection_background,
    use_colors,
    max_completion_items_count,
    kill_ring_max_size,
  }
}

///|
pub fn PromptConfiguration::default() -> PromptConfiguration {
  PromptConfiguration::new()
}
