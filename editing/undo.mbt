///|
/// 记录编辑器快照
pub struct UndoRecord {
  text : String
  cursor_pos : Int // 光标在完整字符串中的位置（对应 left.length()）
}

///|
pub fn UndoRecord::new(text : String, cursor_pos : Int) -> UndoRecord {
  { text, cursor_pos }
}

///|
/// 撤销重做管理器
struct UndoManager {
  history : Array[UndoRecord]
  mut current_index : Int
}

///|
pub fn UndoManager::new(
  initial_text : String,
  initial_cursor : Int,
) -> UndoManager {
  { history: [UndoRecord::new(initial_text, initial_cursor)], current_index: 0 }
}

///|
/// 记录新操作
pub fn UndoManager::track(
  self : UndoManager,
  text : String,
  cursor_pos : Int,
) -> Unit {
  let current = self.history[self.current_index]
  if text == current.text {
    // 文本未变，仅更新光标（防止产生冗余撤销步骤）
    self.history[self.current_index] = UndoRecord::new(text, cursor_pos)
    return
  }

  // 如果当前不在末尾（撤销后新操作），删除后面的记录
  if self.current_index < self.history.length() - 1 {
    let count_to_remove = self.history.length() - 1 - self.current_index
    for _ in 0..<count_to_remove {
      ignore(self.history.pop())
    }
  }

  self.history.push(UndoRecord::new(text, cursor_pos))
  self.current_index = self.history.length() - 1

  // 限制历史长度（可选）
  if self.history.length() > 100 {
    ignore(self.history.remove(0))
    self.current_index = self.current_index - 1
  }
}

///|
/// 执行撤销
pub fn UndoManager::undo(self : UndoManager) -> UndoRecord? {
  if self.current_index > 0 {
    self.current_index = self.current_index - 1
    Some(self.history[self.current_index])
  } else {
    None
  }
}

///|
/// 执行重做
pub fn UndoManager::redo(self : UndoManager) -> UndoRecord? {
  if self.current_index < self.history.length() - 1 {
    self.current_index = self.current_index + 1
    Some(self.history[self.current_index])
  } else {
    None
  }
}
