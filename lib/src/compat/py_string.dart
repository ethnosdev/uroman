/// String and code-point helper functions with Python semantics.
class PyString {
  /// Converts a Dart string to a list of Unicode code points (runes).
  static List<int> toCodePoints(String s) => s.runes.toList(growable: false);

  /// Creates a Dart string from an iterable of Unicode code points.
  static String fromCodePoints(Iterable<int> cps) => String.fromCharCodes(cps);

  /// Implements Python slicing on a list with negative indexing and boundary clamping.
  static List<T> slice<T>(List<T> list, int? start, [int? end]) {
    final len = list.length;
    var s = start ?? 0;
    var e = end ?? len;

    if (s < 0) s = len + s;
    if (s < 0) s = 0;
    if (s > len) s = len;

    if (e < 0) e = len + e;
    if (e < 0) e = 0;
    if (e > len) e = len;

    if (s >= e) return <T>[];
    return list.sublist(s, e);
  }

  /// Removes surrounding matching quotes (`''`, `""`, `“”`) if present.
  static String dequote(String s) {
    final trimmed = s.trim();
    if (trimmed.length >= 2) {
      final first = trimmed[0];
      final last = trimmed[trimmed.length - 1];
      if ((first == "'" && last == "'") ||
          (first == '"' && last == '"') ||
          (first == '“' && last == '”')) {
        return trimmed.substring(1, trimmed.length - 1);
      }
    }
    return s;
  }

  /// Returns the last code unit / character of a string, or empty string if empty.
  static String lastChar(String s) {
    if (s.isEmpty) return '';
    return s[s.length - 1];
  }

  /// Capitalizes a string (first character uppercase, rest lowercase).
  static String capitalize(String s) {
    if (s.isEmpty) return '';
    if (s.length == 1) return s.toUpperCase();
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  /// Decodes Unicode escape notations (\xXX, \uXXXX, \UXXXXXXXX) for non-ASCII characters (> 0x80).
  /// Preserves ASCII escapes such as \x22 (") and \x27 (').
  static String decodeUnicodeEscapes(String s) {
    final pattern = RegExp(r'\\([xuU])([0-9a-fA-F]{2,8})');
    if (!pattern.hasMatch(s)) return s;

    return s.replaceAllMapped(pattern, (match) {
      final type = match.group(1)!;
      final hex = match.group(2)!;
      var validHexLen = 0;
      if (type == 'x' && hex.length >= 2) {
        validHexLen = 2;
      } else if (type == 'u' && hex.length >= 4) {
        validHexLen = 4;
      } else if (type == 'U' && hex.length >= 8) {
        validHexLen = 8;
      }

      if (validHexLen > 0) {
        final hexPart = hex.substring(0, validHexLen);
        final remainder = hex.substring(validHexLen);
        final cp = int.tryParse(hexPart, radix: 16);
        if (cp != null && cp > 0x80 && cp <= 0x10FFFF) {
          return String.fromCharCode(cp) + remainder;
        }
      }
      return match.group(0)!;
    });
  }
}
