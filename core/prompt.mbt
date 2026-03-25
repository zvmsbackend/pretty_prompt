///|
using @ports {trait ClipboardPort, type CancelController}

///|
using @rendering {
  type FormattedString,
  type FormatSpan,
  type ConsoleFormat,
  type Screen,
  type Cell,
  wrap_text,
  get_chars_width,
  get_char_width,
  render_diff,
}

///|
using @editing {
  type HistoryLog,
  type CompletionState,
  type OverloadState,
  type UndoManager,
  type Selection,
  type KillRing,
  type SearchState,
  type UndoRecord,
  type OverloadItem,
}

///|
priv struct PaneState {
  mut completion_state : CompletionState?
  mut selection : Selection?
  mut overload_state : OverloadState?
  mut search_state : SearchState?
}

///|
fn PaneState::new() -> PaneState {
  {
    completion_state: None,
    selection: None,
    overload_state: None,
    search_state: None,
  }
}

///|
struct Prompt {
  console : &ConsolePort
  clipboard : &ClipboardPort
  configuration : PromptConfiguration
  history : HistoryLog
  cancel_controller : CancelController
  mut pane_state : PaneState
  mut last_screen : Screen?
  mut render_anchor : (Int, Int)?
  undo_manager : UndoManager
  kill_ring : KillRing
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
    pane_state: PaneState::new(),
    last_screen: None,
    render_anchor: None,
    undo_manager: UndoManager::new("", 0),
    kill_ring: KillRing::new(max_size=configuration.kill_ring_max_size),
  }
}

///|
pub async fn Prompt::read_line(self : Prompt) -> PromptResult {
  self.read_line_with_prompt(self.configuration.prompt)
}

///|
pub async fn Prompt::read_line_with_prompt(
  self : Prompt,
  prompt : FormattedString,
) -> PromptResult {
  self.cancel_controller.set_mode(CaptureAsInput)
  self.last_screen = None
  self.render_anchor = None
  let state = InputState::new()
  let key_bindings = self.configuration.key_bindings
  self.render_line(prompt, state.left, state.right)

  while true {
    if self.cancel_controller.take_cancellation_requested() {
      self.console.write_line("")
      self.cancel_controller.set_mode(AllowCancelSignal)
      return cancel_result()
    }

    let key_presses = read_key_presses(self.console)
    for key_press in key_presses {
      let result = self.process_key_press(
        prompt, state, key_bindings, key_press,
      )
      match result {
        Handled => continue
        NotHandled => ()
        Return(value) => return value
      }
    }
  }
  cancel_result()
}

///|
async fn Prompt::process_key_press(
  self : Prompt,
  prompt : FormattedString,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
) -> KeyProcessingResult {
  let transformed = (self.configuration.callbacks.transform_key_press)(
    KeyTransformContext::new(
      self.snapshot_of(state.left, state.right),
      key_press,
    ),
  )
  let info = transformed.console_key_info
  if key_bindings.cancel_prompt.matches(info) || is_control_c_key(info) {
    return Return(self.cancel_prompt(info))
  }

  if transformed.pasted_text is Some(pasted) {
    self.pane_state.completion_state = None
    self.pane_state.overload_state = None
    self.pane_state.search_state = None
    self.delete_selection(state.left, state.right)
    state.left.push_iter(pasted.iter())
    self.apply_format_input(state, transformed)
    self.track_undo(state.left, state.right)
    state.request_render()
    state.last_was_yank = false
    return self.commit_requested_render(prompt, state)
  }

  self.run_pane_pipeline(
    prompt,
    state,
    key_bindings,
    transformed,
    default_pane_pipeline(),
  )
}

///|
fn Prompt::cancel_prompt(
  self : Prompt,
  info : @console.ConsoleKeyInfo,
) -> PromptResult {
  self.run_cancel_prompt_handler(info)
}

///|
fn Prompt::snapshot_of(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> PromptSnapshot {
  ignore(self)
  PromptSnapshot::new(line_from_buffers(left, right), left.length())
}

///|
fn Prompt::apply_snapshot(
  self : Prompt,
  state : InputState,
  snapshot : PromptSnapshot,
) -> Unit {
  self.set_line_buffers(state.left, state.right, snapshot.text)
  while state.left.length() > snapshot.caret {
    if state.left.pop() is Some(ch) {
      state.right.push(ch)
    }
  }
}

///|
fn Prompt::normalize_completion_span(
  self : Prompt,
  snapshot : PromptSnapshot,
  span : CompletionSpan,
) -> CompletionSpan {
  ignore(self)
  let start = if span.start < 0 {
    0
  } else if span.start > snapshot.text.length() {
    snapshot.text.length()
  } else {
    span.start
  }
  let end = if span.end() < start {
    start
  } else if span.end() > snapshot.text.length() {
    snapshot.text.length()
  } else {
    span.end()
  }
  CompletionSpan::new(start, end - start)
}

///|
async fn Prompt::apply_format_input(
  self : Prompt,
  state : InputState,
  key_press : KeyPress,
) -> Unit {
  let snapshot = self.snapshot_of(state.left, state.right)
  let (text, caret) = (self.configuration.callbacks.format_input)(
    FormatInputContext::new(snapshot, key_press),
  )
  self.apply_snapshot(state, PromptSnapshot::new(text, caret))
}

///|
fn Prompt::replace_completion_span(
  self : Prompt,
  state : InputState,
  span : CompletionSpan,
  replacement_text : String,
) -> Unit {
  let snapshot = self.snapshot_of(state.left, state.right)
  let normalized = self.normalize_completion_span(snapshot, span)
  let prefix = snapshot.text.sub(end=normalized.start).to_string()
  let suffix = snapshot.text.sub(start=normalized.end()).to_string()
  let next = "\{prefix}\{replacement_text}\{suffix}"
  let next_caret = prefix.length() + replacement_text.length()
  self.apply_snapshot(state, PromptSnapshot::new(next, next_caret))
}

///|
fn Prompt::handle_search_mode(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.run_search_mode_handler(state, key_bindings, info)
}

///|
async fn Prompt::handle_navigation_modes(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.run_navigation_modes_handler(state, key_bindings, info)
}

///|
fn Prompt::handle_search_trigger(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.run_search_trigger_handler(state, key_bindings, info)
}

///|
fn Prompt::handle_selection_clipboard(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.run_selection_clipboard_handler(state, key_bindings, info)
}

///|
fn Prompt::handle_kill_ring(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.run_kill_ring_handler(state, key_bindings, info)
}

///|
fn Prompt::handle_selection_movement_keys(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.run_selection_movement_handler(state, key_bindings, info)
}

///|
fn Prompt::handle_undo_redo(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.run_undo_redo_handler(state, key_bindings, info)
}

///|
async fn Prompt::handle_completion_and_history(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
) -> KeyProcessingResult {
  self.run_completion_and_history_handler(state, key_bindings, key_press)
}

///|
async fn Prompt::handle_submit_or_cancel(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  key_press : KeyPress,
) -> KeyProcessingResult {
  self.run_submit_or_cancel_handler(state, key_bindings, key_press)
}

///|
fn Prompt::handle_edit_keys(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  self.run_edit_keys_handler(state, key_bindings, info)
}

///|
async fn Prompt::handle_character_input(
  self : Prompt,
  state : InputState,
  key_press : KeyPress,
) -> KeyProcessingResult {
  self.run_character_input_handler(state, key_press)
}

///|
fn cycle_previous_index(index : Int, length : Int) -> Int {
  if length == 0 {
    0
  } else {
    (index + length - 1) % length
  }
}

///|
fn cycle_next_index(index : Int, length : Int) -> Int {
  if length == 0 {
    0
  } else {
    (index + 1) % length
  }
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
  match self.pane_state.selection {
    None => self.pane_state.selection = Some(Selection::new(old_pos, new_pos))
    Some(sel) => {
      sel.set_active(new_pos)
      if sel.anchor == sel.active {
        self.pane_state.selection = None
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
  if self.pane_state.selection is Some(sel) {
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
    self.pane_state.selection = None
  }
}

///|
fn Prompt::move_word_left(
  _self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> Bool {
  let mut moved = false
  while left.length() > 0 && !is_word_character(left[left.length() - 1]) {
    if left.pop() is Some(ch) {
      right.push(ch)
      moved = true
    }
  }
  while left.length() > 0 && is_word_character(left[left.length() - 1]) {
    if left.pop() is Some(ch) {
      right.push(ch)
      moved = true
    }
  }
  moved
}

///|
fn Prompt::move_word_right(
  _self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> Bool {
  let mut moved = false
  while right.length() > 0 && !is_word_character(right[right.length() - 1]) {
    if right.pop() is Some(ch) {
      left.push(ch)
      moved = true
    }
  }
  while right.length() > 0 && is_word_character(right[right.length() - 1]) {
    if right.pop() is Some(ch) {
      left.push(ch)
      moved = true
    }
  }
  moved
}

///|
fn Prompt::delete_word_left(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> Bool {
  if self.pane_state.selection is Some(_) {
    self.delete_selection(left, right)
    return true
  }

  let mut deleted = false
  while left.length() > 0 && !is_word_character(left[left.length() - 1]) {
    ignore(left.pop())
    deleted = true
  }
  while left.length() > 0 && is_word_character(left[left.length() - 1]) {
    ignore(left.pop())
    deleted = true
  }
  deleted
}

///|
fn Prompt::delete_word_right(
  self : Prompt,
  left : Array[Char],
  right : Array[Char],
) -> Bool {
  if self.pane_state.selection is Some(_) {
    self.delete_selection(left, right)
    return true
  }

  let mut deleted = false
  while right.length() > 0 && !is_word_character(right[right.length() - 1]) {
    ignore(right.pop())
    deleted = true
  }
  while right.length() > 0 && is_word_character(right[right.length() - 1]) {
    ignore(right.pop())
    deleted = true
  }
  deleted
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
fn Prompt::set_line_buffers(
  _self : Prompt,
  left : Array[Char],
  right : Array[Char],
  text : String,
) -> Unit {
  left.clear()
  right.clear()
  left.push_iter(text.iter())
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
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_'
}

///|
fn is_control_c_key(info : @console.ConsoleKeyInfo) -> Bool {
  (info.key is C && info.control) || (info.key_char == '\u0003' && info.control)
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
fn line_from_buffers(left : Array[Char], right : Array[Char]) -> String {
  let chars = Array::new(capacity=left.length() + right.length())
  chars.append(left)
  right.rev_each(ch => chars.push(ch))
  String::from_array(chars)
}

///|
async fn Prompt::render_line(
  self : Prompt,
  prompt : FormattedString,
  left : Array[Char],
  right : Array[Char],
) -> Unit {
  let width = self.console.get_buffer_width()
  let max_items = self.configuration.max_completion_items_count

  // 1. Determine Prompt Text & Style
  let active_prompt = match self.pane_state.search_state {
    Some(s) =>
      FormattedString::new("(reverse-i-search)'\{s.query}': ", spans=[
        FormatSpan::new(0, 18, ConsoleFormat::new(bold=true, foreground=Cyan)),
      ])
    None => prompt
  }
  let active_prompt_width = active_prompt.width()

  // 2. Word Wrapping
  let raw_line = line_from_buffers(left, right)
  let full_text = active_prompt.text + raw_line
  let wrapped = wrap_text(
    full_text,
    active_prompt_width + get_chars_width(left.iter()),
    width,
  )

  // 2. Calculate heights
  let completion_items_count = match self.pane_state.completion_state {
    Some(state) =>
      if state.items.length() < max_items {
        state.items.length()
      } else {
        max_items
      }
    None => 0
  }
  let overload_items_count = match self.pane_state.overload_state {
    Some(state) =>
      if state.items.length() < 3 {
        state.items.length()
      } else {
        3
      }
    None => 0
  }
  let height = wrapped.lines.length() +
    completion_items_count +
    overload_items_count
  let new_screen = Screen::new(height, width)

  // 4. Draw Input Lines
  let spans = if self.configuration.use_colors {
    (self.configuration.callbacks.highlight_callback)(
      PromptSnapshot::new(raw_line, left.length()),
    )
  } else {
    []
  }
  let sorted_spans = spans.copy()
  sorted_spans.sort_by_key(span => span.start)

  let active_prompt_spans = active_prompt.spans.copy()
  active_prompt_spans.sort_by_key(span => span.start)

  let mut current_text_pos = 0
  for r in 0..<wrapped.lines.length() {
    let line_text = wrapped.lines[r]
    let mut line_col = 0

    for ch in line_text {
      let mut format = ConsoleFormat::default()
      if self.configuration.use_colors {
        if current_text_pos < active_prompt_width {
          // Apply prompt styles
          for span in active_prompt_spans {
            if current_text_pos >= span.start &&
              current_text_pos < span.start + span.length {
              format = span.format
              break
            }
          }
        } else {
          // Apply input text styles
          let i = current_text_pos - active_prompt_width
          for span in sorted_spans {
            if i >= span.start && i < span.start + span.length {
              format = span.format
              break
            }
          }
          if self.pane_state.selection is Some(sel) {
            if sel.contains(i) {
              format = format.with_background(
                self.configuration.selection_background,
              )
            }
          }
        }
      }

      new_screen.rows[r][line_col] = Cell::new(ch, format)
      let w = get_char_width(ch)
      if w == 2 && line_col + 1 < width {
        new_screen.rows[r][line_col + 1] = Cell::new('\u{0000}', format)
      }
      line_col = line_col + w
      current_text_pos = current_text_pos + 1
    }
  }
  new_screen.set_cursor(wrapped.cursor_row, wrapped.cursor_col)

  // 5. Draw Overloads & Completions
  let mut next_row = wrapped.lines.length()
  if self.pane_state.overload_state is Some(state) {
    for i in 0..<overload_items_count {
      let item = state.items[i]
      let format = if i == state.selected_index {
        ConsoleFormat::new(bold=true)
      } else {
        ConsoleFormat::default()
      }
      new_screen.draw_string(next_row, 0, "* " + item.signature, format)
      next_row = next_row + 1
    }
  }
  if self.pane_state.completion_state is Some(state) {
    let start = if state.selected_index < 2 {
      0
    } else {
      state.selected_index - 2
    }
    for i in 0..<completion_items_count {
      let item_index = start + i
      if item_index >= state.items.length() {
        break
      }
      let item = state.items[item_index]
      let is_selected = item_index == state.selected_index
      let format = if is_selected && self.configuration.use_colors {
        ConsoleFormat::new(bold=true, underline=true)
      } else {
        ConsoleFormat::default()
      }
      let prefix = if is_selected { "> " } else { "  " }
      new_screen.draw_string(
        next_row + i,
        0,
        prefix + item.display_text,
        format,
      )
      if is_selected && item.description != "" {
        new_screen.draw_string(
          next_row + i,
          30,
          " │ " + item.description,
          ConsoleFormat::default(),
        )
      }
    }
  }

  // 6. Render Diff
  let (base_row, base_col) = match self.render_anchor {
    Some(anchor) => anchor
    None => {
      let anchor = (
        self.console.get_cursor_top(),
        self.console.get_cursor_left(),
      )
      self.render_anchor = Some(anchor)
      anchor
    }
  }
  let old_screen_val = self.last_screen.unwrap_or_else(() => {
    Screen::new(0, width)
  })
  render_diff(
    self.console,
    new_screen,
    old_screen_val,
    base_row + 1,
    base_col + 1,
  )
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
