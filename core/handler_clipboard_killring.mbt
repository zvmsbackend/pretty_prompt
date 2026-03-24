///|
fn Prompt::run_selection_clipboard_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.copy_selection.matches(info) {
    if self.selection is Some(sel) {
      let (start, end) = sel.range()
      let text = line_from_buffers(state.left, state.right)
      let selected_text = text.sub(start~, end~).to_string()
      let _ = self.clipboard.write_text(selected_text) catch { _ => () }
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.cut_selection.matches(info) {
    if self.selection is Some(sel) {
      let (start, end) = sel.range()
      let text = line_from_buffers(state.left, state.right)
      let selected_text = text.sub(start~, end~).to_string()
      let _ = self.clipboard.write_text(selected_text) catch { _ => () }
      self.kill_ring.add(selected_text)
      self.delete_selection(state.left, state.right)
      self.track_undo(state.left, state.right)
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
  NotHandled
}

///|
fn Prompt::run_kill_ring_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if key_bindings.kill_line_tail.matches(info) {
    if state.right.length() > 0 {
      let text = String::from_array(state.right.rev())
      self.kill_ring.add(text)
      state.right.clear()
      self.track_undo(state.left, state.right)
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.kill_line_head.matches(info) {
    if state.left.length() > 0 {
      let text = String::from_array(state.left)
      self.kill_ring.add(text)
      state.left.clear()
      self.track_undo(state.left, state.right)
      state.request_render()
    }
    state.last_was_yank = false
    return Handled
  }
  if key_bindings.yank.matches(info) {
    if self.kill_ring.yank() is Some(text) {
      self.delete_selection(state.left, state.right)
      state.left.push_iter(text.iter())
      self.track_undo(state.left, state.right)
      state.request_render()
      state.last_was_yank = true
    }
    return Handled
  }
  if key_bindings.yank_pop.matches(info) && state.last_was_yank {
    if self.undo_manager.undo() is Some(record) {
      self.apply_undo_record(state.left, state.right, record)
      if self.kill_ring.yank_pop() is Some(text) {
        state.left.push_iter(text.iter())
        self.track_undo(state.left, state.right)
      }
      state.request_render()
    }
    return Handled
  }
  NotHandled
}
