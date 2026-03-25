///|
using @ports {trait ConsolePort}

///|
struct RenderingConsole {
  mut output : String
  mut write_calls : Int
}

///|
fn RenderingConsole::new() -> RenderingConsole {
  { output: "", write_calls: 0 }
}

///|
impl ConsolePort for RenderingConsole with read_key(self, intercept) {
  self.read_key(intercept)
}

///|
impl ConsolePort for RenderingConsole with key_available(_self) {
  false
}

///|
impl ConsolePort for RenderingConsole with is_error_redirected(_self) {
  false
}

///|
impl ConsolePort for RenderingConsole with get_cursor_top(_self) {
  0
}

///|
impl ConsolePort for RenderingConsole with get_cursor_left(_self) {
  0
}

///|
impl ConsolePort for RenderingConsole with get_buffer_width(_self) {
  80
}

///|
impl ConsolePort for RenderingConsole with get_window_height(_self) {
  24
}

///|
impl ConsolePort for RenderingConsole with get_window_top(_self) {
  0
}

///|
impl ConsolePort for RenderingConsole with write(self, value) {
  self.write_calls = self.write_calls + 1
  self.output = "\{self.output}\{value}"
}

///|
impl ConsolePort for RenderingConsole with write_line(self, value) {
  self.write_calls = self.write_calls + 1
  self.output = "\{self.output}\{value}\n"
}

///|
impl ConsolePort for RenderingConsole with write_error(self, value) {
  self.write_calls = self.write_calls + 1
  self.output = "\{self.output}\{value}"
}

///|
impl ConsolePort for RenderingConsole with write_error_line(self, value) {
  self.write_calls = self.write_calls + 1
  self.output = "\{self.output}\{value}\n"
}

///|
impl ConsolePort for RenderingConsole with clear(_self) {

}

///|
impl ConsolePort for RenderingConsole with show_cursor(_self) {

}

///|
impl ConsolePort for RenderingConsole with hide_cursor(_self) {

}

///|
impl ConsolePort for RenderingConsole with get_treat_control_c_as_input(_self) {
  false
}

///|
impl ConsolePort for RenderingConsole with set_treat_control_c_as_input(
  _self,
  _value,
) {

}

///|
impl ConsolePort for RenderingConsole with add_cancel_key_press_handler(
  _self,
  _handler,
) {
  1
}

///|
impl ConsolePort for RenderingConsole with remove_cancel_key_press_handler(
  _self,
  _id,
) {

}

///|
test "draw_string ignores out-of-range row" {
  let screen = Screen::new(1, 4)
  screen.draw_string(-1, 0, "abc", ConsoleFormat::default())

  assert_eq(screen.rows[0][0].char, ' ')
  assert_eq(screen.rows[0][1].char, ' ')
}

///|
test "draw_string stops when line width reached" {
  let screen = Screen::new(1, 3)
  screen.draw_string(0, 0, "abcd", ConsoleFormat::default())

  assert_eq(screen.rows[0][0].char, 'a')
  assert_eq(screen.rows[0][1].char, 'b')
  assert_eq(screen.rows[0][2].char, 'c')
}

///|
test "render_diff moves cursor up on incremental update" {
  let console = RenderingConsole::new()
  let old_screen = Screen::new(2, 5)
  let new_screen = Screen::new(2, 5)

  old_screen.set_cursor(1, 0)
  new_screen.draw_string(0, 0, "x", ConsoleFormat::default())
  new_screen.set_cursor(0, 1)

  render_diff(console, new_screen, old_screen, 1, 1)

  assert_eq(console.write_calls, 1)
  assert_true(console.output.contains("\u{1b}[1A"))
}

///|
test "render_diff moves cursor down on incremental update" {
  let console = RenderingConsole::new()
  let old_screen = Screen::new(2, 5)
  let new_screen = Screen::new(2, 5)

  old_screen.set_cursor(0, 0)
  new_screen.draw_string(1, 0, "x", ConsoleFormat::default())
  new_screen.set_cursor(1, 1)

  render_diff(console, new_screen, old_screen, 1, 1)

  assert_eq(console.write_calls, 1)
  assert_true(console.output.contains("\u{1b}[1B"))
}

///|
test "render_diff applies style escape when format changes" {
  let console = RenderingConsole::new()
  let old_screen = Screen::new(1, 4)
  let new_screen = Screen::new(1, 4)
  new_screen.draw_string(0, 0, "a", ConsoleFormat::new(bold=true))
  new_screen.set_cursor(0, 1)

  render_diff(console, new_screen, old_screen, 1, 1)

  assert_eq(console.write_calls, 1)
  assert_true(console.output.contains("\u{1b}[1m"))
}

///|
test "unicode width handles control combining and emoji" {
  assert_eq(get_char_width('\u{0000}'), 0)
  assert_eq(get_char_width('\n'), 1)
  assert_eq(get_char_width('\u{0301}'), 0)
  assert_eq(get_char_width('✅'), 2)
}

///|
test "word boundary checks whitespace and type transitions" {
  assert_true(is_word_boundary(Some(' '), Some('a')))
  assert_false(is_word_boundary(Some('a'), Some(' ')))
  assert_true(is_word_boundary(Some('a'), Some('_')))
  assert_false(is_word_boundary(None, Some('a')))
}

///|
test "wrap_text handles zero width and explicit newline" {
  let zero = wrap_text("abc", 2, 0)
  assert_eq(zero.lines, ["abc"])
  assert_eq(zero.cursor_row, 0)
  assert_eq(zero.cursor_col, 2)

  let wrapped = wrap_text("ab\ncd", 3, 10)
  assert_eq(wrapped.lines.length(), 2)
  assert_eq(wrapped.lines[0], "ab")
  assert_eq(wrapped.lines[1], "cd")
}

///|
test "cell equality compares char and format fields" {
  let f1 = ConsoleFormat::new(foreground=Red, bold=true)
  let f2 = ConsoleFormat::new(foreground=Red, bold=true)
  let f3 = ConsoleFormat::new(foreground=Blue, bold=true)
  assert_true(Cell::new('x', f1) == Cell::new('x', f2))
  assert_false(Cell::new('x', f1) == Cell::new('x', f3))
}

///|
test "draw_string writes full-width placeholder cell" {
  let screen = Screen::new(1, 4)
  screen.draw_string(0, 0, "你a", ConsoleFormat::default())
  assert_eq(screen.rows[0][0].char, '你')
  assert_eq(screen.rows[0][1].char, '\u{0000}')
  assert_eq(screen.rows[0][2].char, 'a')
}

///|
test "render_diff skips placeholder sentinel cell" {
  let console = RenderingConsole::new()
  let old_screen = Screen::new(1, 4)
  let new_screen = Screen::new(1, 4)
  new_screen.rows[0][0] = Cell::new('\u{0000}', ConsoleFormat::default())
  new_screen.set_cursor(0, 0)

  render_diff(console, new_screen, old_screen, 1, 1)

  // ensure placeholder character is not emitted
  assert_false(console.output.contains("\u{0000}"))
}

///|
test "render_diff clears rows removed from previous frame" {
  let console = RenderingConsole::new()
  let old_screen = Screen::new(2, 5)
  let new_screen = Screen::new(1, 5)
  old_screen.draw_string(1, 0, "menu", ConsoleFormat::default())
  old_screen.set_cursor(0, 0)
  new_screen.set_cursor(0, 0)

  render_diff(console, new_screen, old_screen, 1, 1)

  assert_true(console.output.contains("\u{1b}[1B"))
  assert_true(console.output.contains("    "))
}

///|
test "unicode width covers control box and wide-range branches" {
  assert_eq(get_char_width('\u{007f}'), 0)
  assert_eq(get_char_width('\u{2501}'), 1)
  assert_eq(get_char_width('你'), 2)
  assert_eq(get_char_width('a'), 1)
}

///|
test "apply_highlights handles empty spans and style variants" {
  let plain = apply_highlights("abc", [])
  assert_eq(plain, "abc")

  let styled = apply_highlights("abcXYZ", [
    FormatSpan::new(
      3,
      3,
      ConsoleFormat::new(
        foreground=Magenta,
        background=Color256(21),
        italic=true,
      ),
    ),
    // overlapping span should be skipped by current implementation
    FormatSpan::new(4, 1, ConsoleFormat::new(underline=true)),
    FormatSpan::new(0, 1, ConsoleFormat::new(background=Rgb(1, 2, 3))),
  ])

  assert_true(styled.contains("\u{1b}[3;35;48;5;21m"))
  assert_true(styled.contains("\u{1b}[48;2;1;2;3m"))
  assert_true(styled.contains("\u{1b}[0m"))
  assert_true(styled.contains("a"))
  assert_true(styled.contains("XYZ"))
}

///|
test "format escape covers default and bright colors" {
  let fg_default = apply_highlights("a", [
    FormatSpan::new(0, 1, ConsoleFormat::new(foreground=Default)),
  ])
  let bright = apply_highlights("b", [
    FormatSpan::new(
      0,
      1,
      ConsoleFormat::new(foreground=BrightWhite, background=BrightBlue),
    ),
  ])
  assert_true(fg_default.contains("a"))
  assert_true(bright.contains("\u{1b}[97;104m"))
}

///|
test "highlight color mapping covers default white and bright magenta" {
  let s1 = apply_highlights("w", [
    FormatSpan::new(0, 1, ConsoleFormat::new(foreground=White)),
  ])
  let s2 = apply_highlights("m", [
    FormatSpan::new(
      0,
      1,
      ConsoleFormat::new(foreground=BrightMagenta, background=Default),
    ),
  ])
  assert_true(s1.contains("\u{1b}[37m"))
  assert_true(s2.contains("\u{1b}[95m"))
}

///|
test "apply_highlights keeps trailing text after last span" {
  let out = apply_highlights("abcdef", [
    FormatSpan::new(1, 2, ConsoleFormat::new(foreground=Cyan)),
  ])
  assert_true(out.contains("def"))
}

///|
test "unicode width falls back to width one for non-wide non-combining" {
  // Greek alpha takes the fallback width=1 branch in the final match.
  assert_eq(get_char_width('α'), 1)
}
