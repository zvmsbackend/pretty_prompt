///|
pub using @ports {
  trait ConsolePort,
  trait ClipboardPort,
  type ClipboardPortError,
  type ControlCMode,
  type Ports,
  type CancelController,
}

///|
pub using @rendering {
  type AnsiColor,
  type ConsoleFormat,
  type FormatSpan,
  type FormattedString,
  type Cell,
  type Screen,
  type WrappedText,
  apply_highlights,
  get_char_width,
  get_chars_width,
  get_string_width,
  is_word_boundary,
  wrap_text,
  render_diff,
}

///|
pub using @editing {
  type CompletionItem,
  type CompletionState,
  type OverloadItem,
  type OverloadState,
  type Parameter,
  type HistoryConfiguration,
  type HistoryLog,
  type SearchState,
  type Selection,
  type KillRing,
  type UndoRecord,
}

///|
pub using @core {
  type KeyPressPattern,
  type KeyPress,
  read_key_presses,
  type KeyPressPatterns,
  type KeyBindings,
  type PromptConfiguration,
  type Prompt,
  type PromptResult,
}
