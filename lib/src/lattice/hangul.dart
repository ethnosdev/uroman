/// Algorithmic Korean Hangul syllable romanization.
class Hangul {
  static const leads = [
    'g',
    'gg',
    'n',
    'd',
    'dd',
    'r',
    'm',
    'b',
    'bb',
    's',
    'ss',
    '-',
    'j',
    'jj',
    'c',
    'k',
    't',
    'p',
    'h',
  ];

  static const vowels = [
    'a',
    'ae',
    'ya',
    'yae',
    'eo',
    'e',
    'yeo',
    'ye',
    'o',
    'wa',
    'wai',
    'oe',
    'yo',
    'u',
    'weo',
    'we',
    'wi',
    'yu',
    'eu',
    'yi',
    'i',
  ];

  static const tails = [
    '-',
    'g',
    'gg',
    'gs',
    'n',
    'nj',
    'nh',
    'd',
    'l',
    'lg',
    'lm',
    'lb',
    'ls',
    'lt',
    'lp',
    'lh',
    'm',
    'b',
    'bs',
    's',
    'ss',
    'ng',
    'j',
    'c',
    'k',
    't',
    'p',
    'h',
  ];

  static final Map<int, String> _cache = {};

  /// Romanizes a Korean Hangul syllable code point in the range `[0xAC00, 0xD7A3]`.
  static String? romanizeHangulCodePoint(int cp) {
    if (cp < 0xAC00 || cp > 0xD7A3) return null;
    final cached = _cache[cp];
    if (cached != null) return cached;

    final code = cp - 0xAC00;
    final leadIndex = code ~/ (28 * 21);
    final vowelIndex = (code ~/ 28) % 21;
    final tailIndex = code % 28;

    final rom = (leads[leadIndex] + vowels[vowelIndex] + tails[tailIndex])
        .replaceAll('-', '');
    _cache[cp] = rom;
    return rom;
  }
}
