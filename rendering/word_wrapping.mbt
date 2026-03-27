///|
pub struct WrappedLine {
  text : String
  start_index : Int
}

///|
pub struct WrappedText {
  lines : Array[WrappedLine]
  cursor_row : Int
  cursor_col : Int
}

///|
pub fn wrap_text(text : String, caret : Int, width : Int) -> WrappedText {
  if width <= 0 {
    return {
      lines: [{ text, start_index: 0 }],
      cursor_row: 0,
      cursor_col: caret,
    }
  }

  let lines = []
  let mut current_line = StringBuilder::new()
  let mut current_width = 0
  let mut cursor_row = 0
  let mut cursor_col = 0
  let mut text_index = 0
  let mut line_start_index = 0

  for ch in text {
    let w = get_string_width(ch.to_string())
    let is_cursor_here = text_index == caret

    if is_cursor_here {
      cursor_row = lines.length()
      cursor_col = current_width
    }

    if ch == '\n' || current_width + w > width {
      lines.push({
        text: current_line.to_string(),
        start_index: line_start_index,
      })
      current_line = StringBuilder::new()
      current_width = 0
      line_start_index = text_index + 1
      if ch == '\n' {
        text_index = text_index + 1
        continue
      }
    }

    current_line.write_char(ch)
    current_width = current_width + w
    text_index = text_index + 1
  }

  if text_index == caret {
    cursor_row = lines.length()
    cursor_col = current_width
  }

  lines.push({ text: current_line.to_string(), start_index: line_start_index })

  { lines, cursor_row, cursor_col }
}
