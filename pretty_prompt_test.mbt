///|
using @ports {trait ConsolePort, trait ClipboardPort}

///|
struct FakeConsole {
  mut treat_control_c_as_input : Bool
  mut next_handler_id : Int
  mut add_calls : Int
  mut removed_handler_id : Int?
  mut last_handler : ((@console.ConsoleSpecialKey) -> Bool)?
  mut write_calls : Int
}

///|
fn FakeConsole::new() -> FakeConsole {
  {
    treat_control_c_as_input: false,
    next_handler_id: 1,
    add_calls: 0,
    removed_handler_id: None,
    last_handler: None,
    write_calls: 0,
  }
}

///|
fn FakeConsole::trigger_cancel(
  self : FakeConsole,
  key : @console.ConsoleSpecialKey,
) -> Bool {
  match self.last_handler {
    Some(handler) => handler(key)
    None => false
  }
}

///|
impl ConsolePort for FakeConsole with read_key(_self, _intercept) {
  @console.ConsoleKeyInfo::new('\n', @console.Enter, false, false, false)
}

///|
impl ConsolePort for FakeConsole with key_available(_self) {
  false
}

///|
impl ConsolePort for FakeConsole with is_error_redirected(_self) {
  false
}

///|
impl ConsolePort for FakeConsole with get_cursor_top(_self) {
  0
}

///|
impl ConsolePort for FakeConsole with get_cursor_left(_self) {
  0
}

///|
impl ConsolePort for FakeConsole with get_buffer_width(_self) {
  80
}

///|
impl ConsolePort for FakeConsole with get_window_height(_self) {
  25
}

///|
impl ConsolePort for FakeConsole with get_window_top(_self) {
  0
}

///|
impl ConsolePort for FakeConsole with write(self, _value) {
  self.write_calls = self.write_calls + 1
}

///|
impl ConsolePort for FakeConsole with write_line(self, _value) {
  self.write_calls = self.write_calls + 1
}

///|
impl ConsolePort for FakeConsole with write_error(self, _value) {
  self.write_calls = self.write_calls + 1
}

///|
impl ConsolePort for FakeConsole with write_error_line(self, _value) {
  self.write_calls = self.write_calls + 1
}

///|
impl ConsolePort for FakeConsole with clear(_self) {

}

///|
impl ConsolePort for FakeConsole with show_cursor(_self) {

}

///|
impl ConsolePort for FakeConsole with hide_cursor(_self) {

}

///|
impl ConsolePort for FakeConsole with get_treat_control_c_as_input(self) {
  self.treat_control_c_as_input
}

///|
impl ConsolePort for FakeConsole with set_treat_control_c_as_input(self, value) {
  self.treat_control_c_as_input = value
}

///|
impl ConsolePort for FakeConsole with add_cancel_key_press_handler(
  self,
  handler,
) {
  self.add_calls = self.add_calls + 1
  self.last_handler = Some(handler)
  let id = self.next_handler_id
  self.next_handler_id = id + 1
  id
}

///|
impl ConsolePort for FakeConsole with remove_cancel_key_press_handler(self, id) {
  self.removed_handler_id = Some(id)
  self.last_handler = None
}

///|
struct FakeClipboard {
  mut text : String
}

///|
fn FakeClipboard::new(text : String) -> FakeClipboard {
  { text, }
}

///|
impl ClipboardPort for FakeClipboard with read_text(self) {
  self.text
}

///|
impl ClipboardPort for FakeClipboard with write_text(self, text) {
  self.text = text
}

///|
test "ports use trait objects" {
  let console = FakeConsole::new()
  let clipboard = FakeClipboard::new("before")
  let ports = @pretty_prompt.Ports::new(console, clipboard)

  ports.console.write("hello")
  assert_eq(console.write_calls, 1)

  let copied = Some(ports.clipboard.read_text()) catch { _ => None }
  assert_eq(copied, Some("before"))
}

///|
test "cancel controller toggles mode and handles cancel" {
  let console = FakeConsole::new()
  let controller = @pretty_prompt.CancelController::new(console)

  assert_eq(console.add_calls, 1)

  controller.set_mode(CaptureAsInput)
  assert_true(console.treat_control_c_as_input)

  let handled = console.trigger_cancel(@console.ControlC)
  assert_true(handled)
  assert_true(controller.is_cancellation_requested())
  assert_true(controller.take_cancellation_requested())
  assert_false(controller.is_cancellation_requested())

  controller.set_mode(AllowCancelSignal)
  assert_false(console.treat_control_c_as_input)

  controller.dispose()
  assert_eq(console.removed_handler_id, Some(1))
}

///|
struct FakeInputConsole {
  keys : Array[@console.ConsoleKeyInfo]
  mut index : Int
  batch_all : Bool
  mut output : String
  mut treat_control_c_as_input : Bool
  mut next_handler_id : Int
  mut removed_handler_id : Int?
}

///|
fn FakeInputConsole::new(
  keys : Array[@console.ConsoleKeyInfo],
) -> FakeInputConsole {
  FakeInputConsole::new_with_batch(keys, false)
}

///|
fn FakeInputConsole::new_with_batch(
  keys : Array[@console.ConsoleKeyInfo],
  batch_all : Bool,
) -> FakeInputConsole {
  {
    keys,
    index: 0,
    batch_all,
    output: "",
    treat_control_c_as_input: false,
    next_handler_id: 1,
    removed_handler_id: None,
  }
}

///|
fn key(
  key_char : Char,
  key : @console.ConsoleKey,
  shift? : Bool = false,
  alt? : Bool = false,
  control? : Bool = false,
) -> @console.ConsoleKeyInfo {
  @console.ConsoleKeyInfo::new(key_char, key, shift, alt, control)
}

///|
pub impl ConsolePort for FakeInputConsole with read_key(self, _intercept) {
  if self.index >= self.keys.length() {
    return key('\n', @console.Enter)
  }
  let current = self.keys[self.index]
  self.index += 1
  current
}

///|
pub impl ConsolePort for FakeInputConsole with key_available(self) {
  self.batch_all && self.index < self.keys.length()
}

///|
pub impl ConsolePort for FakeInputConsole with is_error_redirected(_self) {
  false
}

///|
pub impl ConsolePort for FakeInputConsole with get_cursor_top(_self) {
  0
}

///|
pub impl ConsolePort for FakeInputConsole with get_cursor_left(_self) {
  0
}

///|
pub impl ConsolePort for FakeInputConsole with get_buffer_width(_self) {
  80
}

///|
pub impl ConsolePort for FakeInputConsole with get_window_height(_self) {
  24
}

///|
pub impl ConsolePort for FakeInputConsole with get_window_top(_self) {
  0
}

///|
pub impl ConsolePort for FakeInputConsole with write(self, value) {
  self.output = "\{self.output}\{value}"
}

///|
pub impl ConsolePort for FakeInputConsole with write_line(self, value) {
  self.output = "\{self.output}\{value}\n"
}

///|
pub impl ConsolePort for FakeInputConsole with write_error(self, value) {
  self.output = "\{self.output}\{value}"
}

///|
pub impl ConsolePort for FakeInputConsole with write_error_line(self, value) {
  self.output = "\{self.output}\{value}\n"
}

///|
pub impl ConsolePort for FakeInputConsole with clear(_self) {

}

///|
pub impl ConsolePort for FakeInputConsole with show_cursor(_self) {

}

///|
pub impl ConsolePort for FakeInputConsole with hide_cursor(_self) {

}

///|
pub impl ConsolePort for FakeInputConsole with get_treat_control_c_as_input(
  self,
) {
  self.treat_control_c_as_input
}

///|
pub impl ConsolePort for FakeInputConsole with set_treat_control_c_as_input(
  self,
  value,
) {
  self.treat_control_c_as_input = value
}

///|
pub impl ConsolePort for FakeInputConsole with add_cancel_key_press_handler(
  self,
  _handler,
) {
  let id = self.next_handler_id
  self.next_handler_id = id + 1
  id
}

///|
pub impl ConsolePort for FakeInputConsole with remove_cancel_key_press_handler(
  self,
  id,
) {
  self.removed_handler_id = Some(id)
}

///|
test "read_key_presses normalizes enter char" {
  let console = FakeInputConsole::new([key('\r', @console.Enter)])
  let key_presses = @pretty_prompt.read_key_presses(console)
  assert_eq(key_presses.length(), 1)
  assert_eq(key_presses[0].console_key_info.key_char, '\n')
  assert_eq(key_presses[0].console_key_info.key, @console.Enter)
  assert_eq(key_presses[0].pasted_text, None)
}

///|
test "read_key_presses returns burst as paste" {
  let console = FakeInputConsole::new_with_batch(
    [
      key('a', @console.A),
      key('b', @console.B),
      key('c', @console.C),
      key('d', @console.D),
    ],
    true,
  )
  let key_presses = @pretty_prompt.read_key_presses(console)
  assert_eq(key_presses.length(), 1)
  assert_eq(key_presses[0].console_key_info.key, @console.Insert)
  assert_eq(key_presses[0].console_key_info.shift, true)
  assert_eq(key_presses[0].pasted_text, Some("abcd"))
}

///|
test "read_key_presses keeps control burst as key presses" {
  let console = FakeInputConsole::new_with_batch(
    [
      key('\u0001', @console.A, control=true),
      key('\u0002', @console.B, control=true),
      key('\u0003', @console.C, control=true),
      key('\u0004', @console.D, control=true),
    ],
    true,
  )
  let key_presses = @pretty_prompt.read_key_presses(console)
  assert_eq(key_presses.length(), 4)
  assert_eq(key_presses[0].pasted_text, None)
  assert_eq(key_presses[3].console_key_info.key_char, '\u0004')
}

///|
async test "prompt read_line submits typed text" {
  let console = FakeInputConsole::new([
    key('h', @console.H),
    key('i', @console.I),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(result.is_success)
  assert_eq(result.text, "hi")
  assert_eq(result.submit_key_info.key, @console.Enter)
  assert_true(console.output.contains("> "))
  assert_false(console.treat_control_c_as_input)

  prompt.dispose()
  assert_eq(console.removed_handler_id, Some(1))
}

///|
async test "prompt read_line handles backspace" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('b', @console.B),
    key('\u0008', @console.Backspace),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("# "))
  assert_true(result.is_success)
  assert_eq(result.text, "a")

  prompt.dispose()
}

///|
async test "prompt read_line inserts in middle with arrows" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('c', @console.C),
    key('\u0000', @console.LeftArrow),
    key('b', @console.B),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(result.is_success)
  assert_eq(result.text, "abc")

  prompt.dispose()
}

///|
async test "prompt read_line supports delete key" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('b', @console.B),
    key('c', @console.C),
    key('\u0000', @console.LeftArrow),
    key('\u0000', @console.LeftArrow),
    key('\u0000', @console.Delete),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(result.is_success)
  assert_eq(result.text, "ac")

  prompt.dispose()
}

///|
async test "prompt read_line supports home and end" {
  let console = FakeInputConsole::new([
    key('b', @console.B),
    key('c', @console.C),
    key('\u0000', @console.Home),
    key('a', @console.A),
    key('\u0000', @console.End),
    key('d', @console.D),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(result.is_success)
  assert_eq(result.text, "abcd")

  prompt.dispose()
}

///|
async test "prompt read_line supports move word left and right" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('b', @console.B),
    key(' ', @console.A),
    key('c', @console.C),
    key('d', @console.D),
    key('\u0000', @console.LeftArrow, control=true),
    key('X', @console.X),
    key('\u0000', @console.RightArrow, control=true),
    key('Y', @console.Y),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(result.is_success)
  assert_eq(result.text, "ab XcdY")

  prompt.dispose()
}

///|
async test "prompt read_line supports backward delete word" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('b', @console.B),
    key(' ', @console.A),
    key('c', @console.C),
    key('d', @console.D),
    key('\u0017', @console.W, control=true),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(result.is_success)
  assert_eq(result.text, "ab ")

  prompt.dispose()
}

///|
async test "prompt read_line supports delete word" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('b', @console.B),
    key(' ', @console.A),
    key('c', @console.C),
    key('d', @console.D),
    key('\u0000', @console.Home),
    key('\u0000', @console.Delete, control=true),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(result.is_success)
  assert_eq(result.text, " cd")

  prompt.dispose()
}

///|
async test "prompt read_line returns cancelled on ctrl c" {
  let console = FakeInputConsole::new([key('\u0003', @console.C, control=true)])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt(FormattedString::new("$ "))
  assert_false(result.is_success)
  assert_eq(result.text, "")
  assert_eq(result.submit_key_info.key, @console.C)
  assert_eq(result.submit_key_info.control, true)

  prompt.dispose()
}

///|
async test "prompt read_line uses custom cancel key binding" {
  let console = FakeInputConsole::new([key('\u000c', @console.L, control=true)])
  let clipboard = FakeClipboard::new("")
  let cancel = @pretty_prompt.KeyPressPatterns::single(
    @pretty_prompt.KeyPressPattern::new(@console.L, control=true),
  )
  let key_bindings = @pretty_prompt.KeyBindings::new(cancel_prompt=cancel)
  let configuration = @pretty_prompt.PromptConfiguration::new(key_bindings~)
  let prompt = @pretty_prompt.Prompt::new(console, clipboard, configuration~)

  let result = prompt.read_line_with_prompt(FormattedString::new("$ "))
  assert_false(result.is_success)
  assert_eq(result.text, "")
  assert_eq(result.submit_key_info.key, @console.L)
  assert_true(result.submit_key_info.control)

  prompt.dispose()
}

///|
async test "prompt read_line uses configured default prompt" {
  let console = FakeInputConsole::new([
    key('o', @console.O),
    key('k', @console.K),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let configuration = @pretty_prompt.PromptConfiguration::new(
    prompt=FormattedString::new("pp> "),
  )
  let prompt = @pretty_prompt.Prompt::new(console, clipboard, configuration~)

  let result = prompt.read_line()
  assert_true(result.is_success)
  assert_eq(result.text, "ok")
  assert_true(console.output.contains("pp> "))

  prompt.dispose()
}

///|
async test "prompt read_line uses custom submit key binding" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('b', @console.B),
    key('\u0004', @console.D, control=true),
  ])
  let clipboard = FakeClipboard::new("")
  let submit = @pretty_prompt.KeyPressPatterns::single(
    @pretty_prompt.KeyPressPattern::new(@console.D, control=true),
  )
  let key_bindings = @pretty_prompt.KeyBindings::new(submit_prompt=submit)
  let configuration = @pretty_prompt.PromptConfiguration::new(key_bindings~)
  let prompt = @pretty_prompt.Prompt::new(console, clipboard, configuration~)

  let result = prompt.read_line()
  assert_true(result.is_success)
  assert_eq(result.text, "ab")
  assert_eq(result.submit_key_info.key, @console.D)
  assert_true(result.submit_key_info.control)

  prompt.dispose()
}

///|
async test "prompt history recalls previous entry" {
  let console = FakeInputConsole::new([
    key('f', @console.F),
    key('i', @console.I),
    key('r', @console.R),
    key('s', @console.S),
    key('t', @console.T),
    key('\n', @console.Enter),
    key('\u0000', @console.UpArrow),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let first = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(first.is_success)
  assert_eq(first.text, "first")

  let second = prompt.read_line_with_prompt(FormattedString::new("> "))
  assert_true(second.is_success)
  assert_eq(second.text, "first")

  prompt.dispose()
}

///|
async test "prompt persistent history is loaded across prompt instances" {
  let history_path = "_build/pretty_prompt_history_test.log"
  @fs.remove(history_path) catch {
    _ => ()
  }

  let history_config = @pretty_prompt.HistoryConfiguration::new(
    persistent_history_filepath=history_path,
  )
  let configuration = @pretty_prompt.PromptConfiguration::new(
    history=history_config,
  )

  let writer_console = FakeInputConsole::new([
    key('s', @console.S),
    key('a', @console.A),
    key('v', @console.V),
    key('e', @console.E),
    key('d', @console.D),
    key('\n', @console.Enter),
  ])
  let writer_prompt = @pretty_prompt.Prompt::new(
    writer_console,
    FakeClipboard::new(""),
    configuration~,
  )

  let saved = writer_prompt.read_line()
  assert_true(saved.is_success)
  assert_eq(saved.text, "saved")
  writer_prompt.dispose()

  let reader_console = FakeInputConsole::new([
    key('\u0000', @console.UpArrow),
    key('\n', @console.Enter),
  ])
  let reader_prompt = @pretty_prompt.Prompt::new(
    reader_console,
    FakeClipboard::new(""),
    configuration~,
  )

  let loaded = reader_prompt.read_line()
  assert_true(loaded.is_success)
  assert_eq(loaded.text, "saved")
  reader_prompt.dispose()

  @fs.remove(history_path) catch {
    _ => ()
  }
}
