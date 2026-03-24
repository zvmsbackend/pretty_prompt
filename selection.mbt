///|
/// 文本选区状态
pub struct Selection {
  anchor : Int // 选择开始时的固定点（字符索引）
  mut active : Int // 随光标移动的动态点（字符索引）
}

///|
pub fn Selection::new(anchor : Int, active : Int) -> Selection {
  { anchor, active }
}

///|
/// 获取选区的规格化范围 [min, max)
pub fn Selection::range(self : Selection) -> (Int, Int) {
  if self.anchor <= self.active {
    (self.anchor, self.active)
  } else {
    (self.active, self.anchor)
  }
}

///|
/// 判断索引是否在选区内
pub fn Selection::contains(self : Selection, index : Int) -> Bool {
  let (start, end) = self.range()
  index >= start && index < end
}
