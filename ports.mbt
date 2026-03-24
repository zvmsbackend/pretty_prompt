///|
pub(open) trait ConsolePort {
  read_key(Self, intercept : Bool) -> @console.ConsoleKeyInfo
  key_available(Self) -> Bool
  is_error_redirected(Self) -> Bool
  get_cursor_top(Self) -> Int
  get_buffer_width(Self) -> Int
  get_window_height(Self) -> Int
  get_window_top(Self) -> Int
  write(Self, String) -> Unit
  write_line(Self, String) -> Unit
  write_error(Self, String) -> Unit
  write_error_line(Self, String) -> Unit
  clear(Self) -> Unit
  show_cursor(Self) -> Unit
  hide_cursor(Self) -> Unit
  get_treat_control_c_as_input(Self) -> Bool
  set_treat_control_c_as_input(Self, Bool) -> Unit
  add_cancel_key_press_handler(Self, (@console.ConsoleSpecialKey) -> Bool) -> Int
  remove_cancel_key_press_handler(Self, Int) -> Unit
}

///|
pub(open) trait ClipboardPort {
  read_text(Self) -> String raise ClipboardPortError
  write_text(Self, String) -> Unit raise ClipboardPortError
}

///|
pub suberror ClipboardPortError {
  NotAvailable
  PermissionDenied
  BackendFailure(String)
} derive(Show, Eq)

///|
pub(all) enum ControlCMode {
  CaptureAsInput
  AllowCancelSignal
} derive(Show, Eq)

///|
pub struct Ports {
  console : &ConsolePort
  clipboard : &ClipboardPort
}

///|
pub fn Ports::new(console : &ConsolePort, clipboard : &ClipboardPort) -> Ports {
  { console, clipboard }
}

///|
pub struct CancelController {
  console : &ConsolePort
  cancellation_requested : Ref[Bool]
  handler_id : Int
}

///|
pub fn CancelController::new(console : &ConsolePort) -> CancelController {
  let cancellation_requested = @ref.new(false)
  let handler_id = console.add_cancel_key_press_handler(_ => {
    cancellation_requested.val = true
    true
  })
  { console, cancellation_requested, handler_id }
}

///|
pub fn CancelController::set_mode(
  self : CancelController,
  mode : ControlCMode,
) -> Unit {
  match mode {
    CaptureAsInput => {
      self.cancellation_requested.val = false
      self.console.set_treat_control_c_as_input(true)
    }
    AllowCancelSignal => {
      self.cancellation_requested.val = false
      self.console.set_treat_control_c_as_input(false)
    }
  }
}

///|
pub fn CancelController::is_cancellation_requested(
  self : CancelController,
) -> Bool {
  self.cancellation_requested.val
}

///|
pub fn CancelController::take_cancellation_requested(
  self : CancelController,
) -> Bool {
  let requested = self.cancellation_requested.val
  self.cancellation_requested.val = false
  requested
}

///|
pub fn CancelController::dispose(self : CancelController) -> Unit {
  self.console.remove_cancel_key_press_handler(self.handler_id)
}
