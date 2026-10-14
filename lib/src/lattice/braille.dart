import 'lattice.dart';

/// Implements Braille capitalization preprocessing and Braille number detection.
class Braille {
  static const brailleDigits =
      '\u281A\u2801\u2803\u2809\u2819\u2811\u280B\u281B\u2813\u280A';

  /// Scans for Braille double-dots-6 capitalization markers.
  static void prepBraille(Lattice lat) {
    if (!lat.containsScript.contains('Braille')) return;

    const dots6 = 0x2820;
    var allCaps = false;

    for (var i = 0; i < lat.maxVertex; i++) {
      final cp = lat.codePoints[i];
      if (i >= 1 && lat.codePoints[i - 1] == dots6 && cp == dots6) {
        allCaps = true;
      } else if (allCaps) {
        if (cp == 0x2800) {
          // Braille space
          allCaps = false;
        } else {
          lat.props['is-upper:$i'] = true;
        }
      }
    }
  }

  /// Maps a Braille character code point to its decimal digit '0'-'9'.
  static String? brailleDigit(int cp) {
    final charStr = String.fromCharCode(cp);
    final pos = brailleDigits.indexOf(charStr);
    return pos >= 0 ? pos.toString() : null;
  }

  /// Detects and registers Braille number sequences in the lattice.
  static void addBrailleNumbers(Lattice lat) {
    if (!lat.containsScript.contains('Braille')) return;

    var numS = StringBuffer();
    int? start;

    for (var i = 0; i < lat.maxVertex; i++) {
      final cp = lat.codePoints[i];
      if (cp == 0x283C) {
        // Number mark
        start ??= i;
      } else if (start != null) {
        final digit = brailleDigit(cp);
        if (digit != null) {
          numS.write(digit);
        } else if (cp == 0x2832) {
          // Period
          numS.write('.');
        } else if (cp == 0x2802) {
          // Comma
          numS.write(',');
        } else {
          if (numS.isNotEmpty) {
            _addBrailleNumberEdge(lat, start, i, numS.toString());
            numS = StringBuffer();
            start = null;
          }
        }
      }
    }

    if (start != null && numS.isNotEmpty) {
      _addBrailleNumberEdge(lat, start, lat.maxVertex, numS.toString());
    }
  }

  static void _addBrailleNumberEdge(
    Lattice lat,
    int start,
    int end,
    String txt,
  ) {
    final edge = lat.createNumEdge(start, end, txt);
    edge.type = 'number';
    lat.addEdge(edge);
  }
}
