///|
pub struct HistoryConfiguration {
  persistent_history_filepath : String?
  max_entries : Int
}

///|
pub fn HistoryConfiguration::new(
  persistent_history_filepath? : String,
  max_entries? : Int = 500,
) -> HistoryConfiguration {
  let max_entries = if max_entries < 1 { 1 } else { max_entries }
  { persistent_history_filepath, max_entries }
}

///|
pub fn HistoryConfiguration::default() -> HistoryConfiguration {
  HistoryConfiguration::new()
}

///|
pub struct HistoryLog {
  entries : Array[String]
  config : HistoryConfiguration
  navigation_index : Ref[Int?]
  unsubmitted_buffer : Ref[String]
}

///|
pub fn HistoryLog::new(config : HistoryConfiguration) -> HistoryLog {
  let log = {
    entries: [],
    config,
    navigation_index: @ref.new(None),
    unsubmitted_buffer: @ref.new(""),
  }
  log.load_persistent_history()
  log
}

///|
pub fn HistoryLog::navigate_previous(
  self : HistoryLog,
  current_buffer : String,
) -> String? {
  if self.entries.length() == 0 {
    return None
  }

  if self.navigation_index.val is None {
    self.unsubmitted_buffer.val = current_buffer
  }
  let pattern = self.unsubmitted_buffer.val

  let start = match self.navigation_index.val {
    Some(index) => if index > 0 { index - 1 } else { 0 }
    None => self.entries.length() - 1
  }

  find_previous_matching_index(self.entries, pattern, start).bind(index => {
    self.navigation_index.val = Some(index)
    Some(self.entries[index])
  })
}

///|
pub fn HistoryLog::navigate_next(self : HistoryLog) -> String? {
  let current_index = match self.navigation_index.val {
    Some(index) => index
    None => return None
  }

  let pattern = self.unsubmitted_buffer.val

  if current_index + 1 >= self.entries.length() {
    self.navigation_index.val = None
    return Some(self.unsubmitted_buffer.val)
  }

  match find_next_matching_index(self.entries, pattern, current_index + 1) {
    Some(index) => {
      self.navigation_index.val = Some(index)
      Some(self.entries[index])
    }
    None => {
      self.navigation_index.val = None
      Some(self.unsubmitted_buffer.val)
    }
  }
}

///|
pub fn HistoryLog::reset_navigation(self : HistoryLog) -> Unit {
  self.navigation_index.val = None
}

///|
pub fn HistoryLog::track_submission(self : HistoryLog, text : String) -> Unit {
  self.reset_navigation()
  if text.length() == 0 {
    return
  }
  if self.entries.length() > 0 &&
    self.entries[self.entries.length() - 1] == text {
    return
  }

  self.entries.push(text)
  trim_entries(self.entries, self.config.max_entries)
  self.save_persistent_history()
}

///|
pub fn HistoryLog::entry_count(self : HistoryLog) -> Int {
  self.entries.length()
}

///|
fn trim_entries(entries : Array[String], max_entries : Int) -> Unit {
  while entries.length() > max_entries {
    ignore(entries.remove(0))
  }
}

///|
fn find_previous_matching_index(
  entries : Array[String],
  pattern : String,
  start : Int,
) -> Int? {
  if entries.length() == 0 {
    return None
  }
  let mut i = start
  while i >= 0 {
    let entry = entries[i]
    if matches_history_pattern(entry, pattern) && entry != pattern {
      return Some(i)
    }
    i = i - 1
  }
  None
}

///|
fn find_next_matching_index(
  entries : Array[String],
  pattern : String,
  start : Int,
) -> Int? {
  let mut i = start
  while i < entries.length() {
    let entry = entries[i]
    if matches_history_pattern(entry, pattern) && entry != pattern {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn matches_history_pattern(entry : String, pattern : String) -> Bool {
  if pattern.length() == 0 {
    return true
  }

  if entry.has_prefix(pattern) {
    return true
  }

  let entry_lower = entry.to_lower()
  let pattern_lower = pattern.to_lower()
  entry_lower.has_prefix(pattern_lower) ||
  entry.contains(pattern) ||
  entry_lower.contains(pattern_lower)
}

///|
fn HistoryLog::save_persistent_history(self : HistoryLog) -> Unit {
  let filepath = match self.config.persistent_history_filepath {
    Some(filepath) => filepath
    None => return
  }

  let lines = StringBuilder::new()
  for entry in self.entries {
    let encoded = entry |> @utf8.encode |> @base64.encode
    lines..write_string(encoded).write_char('\n')
  }

  @fs.write_string_to_file(filepath, lines.to_string()) catch {
    _ => ()
  }
}

///|
fn HistoryLog::load_persistent_history(self : HistoryLog) -> Unit {
  let filepath = match self.config.persistent_history_filepath {
    Some(filepath) => filepath
    None => return
  }

  if !@fs.path_exists(filepath) {
    return
  }

  let contents = @fs.read_file_to_string(filepath) catch { _ => return }

  for line in contents.split("\n") {
    if line.length() == 0 {
      continue
    }
    let decoded = @base64.decode(line) catch { _ => continue }
    let text = @utf8.decode(decoded) catch { _ => continue }
    self.entries.push(text)
  }
  trim_entries(self.entries, self.config.max_entries)
}
