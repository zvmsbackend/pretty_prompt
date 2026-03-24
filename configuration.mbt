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
  }
}

///|
impl Default for KeyBindings with default() {
  KeyBindings::new()
}

///|
pub struct PromptConfiguration {
  prompt : String
  key_bindings : KeyBindings
  history : HistoryConfiguration
}

///|
pub fn PromptConfiguration::new(
  prompt? : String = "> ",
  key_bindings? : KeyBindings = KeyBindings::default(),
  history? : HistoryConfiguration = HistoryConfiguration::default(),
) -> PromptConfiguration {
  { prompt, key_bindings, history }
}

///|
pub fn PromptConfiguration::default() -> PromptConfiguration {
  PromptConfiguration::new()
}
