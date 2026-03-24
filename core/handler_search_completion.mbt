///|
async fn Prompt::run_search_mode_handler(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if self.search_state is Some(search_state) {
    if key_bindings.reverse_search.matches(info) {
      if self.history.navigate_search(
          search_state.query,
          search_state.history_index - 1,
        )
        is Some(res) {
        search_state.set_history_index(res.0)
        self.set_line_buffers(state.left, state.right, res.1)
      }
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    if key_bindings.dismiss_completion.matches(info) {
      self.search_state = None
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    if key_bindings.submit_prompt.matches(info) {
      self.search_state = None
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    if key_bindings.backward_delete_character.matches(info) {
      if search_state.query.length() > 0 {
        search_state.set_query(
          search_state.query
          .sub(end=search_state.query.length() - 1)
          .to_string(),
        )
        if self.history.navigate_search(search_state.query, -1) is Some(res) {
          search_state.set_history_index(res.0)
          self.set_line_buffers(state.left, state.right, res.1)
        }
      }
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    let ch = info.key_char
    if !ch.is_control() {
      search_state.set_query(search_state.query + ch.to_string())
      if self.history.navigate_search(search_state.query, -1) is Some(res) {
        search_state.set_history_index(res.0)
        self.set_line_buffers(state.left, state.right, res.1)
      }
      self.render_line(prompt, state.left, state.right)
      return Handled
    }
    self.search_state = None
  }
  NotHandled
}

///|
async fn Prompt::run_search_trigger_handler(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.reverse_search.matches(info) {
    self.completion_state = None
    self.overload_state = None
    self.search_state = Some(SearchState::new())
    self.render_line(prompt, state.left, state.right)
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::run_completion_and_history_handler(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.trigger_completion.matches(info) {
    let raw_line = line_from_buffers(state.left, state.right)
    let items = (self.configuration.completer)(raw_line, state.left.length())
    if items.length() > 0 {
      let prefix_chars = state.left
        .rev_iter()
        .take_while(is_word_character)
        .collect()
      self.completion_state = Some(
        CompletionState::new(items, String::from_array(prefix_chars.rev())),
      )
      self.render_line(prompt, state.left, state.right)
    }
    return Handled
  }
  if key_bindings.history_previous.matches(info) {
    self.completion_state = None
    self.selection = None
    if self.history.navigate_previous(
        line_from_buffers(state.left, state.right),
      )
      is Some(entry) {
      self.set_line_buffers(state.left, state.right, entry)
      self.track_undo(state.left, state.right)
      self.render_line(prompt, state.left, state.right)
    }
    return Handled
  }
  if key_bindings.history_next.matches(info) {
    self.completion_state = None
    self.selection = None
    if self.history.navigate_next() is Some(entry) {
      self.set_line_buffers(state.left, state.right, entry)
      self.track_undo(state.left, state.right)
      self.render_line(prompt, state.left, state.right)
    }
    return Handled
  }
  NotHandled
}
