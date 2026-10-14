import 'dart:typed_data';

import 'unicode_tables.g.dart';

/// Provides Unicode property queries matching Python's `unicodedata` behavior.
class UnicodeProps {
  /// Performs an O(log N) binary search over sorted [start0, end0, start1, end1, ...] range pairs.
  static bool isInRanges(Uint32List ranges, int cp) {
    var low = 0;
    var high = (ranges.length >> 1) - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final idx = mid << 1;
      final start = ranges[idx];
      final end = ranges[idx + 1];
      if (cp < start) {
        high = mid - 1;
      } else if (cp > end) {
        low = mid + 1;
      } else {
        return true;
      }
    }
    return false;
  }

  /// Category 'Mn' (Nonspacing Mark).
  static bool isNonspacingMark(int cp) => isInRanges(mnRanges, cp);

  /// Category 'Cf' (Format Character).
  static bool isFormatChar(int cp) => isInRanges(cfRanges, cp);

  /// Category 'Zs' (Space Separator).
  static bool isSpaceSeparator(int cp) => isInRanges(zsRanges, cp);

  /// Category 'Co' (Private Use Area).
  static bool isPrivateUse(int cp) => isInRanges(coRanges, cp);

  /// Categories 'L*' (\pL or isalpha).
  static bool isLetter(int cp) => isInRanges(letterCatRanges, cp);

  /// Python `isalpha()` equivalent for Unicode characters.
  static bool isAlpha(int cp) => isLetter(cp);

  /// Categories 'M*' (\pM, nonspacing, spacing combining, and enclosing marks).
  static bool isMark(int cp) => isInRanges(markCatRanges, cp);

  /// Matches `\pL|\pM` (letter or mark).
  static bool isLetterOrMark(int cp) => isLetter(cp) || isMark(cp);

  /// Category 'Lu' (Uppercase Letter).
  static bool isUpper(int cp) => isInRanges(upperCatRanges, cp);

  /// Category 'Ll' (Lowercase Letter).
  static bool isLower(int cp) => isInRanges(lowerCatRanges, cp);

  /// Character name contains 'LETTER'.
  static bool hasLetterInName(int cp) => isInRanges(nameLetterRanges, cp);

  /// Character name contains 'DIGIT'.
  static bool hasDigitInName(int cp) => isInRanges(nameDigitRanges, cp);

  /// Character name contains 'SUBJOINED LETTER' (Tibetan subjoined consonants).
  static bool hasSubjoinedInName(int cp) => nameSubjoinedSet.contains(cp);
  static bool hasSubjoinedLetterInName(int cp) => hasSubjoinedInName(cp);

  /// Character name contains 'NUKTA' (Indic nukta marks).
  static bool hasNuktaInName(int cp) => nameNuktaSet.contains(cp);

  /// Character name contains 'VOCALIC' (Indic vocalic signs).
  static bool hasVocalicInName(int cp) => nameVocalicSet.contains(cp);

  /// Character name contains 'MYANMAR VOWEL SIGN KAYAH'.
  static bool isMyanmarKayah(int cp) => nameMyanmarKayahSet.contains(cp);

  /// Character name contains 'MENDE KIKAKUI SYLLABLE'.
  static bool isMendeKikakui(int cp) => nameMendeKikakuiSet.contains(cp);

  /// Numeric value from `ud.numeric(char)`, returning int if whole or double if fractional, or null.
  static num? udNumeric(int cp) => numericIntMap[cp] ?? numericFloatMap[cp];

  /// Decomposition string for `decomp_rom` (e.g. vulgar fractions, compatibility characters).
  static String? decompRom(int cp) => decompRomMap[cp];

  /// Pre-extracted numerator and denominator for `<fraction>` characters.
  static List<int>? fractionDecomp(int cp) => fractionMap[cp];
}
