///|
priv enum KeyProcessingResult {
  Handled
  NotHandled
  Return(PromptResult)
}

///|
priv enum KeyPhase {
  KeyDown
  KeyUp
}

///|
priv struct InputState {
  left : Array[Char]
  right : Array[Char]
  mut last_was_yank : Bool
  mut render_requested : Bool
}

///|
fn InputState::new() -> InputState {
  { left: [], right: [], last_was_yank: false, render_requested: false }
}

///|
fn InputState::request_render(self : InputState) -> Unit {
  self.render_requested = true
}

///|
fn InputState::take_render_requested(self : InputState) -> Bool {
  let requested = self.render_requested
  self.render_requested = false
  requested
}

///|
priv enum KeyHandlerEntry {
  SearchModeHandler
  NavigationModesHandler
  SearchTriggerHandler
  SelectionClipboardHandler
  KillRingHandler
  SelectionMovementHandler
  UndoRedoHandler
  CompletionAndHistoryHandler
  SubmitOrCancelHandler
  EditKeysHandler
  CharacterInputHandler
}

///|
priv trait KeyHandler {
  supports_phase(Self, KeyPhase) -> Bool
  async handle(
    Self,
    Prompt,
    FormattedString,
    InputState,
    KeyBindings,
    @console.ConsoleKeyInfo,
    KeyPhase,
  ) -> KeyProcessingResult
}

///|
impl KeyHandler for KeyHandlerEntry with supports_phase(self, phase) {
  match phase {
    KeyDown => true
    KeyUp => self is CharacterInputHandler
  }
}

///|
impl KeyHandler for KeyHandlerEntry with handle(
  self,
  runtime,
  prompt,
  state,
  key_bindings,
  info,
  phase,
) {
  match phase {
    KeyDown =>
      match self {
        SearchModeHandler =>
          runtime.handle_search_mode(state, key_bindings, info)
        NavigationModesHandler =>
          runtime.handle_navigation_modes(state, key_bindings, info)
        SearchTriggerHandler =>
          runtime.handle_search_trigger(state, key_bindings, info)
        SelectionClipboardHandler =>
          runtime.handle_selection_clipboard(state, key_bindings, info)
        KillRingHandler => runtime.handle_kill_ring(state, key_bindings, info)
        SelectionMovementHandler =>
          runtime.handle_selection_movement_keys(state, key_bindings, info)
        UndoRedoHandler => runtime.handle_undo_redo(state, key_bindings, info)
        CompletionAndHistoryHandler =>
          runtime.handle_completion_and_history(state, key_bindings, info)
        SubmitOrCancelHandler =>
          runtime.handle_submit_or_cancel(state, key_bindings, info)
        EditKeysHandler => runtime.handle_edit_keys(state, key_bindings, info)
        CharacterInputHandler => runtime.handle_character_input(state, info)
      }
    KeyUp => runtime.commit_requested_render(prompt, state)
  }
}

///|
fn default_key_handler_entries() -> Array[KeyHandlerEntry] {
  [
    SearchModeHandler,
    NavigationModesHandler,
    SearchTriggerHandler,
    SelectionClipboardHandler,
    KillRingHandler,
    SelectionMovementHandler,
    UndoRedoHandler,
    CompletionAndHistoryHandler,
    SubmitOrCancelHandler,
    EditKeysHandler,
    CharacterInputHandler,
  ]
}

///|
priv struct KeyHandlerPipeline {
  handlers : Array[KeyHandlerEntry]
}

///|
fn KeyHandlerPipeline::new(
  handlers : Array[KeyHandlerEntry],
) -> KeyHandlerPipeline {
  { handlers, }
}

///|
fn default_key_handler_pipeline() -> KeyHandlerPipeline {
  KeyHandlerPipeline::new(default_key_handler_entries())
}

///|
async fn Prompt::run_key_handler_pipeline(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
  pipeline : KeyHandlerPipeline,
) -> KeyProcessingResult {
  let down = self.run_key_handler_phase(
    prompt,
    state,
    key_bindings,
    info,
    pipeline,
    KeyDown,
  )
  if down is Return(_) {
    return down
  }

  let up = self.run_key_handler_phase(
    prompt,
    state,
    key_bindings,
    info,
    pipeline,
    KeyUp,
  )
  if up is Return(_) {
    return up
  }

  if down is Handled || up is Handled {
    Handled
  } else {
    NotHandled
  }
}

///|
async fn Prompt::commit_requested_render(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
) -> KeyProcessingResult {
  if state.take_render_requested() {
    self.render_line(prompt, state.left, state.right)
    Handled
  } else {
    NotHandled
  }
}

///|
async fn Prompt::run_key_handler_phase(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
  pipeline : KeyHandlerPipeline,
  phase : KeyPhase,
) -> KeyProcessingResult {
  for handler in pipeline.handlers {
    if !handler.supports_phase(phase) {
      continue
    }
    let result = handler.handle(self, prompt, state, key_bindings, info, phase)
    if !(result is NotHandled) {
      return result
    }
  }
  NotHandled
}
