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
priv enum PaneEntry {
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
priv struct PaneContext {
  runtime : Prompt
  prompt : FormattedString
  state : InputState
  key_bindings : KeyBindings
  key_press : KeyPress
}

///|
fn PaneContext::new(
  runtime : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
) -> PaneContext {
  { runtime, prompt, state, key_bindings, key_press }
}

///|
priv trait Pane {
  supports_phase(Self, KeyPhase) -> Bool
  async on_key(Self, PaneContext, KeyPhase) -> KeyProcessingResult
}

///|
impl Pane for PaneEntry with supports_phase(self, phase) {
  match phase {
    KeyDown => true
    KeyUp => self is CharacterInputHandler
  }
}

///|
impl Pane for PaneEntry with on_key(self, context, phase) {
  let runtime = context.runtime
  let prompt = context.prompt
  let state = context.state
  let key_bindings = context.key_bindings
  let key_press = context.key_press
  let info = key_press.console_key_info
  match phase {
    KeyDown =>
      match self {
        SearchModeHandler =>
          SearchPane::new().handle_search_mode(
            runtime, state, key_bindings, info,
          )
        NavigationModesHandler =>
          CompletionPane::new().handle_navigation_modes(
            runtime, state, key_bindings, info,
          )
        SearchTriggerHandler =>
          SearchPane::new().handle_search_trigger(
            runtime, state, key_bindings, info,
          )
        SelectionClipboardHandler =>
          runtime.handle_selection_clipboard(state, key_bindings, info)
        KillRingHandler => runtime.handle_kill_ring(state, key_bindings, info)
        SelectionMovementHandler =>
          runtime.handle_selection_movement_keys(state, key_bindings, info)
        UndoRedoHandler => runtime.handle_undo_redo(state, key_bindings, info)
        CompletionAndHistoryHandler =>
          CompletionPane::new().handle_completion_and_history(
            runtime, state, key_bindings, key_press,
          )
        SubmitOrCancelHandler =>
          runtime.handle_submit_or_cancel(state, key_bindings, key_press)
        EditKeysHandler =>
          runtime.handle_edit_keys(state, key_bindings, key_press)
        CharacterInputHandler =>
          runtime.handle_character_input(state, key_press)
      }
    KeyUp => runtime.commit_requested_render(prompt, state)
  }
}

///|
fn default_pane_entries() -> Array[PaneEntry] {
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
priv struct PanePipeline {
  panes : Array[PaneEntry]
}

///|
fn PanePipeline::new(panes : Array[PaneEntry]) -> PanePipeline {
  { panes, }
}

///|
fn default_pane_pipeline() -> PanePipeline {
  PanePipeline::new(default_pane_entries())
}

///|
async fn Prompt::run_pane_pipeline(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
  pipeline : PanePipeline,
) -> KeyProcessingResult {
  let down = self.run_pane_phase(
    prompt,
    state,
    key_bindings,
    key_press,
    pipeline,
    KeyDown,
  )
  if down is Return(_) {
    return down
  }

  let up = self.run_pane_phase(
    prompt,
    state,
    key_bindings,
    key_press,
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
async fn Prompt::run_pane_phase(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
  pipeline : PanePipeline,
  phase : KeyPhase,
) -> KeyProcessingResult {
  for pane in pipeline.panes {
    if !pane.supports_phase(phase) {
      continue
    }
    let context = PaneContext::new(self, prompt, state, key_bindings, key_press)
    let result = pane.on_key(context, phase)
    if !(result is NotHandled) {
      return result
    }
  }
  NotHandled
}
