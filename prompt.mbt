///|
pub struct Prompt {
  console : &ConsolePort
  clipboard : &ClipboardPort
  cancel_controller : CancelController
}

///|
pub fn Prompt::new(
  console : &ConsolePort,
  clipboard : &ClipboardPort,
) -> Prompt {
  let cancel_controller = CancelController::new(console)
  { console, clipboard, cancel_controller }
}

///|
pub fn Prompt::read_line(
  self : Prompt,
  prompt? : String = "> ",
) -> PromptResult {
  self.cancel_controller.set_mode(CaptureAsInput)
  self.console.write(prompt)
  let left : Array[Char] = []

  while true {
    if self.cancel_controller.take_cancellation_requested() {
      self.console.write_line("")
      return cancel_result()
    }

    let key_presses = read_key_presses(self.console)
    for key_press in key_presses {
      if key_press.pasted_text is Some(pasted) {
        append_text(left, pasted)
        self.console.write(pasted)
        continue
      }

      let info = key_press.console_key_info
      if info.control && info.key is @console.C {
        self.console.write_line("")
        self.cancel_controller.set_mode(AllowCancelSignal)
        return PromptResult::cancelled(info)
      }

      match info.key {
        Enter => {
          self.console.write_line("")
          self.cancel_controller.set_mode(AllowCancelSignal)
          return PromptResult::submitted(String::from_array(left), info)
        }
        Backspace =>
          if left.pop() is Some(_) {
            self.console.write("\u{8} \u{8}")
          }
        _ => {
          let ch = info.key_char
          if !ch.is_control() {
            left.push(ch)
            self.console.write(ch.to_string())
          }
        }
      }
    }
  }
  cancel_result()
}

///|
pub fn Prompt::take_execution_cancellation_requested(self : Prompt) -> Bool {
  self.cancel_controller.take_cancellation_requested()
}

///|
pub fn Prompt::dispose(self : Prompt) -> Unit {
  self.cancel_controller.dispose()
}

///|
fn append_text(target : Array[Char], text : String) -> Unit {
  for ch in text {
    target.push(ch)
  }
}

///|
fn cancel_result() -> PromptResult {
  let key_info = @console.ConsoleKeyInfo::new(
    '\u0003',
    @console.C,
    false,
    false,
    true,
  )
  PromptResult::cancelled(key_info)
}

///|
pub struct PromptResult {
  is_success : Bool
  text : String
  submit_key_info : @console.ConsoleKeyInfo
}

///|
pub fn PromptResult::submitted(
  text : String,
  submit_key_info : @console.ConsoleKeyInfo,
) -> PromptResult {
  { is_success: true, text, submit_key_info }
}

///|
pub fn PromptResult::cancelled(
  submit_key_info : @console.ConsoleKeyInfo,
) -> PromptResult {
  { is_success: false, text: "", submit_key_info }
}
