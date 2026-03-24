///|
pub struct Prompt {
  console : &ConsolePort
  clipboard : &ClipboardPort
  configuration : PromptConfiguration
  history : HistoryLog
  cancel_controller : CancelController
  mut completion_state : CompletionState?
  mut last_screen : Screen?
  undo_manager : UndoManager
  mut selection : Selection?
  mut overload_state : OverloadState?
}

///|
pub async fn Prompt::new(
  console : &ConsolePort,
  clipboard : &ClipboardPort,
  configuration? : PromptConfiguration = PromptConfiguration::default(),
) -> Prompt {
  let cancel_controller = CancelController::new(console)
  let history = HistoryLog::new(configuration.history)
  history.load_persistent_history()
  {
    console,
    clipboard,
    configuration,
    history,
    cancel_controller,
    completion_state: None,
    last_screen: None,
    undo_manager: UndoManager::new("", 0),
    selection: None,
    overload_state: None,
  }
}

///|
pub async fn Prompt::read_line(self : Prompt) -> PromptResult {
  self.read_line_with_prompt(self.configuration.prompt)
}

///|
pub async fn Prompt::read_line_with_prompt(
  self : Prompt,
  prompt : String,
) -> PromptResult {
  self.cancel_controller.set_mode(CaptureAsInput)
  self.console.write(prompt)
  let left : Array[Char] = []
  let right : Array[Char] = []
  let key_bindings = self.configuration.key_bindings

  while true {
    if self.cancel_controller.take_cancellation_requested() {
      self.console.write_line("")
      return cancel_result()
    }

    let key_presses = read_key_presses(self.console)
    for key_press in key_presses {
      if key_press.pasted_text is Some(pasted) {
        self.completion_state = None
        self.overload_state = None
        self.delete_selection(left, right)
        left.push_iter(pasted.iter())
        self.track_undo(left, right)
        self.render_line(prompt, left, right)
        continue
      }

      let info = key_press.console_key_info

      // 1. Global keys
      if key_bindings.cancel_prompt.matches(info) {
        self.completion_state = None
        self.overload_state = None
        self.selection = None
        self.console.write_line("")
        self.cancel_controller.set_mode(AllowCancelSignal)
        return PromptResult::cancelled(info)
      }

      // 2. Handle Navigation Mode (Completion or Overload)
      let is_nav_mode = self.completion_state is Some(_) ||
        self.overload_state is Some(_)
      if is_nav_mode {
        if key_bindings.dismiss_completion.matches(info) {
          self.completion_state = None
          self.overload_state = None
          self.render_line(prompt, left, right)
          continue
        }

        if key_bindings.history_previous.matches(info) {
          if self.completion_state is Some(state) {
            state.selected_index = (
                state.selected_index + state.items.length() - 1
              ) %
              state.items.length()
          } else if self.overload_state is Some(state) {
            state.selected_index = (
                state.selected_index + state.items.length() - 1
              ) %
              state.items.length()
          }
          self.render_line(prompt, left, right)
          continue
        }

        if key_bindings.history_next.matches(info) {
          if self.completion_state is Some(state) {
            state.selected_index = (state.selected_index + 1) %
              state.items.length()
          } else if self.overload_state is Some(state) {
            state.selected_index = (state.selected_index + 1) %
              state.items.length()
          }
          self.render_line(prompt, left, right)
          continue
        }

        // Completion Commitment
        if self.completion_state is Some(state) {
          if key_bindings.submit_prompt.matches(info) ||
            key_bindings.trigger_completion.matches(info) {
            if state.items.length() > 0 {
              let item = state.items[state.selected_index]
              while left.length() > 0 &&
                    is_word_character(left[left.length() - 1]) {
                ignore(left.pop())
              }
              while right.length() > 0 &&
                    is_word_character(right[right.length() - 1]) {
                ignore(right.pop())
              }
              left.push_iter(item.replacement_text.iter())
              self.track_undo(left, right)
            }
            self.completion_state = None
            self.render_line(prompt, left, right)
            continue
          }
        }
      }

      // 3. Selection specific keys
      if key_bindings.copy_selection.matches(info) {
        if self.selection is Some(sel) {
          let (start, end) = sel.range()
          let text = line_from_buffers(left, right)
          let selected_text = text.sub(start~, end~).to_string()
          let _ = self.clipboard.write_text(selected_text) catch { _ => () }
        }
        continue
      }

      if key_bindings.cut_selection.matches(info) {
        if self.selection is Some(sel) {
          let (start, end) = sel.range()
          let text = line_from_buffers(left, right)
          let selected_text = text.sub(start~, end~).to_string()
          let _ = self.clipboard.write_text(selected_text) catch { _ => () }
          self.delete_selection(left, right)
          self.track_undo(left, right)
          self.render_line(prompt, left, right)
        }
        continue
      }

      // 4. Movement with Selection
      if key_bindings.move_left_selection.matches(info) {
        self.handle_selection_movement(left, right, -1)
        self.render_line(prompt, left, right)
        continue
      }
      if key_bindings.move_right_selection.matches(info) {
        self.handle_selection_movement(left, right, 1)
        self.render_line(prompt, left, right)
        continue
      }
      if key_bindings.move_home_selection.matches(info) {
        self.handle_selection_movement(left, right, -left.length())
        self.render_line(prompt, left, right)
        continue
      }
      if key_bindings.move_end_selection.matches(info) {
        self.handle_selection_movement(left, right, right.length())
        self.render_line(prompt, left, right)
        continue
      }

      // 5. Undo/Redo
      if key_bindings.undo.matches(info) {
        self.completion_state = None
        self.overload_state = None
        self.selection = None
        if self.undo_manager.undo() is Some(record) {
          self.apply_undo_record(left, right, record)
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.redo.matches(info) {
        self.completion_state = None
        self.overload_state = None
        self.selection = None
        if self.undo_manager.redo() is Some(record) {
          self.apply_undo_record(left, right, record)
          self.render_line(prompt, left, right)
        }
        continue
      }

      // 6. Trigger Completion
      if key_bindings.trigger_completion.matches(info) {
        let raw_line = line_from_buffers(left, right)
        let items = (self.configuration.completer)(raw_line, left.length())
        if items.length() > 0 {
          let prefix_chars = left
            .rev_iter()
            .take_while(is_word_character)
            .collect()
          let filter_prefix = String::from_array(prefix_chars.rev())
          self.completion_state = Some(
            CompletionState::new(items, filter_prefix),
          )
          self.render_line(prompt, left, right)
        }
        continue
      }

      // 7. Standard Keys
      if key_bindings.history_previous.matches(info) {
        self.completion_state = None
        self.overload_state = None
        self.selection = None
        if self.history.navigate_previous(line_from_buffers(left, right))
          is Some(entry) {
          set_line_buffers(left, right, entry)
          self.track_undo(left, right)
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.history_next.matches(info) {
        self.completion_state = None
        self.overload_state = None
        self.selection = None
        if self.history.navigate_next() is Some(entry) {
          set_line_buffers(left, right, entry)
          self.track_undo(left, right)
          self.render_line(prompt, left, right)
        }
        continue
      }

      self.history.reset_navigation()

      if key_bindings.submit_prompt.matches(info) {
        self.completion_state = None
        self.overload_state = None
        self.selection = None
        let line = line_from_buffers(left, right)
        self.history.track_submission(line)
        self.console.write("\r")
        self.console.write(prompt)
        self.console.write(line)
        self.console.write_line("")
        self.cancel_controller.set_mode(AllowCancelSignal)
        return PromptResult::submitted(line, info)
      }

      if key_bindings.backward_delete_character.matches(info) {
        if self.selection is Some(_) {
          self.delete_selection(left, right)
          self.track_undo(left, right)
          self.render_line(prompt, left, right)
        } else if left.pop() is Some(_) {
          if self.completion_state is Some(state) {
            update_completion_filter(state, left)
          }
          self.track_undo(left, right)
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.delete_character.matches(info) {
        if self.selection is Some(_) {
          self.delete_selection(left, right)
          self.track_undo(left, right)
          self.render_line(prompt, left, right)
        } else if right.pop() is Some(_) {
          self.completion_state = None
          self.track_undo(left, right)
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.move_left.matches(info) {
        self.selection = None
        if left.pop() is Some(ch) {
          right.push(ch)
          self.completion_state = None
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.move_right.matches(info) {
        self.selection = None
        if right.pop() is Some(ch) {
          left.push(ch)
          self.completion_state = None
          self.render_line(prompt, left, right)
        }
        continue
      }

      let ch = info.key_char
      if !ch.is_control() {
        self.delete_selection(left, right)
        left.push(ch)
        if self.completion_state is Some(state) {
          update_completion_filter(state, left)
        } else if ch == '.' {
          let raw_line = line_from_buffers(left, right)
          let items = (self.configuration.completer)(raw_line, left.length())
          if items.length() > 0 {
            self.completion_state = Some(CompletionState::new(items, ""))
          }
        } else if ch == '(' {
          let raw_line = line_from_buffers(left, right)
          let overloads = (self.configuration.overload_provider)(
            raw_line,
            left.length(),
          )
          if overloads.length() > 0 {
            self.overload_state = Some(OverloadState::new(overloads))
          }
        }
        self.track_undo(left, right)
        self.render_line(prompt, left, right)
      }
    }
  }
  cancel_result()
}

///|
fn Prompt::handle_selection_movement(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
  delta : Int,
) -> Unit {
  let old_pos = left.length()
  if delta < 0 {
    for _ in 0..<-delta {
      if left.pop() is Some(ch) {
        right.push(ch)
      }
    }
  } else {
    for _ in 0..<delta {
      if right.pop() is Some(ch) {
        left.push(ch)
      }
    }
  }
  let new_pos = left.length()
  match self.selection {
    None => self.selection = Some(Selection::new(old_pos, new_pos))
    Some(sel) => {
      sel.active = new_pos
      if sel.anchor == sel.active {
        self.selection = None
      }
    }
  }
}

///|
fn Prompt::delete_selection(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> Unit {
  if self.selection is Some(sel) {
    let (start, end) = sel.range()
    let text = line_from_buffers(left, right)
    let chars = text.to_array()
    left.clear()
    right.clear()
    for i in 0..<start {
      if i < chars.length() {
        left.push(chars[i])
      }
    }
    for i in chars.length()>..end {
      right.push(chars[i])
    }
    self.selection = None
  }
}

///|
fn Prompt::track_undo(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> Unit {
  self.undo_manager.track(line_from_buffers(left, right), left.length())
}

///|
fn Prompt::apply_undo_record(
  _self : Prompt,
  left : Array[Char],
  right : Array[Char],
  record : UndoRecord,
) -> Unit {
  left.clear()
  right.clear()
  let chars = record.text.to_array()
  for i in 0..<record.cursor_pos {
    if i < chars.length() {
      left.push(chars[i])
    }
  }
  for i in chars.length()>..record.cursor_pos {
    right.push(chars[i])
  }
}

///|
fn update_completion_filter(
  state : CompletionState,
  left : Array[Char],
) -> Unit {
  let prefix_chars = left.rev_iter().take_while(is_word_character).collect()
  state.filter(String::from_array(prefix_chars.rev()))
}

///|
fn is_word_character(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_'
}

///|
pub fn Prompt::take_execution_cancellation_requested(self : Prompt) -> Bool {
  self.cancel_controller.take_cancellation_requested()
}

///|
pub async fn Prompt::dispose(self : Prompt) -> Unit {
  self.history.save_persistent_history_full()
  self.cancel_controller.dispose()
}

///|
fn set_line_buffers(
  left : Array[Char],
  right : Array[Char],
  text : String,
) -> Unit {
  left.clear()
  right.clear()
  left.push_iter(text.iter())
}

///|
fn line_from_buffers(left : Array[Char], right : Array[Char]) -> String {
  let chars = Array::new(capacity=left.length() + right.length())
  chars.append(left)
  right.rev_each(ch => chars.push(ch))
  String::from_array(chars)
}

///|
async fn Prompt::render_line(
  self : Prompt,
  prompt : String,
  left : Array[Char],
  right : Array[Char],
) -> Unit {
  let width = self.console.get_buffer_width()
  let max_items = self.configuration.max_completion_items_count

  // Calculate heights
  let completion_items_count = match self.completion_state {
    Some(state) =>
      if state.items.length() < max_items {
        state.items.length()
      } else {
        max_items
      }
    None => 0
  }
  let overload_items_count = match self.overload_state {
    Some(state) =>
      if state.items.length() < 3 {
        state.items.length()
      } else {
        3
      }
    None => 0
  }
  let height = 1 + completion_items_count + overload_items_count
  let new_screen = Screen::new(height, width)

  // 1. Draw main line
  let raw_line = line_from_buffers(left, right)
  let spans = if self.configuration.use_colors {
    (self.configuration.highlighter)(raw_line)
  } else {
    []
  }
  new_screen.draw_string(0, 0, prompt, ConsoleFormat::default())
  let prompt_width = get_string_width(prompt)
  let mut current_col = prompt_width
  let sorted_spans = spans.copy()
  sorted_spans.sort_by_key(span => span.start)
  let chars = raw_line.to_array()
  for i in 0..<chars.length() {
    let mut format = ConsoleFormat::default()
    if self.configuration.use_colors {
      for span in sorted_spans {
        if i >= span.start && i < span.start + span.length {
          format = span.format
          break
        }
      }
      if self.selection is Some(sel) {
        if sel.contains(i) {
          format = {
            ..format,
            background: self.configuration.selection_background,
          }
        }
      }
    }
    new_screen.draw_string(0, current_col, chars[i].to_string(), format)
    current_col = current_col + get_char_width(chars[i])
  }
  new_screen.cursor_row = 0
  new_screen.cursor_col = prompt_width + get_chars_width(left.iter())

  // 2. Draw Parameter Overloads (if any)
  let mut next_row = 1
  if self.overload_state is Some(state) {
    for i in 0..<overload_items_count {
      let item = state.items[i]
      let format = if i == state.selected_index {
        ConsoleFormat::new(bold=true)
      } else {
        ConsoleFormat::default()
      }
      let prefix = if i == state.selected_index { "* " } else { "  " }
      new_screen.draw_string(next_row, 0, prefix + item.signature, format)
      next_row = next_row + 1
    }
  }

  // 3. Draw Completion Menu + Description Box
  if self.completion_state is Some(state) {
    let start = if state.selected_index < 2 {
      0
    } else {
      state.selected_index - 2
    }
    let menu_max_width = 30 // Simplified
    for i in 0..<completion_items_count {
      let item_index = start + i
      if item_index >= state.items.length() {
        break
      }
      let item = state.items[item_index]
      let row = next_row + i
      let is_selected = item_index == state.selected_index
      let format = if is_selected && self.configuration.use_colors {
        ConsoleFormat::new(bold=true, underline=true)
      } else {
        ConsoleFormat::default()
      }
      let prefix = if is_selected { "> " } else { "  " }
      new_screen.draw_string(row, 0, prefix + item.display_text, format)

      // Draw side description for selected item
      if is_selected && item.description != "" {
        new_screen.draw_string(
          row,
          menu_max_width,
          " │ \{item.description}",
          ConsoleFormat::default(),
        )
      }
    }
  }

  // 4. Render Diff
  let base_row = self.console.get_cursor_top()
  let old_screen_val = self.last_screen.unwrap_or_else(() => {
    Screen::new(height, width)
  })
  render_diff(self.console, new_screen, old_screen_val, base_row, 1)
  self.last_screen = Some(new_screen)
}

///|
fn cancel_result() -> PromptResult {
  let key_info = @console.ConsoleKeyInfo::new(
    '\u0003',
    @console.C,
    false,
    false,
    true,
  )
  PromptResult::cancelled(key_info)
}

///|
pub struct PromptResult {
  is_success : Bool
  text : String
  submit_key_info : @console.ConsoleKeyInfo
}

///|
pub fn PromptResult::submitted(
  text : String,
  submit_key_info : @console.ConsoleKeyInfo,
) -> PromptResult {
  { is_success: true, text, submit_key_info }
}

///|
pub fn PromptResult::cancelled(
  submit_key_info : @console.ConsoleKeyInfo,
) -> PromptResult {
  { is_success: false, text: "", submit_key_info }
}
