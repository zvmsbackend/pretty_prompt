///|
fn Prompt::run_cancel_prompt_handler(
  self : Prompt,
  info : @console.ConsoleKeyInfo,
) -> PromptResult {
  self.completion_state = None
  self.overload_state = None
  self.selection = None
  self.console.write_line("")
  self.cancel_controller.set_mode(AllowCancelSignal)
  PromptResult::cancelled(info)
}

///|
async fn Prompt::run_submit_or_cancel_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.history.reset_navigation()

  if key_bindings.cancel_prompt.matches(info) || is_control_c_key(info) {
    return Return(self.run_cancel_prompt_handler(info))
  }

  if key_bindings.submit_prompt.matches(info) {
    self.completion_state = None
    self.overload_state = None
    self.selection = None
    let line = line_from_buffers(state.left, state.right)
    self.history.track_submission(line)
    self.console.write_line("")
    self.cancel_controller.set_mode(AllowCancelSignal)
    return Return(PromptResult::submitted(line, info))
  }
  NotHandled
}
