///|
priv struct SearchPane {}

///|
fn SearchPane::new() -> SearchPane {
  SearchPane::{  }
}

///|
fn SearchPane::handle_search_mode(
  _self : SearchPane,
  runtime : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  runtime.handle_search_mode(state, key_bindings, info)
}

///|
fn SearchPane::handle_search_trigger(
  _self : SearchPane,
  runtime : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  runtime.handle_search_trigger(state, key_bindings, info)
}

///|
priv struct CompletionPane {}

///|
fn CompletionPane::new() -> CompletionPane {
  CompletionPane::{  }
}

///|
async fn CompletionPane::handle_navigation_modes(
  self : CompletionPane,
  runtime : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  ignore(self)
  runtime.handle_navigation_modes(state, key_bindings, info)
}

///|
async fn CompletionPane::handle_completion_and_history(
  self : CompletionPane,
  runtime : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
) -> KeyProcessingResult {
  ignore(self)
  runtime.handle_completion_and_history(state, key_bindings, key_press)
}
