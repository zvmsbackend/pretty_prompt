///|
using @ports {trait ConsolePort}

///|
struct RenderCaptureConsole {
  mut output : String
  mut write_calls : Int
}

///|
fn RenderCaptureConsole::new() -> RenderCaptureConsole {
  { output: "", write_calls: 0 }
}

///|
impl ConsolePort for RenderCaptureConsole with read_key(_self, _intercept) {
  @console.ConsoleKeyInfo::new('\n', Enter, false, false, false)
}

///|
impl ConsolePort for RenderCaptureConsole with key_available(_self) {
  false
}

///|
impl ConsolePort for RenderCaptureConsole with is_error_redirected(_self) {
  false
}

///|
impl ConsolePort for RenderCaptureConsole with get_cursor_top(_self) {
  0
}

///|
impl ConsolePort for RenderCaptureConsole with get_cursor_left(_self) {
  0
}

///|
impl ConsolePort for RenderCaptureConsole with get_buffer_width(_self) {
  80
}

///|
impl ConsolePort for RenderCaptureConsole with get_window_height(_self) {
  24
}

///|
impl ConsolePort for RenderCaptureConsole with get_window_top(_self) {
  0
}

///|
impl ConsolePort for RenderCaptureConsole with write(self, value) {
  self.write_calls = self.write_calls + 1
  self.output = "\{self.output}\{value}"
}

///|
impl ConsolePort for RenderCaptureConsole with write_line(self, value) {
  self.write_calls = self.write_calls + 1
  self.output = "\{self.output}\{value}\n"
}

///|
impl ConsolePort for RenderCaptureConsole with write_error(self, value) {
  self.write_calls = self.write_calls + 1
  self.output = "\{self.output}\{value}"
}

///|
impl ConsolePort for RenderCaptureConsole with write_error_line(self, value) {
  self.write_calls = self.write_calls + 1
  self.output = "\{self.output}\{value}\n"
}

///|
impl ConsolePort for RenderCaptureConsole with clear(_self) {

}

///|
impl ConsolePort for RenderCaptureConsole with show_cursor(_self) {

}

///|
impl ConsolePort for RenderCaptureConsole with hide_cursor(_self) {

}

///|
impl ConsolePort for RenderCaptureConsole with get_treat_control_c_as_input(
  _self,
) {
  false
}

///|
impl ConsolePort for RenderCaptureConsole with set_treat_control_c_as_input(
  _self,
  _value,
) {

}

///|
impl ConsolePort for RenderCaptureConsole with add_cancel_key_press_handler(
  _self,
  _handler,
) {
  1
}

///|
impl ConsolePort for RenderCaptureConsole with remove_cancel_key_press_handler(
  _self,
  _id,
) {

}

///|
test "draw_string stores full-width placeholder" {
  let screen = Screen::new(1, 6)
  screen.draw_string(0, 0, "你a", ConsoleFormat::default())

  assert_eq(screen.rows[0][0].char, '你')
  assert_eq(screen.rows[0][1].char, '\u{0000}')
  assert_eq(screen.rows[0][2].char, 'a')
}

///|
test "render_diff first frame anchors once and writes once" {
  let console = RenderCaptureConsole::new()
  let old_screen = Screen::new(0, 10)
  let new_screen = Screen::new(1, 10)
  new_screen.draw_string(0, 0, "ab", ConsoleFormat::default())
  new_screen.set_cursor(0, 2)

  render_diff(console, new_screen, old_screen, 3, 5)

  assert_eq(console.write_calls, 1)
  assert_true(console.output.contains("\u{1b}[3;5H"))
  assert_true(console.output.contains("ab"))
}

///|
test "render_diff incremental update uses relative move" {
  let console = RenderCaptureConsole::new()
  let old_screen = Screen::new(1, 8)
  let new_screen = Screen::new(1, 8)
  old_screen.draw_string(0, 0, "abc", ConsoleFormat::default())
  new_screen.draw_string(0, 0, "abx", ConsoleFormat::default())
  old_screen.set_cursor(0, 3)
  new_screen.set_cursor(0, 3)

  render_diff(console, new_screen, old_screen, 9, 9)

  assert_eq(console.write_calls, 1)
  assert_true(console.output.contains("\u{1b}[1D"))
  assert_true(console.output.contains("x"))
  assert_false(console.output.contains("\u{1b}[9;9H"))
}
