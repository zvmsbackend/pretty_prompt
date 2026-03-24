///|
priv enum KeyProcessingResult {
  Handled
  NotHandled
  Return(PromptResult)
}

///|
priv struct InputState {
  left : Array[Char]
  right : Array[Char]
  mut last_was_yank : Bool
}

///|
fn InputState::new() -> InputState {
  { left: [], right: [], last_was_yank: false }
}

///|
priv enum HandlerStage {
  SearchMode
  NavigationModes
  SearchTrigger
  SelectionClipboard
  KillRing
  SelectionMovement
  UndoRedo
  CompletionAndHistory
  SubmitOrCancel
  EditKeys
  CharacterInput
}

///|
fn default_handler_stages() -> Array[HandlerStage] {
  [
    SearchMode,
    NavigationModes,
    SearchTrigger,
    SelectionClipboard,
    KillRing,
    SelectionMovement,
    UndoRedo,
    CompletionAndHistory,
    SubmitOrCancel,
    EditKeys,
    CharacterInput,
  ]
}

///|
async fn Prompt::run_key_handler_pipeline(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
  stages : Array[HandlerStage],
) -> KeyProcessingResult {
  for stage in stages {
    let result = self.execute_handler_stage(
      prompt, state, key_bindings, info, stage,
    )
    if !(result is NotHandled) {
      return result
    }
  }
  NotHandled
}

///|
async fn Prompt::execute_handler_stage(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
  stage : HandlerStage,
) -> KeyProcessingResult {
  match stage {
    SearchMode => self.handle_search_mode(prompt, state, key_bindings, info)
    NavigationModes =>
      self.handle_navigation_modes(prompt, state, key_bindings, info)
    SearchTrigger =>
      self.handle_search_trigger(prompt, state, key_bindings, info)
    SelectionClipboard =>
      self.handle_selection_clipboard(prompt, state, key_bindings, info)
    KillRing => self.handle_kill_ring(prompt, state, key_bindings, info)
    SelectionMovement =>
      self.handle_selection_movement_keys(prompt, state, key_bindings, info)
    UndoRedo => self.handle_undo_redo(prompt, state, key_bindings, info)
    CompletionAndHistory =>
      self.handle_completion_and_history(prompt, state, key_bindings, info)
    SubmitOrCancel => self.handle_submit_or_cancel(state, key_bindings, info)
    EditKeys => self.handle_edit_keys(prompt, state, key_bindings, info)
    CharacterInput => self.handle_character_input(prompt, state, info)
  }
}
