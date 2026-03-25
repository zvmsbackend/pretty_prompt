///|
fn Prompt::run_cancel_prompt_handler(
  self : Prompt,
  info : @console.ConsoleKeyInfo,
) -> PromptResult {
  self.pane_state.completion_state = None
  self.pane_state.overload_state = None
  self.pane_state.selection = None
  self.console.write_line("")
  self.cancel_controller.set_mode(AllowCancelSignal)
  PromptResult::cancelled(info)
}

///|
async fn Prompt::run_submit_or_cancel_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
) -> KeyProcessingResult {
  let info = key_press.console_key_info
  self.history.reset_navigation()

  if key_bindings.cancel_prompt.matches(info) || is_control_c_key(info) {
    return Return(self.run_cancel_prompt_handler(info))
  }

  if key_bindings.new_line.matches(info) {
    return self.insert_soft_newline(state)
  }

  if key_bindings.submit_prompt.matches(info) {
    let snapshot = self.snapshot_of(state.left, state.right)
    let should_insert_soft_newline = (self.configuration.callbacks.should_insert_soft_newline)(
      snapshot, key_press,
    )
    if should_insert_soft_newline {
      return self.insert_soft_newline(state)
    }

    self.pane_state.completion_state = None
    self.pane_state.overload_state = None
    self.pane_state.selection = None
    let line = line_from_buffers(state.left, state.right)
    self.history.track_submission(line)
    self.console.write_line("")
    self.cancel_controller.set_mode(AllowCancelSignal)
    return Return(PromptResult::submitted(line, info))
  }
  NotHandled
}

///|
fn Prompt::insert_soft_newline(
  self : Prompt,
  state : InputState,
) -> KeyProcessingResult {
  self.pane_state.completion_state = None
  self.pane_state.overload_state = None
  self.delete_selection(state.left, state.right)
  state.left.push('\n')
  self.track_undo(state.left, state.right)
  state.request_render()
  state.last_was_yank = false
  Handled
}
