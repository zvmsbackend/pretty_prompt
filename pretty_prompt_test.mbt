///|
struct FakeConsole {
  treat_control_c_as_input : Ref[Bool]
  next_handler_id : Ref[Int]
  add_calls : Ref[Int]
  removed_handler_id : Ref[Int?]
  last_handler : Ref[((@console.ConsoleSpecialKey) -> Bool)?]
  write_calls : Ref[Int]
}

///|
fn FakeConsole::new() -> FakeConsole {
  {
    treat_control_c_as_input: @ref.new(false),
    next_handler_id: @ref.new(1),
    add_calls: @ref.new(0),
    removed_handler_id: @ref.new(None),
    last_handler: @ref.new(None),
    write_calls: @ref.new(0),
  }
}

///|
fn FakeConsole::trigger_cancel(
  self : FakeConsole,
  key : @console.ConsoleSpecialKey,
) -> Bool {
  match self.last_handler.val {
    Some(handler) => handler(key)
    None => false
  }
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with read_key(self, _intercept) {
  self |> ignore
  @console.ConsoleKeyInfo::new('\n', @console.Enter, false, false, false)
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with key_available(self) {
  self |> ignore
  false
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with is_error_redirected(self) {
  self |> ignore
  false
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with get_cursor_top(self) {
  self |> ignore
  0
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with get_buffer_width(self) {
  self |> ignore
  80
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with get_window_height(self) {
  self |> ignore
  25
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with get_window_top(self) {
  self |> ignore
  0
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with write(self, _value) {
  self.write_calls.val = self.write_calls.val + 1
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with write_line(self, _value) {
  self.write_calls.val = self.write_calls.val + 1
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with write_error(self, _value) {
  self.write_calls.val = self.write_calls.val + 1
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with write_error_line(
  self,
  _value,
) {
  self.write_calls.val = self.write_calls.val + 1
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with clear(self) {
  self |> ignore
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with show_cursor(self) {
  self |> ignore
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with hide_cursor(self) {
  self |> ignore
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with get_treat_control_c_as_input(
  self,
) {
  self.treat_control_c_as_input.val
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with set_treat_control_c_as_input(
  self,
  value,
) {
  self.treat_control_c_as_input.val = value
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with add_cancel_key_press_handler(
  self,
  handler,
) {
  self.add_calls.val = self.add_calls.val + 1
  self.last_handler.val = Some(handler)
  let id = self.next_handler_id.val
  self.next_handler_id.val = id + 1
  id
}

///|
impl @pretty_prompt.ConsolePort for FakeConsole with remove_cancel_key_press_handler(
  self,
  id,
) {
  self.removed_handler_id.val = Some(id)
  self.last_handler.val = None
}

///|
struct FakeClipboard {
  text : Ref[String]
}

///|
fn FakeClipboard::new(text : String) -> FakeClipboard {
  { text: @ref.new(text) }
}

///|
impl @pretty_prompt.ClipboardPort for FakeClipboard with read_text(self) {
  self.text.val
}

///|
impl @pretty_prompt.ClipboardPort for FakeClipboard with write_text(self, text) {
  self.text.val = text
}

///|
test "ports use trait objects" {
  let console = FakeConsole::new()
  let clipboard = FakeClipboard::new("before")
  let ports = @pretty_prompt.Ports::new(console, clipboard)

  ports.console.write("hello")
  assert_eq(console.write_calls.val, 1)

  let copied = Some(ports.clipboard.read_text()) catch { _ => None }
  assert_eq(copied, Some("before"))
}

///|
test "cancel controller toggles mode and handles cancel" {
  let console = FakeConsole::new()
  let controller = @pretty_prompt.CancelController::new(console)

  assert_eq(console.add_calls.val, 1)

  controller.set_mode(@pretty_prompt.CaptureAsInput)
  assert_true(console.treat_control_c_as_input.val)

  let handled = console.trigger_cancel(@console.ControlC)
  assert_true(handled)
  assert_true(controller.is_cancellation_requested())
  assert_true(controller.take_cancellation_requested())
  assert_false(controller.is_cancellation_requested())

  controller.set_mode(@pretty_prompt.AllowCancelSignal)
  assert_false(console.treat_control_c_as_input.val)

  controller.dispose()
  assert_eq(console.removed_handler_id.val, Some(1))
}

///|
struct FakeInputConsole {
  keys : Array[@console.ConsoleKeyInfo]
  index : Ref[Int]
  batch_all : Bool
  output : Ref[String]
  treat_control_c_as_input : Ref[Bool]
  next_handler_id : Ref[Int]
  removed_handler_id : Ref[Int?]
  last_handler : Ref[((@console.ConsoleSpecialKey) -> Bool)?]
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
    index: @ref.new(0),
    batch_all,
    output: @ref.new(""),
    treat_control_c_as_input: @ref.new(false),
    next_handler_id: @ref.new(1),
    removed_handler_id: @ref.new(None),
    last_handler: @ref.new(None),
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
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with read_key(
  self,
  _intercept,
) {
  if self.index.val >= self.keys.length() {
    return key('\n', @console.Enter)
  }
  let current = self.keys[self.index.val]
  self.index.val = self.index.val + 1
  current
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with key_available(
  self,
) {
  self.batch_all && self.index.val < self.keys.length()
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with is_error_redirected(
  self,
) {
  self |> ignore
  false
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with get_cursor_top(
  self,
) {
  self |> ignore
  0
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with get_buffer_width(
  self,
) {
  self |> ignore
  80
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with get_window_height(
  self,
) {
  self |> ignore
  24
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with get_window_top(
  self,
) {
  self |> ignore
  0
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with write(self, value) {
  self.output.val = "\{self.output.val}\{value}"
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with write_line(
  self,
  value,
) {
  self.output.val = "\{self.output.val}\{value}\n"
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with write_error(
  self,
  value,
) {
  self.output.val = "\{self.output.val}\{value}"
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with write_error_line(
  self,
  value,
) {
  self.output.val = "\{self.output.val}\{value}\n"
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with clear(self) {
  self |> ignore
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with show_cursor(self) {
  self |> ignore
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with hide_cursor(self) {
  self |> ignore
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with get_treat_control_c_as_input(
  self,
) {
  self.treat_control_c_as_input.val
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with set_treat_control_c_as_input(
  self,
  value,
) {
  self.treat_control_c_as_input.val = value
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with add_cancel_key_press_handler(
  self,
  handler,
) {
  self.last_handler.val = Some(handler)
  let id = self.next_handler_id.val
  self.next_handler_id.val = id + 1
  id
}

///|
pub impl @pretty_prompt.ConsolePort for FakeInputConsole with remove_cancel_key_press_handler(
  self,
  id,
) {
  self.removed_handler_id.val = Some(id)
  self.last_handler.val = None
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
test "prompt read_line submits typed text" {
  let console = FakeInputConsole::new([
    key('h', @console.H),
    key('i', @console.I),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt("> ")
  assert_true(result.is_success)
  assert_eq(result.text, "hi")
  assert_eq(result.submit_key_info.key, @console.Enter)
  assert_true(console.output.val.contains("> "))
  assert_false(console.treat_control_c_as_input.val)

  prompt.dispose()
  assert_eq(console.removed_handler_id.val, Some(1))
}

///|
test "prompt read_line handles backspace" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('b', @console.B),
    key('\u0008', @console.Backspace),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt("# ")
  assert_true(result.is_success)
  assert_eq(result.text, "a")

  prompt.dispose()
}

///|
test "prompt read_line inserts in middle with arrows" {
  let console = FakeInputConsole::new([
    key('a', @console.A),
    key('c', @console.C),
    key('\u0000', @console.LeftArrow),
    key('b', @console.B),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt("> ")
  assert_true(result.is_success)
  assert_eq(result.text, "abc")

  prompt.dispose()
}

///|
test "prompt read_line supports delete key" {
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

  let result = prompt.read_line_with_prompt("> ")
  assert_true(result.is_success)
  assert_eq(result.text, "ac")

  prompt.dispose()
}

///|
test "prompt read_line supports home and end" {
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

  let result = prompt.read_line_with_prompt("> ")
  assert_true(result.is_success)
  assert_eq(result.text, "abcd")

  prompt.dispose()
}

///|
test "prompt read_line returns cancelled on ctrl c" {
  let console = FakeInputConsole::new([key('\u0003', @console.C, control=true)])
  let clipboard = FakeClipboard::new("")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard)

  let result = prompt.read_line_with_prompt("$ ")
  assert_false(result.is_success)
  assert_eq(result.text, "")
  assert_eq(result.submit_key_info.key, @console.C)
  assert_eq(result.submit_key_info.control, true)

  prompt.dispose()
}

///|
test "prompt read_line uses configured default prompt" {
  let console = FakeInputConsole::new([
    key('o', @console.O),
    key('k', @console.K),
    key('\n', @console.Enter),
  ])
  let clipboard = FakeClipboard::new("")
  let configuration = @pretty_prompt.PromptConfiguration::new(prompt="pp> ")
  let prompt = @pretty_prompt.Prompt::new(console, clipboard, configuration~)

  let result = prompt.read_line()
  assert_true(result.is_success)
  assert_eq(result.text, "ok")
  assert_true(console.output.val.contains("pp> "))

  prompt.dispose()
}

///|
test "prompt read_line uses custom submit key binding" {
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
test "prompt history recalls previous entry" {
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

  let first = prompt.read_line_with_prompt("> ")
  assert_true(first.is_success)
  assert_eq(first.text, "first")

  let second = prompt.read_line_with_prompt("> ")
  assert_true(second.is_success)
  assert_eq(second.text, "first")

  prompt.dispose()
}

///|
test "prompt persistent history is loaded across prompt instances" {
  let history_path = "_build/pretty_prompt_history_test.log"
  @fs.remove_file(history_path) catch {
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

  @fs.remove_file(history_path) catch {
    _ => ()
  }
}
