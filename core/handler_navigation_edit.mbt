///|
async fn Prompt::run_navigation_modes_handler(
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
      if self.pane_state.completion_state is Some(s) {
        s.set_selected_index(
          cycle_previous_index(s.selected_index, s.items.length()),
        )
      } else if self.pane_state.overload_state is Some(s) {
        s.set_selected_index(
          cycle_previous_index(s.selected_index, s.items.length()),
        )
      }
      state.request_render()
      state.last_was_yank = false
      return Handled
    }
    if key_bindings.history_next.matches(info) {
      if self.pane_state.completion_state is Some(s) {
        s.set_selected_index(
          cycle_next_index(s.selected_index, s.items.length()),
        )
      } else if self.pane_state.overload_state is Some(s) {
        s.set_selected_index(
          cycle_next_index(s.selected_index, s.items.length()),
        )
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
          let snapshot = self.snapshot_of(state.left, state.right)
          let key_press = KeyPress::from_console_key_info(info)
          let span = self.normalize_completion_span(
            snapshot,
            (self.configuration.callbacks.completion_span_provider)(snapshot),
          )
          let should_commit = (self.configuration.callbacks.confirm_completion_commit)(
            CompletionCommitContext::new(snapshot, key_press, item, span),
          )
          if should_commit {
            self
            ..replace_completion_span(state, span, item.replacement_text)
            .track_undo(state.left, state.right)
          }
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
  if key_bindings.backward_delete_word.matches(info) {
    self.pane_state.selection = None
    if self.delete_word_left(state.left, state.right) {
      if self.pane_state.completion_state is Some(completion_state) {
        update_completion_filter(completion_state, state.left)
      }
      self.track_undo(state.left, state.right)
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.delete_word.matches(info) {
    self.pane_state.selection = None
    if self.delete_word_right(state.left, state.right) {
      self.track_undo(state.left, state.right)
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_word_left.matches(info) {
    self.pane_state.selection = None
    if self.move_word_left(state.left, state.right) {
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.move_word_right.matches(info) {
    self.pane_state.selection = None
    if self.move_word_right(state.left, state.right) {
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
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
  key_press : KeyPress,
) -> KeyProcessingResult {
  let info = key_press.console_key_info
  let ch = info.key_char
  if !ch.is_control() {
    self.delete_selection(state.left, state.right)
    state.left.push(ch)
    self.apply_format_input(state, key_press)

    let snapshot = self.snapshot_of(state.left, state.right)
    if self.pane_state.completion_state is Some(completion_state) {
      let span = self.normalize_completion_span(
        snapshot,
        (self.configuration.callbacks.completion_span_provider)(snapshot),
      )
      let prefix = if span.contains_caret(snapshot.caret) {
        snapshot.text.sub(start=span.start, end=snapshot.caret).to_string()
      } else {
        ""
      }
      completion_state.filter(prefix)
    } else {
      let should_open = (self.configuration.callbacks.should_open_completion_window)(
        CompletionTriggerContext::new(snapshot, key_press),
      )
      if should_open {
        let span = self.normalize_completion_span(
          snapshot,
          (self.configuration.callbacks.completion_span_provider)(snapshot),
        )
        let items = (self.configuration.callbacks.completion_items_provider)(
          CompletionRequest::new(snapshot, span),
        )
        if items.length() > 0 {
          let prefix = if span.contains_caret(snapshot.caret) {
            snapshot.text.sub(start=span.start, end=snapshot.caret).to_string()
          } else {
            ""
          }
          self.pane_state.completion_state = Some(
            CompletionState::new(items, prefix),
          )
        }
      }
    }

    let (overloads, selected_index) = (self.configuration.callbacks.overload_provider)(
      snapshot,
    )
    if overloads.length() > 0 {
      let overload_state = OverloadState::new(overloads)
      let normalized_index = if selected_index < 0 {
        0
      } else if selected_index >= overload_state.items.length() {
        overload_state.items.length() - 1
      } else {
        selected_index
      }
      overload_state.set_selected_index(normalized_index)
      self.pane_state.overload_state = Some(overload_state)
    } else {
      self.pane_state.overload_state = None
    }

    self.track_undo(state.left, state.right)
    state.request_render()
    state.last_was_yank = false
    return Handled
  }
  state.last_was_yank = false
  NotHandled
}
