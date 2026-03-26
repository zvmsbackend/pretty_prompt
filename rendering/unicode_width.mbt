///|
priv struct Interval {
  first : Int
  last : Int
}

///|
fn Interval::new(first : Int, last : Int) -> Interval {
  { first, last }
}

///|
fn binary_search(ucs : Int, table : Array[Interval]) -> Bool {
  let mut min = 0
  let mut max = table.length() - 1
  if ucs < table[0].first || ucs > table[max].last {
    return false
  }
  while max >= min {
    let mid = (min + max) / 2
    if ucs > table[mid].last {
      min = mid + 1
    } else if ucs < table[mid].first {
      max = mid - 1
    } else {
      return true
    }
  }
  false
}

///|
let combining : Array[Interval] = [
  Interval::new(0x0300, 0x036F),
  Interval::new(0x0483, 0x0486),
  Interval::new(0x0488, 0x0489),
  Interval::new(0x0591, 0x05BD),
  Interval::new(0x05BF, 0x05BF),
  Interval::new(0x05C1, 0x05C2),
  Interval::new(0x05C4, 0x05C5),
  Interval::new(0x05C7, 0x05C7),
  Interval::new(0x0600, 0x0603),
  Interval::new(0x0610, 0x0615),
  Interval::new(0x064B, 0x065E),
  Interval::new(0x0670, 0x0670),
  Interval::new(0x06D6, 0x06E4),
  Interval::new(0x06E7, 0x06E8),
  Interval::new(0x06EA, 0x06ED),
  Interval::new(0x070F, 0x070F),
  Interval::new(0x0711, 0x0711),
  Interval::new(0x0730, 0x074A),
  Interval::new(0x07A6, 0x07B0),
  Interval::new(0x07EB, 0x07F3),
  Interval::new(0x0901, 0x0902),
  Interval::new(0x093C, 0x093C),
  Interval::new(0x0941, 0x0948),
  Interval::new(0x094D, 0x094D),
  Interval::new(0x0951, 0x0954),
  Interval::new(0x0962, 0x0963),
  Interval::new(0x0981, 0x0981),
  Interval::new(0x09BC, 0x09BC),
  Interval::new(0x09C1, 0x09C4),
  Interval::new(0x09CD, 0x09CD),
  Interval::new(0x09E2, 0x09E3),
  Interval::new(0x0A01, 0x0A02),
  Interval::new(0x0A3C, 0x0A3C),
  Interval::new(0x0A41, 0x0A42),
  Interval::new(0x0A47, 0x0A48),
  Interval::new(0x0A4B, 0x0A4D),
  Interval::new(0x0A70, 0x0A71),
  Interval::new(0x0A81, 0x0A82),
  Interval::new(0x0ABC, 0x0ABC),
  Interval::new(0x0AC1, 0x0AC5),
  Interval::new(0x0AC7, 0x0AC8),
  Interval::new(0x0ACD, 0x0ACD),
  Interval::new(0x0AE2, 0x0AE3),
  Interval::new(0x0B01, 0x0B01),
  Interval::new(0x0B3C, 0x0B3C),
  Interval::new(0x0B3F, 0x0B3F),
  Interval::new(0x0B41, 0x0B43),
  Interval::new(0x0B4D, 0x0B4D),
  Interval::new(0x0B56, 0x0B56),
  Interval::new(0x0B82, 0x0B82),
  Interval::new(0x0BC0, 0x0BC0),
  Interval::new(0x0BCD, 0x0BCD),
  Interval::new(0x0C3E, 0x0C40),
  Interval::new(0x0C46, 0x0C48),
  Interval::new(0x0C4A, 0x0C4D),
  Interval::new(0x0C55, 0x0C56),
  Interval::new(0x0CBC, 0x0CBC),
  Interval::new(0x0CBF, 0x0CBF),
  Interval::new(0x0CC6, 0x0CC6),
  Interval::new(0x0CCC, 0x0CCD),
  Interval::new(0x0CE2, 0x0CE3),
  Interval::new(0x0D41, 0x0D43),
  Interval::new(0x0D4D, 0x0D4D),
  Interval::new(0x0DCA, 0x0DCA),
  Interval::new(0x0DD2, 0x0DD4),
  Interval::new(0x0DD6, 0x0DD6),
  Interval::new(0x0E31, 0x0E31),
  Interval::new(0x0E34, 0x0E3A),
  Interval::new(0x0E47, 0x0E4E),
  Interval::new(0x0EB1, 0x0EB1),
  Interval::new(0x0EB4, 0x0EB9),
  Interval::new(0x0EBB, 0x0EBC),
  Interval::new(0x0EC8, 0x0ECD),
  Interval::new(0x0F18, 0x0F19),
  Interval::new(0x0F35, 0x0F35),
  Interval::new(0x0F37, 0x0F37),
  Interval::new(0x0F39, 0x0F39),
  Interval::new(0x0F71, 0x0F7E),
  Interval::new(0x0F80, 0x0F84),
  Interval::new(0x0F86, 0x0F87),
  Interval::new(0x0F90, 0x0F97),
  Interval::new(0x0F99, 0x0FBC),
  Interval::new(0x0FC6, 0x0FC6),
  Interval::new(0x102D, 0x1030),
  Interval::new(0x1032, 0x1032),
  Interval::new(0x1036, 0x1037),
  Interval::new(0x1039, 0x1039),
  Interval::new(0x1058, 0x1059),
  Interval::new(0x1160, 0x11FF),
  Interval::new(0x135F, 0x135F),
  Interval::new(0x1712, 0x1714),
  Interval::new(0x1732, 0x1734),
  Interval::new(0x1752, 0x1753),
  Interval::new(0x1772, 0x1773),
  Interval::new(0x17B4, 0x17B5),
  Interval::new(0x17B7, 0x17BD),
  Interval::new(0x17C6, 0x17C6),
  Interval::new(0x17C9, 0x17D3),
  Interval::new(0x17DD, 0x17DD),
  Interval::new(0x180B, 0x180D),
  Interval::new(0x18A9, 0x18A9),
  Interval::new(0x1920, 0x1922),
  Interval::new(0x1927, 0x1928),
  Interval::new(0x1932, 0x1932),
  Interval::new(0x1939, 0x193B),
  Interval::new(0x1A17, 0x1A18),
  Interval::new(0x1B00, 0x1B03),
  Interval::new(0x1B34, 0x1B34),
  Interval::new(0x1B36, 0x1B3A),
  Interval::new(0x1B3C, 0x1B3C),
  Interval::new(0x1B42, 0x1B42),
  Interval::new(0x1B6B, 0x1B73),
  Interval::new(0x1DC0, 0x1DCA),
  Interval::new(0x1DFE, 0x1DFF),
  Interval::new(0x200B, 0x200F),
  Interval::new(0x202A, 0x202E),
  Interval::new(0x2060, 0x2063),
  Interval::new(0x206A, 0x206F),
  Interval::new(0x20D0, 0x20EF),
  Interval::new(0x302A, 0x302F),
  Interval::new(0x3099, 0x309A),
  Interval::new(0xA806, 0xA806),
  Interval::new(0xA80B, 0xA80B),
  Interval::new(0xA825, 0xA826),
  Interval::new(0xFB1E, 0xFB1E),
  Interval::new(0xFE00, 0xFE0F),
  Interval::new(0xFE20, 0xFE23),
  Interval::new(0xFEFF, 0xFEFF),
  Interval::new(0xFFF9, 0xFFFB),
  Interval::new(0x10A01, 0x10A03),
  Interval::new(0x10A05, 0x10A06),
  Interval::new(0x10A0C, 0x10A0F),
  Interval::new(0x10A38, 0x10A3A),
  Interval::new(0x10A3F, 0x10A3F),
  Interval::new(0x1D167, 0x1D169),
  Interval::new(0x1D173, 0x1D182),
  Interval::new(0x1D185, 0x1D18B),
  Interval::new(0x1D1AA, 0x1D1AD),
  Interval::new(0x1D242, 0x1D244),
  Interval::new(0xE0001, 0xE0001),
  Interval::new(0xE0020, 0xE007F),
  Interval::new(0xE0100, 0xE01EF),
]

///|
fn get_char_width(ch : Char) -> Int {
  let ucs = ch.to_int()
  if ucs == 0 {
    return 0
  }
  if ucs == 10 {
    return 1
  }
  if ucs < 32 || (ucs >= 0x7F && ucs < 0xA0) {
    return 0
  }
  if ucs < 0x0300 {
    return 1
  }
  if ucs >= 0x2500 && ucs <= 0x257F {
    return 1
  }
  if binary_search(ucs, combining) {
    return 0
  }
  match ucs {
    0x26AA | 0x26AB | 0x2B55 | 0x26A1 | 0x2B1B | 0x2B1C | 0x274C | 0x2705 => 2
    _ =>
      if ucs >= 0x1100 &&
        (
          ucs <= 0x115F ||
          ucs == 0x2329 ||
          ucs == 0x232A ||
          (ucs >= 0x2E80 && ucs <= 0xA4CF && ucs != 0x303F) ||
          (ucs >= 0xAC00 && ucs <= 0xD7A3) ||
          (ucs >= 0xF900 && ucs <= 0xFAFF) ||
          (ucs >= 0xFE10 && ucs <= 0xFE19) ||
          (ucs >= 0xFE30 && ucs <= 0xFE6F) ||
          (ucs >= 0xFF00 && ucs <= 0xFF60) ||
          (ucs >= 0xFFE0 && ucs <= 0xFFE6) ||
          (ucs >= 0x20000 && ucs <= 0x2FFFD) ||
          (ucs >= 0x30000 && ucs <= 0x3FFFD)
        ) {
        2
      } else {
        1
      }
  }
}

///|
fn get_chars_width(chars : Iter[Char]) -> Int {
  for ch in chars; width = 0 {
    continue width + get_char_width(ch)
  } nobreak {
    width
  }
}

///|
pub fn get_string_width(s : String) -> Int {
  get_chars_width(s.iter())
}

///|
pub fn is_word_boundary(c1 : Char?, c2 : Char?) -> Bool {
  match (c1, c2) {
    (Some(c1), Some(c2)) => {
      let is_whitespace1 = c1.is_whitespace()
      let is_whitespace2 = c2.is_whitespace()
      if is_whitespace1 && !is_whitespace2 {
        true
      } else if is_whitespace1 || is_whitespace2 {
        false
      } else {
        is_alphanumeric(c1) != is_alphanumeric(c2)
      }
    }
    _ => false
  }
}

///|
fn is_alphanumeric(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit()
}
