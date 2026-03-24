///|
/// 搜索状态
pub struct SearchState {
  mut query : String
  mut history_index : Int // 当前匹配到的历史记录索引
}

///|
pub fn SearchState::new() -> SearchState {
  { query: "", history_index: -1 }
}
