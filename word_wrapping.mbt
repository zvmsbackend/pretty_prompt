///|
/// 自动换行结果
pub struct WrappedText {
  lines : Array[String]
  cursor_row : Int
  cursor_col : Int
}

///|
/// 根据宽度对文本进行折行处理
pub fn wrap_text(text : String, caret : Int, width : Int) -> WrappedText {
  if width <= 0 {
    return { lines: [text], cursor_row: 0, cursor_col: caret }
  }

  let lines = []
  let mut current_line = StringBuilder::new()
  let mut current_width = 0
  let mut cursor_row = 0
  let mut cursor_col = 0
  let mut text_index = 0

  for ch in text {
    let w = get_char_width(ch)
    let is_cursor_here = text_index == caret

    if is_cursor_here {
      cursor_row = lines.length()
      cursor_col = current_width
    }

    // 处理显式换行符或达到宽度上限
    if ch == '\n' || current_width + w > width {
      lines.push(current_line.to_string())
      current_line = StringBuilder::new()
      current_width = 0
      if ch == '\n' {
        text_index = text_index + 1
        continue
      }
    }

    current_line.write_char(ch)
    current_width = current_width + w
    text_index = text_index + 1
  }

  // 处理末尾光标
  if text_index == caret {
    cursor_row = lines.length()
    cursor_col = current_width
  }

  lines.push(current_line.to_string())

  { lines, cursor_row, cursor_col }
}
