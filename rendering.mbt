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
pub fn Cell::default() -> Cell {
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
/// 将新旧屏幕差异输出到控制台
pub fn render_diff(
  console : &ConsolePort,
  new_screen : Screen,
  old_screen : Screen,
  base_row : Int,
  base_col : Int,
) -> Unit {
  let mut current_format = ConsoleFormat::default()
  console.write("\u{1b}[0m") // 重置初始样式

  for r in 0..<new_screen.height {
    let mut row_dirty = false
    for c in 0..<new_screen.width {
      let new_cell = new_screen.rows[r][c]
      let old_cell = if r < old_screen.height && c < old_screen.width {
        old_screen.rows[r][c]
      } else {
        Cell::default()
      }

      if new_cell != old_cell {
        if !row_dirty {
          // 定位到该行的起始差异点
          let target_row = base_row + r
          let target_col = base_col + c
          console.write("\u{1b}[\{target_row};\{target_col}H")
          row_dirty = true
        }

        // 更新样式
        if !(new_cell.format.foreground == current_format.foreground &&
          new_cell.format.background == current_format.background &&
          new_cell.format.bold == current_format.bold &&
          new_cell.format.italic == current_format.italic &&
          new_cell.format.underline == current_format.underline) {
          console.write("\u{1b}[0m") // 简单处理：先重置再应用新样式
          console.write(new_cell.format.to_escape_sequence())
          current_format = new_cell.format
        }

        if new_cell.char != '\u{0000}' {
          console.write(new_cell.char.to_string())
        }
      } else {
        row_dirty = false
      }
    }
  }

  // 最后恢复光标位置
  let final_row = base_row + new_screen.cursor_row
  let final_col = base_col + new_screen.cursor_col
  console.write("\u{1b}[\{final_row};\{final_col}H")
  console.write("\u{1b}[0m")
}
