import '../models/edge.dart';
import '../models/rom_format.dart';
import '../unicode/unicode_props.dart';
import 'alternatives.dart';
import 'braille.dart';
import 'candidate_selector.dart';
import 'hangul.dart';
import 'lattice.dart';
import 'number_pipeline.dart';
import 'special_expansions.dart';
import 'tibetan.dart';

/// Coordinates the full multi-stage romanization pipeline on a [Lattice].
class LatticeEngine {
  /// Executes the romanization pipeline and returns the requested format.
  static dynamic romanizeCore(
    Lattice lat, {
    RomFormat format = RomFormat.str,
    int offset = 0,
  }) {
    // Stage 1: Tibetan vowel picking
    Tibetan.pickTibetanVowelEdge(lat);

    // Stage 2: Braille capitalization prep
    Braille.prepBraille(lat);

    // Stage 3: Romanization rule matching, Hangul, decomposition
    _addRomanization(lat);

    // Stage 4: Numbers pipeline (D1, G1-G6, F1)
    NumberPipeline.addNumbers(lat);

    // Stage 5: Braille numbers
    Braille.addBrailleNumbers(lat);

    // Stage 6: Fallback singles
    _addRomFallbackSingles(lat);

    // Stage 7: Path finding & formatting
    if (format == RomFormat.lattice) {
      final allEdges = lat.allEdges(0, lat.maxVertex);
      Alternatives.addAlternatives(lat, allEdges);
      if (offset != 0) _applyOffsetToEdges(allEdges, offset);
      return allEdges;
    }

    final bestEdges = lat.bestRomEdgePath(0, lat.maxVertex);
    if (format == RomFormat.edges || format == RomFormat.alts) {
      if (format == RomFormat.alts) {
        Alternatives.addAlternatives(lat, bestEdges);
      }
      if (offset != 0) _applyOffsetToEdges(bestEdges, offset);
      return bestEdges;
    }

    // Default: RomFormat.str
    return Lattice.edgePathToSurf(bestEdges);
  }

  static void _addRomanization(Lattice lat) {
    for (var start = 0; start < lat.maxVertex; start++) {
      for (var end = start + 1; end <= lat.maxVertex; end++) {
        final s = lat.substring(start, end);
        if (!lat.uroman.sPrefix.contains(s)) break;

        var rom = CandidateSelector.simpleTopCandidate(lat, start, end);
        if (rom != null) {
          if (lat.containsScript.contains('Braille') && start + 1 == end) {
            if (lat.props['is-upper:$start'] == true) {
              rom = rom.toUpperCase();
            }
          }

          var edgeAnnotation = 'rom';
          final mTail = RegExp(r'^\+(m|ng|n|h|r)').firstMatch(rom);
          if (mTail != null) {
            rom = rom.substring(1);
            edgeAnnotation = 'rom tail';
          }

          final newRom = SpecialExpansions.addDefaultAbugidaVowel(
            lat,
            rom,
            start,
            end,
            annotation: edgeAnnotation,
          );

          if (newRom.startsWith(rom)) {
            final suffix = newRom.substring(rom.length);
            if (suffix.isNotEmpty && RegExp(r'[aeiou]+$').hasMatch(suffix)) {
              edgeAnnotation += ' c:$rom s:$suffix';
            }
          }
          rom = newRom;

          final (
            romExp,
            start2,
            end2,
            expAnnotation,
          ) = SpecialExpansions.expandRomWithSpecialChars(
            lat,
            rom,
            start,
            end,
            annotation: edgeAnnotation,
          );
          edgeAnnotation = expAnnotation ?? edgeAnnotation;

          lat.addEdge(lat.createEdge(start2, end2, romExp, edgeAnnotation));
        }
      }

      // Korean Hangul
      final cp = lat.codePoints[start];
      if (cp >= 0xAC00 && cp <= 0xD7A3) {
        final hRom = Hangul.romanizeHangulCodePoint(cp);
        if (hRom != null) {
          lat.addEdge(lat.createEdge(start, start + 1, hRom, 'rom'));
        }
      }

      // Decomposition
      final decomp = UnicodeProps.decompRom(cp);
      if (decomp != null) {
        var romDecomp = decomp;
        if (UnicodeProps.udNumeric(cp) != null) {
          romDecomp = romDecomp.replaceAll('⁄', '/');
          if (start >= 1 &&
              UnicodeProps.udNumeric(lat.codePoints[start - 1]) != null) {
            romDecomp = ' $romDecomp';
          }
          if (start + 1 < lat.maxVertex &&
              UnicodeProps.udNumeric(lat.codePoints[start + 1]) != null) {
            romDecomp += ' ';
          }
        }
        lat.addEdge(lat.createEdge(start, start + 1, romDecomp, 'rom decomp'));
      }
    }
  }

  static void _addRomFallbackSingles(Lattice lat) {
    for (var start = 0; start < lat.maxVertex; start++) {
      if (!lat.hasEdgesInSpan(start, start + 1)) {
        final cp = lat.codePoints[start];
        final charStr = String.fromCharCode(cp);
        var rom = charStr;
        var edgeAnnotation = 'orig';

        if (UnicodeProps.isNonspacingMark(cp)) {
          rom = '';
          edgeAnnotation = 'Mn';
        } else if (UnicodeProps.isFormatChar(cp)) {
          rom = '';
          edgeAnnotation = 'Cf';
        } else if (UnicodeProps.isPrivateUse(cp)) {
          rom = '';
          edgeAnnotation = 'Co';
        } else if (charStr == ' ') {
          edgeAnnotation = 'orig';
        } else {
          final rom2 = CandidateSelector.simpleTopCandidate(
            lat,
            start,
            start + 1,
          );
          if (rom2 != null) {
            rom = rom2;
            final mTail = RegExp(r'^\+(m|ng|n|h|r)').firstMatch(rom);
            if (mTail != null) {
              rom = rom.substring(1);
            }
            edgeAnnotation = 'rom single';
          }
        }

        lat.addEdge(lat.createEdge(start, start + 1, rom, edgeAnnotation));
      }
    }
  }

  static void _applyOffsetToEdges(List<Edge> edges, int offset) {
    // Phase 5 will implement offset shifting for caching
  }
}
