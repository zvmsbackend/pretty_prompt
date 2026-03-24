///|
pub struct KeyPress {
  console_key_info : @console.ConsoleKeyInfo
  pasted_text : String?
}

///|
pub fn KeyPress::from_console_key_info(
  console_key_info : @console.ConsoleKeyInfo,
) -> KeyPress {
  let normalized = normalize_enter(console_key_info)
  { console_key_info: normalized, pasted_text: None }
}

///|
pub fn KeyPress::from_pasted_text(pasted_text : String) -> KeyPress {
  let paste_key = @console.ConsoleKeyInfo::new(
    '\u0000',
    @console.Insert,
    true,
    false,
    false,
  )
  { console_key_info: paste_key, pasted_text: Some(pasted_text) }
}

///|
pub fn read_key_presses(console : &ConsolePort) -> Array[KeyPress] {
  let first = console.read_key(true)
  if !console.key_available() {
    return [KeyPress::from_console_key_info(first)]
  }

  let keys : Array[@console.ConsoleKeyInfo] = [first]
  while console.key_available() {
    keys.push(console.read_key(true))
  }

  if keys.length() < 4 || all_control_chars(keys) {
    return keys_to_key_presses(keys)
  }

  let pasted = StringBuilder::new()
  for key in keys {
    pasted.write_string(key.key_char.to_string())
  }
  [KeyPress::from_pasted_text(pasted.to_string())]
}

///|
fn normalize_enter(
  key_info : @console.ConsoleKeyInfo,
) -> @console.ConsoleKeyInfo {
  if key_info.key is @console.Enter && key_info.key_char == '\r' {
    @console.ConsoleKeyInfo::new(
      '\n',
      @console.Enter,
      key_info.shift,
      key_info.alt,
      key_info.control,
    )
  } else {
    key_info
  }
}

///|
fn keys_to_key_presses(
  keys : Array[@console.ConsoleKeyInfo],
) -> Array[KeyPress] {
  keys.map(KeyPress::from_console_key_info)
}

///|
fn all_control_chars(keys : Array[@console.ConsoleKeyInfo]) -> Bool {
  keys.iter().all(key => key.key_char.is_ascii_control())
}
