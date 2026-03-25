///|
using @rendering {type AnsiColor}

///|
using @editing {type HistoryConfiguration, type CompletionItem}

///|
pub struct CompletionSpan {
  start : Int
  length : Int
}

///|
pub fn CompletionSpan::new(start : Int, length : Int) -> CompletionSpan {
  {
    start: if start < 0 {
      0
    } else {
      start
    },
    length: if length < 0 {
      0
    } else {
      length
    },
  }
}

///|
pub fn CompletionSpan::end(self : CompletionSpan) -> Int {
  self.start + self.length
}

///|
pub fn CompletionSpan::contains_caret(
  self : CompletionSpan,
  caret : Int,
) -> Bool {
  caret >= self.start && caret <= self.end()
}

///|
pub struct PromptSnapshot {
  text : String
  caret : Int
}

///|
pub fn PromptSnapshot::new(text : String, caret : Int) -> PromptSnapshot {
  let text_length = text.length()
  let caret = if caret < 0 {
    0
  } else if caret > text_length {
    text_length
  } else {
    caret
  }
  { text, caret }
}

///|
pub struct KeyTransformContext {
  snapshot : PromptSnapshot
  key_press : KeyPress
}

///|
pub fn KeyTransformContext::new(
  snapshot : PromptSnapshot,
  key_press : KeyPress,
) -> KeyTransformContext {
  { snapshot, key_press }
}

///|
pub struct FormatInputContext {
  snapshot : PromptSnapshot
  key_press : KeyPress
}

///|
pub fn FormatInputContext::new(
  snapshot : PromptSnapshot,
  key_press : KeyPress,
) -> FormatInputContext {
  { snapshot, key_press }
}

///|
pub struct CompletionRequest {
  snapshot : PromptSnapshot
  span_to_replace : CompletionSpan
}

///|
pub fn CompletionRequest::new(
  snapshot : PromptSnapshot,
  span_to_replace : CompletionSpan,
) -> CompletionRequest {
  { snapshot, span_to_replace }
}

///|
pub struct CompletionTriggerContext {
  snapshot : PromptSnapshot
  key_press : KeyPress
}

///|
pub fn CompletionTriggerContext::new(
  snapshot : PromptSnapshot,
  key_press : KeyPress,
) -> CompletionTriggerContext {
  { snapshot, key_press }
}

///|
pub struct CompletionCommitContext {
  snapshot : PromptSnapshot
  key_press : KeyPress
  selected_item : CompletionItem
  span_to_replace : CompletionSpan
}

///|
pub fn CompletionCommitContext::new(
  snapshot : PromptSnapshot,
  key_press : KeyPress,
  selected_item : CompletionItem,
  span_to_replace : CompletionSpan,
) -> CompletionCommitContext {
  { snapshot, key_press, selected_item, span_to_replace }
}

///|
pub(all) enum KeyPressCallbackResult {
  StayOnPrompt
  SubmitPrompt(text~ : String)
}

///|
pub struct KeyPressCallback {
  pattern : KeyPressPattern
  callback : async (PromptSnapshot) -> KeyPressCallbackResult
}

///|
pub fn KeyPressCallback::new(
  pattern : KeyPressPattern,
  callback : async (PromptSnapshot) -> KeyPressCallbackResult,
) -> KeyPressCallback {
  { pattern, callback }
}

///|
pub struct PromptCallbacks {
  key_press_callbacks : Array[KeyPressCallback]
  highlight_callback : async (PromptSnapshot) -> Array[FormatSpan]
  completion_span_provider : async (PromptSnapshot) -> CompletionSpan
  completion_items_provider : async (CompletionRequest) -> Array[CompletionItem]
  should_open_completion_window : async (CompletionTriggerContext) -> Bool
  transform_key_press : async (KeyTransformContext) -> KeyPress
  confirm_completion_commit : async (CompletionCommitContext) -> Bool
  should_insert_soft_newline : async (PromptSnapshot, KeyPress) -> Bool
  format_input : async (FormatInputContext) -> (String, Int)
  overload_provider : async (PromptSnapshot) -> (Array[OverloadItem], Int)
}

///|
#warnings("-unused_async")
async fn default_completion_span(snapshot : PromptSnapshot) -> CompletionSpan {
  let text = snapshot.text
  let caret = snapshot.caret

  let mut start = caret
  while start > 0 {
    let ch = text.get_char(start - 1).unwrap()
    if ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_' {
      start = start - 1
    } else {
      break
    }
  }

  let mut end = caret
  while end < text.length() {
    let ch = text.get_char(end).unwrap()
    if ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_' {
      end = end + 1
    } else {
      break
    }
  }

  CompletionSpan::new(start, end - start)
}

///|
#warnings("-unused_async")
async fn default_should_open_completion_window(
  ctx : CompletionTriggerContext,
) -> Bool {
  let text = ctx.snapshot.text
  let caret = ctx.snapshot.caret
  if caret > 0 {
    let previous = text.get_char(caret - 1).unwrap()
    if previous == '.' || previous == '(' {
      return true
    }
  }

  if caret == 1 {
    let first = text.get_char(0).unwrap()
    let second_is_word = text.length() > 1 &&
      text.get_char(1).unwrap().is_ascii_alphabetic()
    return !first.is_whitespace() && !second_is_word
  }

  caret - 2 >= 0 &&
  text.get_char(caret - 2).unwrap().is_whitespace() &&
  text.get_char(caret - 1).unwrap().is_ascii_alphabetic()
}

///|
pub fn PromptCallbacks::new(
  key_press_callbacks? : Array[KeyPressCallback] = [],
  highlight_callback? : async (PromptSnapshot) -> Array[FormatSpan] = _ => [],
  completion_span_provider? : async (PromptSnapshot) -> CompletionSpan = default_completion_span,
  completion_items_provider? : async (CompletionRequest) -> Array[
    CompletionItem,
  ] = _ => [],
  should_open_completion_window? : async (CompletionTriggerContext) -> Bool = default_should_open_completion_window,
  transform_key_press? : async (KeyTransformContext) -> KeyPress = ctx => {
    ctx.key_press
  },
  confirm_completion_commit? : async (CompletionCommitContext) -> Bool = _ => {
    true
  },
  should_insert_soft_newline? : async (PromptSnapshot, KeyPress) -> Bool = (
    _,
    _,
  ) => false,
  format_input? : async (FormatInputContext) -> (String, Int) = ctx => {
    (ctx.snapshot.text, ctx.snapshot.caret)
  },
  overload_provider? : async (PromptSnapshot) -> (Array[OverloadItem], Int) = _ => {
    ([], 0)
  },
) -> PromptCallbacks {
  {
    key_press_callbacks,
    highlight_callback,
    completion_span_provider,
    completion_items_provider,
    should_open_completion_window,
    transform_key_press,
    confirm_completion_commit,
    should_insert_soft_newline,
    format_input,
    overload_provider,
  }
}

///|
pub impl Default for PromptCallbacks with default() {
  PromptCallbacks::new()
}

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
  new_line : KeyPressPatterns
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
  paste : KeyPressPatterns
}

///|
let default_submit_prompt_patterns : KeyPressPatterns = KeyPressPatterns::new([
  KeyPressPattern::new(Enter),
  KeyPressPattern::new(Enter, control=true),
  KeyPressPattern::new(Enter, alt=true, control=true),
])

///|
let default_new_line_patterns : KeyPressPatterns = KeyPressPatterns::single(
  KeyPressPattern::new(Enter, control=true),
)

///|
let default_cancel_prompt_patterns : KeyPressPatterns = KeyPressPatterns::single(
  KeyPressPattern::new(C, control=true),
)

///|
let default_backward_delete_character_patterns : KeyPressPatterns = @console.Backspace
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_history_previous_patterns : KeyPressPatterns = @console.UpArrow
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_history_next_patterns : KeyPressPatterns = @console.DownArrow
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_delete_character_patterns : KeyPressPatterns = @console.Delete
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_move_left_patterns : KeyPressPatterns = @console.LeftArrow
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_move_right_patterns : KeyPressPatterns = @console.RightArrow
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_move_home_patterns : KeyPressPatterns = @console.Home
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_move_end_patterns : KeyPressPatterns = @console.End
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_move_word_left_patterns : KeyPressPatterns = KeyPressPatterns::new([
  KeyPressPattern::new(LeftArrow, control=true),
  KeyPressPattern::new(B, alt=true),
])

///|
let default_move_word_right_patterns : KeyPressPatterns = KeyPressPatterns::new([
    KeyPressPattern::new(RightArrow, control=true),
    KeyPressPattern::new(F, alt=true),
  ],
)

///|
let default_backward_delete_word_patterns : KeyPressPatterns = KeyPressPatterns::new([
    KeyPressPattern::new(W, control=true),
    KeyPressPattern::new(Backspace, alt=true),
  ],
)

///|
let default_delete_word_patterns : KeyPressPatterns = KeyPressPatterns::new([
  KeyPressPattern::new(D, alt=true),
  KeyPressPattern::new(Delete, control=true),
])

///|
let default_trigger_completion_patterns : KeyPressPatterns = @console.Tab
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_dismiss_completion_patterns : KeyPressPatterns = @console.Escape
  |> KeyPressPattern::new
  |> KeyPressPatterns::single

///|
let default_undo_patterns : KeyPressPatterns = @console.Z
  |> KeyPressPattern::new(control=true)
  |> KeyPressPatterns::single

///|
let default_redo_patterns : KeyPressPatterns = @console.Y
  |> KeyPressPattern::new(control=true)
  |> KeyPressPatterns::single

///|
let default_move_left_selection_patterns : KeyPressPatterns = @console.LeftArrow
  |> KeyPressPattern::new(shift=true)
  |> KeyPressPatterns::single

///|
let default_move_right_selection_patterns : KeyPressPatterns = @console.RightArrow
  |> KeyPressPattern::new(shift=true)
  |> KeyPressPatterns::single

///|
let default_move_home_selection_patterns : KeyPressPatterns = @console.Home
  |> KeyPressPattern::new(shift=true)
  |> KeyPressPatterns::single

///|
let default_move_end_selection_patterns : KeyPressPatterns = @console.End
  |> KeyPressPattern::new(shift=true)
  |> KeyPressPatterns::single

///|
let default_copy_selection_patterns : KeyPressPatterns = @console.C
  |> KeyPressPattern::new(control=true)
  |> KeyPressPatterns::single

///|
let default_cut_selection_patterns : KeyPressPatterns = @console.X
  |> KeyPressPattern::new(control=true)
  |> KeyPressPatterns::single

///|
let default_kill_line_tail_patterns : KeyPressPatterns = @console.K
  |> KeyPressPattern::new(control=true)
  |> KeyPressPatterns::single

///|
let default_kill_line_head_patterns : KeyPressPatterns = @console.U
  |> KeyPressPattern::new(control=true)
  |> KeyPressPatterns::single

///|
let default_yank_patterns : KeyPressPatterns = @console.Y
  |> KeyPressPattern::new(control=true)
  |> KeyPressPatterns::single

///|
let default_yank_pop_patterns : KeyPressPatterns = @console.Y
  |> KeyPressPattern::new(alt=true)
  |> KeyPressPatterns::single

///|
let default_reverse_search_patterns : KeyPressPatterns = @console.R
  |> KeyPressPattern::new(control=true)
  |> KeyPressPatterns::single

///|
let default_paste_patterns : KeyPressPatterns = KeyPressPatterns::new([
  KeyPressPattern::new(V, control=true),
  KeyPressPattern::new(Insert, shift=true),
  KeyPressPattern::new(V, control=true, shift=true),
])

///|
pub fn KeyBindings::new(
  submit_prompt? : KeyPressPatterns = default_submit_prompt_patterns,
  new_line? : KeyPressPatterns = default_new_line_patterns,
  cancel_prompt? : KeyPressPatterns = default_cancel_prompt_patterns,
  history_previous? : KeyPressPatterns = default_history_previous_patterns,
  history_next? : KeyPressPatterns = default_history_next_patterns,
  backward_delete_character? : KeyPressPatterns = default_backward_delete_character_patterns,
  delete_character? : KeyPressPatterns = default_delete_character_patterns,
  move_left? : KeyPressPatterns = default_move_left_patterns,
  move_right? : KeyPressPatterns = default_move_right_patterns,
  move_home? : KeyPressPatterns = default_move_home_patterns,
  move_end? : KeyPressPatterns = default_move_end_patterns,
  move_word_left? : KeyPressPatterns = default_move_word_left_patterns,
  move_word_right? : KeyPressPatterns = default_move_word_right_patterns,
  backward_delete_word? : KeyPressPatterns = default_backward_delete_word_patterns,
  delete_word? : KeyPressPatterns = default_delete_word_patterns,
  trigger_completion? : KeyPressPatterns = default_trigger_completion_patterns,
  dismiss_completion? : KeyPressPatterns = default_dismiss_completion_patterns,
  undo? : KeyPressPatterns = default_undo_patterns,
  redo? : KeyPressPatterns = default_redo_patterns,
  move_left_selection? : KeyPressPatterns = default_move_left_selection_patterns,
  move_right_selection? : KeyPressPatterns = default_move_right_selection_patterns,
  move_home_selection? : KeyPressPatterns = default_move_home_selection_patterns,
  move_end_selection? : KeyPressPatterns = default_move_end_selection_patterns,
  copy_selection? : KeyPressPatterns = default_copy_selection_patterns,
  cut_selection? : KeyPressPatterns = default_cut_selection_patterns,
  kill_line_tail? : KeyPressPatterns = default_kill_line_tail_patterns,
  kill_line_head? : KeyPressPatterns = default_kill_line_head_patterns,
  yank? : KeyPressPatterns = default_yank_patterns,
  yank_pop? : KeyPressPatterns = default_yank_pop_patterns,
  reverse_search? : KeyPressPatterns = default_reverse_search_patterns,
  paste? : KeyPressPatterns = default_paste_patterns,
) -> KeyBindings {
  {
    submit_prompt,
    new_line,
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
    paste,
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
  callbacks : PromptCallbacks
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
  callbacks? : PromptCallbacks = PromptCallbacks::default(),
  selection_background? : AnsiColor = Blue,
  use_colors? : Bool = true,
  max_completion_items_count? : Int = 5,
  kill_ring_max_size? : Int = 20,
) -> PromptConfiguration {
  {
    prompt,
    key_bindings,
    history,
    callbacks,
    selection_background,
    use_colors,
    max_completion_items_count,
    kill_ring_max_size,
  }
}

///|
pub impl Default for PromptConfiguration with default() {
  PromptConfiguration::new()
}
