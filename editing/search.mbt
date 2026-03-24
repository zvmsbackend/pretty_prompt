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

///|
pub fn SearchState::set_query(self : SearchState, query : String) -> Unit {
  self.query = query
}

///|
pub fn SearchState::set_history_index(
  self : SearchState,
  history_index : Int,
) -> Unit {
  self.history_index = history_index
}
