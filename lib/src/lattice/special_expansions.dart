import '../unicode/unicode_props.dart';
import 'candidate_selector.dart';
import 'lattice.dart';
import 'word_boundary.dart';

/// Implements abugida default vowel insertion and special character expansions.
class SpecialExpansions {
  /// Adds default abugida vowels where appropriate (e.g. for Indic/Brahmic scripts).
  static String addDefaultAbugidaVowel(
    Lattice lat,
    String rom,
    int start,
    int end, {
    String annotation = '',
  }) {
    try {
      final firstCharStr = lat.charAt(start);
      final lastCharCp = lat.codePoints[end - 1];
      final scriptName = lat.uroman.charToScript[firstCharStr] ?? '';
      final script = lat.uroman.scripts[scriptName.toLowerCase()];
      if (script == null || script.abugidaDefaultVowels.isEmpty) {
        return rom;
      }

      final abugidaDefaultVowels = script.abugidaDefaultVowels;
      final key = '${script.scriptName}:$rom';
      String? baseRom;
      String? baseRomPlusVowel;

      final cached = lat.uroman.abugidaCache[key];
      if (cached != null) {
        baseRom = cached.$1;
        baseRomPlusVowel = cached.$2;
        rom = cached.$3;
      } else {
        final vRegex1 = abugidaDefaultVowels.join('|');
        final vRegex2 = abugidaDefaultVowels.map((v) => '$v+').join('|');

        final m1 = RegExp('^([cfghkmnqrstxy]?y)($vRegex2)-?\$').firstMatch(rom);
        if (m1 != null) {
          baseRom = m1.group(1);
          baseRomPlusVowel = baseRom! + m1.group(2)!;
        } else {
          final m2 = RegExp('^([bcdfghjklmnpqrstvwxyz]+)($vRegex1)-?\$')
              .firstMatch(rom);
          if (m2 != null) {
            baseRom = m2.group(1);
            baseRomPlusVowel = baseRom! + m2.group(2)!;
            if (rom.endsWith('-') &&
                start + 1 == end &&
                _isAsciiAlpha(rom[0])) {
              rom = rom.substring(0, rom.length - 1);
            }
          } else {
            baseRom = rom;
            baseRomPlusVowel = baseRom + abugidaDefaultVowels[0];
          }
        }

        if (!RegExp(r'^[bcdfghjklmnpqrstvwxyz]+$').hasMatch(baseRom) &&
            !(scriptName == 'Tibetan' && baseRom == "'")) {
          baseRom = null;
          baseRomPlusVowel = null;
        }

        lat.uroman.abugidaCache[key] = (baseRom, baseRomPlusVowel, rom);
      }

      if (baseRom == null) return rom;
      if (annotation.contains('tail')) return rom;

      final prevCharCp = start >= 1 ? lat.codePoints[start - 1] : null;
      final prevCharStr = prevCharCp != null
          ? String.fromCharCode(prevCharCp)
          : '';
      final nextCharCp = end < lat.maxVertex ? lat.codePoints[end] : null;
      final nextCharStr = nextCharCp != null
          ? String.fromCharCode(nextCharCp)
          : '';
      final next2CharCp = end + 1 < lat.maxVertex
          ? lat.codePoints[end + 1]
          : null;
      final next2CharStr = next2CharCp != null
          ? String.fromCharCode(next2CharCp)
          : '';

      if (scriptName == 'Tibetan') {
        if (lat.props['edge-delete:$start'] == true) {
          return '';
        } else if (lat.props['edge-vowel:$start'] == true) {
          return baseRomPlusVowel!;
        } else {
          return baseRom;
        }
      }

      // Khmer yo
      if (nextCharStr.isNotEmpty &&
          ('bcdfghklmnpqrstvwz'.contains(baseRom) || baseRom == 'ng') &&
          nextCharStr == 'យ') {
        return baseRom;
      }

      if (lat.uroman.isVowelSign.contains(nextCharStr)) return baseRom;
      if (lat.uroman.isMedialConsonantSign.contains(nextCharStr)) {
        return baseRom;
      }
      if (nextCharCp != null &&
          WordBoundary.charIsSubjoinedLetter(lat, nextCharCp)) {
        return baseRom;
      }
      if (nextCharCp != null &&
          UnicodeProps.isNonspacingMark(nextCharCp) &&
          lat.uroman.isVowelSign.contains(next2CharStr)) {
        return baseRom;
      }
      if (lat.uroman.isVirama.contains(nextCharStr)) return baseRom;
      if (nextCharCp != null &&
          UnicodeProps.isNonspacingMark(nextCharCp) &&
          lat.uroman.isVirama.contains(next2CharStr)) {
        return baseRom;
      }
      if (lat.uroman.isVirama.contains(prevCharStr)) {
        return baseRomPlusVowel!;
      }

      if (WordBoundary.isAtStartOfWord(lat, start) &&
          !RegExp(r'[aeiou]').hasMatch(rom)) {
        return baseRomPlusVowel!;
      }

      // Delete many final schwas from most Devanagari languages (except: Sanskrit)
      if (WordBoundary.isAtEndOfWord(lat, end)) {
        if (scriptName == 'Devanagari' && lat.lcode != 'san') {
          return rom;
        } else if (const {
          'asm',
          'ben',
          'guj',
          'kas',
          'pan',
        }.contains(lat.lcode)) {
          return rom;
        } else {
          return baseRomPlusVowel!;
        }
      }

      final prevScript = lat.uroman.charToScript[prevCharStr] ?? '';
      if (prevScript != scriptName) {
        return baseRomPlusVowel!;
      }

      if (UnicodeProps.hasVocalicInName(lastCharCp)) {
        return baseRom;
      }

      final nextScript = lat.uroman.charToScript[nextCharStr] ?? '';
      if (nextScript == scriptName) {
        return baseRomPlusVowel!;
      }
    } catch (_) {
      return rom;
    }
    return rom;
  }

  /// Applies contextual expansions matching Python `expand_rom_with_special_chars`.
  static (String, int, int, String?) expandRomWithSpecialChars(
    Lattice lat,
    String rom,
    int start,
    int end, {
    String? annotation,
    bool recursive = false,
  }) {
    final origStart = start;
    String? annot = annotation;
    if (rom.isEmpty) return (rom, start, end, null);

    final prevCp = start >= 1 ? lat.codePoints[start - 1] : null;
    final prevChar = prevCp != null ? String.fromCharCode(prevCp) : '';
    final firstCharStr = lat.charAt(start);
    final lastCharStr = lat.charAt(end - 1);
    var nextCp = end < lat.maxVertex ? lat.codePoints[end] : null;
    var nextChar = nextCp != null ? String.fromCharCode(nextCp) : '';

    // Braille capital letter mark (\u2820)
    if (prevChar == '\u2820' && RegExp(r'^[a-z]').hasMatch(rom)) {
      return (
        rom[0].toUpperCase() + rom.substring(1),
        start - 1,
        end,
        'rom exp',
      );
    }

    // Multi-upper case normalization: THessalonike -> Thessalonike
    if (start + 1 == end &&
        rom.length > 1 &&
        rom == rom.toUpperCase() &&
        nextChar.isNotEmpty &&
        nextChar == nextChar.toLowerCase() &&
        nextChar != nextChar.toUpperCase()) {
      rom = rom[0].toUpperCase() + rom.substring(1).toLowerCase();
    }

    // Japanese small tsu (and Gurmukhi addak) consonant doubling
    final isTsu = prevChar.isNotEmpty && 'っッ'.contains(prevChar);
    final isAddak = prevChar == '\u0A71';
    final charScript = lat.uroman.charToScript[firstCharStr] ?? '';
    final scriptMatches =
        (isTsu && (charScript == 'Hiragana' || charScript == 'Katakana')) ||
        (isAddak && charScript == 'Gurmukhi');
    if (scriptMatches) {
      final mDouble = RegExp(r'^(ch|[bcdfghjklmnpqrstwz])').firstMatch(rom);
      if (mDouble != null) {
        final c1 = mDouble.group(1)!;
        if ('っッ'.contains(prevChar)) {
          rom = c1.replaceAll('ch', 't') + rom;
        } else {
          rom = c1.replaceAll('ch', 'c') + rom;
        }
        start = start - 1;
      }
    }

    // Thai expansions
    if ((lat.uroman.charToScript[firstCharStr] ?? '') == 'Thai') {
      if (start + 1 == end &&
          RegExp(r'^[bcdfghjklmnpqrstvwxyz]+$').hasMatch(rom)) {
        if (lat.uroman.charToSyllableInfo[prevChar] ==
            'written-pre-consonant-spoken-post-consonant') {
          if (1 <= start) {
            for (final vowelSuffixLen in [3, 2, 1]) {
              if (end + vowelSuffixLen <= lat.maxVertex) {
                final pattern =
                    '${lat.substring(start - 1, start)}–${lat.substring(end, end + vowelSuffixLen)}';
                final rules = lat.uroman.romRules[pattern];
                if (rules != null && rules.isNotEmpty) {
                  final vowelRom = rules[0].t ?? '';
                  return (
                    rom + vowelRom,
                    start - 1,
                    end + vowelSuffixLen,
                    'rom exp',
                  );
                }
              }
            }
          }
        }
      }

      if ((lat.uroman.charToScript[prevChar] ?? '') == 'Thai' &&
          lat.uroman.charToSyllableInfo[prevChar] ==
              'written-pre-consonant-spoken-post-consonant' &&
          RegExp(r'^[bcdfghjklmnpqrstvwxyz]').hasMatch(rom)) {
        final vowelRom = CandidateSelector.romanizationByFirstRule(
          lat,
          prevChar,
        );
        if (vowelRom != null) {
          return (rom + vowelRom, start - 1, end, 'rom exp');
        }
      }

      // THAI CHARACTER O ANG (\u0E2D)
      if (lat.codePoints[start] == 0x0E2D && end - start == 1) {
        final prevScript = lat.uroman.charToScript[prevChar] ?? '';
        final nextScript = lat.uroman.charToScript[nextChar] ?? '';
        final prevRom = lat.findRomEdgePathBackwardsStr(0, start, minChar: 1);
        final nextRom =
            CandidateSelector.romanizationByFirstRule(lat, nextChar) ?? '';
        if (!(prevScript == 'Thai' &&
            nextScript == 'Thai' &&
            RegExp(r'[bcdfghjklmnpqrstvwxz]+$').hasMatch(prevRom) &&
            RegExp(r'[bcdfghjklmnpqrstvwxz]+$').hasMatch(nextRom))) {
          return ('', start, end, 'rom del');
        }
      }
    }

    // Coptic: consonant + grace-accent (\u0300) = e + consonant
    if (nextChar == '\u0300' &&
        (lat.uroman.charToScript[lastCharStr] ?? '') == 'Coptic' &&
        CandidateSelector.simpleTopCandidate(lat, origStart, end + 1) == null) {
      rom = 'e$rom';
      end = end + 1;
      nextCp = end < lat.maxVertex ? lat.codePoints[end] : null;
      nextChar = nextCp != null ? String.fromCharCode(nextCp) : '';
      annot = 'rom exp';
    }

    // Japanese small y (ゃゅょャュョ): ki + small ya = kya
    if (nextChar.isNotEmpty &&
        'ゃゅょャュョ'.contains(nextChar) &&
        (lat.uroman.charToScript[lastCharStr] ?? '') ==
            (lat.uroman.charToScript[nextChar] ?? '') &&
        RegExp(r'[bcdfghjklmnpqrstvwxyz]i$').hasMatch(rom)) {
      final yRom = CandidateSelector.romanizationByFirstRule(lat, nextChar);
      if (yRom != null &&
          CandidateSelector.simpleTopCandidate(lat, origStart, end + 1) ==
              null &&
          CandidateSelector.simpleTopCandidate(lat, start, end + 1) == null) {
        rom = rom.substring(0, rom.length - 1) + yRom;
        end = end + 1;
        nextCp = end < lat.maxVertex ? lat.codePoints[end] : null;
        nextChar = nextCp != null ? String.fromCharCode(nextCp) : '';
        annot = 'rom exp';
      }
    }

    // Japanese vowel lengthener (ー U+30FC)
    if (nextChar == 'ー' &&
        const {
          'Hiragana',
          'Katakana',
        }.contains(lat.uroman.charToScript[lastCharStr]) &&
        rom.isNotEmpty &&
        'aeiou'.contains(rom[rom.length - 1])) {
      return (rom + rom[rom.length - 1], start, end + 1, 'rom exp');
    }

    // Virama (Indian languages)
    if (nextChar.isNotEmpty && lat.uroman.isVirama.contains(nextChar)) {
      return (rom, start, end + 1, 'rom exp');
    }

    // Space trimming at boundaries
    if (rom.startsWith(' ') && (start == 0 || prevChar == ' ')) {
      rom = rom.substring(1);
    }
    if (rom.endsWith(' ') &&
        ((lat.isAtStringEnd && end >= lat.maxVertex) || nextChar == ' ')) {
      rom = rom.substring(0, rom.length - 1);
    }

    return (rom, start, end, annot);
  }

  static bool _isAsciiAlpha(String s) {
    if (s.isEmpty) return false;
    final cu = s.codeUnitAt(0);
    return (cu >= 0x41 && cu <= 0x5A) || (cu >= 0x61 && cu <= 0x7A);
  }
}
