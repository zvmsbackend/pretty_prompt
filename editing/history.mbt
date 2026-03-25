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
pub impl Default for HistoryConfiguration with default() {
  HistoryConfiguration::new()
}

///|
pub struct HistoryLog {
  entries : Array[String]
  config : HistoryConfiguration
  mut navigation_index : Int?
  mut unsubmitted_buffer : String
  mut submissions_since_last_trim : Int
}

///|
pub fn HistoryLog::new(config : HistoryConfiguration) -> HistoryLog {
  {
    entries: [],
    config,
    navigation_index: None,
    unsubmitted_buffer: "",
    submissions_since_last_trim: 0,
  }
}

///|
pub async fn HistoryLog::load_persistent_history(self : HistoryLog) -> Unit {
  let filepath = match self.config.persistent_history_filepath {
    Some(filepath) => filepath
    None => return
  }

  if !@fs.exists(filepath) {
    return
  }

  let contents = @fs.read_file(filepath).text() catch {
    e => {
      if @async.is_being_cancelled() {
        raise e
      }
      return
    }
  }

  self.entries.clear()
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

///|
pub fn HistoryLog::navigate_previous(
  self : HistoryLog,
  current_buffer : String,
) -> String? {
  if self.entries.length() == 0 {
    return None
  }

  if self.navigation_index is None {
    self.unsubmitted_buffer = current_buffer
  }
  let pattern = self.unsubmitted_buffer

  let start = match self.navigation_index {
    Some(index) => if index > 0 { index - 1 } else { 0 }
    None => self.entries.length() - 1
  }

  find_previous_matching_index(self.entries, pattern, start).bind(index => {
    self.navigation_index = Some(index)
    Some(self.entries[index])
  })
}

///|
pub fn HistoryLog::navigate_next(self : HistoryLog) -> String? {
  let current_index = match self.navigation_index {
    Some(index) => index
    None => return None
  }

  let pattern = self.unsubmitted_buffer

  if current_index + 1 >= self.entries.length() {
    self.navigation_index = None
    return Some(self.unsubmitted_buffer)
  }

  match find_next_matching_index(self.entries, pattern, current_index + 1) {
    Some(index) => {
      self.navigation_index = Some(index)
      Some(self.entries[index])
    }
    None => {
      self.navigation_index = None
      Some(self.unsubmitted_buffer)
    }
  }
}

///|
pub fn HistoryLog::reset_navigation(self : HistoryLog) -> Unit {
  self.navigation_index = None
}

///|
pub async fn HistoryLog::track_submission(
  self : HistoryLog,
  text : String,
) -> Unit {
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
  self.append_persistent_history_entry(text)

  self.submissions_since_last_trim = self.submissions_since_last_trim + 1
  if self.submissions_since_last_trim >= 100 {
    self.save_persistent_history_full()
    self.submissions_since_last_trim = 0
  }
}

///|
pub fn HistoryLog::entry_count(self : HistoryLog) -> Int {
  self.entries.length()
}

///|
/// 在历史记录中搜索匹配项
pub fn HistoryLog::navigate_search(
  self : HistoryLog,
  query : String,
  start_index : Int,
) -> (Int, String)? {
  if self.entries.length() == 0 {
    return None
  }
  let start = if start_index < 0 {
    self.entries.length() - 1
  } else if start_index >= self.entries.length() {
    self.entries.length() - 1
  } else {
    start_index
  }
  for i in start>=..0 {
    let entry = self.entries[i]
    if matches_history_pattern(entry, query) {
      return Some((i, entry))
    }
  }
  None
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
async fn HistoryLog::append_persistent_history_entry(
  self : HistoryLog,
  text : String,
) -> Unit {
  let filepath = match self.config.persistent_history_filepath {
    Some(filepath) => filepath
    None => return
  }

  let entry = "\{text |> @utf8.encode |> @base64.encode}\n"
  let file = @fs.open(
    filepath,
    mode=WriteOnly,
    sync=Data,
    append=true,
    create=0o644,
  ) catch {
    _ => return
  }
  defer file.close()
  file.write(entry) catch {
    _ => ()
  }
}

///|
pub async fn HistoryLog::save_persistent_history_full(
  self : HistoryLog,
) -> Unit {
  let filepath = match self.config.persistent_history_filepath {
    Some(filepath) => filepath
    None => return
  }

  let lines = StringBuilder::new()
  for entry in self.entries {
    let encoded = entry |> @utf8.encode |> @base64.encode
    lines..write_string(encoded).write_char('\n')
  }

  @fs.write_file(filepath, lines.to_string(), create=0o644) catch {
    _ => ()
  }
}
