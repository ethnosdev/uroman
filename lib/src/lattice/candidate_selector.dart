import '../models/rom_rule.dart';
import 'lattice.dart';
import 'word_boundary.dart';

/// Selects candidate romanization rules for spans in the lattice.
class CandidateSelector {
  /// Validates whether a romanization rule can apply to the span `[start, end]`.
  static bool candIsValid(
    Lattice lat,
    RomRule rule,
    int start,
    int end,
    String? rom,
  ) {
    if (rom == null) return false;

    if (rule.dontUseAtStartOfWord && WordBoundary.isAtStartOfWord(lat, start)) {
      return false;
    }
    if (rule.useOnlyAtStartOfWord &&
        !WordBoundary.isAtStartOfWord(lat, start)) {
      return false;
    }
    if (rule.dontUseAtEndOfWord && WordBoundary.isAtEndOfWord(lat, end)) {
      return false;
    }
    if (rule.useOnlyAtEndOfWord && !WordBoundary.isAtEndOfWord(lat, end)) {
      return false;
    }
    if (rule.useOnlyForWholeWord &&
        !(WordBoundary.isAtStartOfWord(lat, start) &&
            WordBoundary.isAtEndOfWord(lat, end))) {
      return false;
    }
    if (rule.lcodes.isNotEmpty &&
        (lat.lcode == null || !rule.lcodes.contains(lat.lcode))) {
      return false;
    }
    return true;
  }

  /// Finds the highest-priority romanization candidate for span `[start, end]`.
  static String? simpleTopCandidate(
    Lattice lat,
    int start,
    int end, {
    bool simpleSearch = false,
  }) {
    if (start < 0 || end > lat.maxVertex) return null;

    final spanKey = (start << 32) | (end & 0xFFFFFFFF);
    if (lat.simpleTopRomCache.containsKey(spanKey)) {
      return lat.simpleTopRomCache[spanKey];
    }

    final s = lat.substring(start, end);
    final rules = lat.uroman.romRules[s];
    if (rules == null || rules.isEmpty) {
      if (!simpleSearch) lat.simpleTopRomCache[spanKey] = null;
      return null;
    }

    String? bestCand;
    int? bestNRestr;
    RomRule? bestRule;

    for (final rule in rules) {
      if (candIsValid(lat, rule, start, end, rule.t)) {
        final nRestr = rule.nRestr;
        if (bestNRestr == null || nRestr > bestNRestr) {
          bestCand = rule.t;
          bestNRestr = nRestr;
          bestRule = rule;
        }
      }
    }

    if (simpleSearch) return bestCand;

    if (bestRule != null && bestRule.tAtEndOfSyllable != null) {
      final (isEndOfSyllable, _) = WordBoundary.isAtEndOfSyllable(lat, end);
      if (isEndOfSyllable) {
        bestCand = bestRule.tAtEndOfSyllable;
      }
    }

    lat.simpleTopRomCache[spanKey] = bestCand;
    return bestCand;
  }

  /// Returns romanization by the first rule for a string, matching Python `romanization_by_first_rule`.
  static String? romanizationByFirstRule(Lattice lat, String s) {
    final rules = lat.uroman.romRules[s];
    if (rules != null && rules.isNotEmpty) {
      return rules[0].t;
    }
    return null;
  }
}
