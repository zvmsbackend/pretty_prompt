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

  let copied = ports.clipboard.read_text() catch {
    _ => abort("clipboard read should succeed")
  }
  assert_eq(copied, "before")
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
