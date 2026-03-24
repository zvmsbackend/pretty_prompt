///|
struct SystemConsolePort {}

///|
pub fn SystemConsolePort::new() -> SystemConsolePort {
  SystemConsolePort::{  }
}

///|
pub impl ConsolePort for SystemConsolePort with read_key(__self, intercept) {
  @console.read_key(intercept~)
}

///|
pub impl ConsolePort for SystemConsolePort with key_available(_self) {
  @console.key_available()
}

///|
pub impl ConsolePort for SystemConsolePort with is_error_redirected(_self) {
  @console.is_error_redirected()
}

///|
pub impl ConsolePort for SystemConsolePort with get_cursor_top(_self) {
  @console.get_cursor_top()
}

///|
pub impl ConsolePort for SystemConsolePort with get_buffer_width(_self) {
  @console.get_buffer_width()
}

///|
pub impl ConsolePort for SystemConsolePort with get_window_height(_self) {
  @console.get_window_height()
}

///|
pub impl ConsolePort for SystemConsolePort with get_window_top(_self) {
  @console.get_window_top()
}

///|
pub impl ConsolePort for SystemConsolePort with write(_self, value) {
  @console.write(value)
}

///|
pub impl ConsolePort for SystemConsolePort with write_line(_self, value) {
  @console.write_line(value)
}

///|
pub impl ConsolePort for SystemConsolePort with write_error(_self, value) {
  @console.error_write(value) |> ignore
}

///|
pub impl ConsolePort for SystemConsolePort with write_error_line(_self, value) {
  @console.error_write_line(value) |> ignore
}

///|
pub impl ConsolePort for SystemConsolePort with clear(_self) {
  @console.clear()
}

///|
pub impl ConsolePort for SystemConsolePort with show_cursor(_self) {
  @console.show_cursor()
}

///|
pub impl ConsolePort for SystemConsolePort with hide_cursor(_self) {
  @console.hide_cursor()
}

///|
pub impl ConsolePort for SystemConsolePort with get_treat_control_c_as_input(
  _self,
) {
  @console.get_treat_control_c_as_input()
}

///|
pub impl ConsolePort for SystemConsolePort with set_treat_control_c_as_input(
  _self,
  value,
) {
  @console.set_treat_control_c_as_input(value)
}

///|
pub impl ConsolePort for SystemConsolePort with add_cancel_key_press_handler(
  _self,
  handler,
) {
  @console.add_cancel_key_press_handler(handler)
}

///|
pub impl ConsolePort for SystemConsolePort with remove_cancel_key_press_handler(
  _self,
  id,
) {
  @console.remove_cancel_key_press_handler(id)
}

///|
pub struct SystemClipboardPort {}

///|
pub fn SystemClipboardPort::new() -> SystemClipboardPort {
  SystemClipboardPort::{  }
}

///|
fn map_clipboard_error(error : @clipboard.ClipboardError) -> ClipboardPortError {
  match error {
    NotAvailable => NotAvailable
    PermissionDenied => PermissionDenied
    BackendFailure(message) => BackendFailure(message)
  }
}

///|
pub impl ClipboardPort for SystemClipboardPort with read_text(_self) {
  @clipboard.read_text() catch {
    error => raise map_clipboard_error(error)
  }
}

///|
pub impl ClipboardPort for SystemClipboardPort with write_text(_self, text) {
  @clipboard.write_text(text) catch {
    error => raise map_clipboard_error(error)
  }
}
