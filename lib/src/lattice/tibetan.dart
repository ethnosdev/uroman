import 'candidate_selector.dart';
import 'lattice.dart';
import 'word_boundary.dart';

/// Implements Tibetan vowel edge selection heuristics.
class Tibetan {
  static void pickTibetanVowelEdge(Lattice lat) {
    if (!lat.containsScript.contains('Tibetan')) return;

    final tibetanSyllables = <List<int>>[];
    var currentSyllable = <int>[];

    for (var start = 0; start < lat.maxVertex; start++) {
      final cp = lat.codePoints[start];
      final charStr = String.fromCharCode(cp);
      if ((lat.uroman.charToScript[charStr] ?? '') == 'Tibetan' &&
          WordBoundary.charIsLetterOrVowelSign(lat, cp)) {
        currentSyllable.add(start);
      } else {
        if (currentSyllable.isNotEmpty) {
          tibetanSyllables.add(currentSyllable);
          currentSyllable = [];
        }
      }
    }
    if (currentSyllable.isNotEmpty) {
      tibetanSyllables.add(currentSyllable);
    }

    for (final positions in tibetanSyllables) {
      int? vowelPos;
      final roms = <String>[];
      final subjoinedLetterPositions = <int>[];
      final firstPos = positions[0];

      for (final i in positions) {
        final cp = lat.codePoints[i];
        var rom = CandidateSelector.simpleTopCandidate(lat, i, i + 1) ?? '?';
        lat.props['edge-vowel:$i'] = null;

        if (WordBoundary.charIsVowelSign(lat, cp) ||
            RegExp(r'[aeiou]+$').hasMatch(rom)) {
          vowelPos = i;
          lat.props['edge-vowel:$i'] = true;
          // Delete syllable-initial ' before vowel
          if (roms.length == 1 && roms[0] == "'") {
            lat.props['edge-delete:${i - 1}'] = true;
          }
        } else if (WordBoundary.charIsSubjoinedLetter(lat, cp)) {
          subjoinedLetterPositions.add(i);
          if (i > firstPos) {
            if (cp == 0x0FB0) {
              vowelPos = i - 1;
              lat.props['edge-vowel:${i - 1}'] = true;
            } else {
              lat.props['edge-vowel:${i - 1}'] = false;
            }
          }
          rom = rom.replaceFirst(
            RegExp(r'([bcdfghjklmnpqrstvwxyz].*)a$'),
            r'$1',
          );
        } else if (cp == 0x0F60) {
          // Tibetan letter -a, romanized as apostrophe "'"
          lat.props['edge-vowel:$i'] = false;
          if (i > firstPos) {
            vowelPos = i - 1;
            lat.props['edge-vowel:${i - 1}'] = true;
            if (i == positions.last) {
              lat.props['edge-delete:$i'] = true;
            }
          }
          if (roms.isNotEmpty && !RegExp(r'[aeiou]$').hasMatch(roms.last)) {
            rom = "a'";
          } else {
            rom = "'";
          }
        } else {
          rom = rom.replaceFirst(
            RegExp(r'([bcdfghjklmnpqrstvwxyz].*)a$'),
            r'$1',
          );
        }
        roms.add(rom);
      }

      if (vowelPos != null) {
        for (final i in positions) {
          if (lat.props['edge-vowel:$i'] == null) {
            lat.props['edge-vowel:$i'] = false;
          }
        }
      } else {
        var bestCost = double.infinity;
        int? bestVowelPos;
        final nLetters = positions.length;

        for (final i in positions) {
          final relPos = i - firstPos;
          final pre = roms.sublist(0, relPos + 1).join('');
          final post = roms.sublist(relPos + 1).join('');
          double cost;

          if (lat.props['edge-vowel:$i'] == false) {
            cost = 20.0;
          } else if (nLetters == 1) {
            cost = 0.0;
          } else if (nLetters == 2) {
            cost = (relPos == 0) ? 0.0 : 0.1;
          } else {
            final goodSuffix = RegExp(
              r"^(?:|[bcdfghjklmnpqrstvwxz]|bh|bs|ch|cs|dd|ddh|"
              r"dh|dz|dzh|gh|gr|gs|kh|khs|kss|n|nn|nt|ms|ng|ngs|ns|ph|"
              r"rm|sh|ss|th|ts|tsh|tt|tth|zh|zhs)'?$",
            ).hasMatch(post);

            final goodPrefix = RegExp(
              r"^'?(?:.|bd|br|brg|brgy|bs|bsh|bst|bt|bts|by|bz|bzh|"
              r"ch|db|dby|dk|dm|dp|dpy|dr|"
              r"gl|gn|gr|gs|gt|gy|gzh|kh|khr|khy|kr|ky|ld|lh|lt|mkh|mny|mth|mtsh|"
              r"ny|ph|phr|phy|rgy|rk|el|rn|rny|rt|rts|"
              r"sk|skr|sky|sl|sm|sn|sny|sp|spy|sr|st|th|ts|tsh)$",
            ).hasMatch(pre);

            final remainingPositions = positions.sublist(
              relPos + 2 < positions.length ? relPos + 2 : positions.length,
            );
            final subjoinedSuffix = remainingPositions.every(
              (x) => subjoinedLetterPositions.contains(x),
            );

            if (goodSuffix && goodPrefix) {
              cost = pre.length * 0.1;
            } else if (goodSuffix) {
              cost = pre.length * 1.0;
            } else if (subjoinedSuffix && goodPrefix) {
              cost = pre.length * 0.3;
            } else if (subjoinedSuffix) {
              cost = pre.length * 0.5;
            } else {
              cost = double.infinity;
            }
          }

          if (cost < bestCost) {
            bestCost = cost;
            bestVowelPos = i;
          }
        }

        if (bestVowelPos != null) {
          for (final i in positions) {
            if (lat.props['edge-vowel:$i'] == null) {
              lat.props['edge-vowel:$i'] = (i == bestVowelPos);
            }
          }
        }
      }
    }
  }
}
