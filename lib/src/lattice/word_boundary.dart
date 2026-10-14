import '../unicode/unicode_props.dart';
import 'candidate_selector.dart';
import 'lattice.dart';

/// Helper methods for determining word and syllable boundaries in the lattice.
class WordBoundary {
  static bool charIsBraille(int cp) => cp >= 0x2800 && cp <= 0x28FF;

  static bool charIsSubjoinedLetter(Lattice lat, int cp) =>
      UnicodeProps.hasSubjoinedLetterInName(cp);

  static bool charIsLetter(Lattice lat, int cp) =>
      UnicodeProps.hasLetterInName(cp);

  static bool charIsRegularLetter(Lattice lat, int cp) =>
      UnicodeProps.hasLetterInName(cp) &&
      !UnicodeProps.hasSubjoinedLetterInName(cp);

  static bool charIsVowelSign(Lattice lat, int cp) =>
      lat.uroman.isVowelSign.contains(String.fromCharCode(cp));

  static bool charIsLetterOrVowelSign(Lattice lat, int cp) =>
      charIsLetter(lat, cp) || charIsVowelSign(lat, cp);

  /// Checks if [position] is at the start of a word.
  static bool isAtStartOfWord(Lattice lat, int position) {
    if (position >= lat.maxVertex) return true;
    final firstCharCp = lat.codePoints[position];
    final firstCharIsBraille = charIsBraille(firstCharCp);
    final cacheKey = 'preceded_by_alpha:$position';
    final cached = lat.props[cacheKey];
    if (cached is bool) return !cached;

    if (position > 0) {
      final prevCp = lat.codePoints[position - 1];
      if (UnicodeProps.isAlpha(prevCp)) {
        lat.props[cacheKey] = true;
        return false;
      }
    }

    for (final start in lat.sortedLeftStarts(position)) {
      for (final edge in lat.edgesInSpan(start, position)) {
        if (edge.txt.isNotEmpty) {
          final lastChar = edge.txt[edge.txt.length - 1];
          final lastCp = lastChar.codeUnitAt(0);
          final isAlpha =
              UnicodeProps.isAlpha(lastCp) ||
              (lastCp >= 0x41 && lastCp <= 0x5A) ||
              (lastCp >= 0x61 && lastCp <= 0x7A);
          if (isAlpha || (firstCharIsBraille && lastChar == "'")) {
            lat.props[cacheKey] = true;
            return false;
          }
        }
      }
    }

    lat.props[cacheKey] = false;
    return true;
  }

  /// Checks if [position] is at the end of a word.
  static bool isAtEndOfWord(Lattice lat, int position) {
    final cacheKey = 'followed_by_alpha:$position';
    final cached = lat.props[cacheKey];
    if (cached is bool) return !cached;

    var start = position;
    if (start < lat.maxVertex) {
      final nextCp = lat.codePoints[start];
      if (UnicodeProps.isAlpha(nextCp)) {
        lat.props[cacheKey] = true;
        return false;
      }
    }

    while (start + 1 < lat.maxVertex &&
        UnicodeProps.isNonspacingMark(lat.codePoints[start]) &&
        UnicodeProps.hasNuktaInName(lat.codePoints[start])) {
      start++;
    }

    for (var end = start + 1; end <= lat.maxVertex; end++) {
      final s = lat.substring(start, end);
      if (!lat.uroman.sPrefix.contains(s)) break;

      final rules = lat.uroman.romRules[s];
      if (rules != null) {
        for (final rule in rules) {
          final rom = rule.t;
          if (rom != null &&
              !rule.useOnlyAtStartOfWord &&
              _containsLetter(rom)) {
            lat.props[cacheKey] = true;
            return false;
          }
        }
      }
    }

    lat.props[cacheKey] = false;
    return true;
  }

  /// Checks if [position] is at the end of a syllable (mainly for Thai).
  static (bool, String) isAtEndOfSyllable(Lattice lat, int position) {
    final prevCharCp = position >= 2 ? lat.codePoints[position - 2] : null;
    final nextCharCp = position < lat.maxVertex
        ? lat.codePoints[position]
        : null;

    final nextCharStr = nextCharCp != null
        ? String.fromCharCode(nextCharCp)
        : null;
    int adjPosition;
    int? adjNextCharCp;

    if (nextCharStr != null &&
        lat.uroman.charToToneMark.containsKey(nextCharStr)) {
      adjPosition = position + 1;
      adjNextCharCp = adjPosition < lat.maxVertex
          ? lat.codePoints[adjPosition]
          : null;
    } else {
      adjPosition = position;
      adjNextCharCp = nextCharCp;
    }

    final nextChar2Cp = adjPosition + 1 < lat.maxVertex
        ? lat.codePoints[adjPosition + 1]
        : null;

    if (prevCharCp == null) {
      return (false, 'start-of-string');
    }

    if (!UnicodeProps.isLetterOrMark(prevCharCp)) {
      return (false, 'start-of-token');
    }

    final prevCharStr = String.fromCharCode(prevCharCp);
    if (lat.uroman.charToSyllableInfo[prevCharStr] ==
        'written-pre-consonant-spoken-post-consonant') {
      return (false, 'pre-post-vowel-on-left');
    }

    final adjNextCharStr = adjNextCharCp != null
        ? String.fromCharCode(adjNextCharCp)
        : null;
    if (adjNextCharStr != null &&
        lat.uroman.charToSyllableInfo[adjNextCharStr] ==
            'written-pre-consonant-spoken-post-consonant') {
      return (true, 'pre-post-vowel-on-right');
    }

    if (adjPosition >= lat.maxVertex) {
      return (true, 'end-of-string');
    }

    if (adjNextCharCp != null && !UnicodeProps.isLetterOrMark(adjNextCharCp)) {
      return (true, 'end-of-token');
    }

    if (position > 0) {
      final leftEdge = lat.bestLeftNeighborEdge(position - 1);
      if (leftEdge != null &&
          RegExp(r'[bcdfghjklmnpqrstvxz]$').hasMatch(leftEdge.txt)) {
        return (false, 'consonant-to-the-left');
      }
    }

    final cand2 = CandidateSelector.simpleTopCandidate(
      lat,
      adjPosition,
      adjPosition + 2,
      simpleSearch: true,
    );
    final cand1 = CandidateSelector.simpleTopCandidate(
      lat,
      adjPosition,
      adjPosition + 1,
      simpleSearch: true,
    );
    final nextCharRom = cand2 ?? cand1 ?? '?';

    if (!RegExp(r'^[aeiou]', caseSensitive: false).hasMatch(nextCharRom)) {
      return (true, 'not-followed-by-vowel $nextCharRom');
    }

    if (adjNextCharCp == 0x0E2D && nextChar2Cp != null) {
      // THAI CHARACTER O ANG
      final candOAng = CandidateSelector.simpleTopCandidate(
        lat,
        adjPosition + 1,
        adjPosition + 2,
        simpleSearch: true,
      );
      final nextChar2Rom = candOAng ?? '?';
      if (RegExp(r'^[aeiou]', caseSensitive: false).hasMatch(nextChar2Rom)) {
        return (true, 'o-ang-followed-by-vowel');
      }
    }

    return (false, 'not-at-syllable-end-by-default');
  }

  static bool _containsLetter(String s) {
    for (final rune in s.runes) {
      if (UnicodeProps.isAlpha(rune) ||
          (rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A)) {
        return true;
      }
    }
    return false;
  }
}
