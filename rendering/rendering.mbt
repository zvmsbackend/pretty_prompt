///|
/// 屏幕上的一个单元格
pub struct Cell {
  char : Char
  format : ConsoleFormat
} derive(Eq)

///|
pub fn Cell::new(char : Char, format : ConsoleFormat) -> Cell {
  { char, format }
}

///|
pub impl Default for Cell with default() -> Cell {
  { char: ' ', format: ConsoleFormat::default() }
}

///|
/// 判断两个单元格是否完全一致（内容和样式）
pub fn Cell::op_equal(self : Cell, other : Cell) -> Bool {
  self.char == other.char &&
  self.format.foreground == other.format.foreground &&
  self.format.background == other.format.background &&
  self.format.bold == other.format.bold &&
  self.format.italic == other.format.italic &&
  self.format.underline == other.format.underline
}

///|
/// 虚拟屏幕缓冲区
pub struct Screen {
  rows : Array[Array[Cell]]
  width : Int
  height : Int
  mut cursor_row : Int
  mut cursor_col : Int
}

///|
pub fn Screen::set_cursor(self : Screen, row : Int, col : Int) -> Unit {
  self.cursor_row = row
  self.cursor_col = col
}

///|
/// 创建指定大小的空屏幕
pub fn Screen::new(height : Int, width : Int) -> Screen {
  let rows = Array::new(capacity=height)
  for _ in 0..<height {
    let row = Array::new(capacity=width)
    for _ in 0..<width {
      row.push(Cell::default())
    }
    rows.push(row)
  }
  { rows, width, height, cursor_row: 0, cursor_col: 0 }
}

///|
/// 在指定位置绘制带样式的字符串（处理 Unicode 宽度）
pub fn Screen::draw_string(
  self : Screen,
  row : Int,
  col : Int,
  text : String,
  format : ConsoleFormat,
) -> Unit {
  if row < 0 || row >= self.height {
    return
  }
  let mut current_col = col
  for ch in text {
    let w = get_char_width(ch)
    if current_col + w > self.width {
      break
    }
    if current_col >= 0 {
      self.rows[row][current_col] = Cell::new(ch, format)
      // 如果是宽字符，后续格子标记为空白以防重叠渲染逻辑出错
      if w == 2 && current_col + 1 < self.width {
        self.rows[row][current_col + 1] = Cell::new('\u{0000}', format)
      }
    }
    current_col = current_col + w
  }
}

///|
fn append_relative_cursor_move(
  output : Array[String],
  from_row : Int,
  from_col : Int,
  to_row : Int,
  to_col : Int,
) -> Unit {
  let row_delta = to_row - from_row
  if row_delta < 0 {
    output.push("\u{1b}[\{-row_delta}A")
  } else if row_delta > 0 {
    output.push("\u{1b}[\{row_delta}B")
  }

  let col_delta = to_col - from_col
  if col_delta < 0 {
    output.push("\u{1b}[\{-col_delta}D")
  } else if col_delta > 0 {
    output.push("\u{1b}[\{col_delta}C")
  }
}

///|
/// 将新旧屏幕差异输出到控制台
pub fn render_diff(
  console : &@ports.ConsolePort,
  new_screen : Screen,
  old_screen : Screen,
  base_row : Int,
  base_col : Int,
) -> Unit {
  let output = Array::new()
  let mut current_format = ConsoleFormat::default()
  output.push("\u{1b}[0m") // 重置初始样式

  // 首帧仍用绝对定位建立锚点；后续刷新使用相对移动。
  let mut cursor_row = old_screen.cursor_row
  let mut cursor_col = old_screen.cursor_col
  if old_screen.height == 0 {
    output.push("\u{1b}[\{base_row};\{base_col}H")
    cursor_row = 0
    cursor_col = 0
  }

  for r in 0..<new_screen.height {
    for c in 0..<new_screen.width {
      let new_cell = new_screen.rows[r][c]
      let old_cell = if r < old_screen.height && c < old_screen.width {
        old_screen.rows[r][c]
      } else {
        Cell::default()
      }

      if new_cell != old_cell {
        if new_cell.char == '\u{0000}' {
          continue
        }

        append_relative_cursor_move(output, cursor_row, cursor_col, r, c)
        cursor_row = r
        cursor_col = c

        // 更新样式
        if !(new_cell.format.foreground == current_format.foreground &&
          new_cell.format.background == current_format.background &&
          new_cell.format.bold == current_format.bold &&
          new_cell.format.italic == current_format.italic &&
          new_cell.format.underline == current_format.underline) {
          output.push("\u{1b}[0m") // 简单处理：先重置再应用新样式
          output.push(new_cell.format.to_escape_sequence())
          current_format = new_cell.format
        }

        output.push(new_cell.char.to_string())
        cursor_col = cursor_col + get_char_width(new_cell.char)
      }
    }
  }

  // 最后恢复光标位置
  append_relative_cursor_move(
    output,
    cursor_row,
    cursor_col,
    new_screen.cursor_row,
    new_screen.cursor_col,
  )
  output.push("\u{1b}[0m")

  console.write(output.join(""))
}
