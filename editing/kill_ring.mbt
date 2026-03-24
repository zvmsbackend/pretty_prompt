///|
/// 剪切环（环形缓冲区）
pub struct KillRing {
  items : Array[String]
  mut current_index : Int
  max_size : Int
}

///|
pub fn KillRing::new(max_size? : Int = 20) -> KillRing {
  { items: [], current_index: -1, max_size }
}

///|
/// 添加文本到剪切环
pub fn KillRing::add(self : KillRing, text : String) -> Unit {
  if text == "" {
    return
  }
  // 如果与上一个相同，通常不重复添加
  if self.items.length() > 0 && self.items[0] == text {
    return
  }
  self.items.insert(0, text)
  if self.items.length() > self.max_size {
    ignore(self.items.pop())
  }
  self.current_index = 0
}

///|
/// 获取最近的文本
pub fn KillRing::yank(self : KillRing) -> String? {
  if self.items.length() == 0 {
    None
  } else {
    self.current_index = 0
    Some(self.items[0])
  }
}

///|
/// 循环切换
pub fn KillRing::yank_pop(self : KillRing) -> String? {
  if self.items.length() <= 1 {
    None
  } else {
    self.current_index = (self.current_index + 1) % self.items.length()
    Some(self.items[self.current_index])
  }
}
