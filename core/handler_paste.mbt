///|
fn Prompt::run_paste_handler(
  self : Prompt,
  state : InputState,
  key_bindings : KeyBindings,
  info : @console.ConsoleKeyInfo,
) -> KeyProcessingResult {
  if !key_bindings.paste.matches(info) {
    return NotHandled
  }
  let text = self.clipboard.read_text() catch {
    BackendFailure(_) => return Handled
    _ => return NotHandled
  }
  if text.length() == 0 {
    return Handled
  }
  let filtered = dedent_and_filter_paste(text)
  self.pane_state.completion_state = None
  self.pane_state.overload_state = None
  self.pane_state.search_state = None
  self.delete_selection(state.left, state.right)
  state.left.push_iter(filtered.iter())
  self.track_undo(state.left, state.right)
  state.request_render()
  state.last_was_yank = false
  Handled
}

///|
fn dedent_and_filter_paste(text : String) -> String {
  let lines = text.split("\n").collect()
  let result = StringBuilder::new()
  let has_cr = text.contains("\r")
  let line_count = lines.length()
  if line_count > 1 {
    let non_empty_lines = lines.filter(line => {
      let line_without_cr = if has_cr && line.has_suffix("\r") {
        line[:line.length() - 1]
      } else {
        line
      }
      !line_without_cr.is_blank()
    })
    if non_empty_lines.length() <= 1 {
      append_filtered_lines(result, lines, has_cr)
    } else {
      let min_indent = compute_min_indent(non_empty_lines, has_cr)
      if min_indent == 0 {
        append_filtered_lines(result, lines, has_cr)
      } else {
        for i, line in lines {
          if i > 0 {
            result.write_char('\n')
          }
          let line_without_cr = if has_cr && line.has_suffix("\r") {
            line[:line.length() - 1]
          } else {
            line
          }
          let dedented = if line_without_cr.length() > min_indent {
            line_without_cr[min_indent:]
          } else {
            line_without_cr
          }
          append_filtered(result, dedented)
        }
      }
    }
  } else {
    append_filtered(result, text)
  }
  result.to_string()
}

///|
fn compute_min_indent(lines : Array[StringView], has_cr : Bool) -> Int {
  let mut min_indent = 0
  for line in lines {
    let line_without_cr = if has_cr && line.has_suffix("\r") {
      line[:line.length() - 1]
    } else {
      line
    }
    let indent = count_leading_whitespace(line_without_cr)
    if min_indent == 0 || indent < min_indent {
      min_indent = indent
    }
  }
  min_indent
}

///|
fn count_leading_whitespace(s : StringView) -> Int {
  let mut count = 0
  for ch in s {
    if ch.is_whitespace() {
      count += 1
    } else {
      break
    }
  }
  count
}

///|
fn append_filtered(sb : StringBuilder, s : StringView) -> Unit {
  for ch in s {
    if ch == '\t' {
      sb.write_view("    ")
    } else if ch != '\r' {
      sb.write_char(ch)
    }
  }
}

///|
fn append_filtered_lines(
  sb : StringBuilder,
  lines : Array[StringView],
  has_cr : Bool,
) -> Unit {
  for i, line in lines {
    if i > 0 {
      sb.write_char('\n')
    }
    let line_without_cr = if has_cr && line.has_suffix("\r") {
      line[:line.length() - 1]
    } else {
      line
    }
    append_filtered(sb, line_without_cr)
  }
}
