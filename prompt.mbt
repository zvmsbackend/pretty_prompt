///|
pub struct Prompt {
  console : &ConsolePort
  clipboard : &ClipboardPort
  configuration : PromptConfiguration
  history : HistoryLog
  cancel_controller : CancelController
  completion_state : Ref[CompletionState?]
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
    completion_state: @ref.new(None),
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
        self.completion_state.val = None
        left.push_iter(pasted.iter())
        self.render_line(prompt, left, right)
        continue
      }

      let info = key_press.console_key_info

      // 1. Check for global/mode-switching keys
      if key_bindings.cancel_prompt.matches(info) {
        self.completion_state.val = None
        self.console.write_line("")
        self.cancel_controller.set_mode(AllowCancelSignal)
        return PromptResult::cancelled(info)
      }

      // 2. Handle Completion Mode
      if self.completion_state.val is Some(state) {
        if key_bindings.dismiss_completion.matches(info) {
          self.completion_state.val = None
          self.render_line(prompt, left, right)
          continue
        }

        if key_bindings.history_previous.matches(info) {
          state.selected_index = (
              state.selected_index + state.items.length() - 1
            ) %
            state.items.length()
          self.render_line(prompt, left, right)
          continue
        }

        if key_bindings.history_next.matches(info) {
          state.selected_index = (state.selected_index + 1) %
            state.items.length()
          self.render_line(prompt, left, right)
          continue
        }

        if key_bindings.submit_prompt.matches(info) ||
          key_bindings.trigger_completion.matches(info) {
          let item = state.items[state.selected_index]
          // Simple replacement: clear current word and insert replacement
          // A more robust implementation would use spanToBeReplaced from .NET version
          while left.length() > 0 {
            let ch = left[left.length() - 1]
            if ch.is_whitespace() {
              break
            }
            ignore(left.pop())
          }
          left.push_iter(item.replacement_text.iter())
          self.completion_state.val = None
          self.render_line(prompt, left, right)
          continue
        }
      }

      // 3. Trigger Completion
      if key_bindings.trigger_completion.matches(info) {
        let raw_line = line_from_buffers(left, right)
        let items = (self.configuration.completer)(raw_line, left.length())
        if items.length() > 0 {
          self.completion_state.val = Some(CompletionState::new(items, ""))
          self.render_line(prompt, left, right)
        }
        continue
      }

      // 4. Standard Keys (with completion dismissal)
      if key_bindings.history_previous.matches(info) {
        self.completion_state.val = None
        if self.history.navigate_previous(line_from_buffers(left, right))
          is Some(entry) {
          set_line_buffers(left, right, entry)
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.history_next.matches(info) {
        if self.history.navigate_next() is Some(entry) {
          set_line_buffers(left, right, entry)
          self.render_line(prompt, left, right)
        }
        continue
      }

      self.history.reset_navigation()

      if key_bindings.submit_prompt.matches(info) {
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
        if left.pop() is Some(_) {
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.delete_character.matches(info) {
        if right.pop() is Some(_) {
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.move_left.matches(info) {
        if left.pop() is Some(ch) {
          right.push(ch)
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.move_right.matches(info) {
        if right.pop() is Some(ch) {
          left.push(ch)
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.move_word_left.matches(info) {
        let mut changed = false
        while left.length() > 0 {
          let i = left.length() - 1
          let ch = left[i]
          let next_ch = if right.length() > 0 {
            Some(right[right.length() - 1])
          } else {
            None
          }
          if changed && is_word_boundary(Some(ch), next_ch) {
            break
          }
          if left.pop() is Some(c) {
            right.push(c)
            changed = true
          }
        }
        if changed {
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.move_word_right.matches(info) {
        let mut changed = false
        while right.length() > 0 {
          let i = right.length() - 1
          let ch = right[i]
          let prev_ch = if left.length() > 0 {
            Some(left[left.length() - 1])
          } else {
            None
          }
          if changed && is_word_boundary(prev_ch, Some(ch)) {
            break
          }
          if right.pop() is Some(c) {
            left.push(c)
            changed = true
          }
        }
        if changed {
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.backward_delete_word.matches(info) {
        let mut changed = false
        while left.length() > 0 {
          let i = left.length() - 1
          let ch = left[i]
          let next_ch = if right.length() > 0 {
            Some(right[right.length() - 1])
          } else {
            None
          }
          if changed && is_word_boundary(Some(ch), next_ch) {
            break
          }
          if left.pop() is Some(_) {
            changed = true
          }
        }
        if changed {
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.delete_word.matches(info) {
        let mut changed = false
        while right.length() > 0 {
          let i = right.length() - 1
          let ch = right[i]
          let prev_ch = if left.length() > 0 {
            Some(left[left.length() - 1])
          } else {
            None
          }
          if changed && is_word_boundary(prev_ch, Some(ch)) {
            break
          }
          if right.pop() is Some(_) {
            changed = true
          }
        }
        if changed {
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.move_home.matches(info) {
        let mut changed = false
        while left.pop() is Some(ch) {
          right.push(ch)
          changed = true
        }
        if changed {
          self.render_line(prompt, left, right)
        }
        continue
      }

      if key_bindings.move_end.matches(info) {
        let mut changed = false
        while right.pop() is Some(ch) {
          left.push(ch)
          changed = true
        }
        if changed {
          self.render_line(prompt, left, right)
        }
        continue
      }

      let ch = info.key_char
      if !ch.is_control() {
        left.push(ch)
        self.render_line(prompt, left, right)
      }
    }
  }
  cancel_result()
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
  // 1. Render the main line
  self.console.write("\r")
  self.console.write(prompt)
  let raw_line = line_from_buffers(left, right)
  let spans = (self.configuration.highlighter)(raw_line)
  let highlighted_line = apply_highlights(raw_line, spans)
  self.console.write(highlighted_line)
  self.console.write("\u{1b}[K")

  // 2. Render completion list if any
  let mut lines_down = 0
  if self.completion_state.val is Some(state) {
    let start = if state.selected_index < 2 {
      0
    } else {
      state.selected_index - 2
    }
    let end = if start + 5 > state.items.length() {
      state.items.length()
    } else {
      start + 5
    }
    for i in start..<end {
      let item = state.items[i]
      self.console.write("\n\r")
      lines_down = lines_down + 1
      if i == state.selected_index {
        self.console.write("\u{1b}[7m> \{item.display_text}\u{1b}[0m")
      } else {
        self.console.write("  \{item.display_text}")
      }
      self.console.write("\u{1b}[K")
    }
    // Return to main line
    if lines_down > 0 {
      self.console.write("\u{1b}[\{lines_down}A")
    }
  }

  // 3. Position the cursor correctly at the edit point
  self.console.write("\r")
  let prompt_width = get_string_width(prompt)
  let left_width = get_chars_width(left.iter())
  let total_move_right = prompt_width + left_width
  if total_move_right > 0 {
    self.console.write("\u{1b}[\{total_move_right}C")
  }
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
