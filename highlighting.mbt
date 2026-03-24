///|
pub(all) enum AnsiColor {
  Default
  Black
  Red
  Green
  Yellow
  Blue
  Magenta
  Cyan
  White
  BrightBlack
  BrightRed
  BrightGreen
  BrightYellow
  BrightBlue
  BrightMagenta
  BrightCyan
  BrightWhite
  Color256(Int)
  Rgb(Int, Int, Int)
}

///|
pub struct ConsoleFormat {
  foreground : AnsiColor
  background : AnsiColor
  bold : Bool
  italic : Bool
  underline : Bool
}

///|
pub fn ConsoleFormat::default() -> ConsoleFormat {
  {
    foreground: Default,
    background: Default,
    bold: false,
    italic: false,
    underline: false,
  }
}

///|
pub fn ConsoleFormat::new(
  foreground? : AnsiColor = Default,
  background? : AnsiColor = Default,
  bold? : Bool = false,
  italic? : Bool = false,
  underline? : Bool = false,
) -> ConsoleFormat {
  { foreground, background, bold, italic, underline }
}

///|
pub struct FormatSpan {
  start : Int // Start index in characters
  length : Int // Length in characters
  format : ConsoleFormat
}

///|
pub fn FormatSpan::new(
  start : Int,
  length : Int,
  format : ConsoleFormat,
) -> FormatSpan {
  { start, length, format }
}

///|
fn AnsiColor::to_escape_code(self : AnsiColor, is_background : Bool) -> String {
  let prefix = if is_background { "4" } else { "3" }
  let bright_prefix = if is_background { "10" } else { "9" }
  match self {
    Default => if is_background { "49" } else { "39" }
    Black => "\{prefix}0"
    Red => "\{prefix}1"
    Green => "\{prefix}2"
    Yellow => "\{prefix}3"
    Blue => "\{prefix}4"
    Magenta => "\{prefix}5"
    Cyan => "\{prefix}6"
    White => "\{prefix}7"
    BrightBlack => "\{bright_prefix}0"
    BrightRed => "\{bright_prefix}1"
    BrightGreen => "\{bright_prefix}2"
    BrightYellow => "\{bright_prefix}3"
    BrightBlue => "\{bright_prefix}4"
    BrightMagenta => "\{bright_prefix}5"
    BrightCyan => "\{bright_prefix}6"
    BrightWhite => "\{bright_prefix}7"
    Color256(code) =>
      (if is_background { "48;5;" } else { "38;5;" }) + code.to_string()
    Rgb(r, g, b) =>
      (if is_background { "48;2;" } else { "38;2;" }) + "\{r};\{g};\{b}"
  }
}

///|
fn ConsoleFormat::to_escape_sequence(self : ConsoleFormat) -> String {
  let parts = []
  if self.bold {
    parts.push("1")
  }
  if self.italic {
    parts.push("3")
  }
  if self.underline {
    parts.push("4")
  }

  if !(self.foreground is Default) {
    parts.push(self.foreground.to_escape_code(false))
  }
  if !(self.background is Default) {
    parts.push(self.background.to_escape_code(true))
  }

  if parts is [] {
    ""
  } else {
    "\u{1b}[" + parts.join(";") + "m"
  }
}

///|
let reset_sequence : String = "\u{1b}[0m"

///|
pub fn apply_highlights(text : String, spans : Array[FormatSpan]) -> String {
  if spans.length() == 0 {
    return text
  }

  // Sort spans by start position
  let sorted_spans = spans.copy()
  sorted_spans.sort_by_key(span => span.start)

  let result = StringBuilder::new()
  let chars = text.to_array()
  let mut current_pos = 0

  for span in sorted_spans {
    if span.start < current_pos {
      continue // Overlapping spans not fully supported in this simple version
    }

    // Text before span
    if span.start > current_pos {
      for i in current_pos..<span.start {
        result.write_char(chars[i])
      }
    }

    // Span text with formatting
    result.write_string(span.format.to_escape_sequence())
    let end = @cmp.minimum(span.start + span.length, chars.length())
    for i in span.start..<end {
      result.write_char(chars[i])
    }
    result.write_string(reset_sequence)
    current_pos = end
  }

  // Remaining text
  if current_pos < chars.length() {
    for i in current_pos..<chars.length() {
      result.write_char(chars[i])
    }
  }

  result.to_string()
}
