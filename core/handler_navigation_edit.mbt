///|
fn Prompt::run_navigation_modes_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if self.pane_state.completion_state is Some(_) ||
    self.pane_state.overload_state is Some(_) {
    if key_bindings.dismiss_completion.matches(info) {
      self.pane_state.completion_state = None
      self.pane_state.overload_state = None
      state.request_render()
      state.last_was_yank = false
      return Handled
    }
    if key_bindings.history_previous.matches(info) {
      match self.pane_state.completion_state {
        Some(s) =>
          s.set_selected_index(
            cycle_previous_index(s.selected_index, s.items.length()),
          )
        None =>
          if self.pane_state.overload_state is Some(s) {
            s.set_selected_index(
              cycle_previous_index(s.selected_index, s.items.length()),
            )
          }
      }
      state.request_render()
      state.last_was_yank = false
      return Handled
    }
    if key_bindings.history_next.matches(info) {
      match self.pane_state.completion_state {
        Some(s) =>
          s.set_selected_index(
            cycle_next_index(s.selected_index, s.items.length()),
          )
        None =>
          if self.pane_state.overload_state is Some(s) {
            s.set_selected_index(
              cycle_next_index(s.selected_index, s.items.length()),
            )
          }
      }
      state.request_render()
      state.last_was_yank = false
      return Handled
    }
    if self.pane_state.completion_state is Some(s) {
      if key_bindings.submit_prompt.matches(info) ||
        key_bindings.trigger_completion.matches(info) {
        if s.items.length() > 0 {
          let item = s.items[s.selected_index]
          while state.left.length() > 0 &&
                is_word_character(state.left[state.left.length() - 1]) {
            ignore(state.left.pop())
          }
          while state.right.length() > 0 &&
                is_word_character(state.right[state.right.length() - 1]) {
            ignore(state.right.pop())
          }
          state.left.push_iter(item.replacement_text.iter())
          self.track_undo(state.left, state.right)
        }
        self.pane_state.completion_state = None
        state.request_render()
        state.last_was_yank = false
        return Handled
      }
    }
  }
  NotHandled
}

///|
fn Prompt::run_selection_movement_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.move_left_selection.matches(info) {
    self.handle_selection_movement(state.left, state.right, -1)
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_right_selection.matches(info) {
    self.handle_selection_movement(state.left, state.right, 1)
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_home_selection.matches(info) {
    self.handle_selection_movement(
      state.left,
      state.right,
      -state.left.length(),
    )
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_end_selection.matches(info) {
    self.handle_selection_movement(
      state.left,
      state.right,
      state.right.length(),
    )
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  NotHandled
}

///|
fn Prompt::run_undo_redo_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.undo.matches(info) {
    self.pane_state.completion_state = None
    self.pane_state.overload_state = None
    self.pane_state.selection = None
    if self.undo_manager.undo() is Some(record) {
      self.apply_undo_record(state.left, state.right, record)
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.redo.matches(info) {
    self.pane_state.completion_state = None
    self.pane_state.overload_state = None
    self.pane_state.selection = None
    if self.undo_manager.redo() is Some(record) {
      self.apply_undo_record(state.left, state.right, record)
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
  NotHandled
}

///|
fn Prompt::run_edit_keys_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.backward_delete_character.matches(info) {
    if self.pane_state.selection is Some(_) {
      self.delete_selection(state.left, state.right)
    } else if state.left.pop() is Some(_) {
      if self.pane_state.completion_state is Some(completion_state) {
        update_completion_filter(completion_state, state.left)
      }
    }
    self.track_undo(state.left, state.right)
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.delete_character.matches(info) {
    if self.pane_state.selection is Some(_) {
      self.delete_selection(state.left, state.right)
    } else {
      ignore(state.right.pop())
    }
    self.track_undo(state.left, state.right)
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_left.matches(info) {
    self.pane_state.selection = None
    if state.left.pop() is Some(ch) {
      state.right.push(ch)
    }
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_right.matches(info) {
    self.pane_state.selection = None
    if state.right.pop() is Some(ch) {
      state.left.push(ch)
    }
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_home.matches(info) {
    self.pane_state.selection = None
    while state.left.pop() is Some(ch) {
      state.right.push(ch)
    }
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_end.matches(info) {
    self.pane_state.selection = None
    while state.right.pop() is Some(ch) {
      state.left.push(ch)
    }
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  NotHandled
}

///|
async fn Prompt::run_character_input_handler(
  self : Prompt,
  state : InputState,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  let ch = info.key_char
  if !ch.is_control() {
    self.delete_selection(state.left, state.right)
    state.left.push(ch)
    if self.pane_state.completion_state is Some(completion_state) {
      update_completion_filter(completion_state, state.left)
    } else if ch == '.' {
      let raw_line = line_from_buffers(state.left, state.right)
      let items = (self.configuration.completer)(raw_line, state.left.length())
      if items.length() > 0 {
        self.pane_state.completion_state = Some(CompletionState::new(items, ""))
      }
    } else if ch == '(' {
      let raw_line = line_from_buffers(state.left, state.right)
      let overloads = (self.configuration.overload_provider)(
        raw_line,
        state.left.length(),
      )
      if overloads.length() > 0 {
        self.pane_state.overload_state = Some(OverloadState::new(overloads))
      }
    }
    self.track_undo(state.left, state.right)
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  state.last_was_yank = false
  NotHandled
}
