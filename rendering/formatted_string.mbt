///|
/// 带样式的字符串
pub struct FormattedString {
  text : String
  spans : Array[FormatSpan]
}

///|
pub fn FormattedString::new(
  text : String,
  spans? : Array[FormatSpan] = [],
) -> FormattedString {
  { text, spans }
}

///|
/// 获取长度（处理 Unicode 宽度）
pub fn FormattedString::width(self : FormattedString) -> Int {
  get_string_width(self.text)
}
