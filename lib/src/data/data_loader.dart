import 'dart:convert';

import '../compat/py_string.dart';
import '../models/num_prop.dart';
import '../models/rom_rule.dart';
import '../models/script.dart';
import '../unicode/unicode_props.dart';
import 'uroman_data.dart';

/// Loads and parses uroman runtime data files into a [UromanData] store.
class DataLoader {
  /// Pinyin accent reduction map for Chinese_to_Pinyin.txt.
  static const Map<String, String> _pinyinAccents = {
    'í': 'i',
    'ī': 'i',
    'è': 'e',
    'ā': 'a',
    'ì': 'i',
    'ǔ': 'u',
    'ù': 'u',
    'ū': 'u',
    'à': 'a',
    'ǐ': 'i',
    'é': 'e',
    'ó': 'o',
    'ò': 'o',
    'ō': 'o',
    'ú': 'u',
    'ě': 'e',
    'ē': 'e',
    'ǎ': 'a',
    'á': 'a',
    'ü': 'u',
    'ǒ': 'o',
    'ǜ': 'u',
    'ň': 'n',
    'ǚ': 'u',
    'ǘ': 'u',
    'ḿ': 'm',
    'ń': 'n',
  };

  /// Parses slots in a double-colon delimited line (e.g. `::s a ::t b ::cost 0.3`).
  static Map<String, String> parseSlots(String line) {
    final slots = <String, String>{};
    // Slots are delimited by ' ::' or start of line '::'
    var idx = 0;
    while (idx < line.length) {
      final nextColon = line.indexOf('::', idx);
      if (nextColon == -1) break;
      // Must be at start of line or preceded by whitespace
      if (nextColon > 0 && line.codeUnitAt(nextColon - 1) > 0x20) {
        idx = nextColon + 2;
        continue;
      }
      final slotStart = nextColon + 2;
      // Find where slot name ends (at whitespace or next :: or end of line)
      var nameEnd = slotStart;
      while (nameEnd < line.length && line.codeUnitAt(nameEnd) > 0x20) {
        nameEnd++;
      }
      final slotName = line.substring(slotStart, nameEnd);
      if (slotName.isEmpty) {
        idx = nextColon + 2;
        continue;
      }

      // Find value until next ' ::' or end of line
      var valStart = nameEnd;
      while (valStart < line.length && line.codeUnitAt(valStart) <= 0x20) {
        valStart++;
      }

      var valEnd = line.length;
      var searchIdx = valStart;
      while (searchIdx < line.length) {
        final cIdx = line.indexOf('::', searchIdx);
        if (cIdx == -1) {
          valEnd = line.length;
          break;
        }
        if (cIdx > 0 && line.codeUnitAt(cIdx - 1) <= 0x20) {
          valEnd = cIdx;
          break;
        }
        searchIdx = cIdx + 2;
      }

      final val = valStart < valEnd
          ? line.substring(valStart, valEnd).trim()
          : '';
      slots[slotName] = val;
      idx = valEnd;
    }
    return slots;
  }

  /// De-accents a pinyin string matching Python `de_accent_pinyin`.
  static String deAccentPinyin(String s) {
    final buf = StringBuffer();
    for (final char in s.split('')) {
      buf.write(_pinyinAccents[char] ?? char);
    }
    return buf.toString();
  }

  /// Applies second romanization filter matching Python `second_rom_filter`.
  static String? secondRomFilter(String c, String? rom, String? name) {
    if (rom != null && rom.contains(' ')) {
      final cps = c.runes.toList(growable: false);
      if (cps.length == 1) {
        final cp = cps[0];
        if (UnicodeProps.isMyanmarKayah(cp)) {
          final m = RegExp(r'kayah\s+(\S+)\s*$').firstMatch(rom);
          if (m != null) return m.group(1);
        }
        if (UnicodeProps.isMendeKikakui(cp)) {
          final m = RegExp(r'm\d+\s+(\S+)\s*$').firstMatch(rom);
          if (m != null) return m.group(1);
        }
      }
      if (RegExp(r'\S\s+\S').hasMatch(rom)) {
        return c;
      }
    }
    return null;
  }

  /// Loads and parses all 9 resource files into a [UromanData] instance.
  static UromanData load(Map<String, String> files) {
    final data = UromanData();

    // 1. romanization-auto-table.txt (provenance: ud, format: rom)
    if (files.containsKey('romanization-auto-table.txt')) {
      _loadRomFile(data, files['romanization-auto-table.txt']!, 'ud', 'rom');
    }

    // 2. UnicodeDataOverwrite.txt (provenance: ow, format: u2r)
    if (files.containsKey('UnicodeDataOverwrite.txt')) {
      _loadRomFile(data, files['UnicodeDataOverwrite.txt']!, 'ow', 'u2r');
    }

    // 3. romanization-table.txt (provenance: man, format: rom)
    if (files.containsKey('romanization-table.txt')) {
      _loadRomFile(data, files['romanization-table.txt']!, 'man', 'rom');
    }

    // 4. Chinese_to_Pinyin.txt
    if (files.containsKey('Chinese_to_Pinyin.txt')) {
      _loadChinesePinyinFile(data, files['Chinese_to_Pinyin.txt']!);
    }

    // 5. Scripts.txt
    if (files.containsKey('Scripts.txt')) {
      _loadScriptFile(data, files['Scripts.txt']!);
    }

    // 6. NumProps.jsonl
    if (files.containsKey('NumProps.jsonl')) {
      _loadNumProps(data, files['NumProps.jsonl']!);
    }

    // 7. UnicodeDataProps.txt, UnicodeDataPropsCJK.txt, UnicodeDataPropsHangul.txt
    for (final baseFile in [
      'UnicodeDataProps.txt',
      'UnicodeDataPropsCJK.txt',
      'UnicodeDataPropsHangul.txt',
    ]) {
      if (files.containsKey(baseFile)) {
        _loadUnicodeDataProps(data, files[baseFile]!);
      }
    }

    return data;
  }

  static void _loadRomFile(
    UromanData data,
    String content,
    String provenance,
    String fileFormat,
  ) {
    final lines = const LineSplitter().convert(content);
    for (var line in lines) {
      if (line.startsWith('#') || line.trim().isEmpty) continue;
      // Strip comments after 2 or more spaces: \s{2,}#.*$
      final hashIdx = line.indexOf('##');
      if (hashIdx != -1) {
        // Check for 2+ spaces before hash
        line = line.replaceFirst(RegExp(r'\s{2,}#.*$'), '');
      } else if (line.contains('#')) {
        line = line.replaceFirst(RegExp(r'\s{2,}#.*$'), '');
      }

      final slots = parseSlots(line);
      String? s;
      String? t;
      String? tAtEndOfSyllable;

      if (fileFormat == 'u2r') {
        final u = PyString.dequote(slots['u'] ?? '');
        final cp = int.tryParse(u, radix: 16);
        if (cp == null) continue;
        s = String.fromCharCode(cp);
        t = slots['r'] != null ? PyString.dequote(slots['r']!) : null;
        final name = slots['name'];
        if (name != null) data.charToName[s] = name;
        final pic = slots['pic'];
        if (pic != null) data.charToPic[s] = pic;
        final toneMark = slots['tone-mark'];
        if (toneMark != null) data.charToToneMark[s] = toneMark;
        final syllableInfo = slots['syllable-info'];
        if (syllableInfo != null) data.charToSyllableInfo[s] = syllableInfo;
      } else {
        s = slots['s'] != null ? PyString.dequote(slots['s']!) : null;
        final rawT = slots['t'] ?? slots[':t'];
        t = rawT != null ? PyString.dequote(rawT) : null;
        tAtEndOfSyllable = slots['t-end-of-syllable'] != null
            ? PyString.dequote(slots['t-end-of-syllable']!)
            : null;
      }

      num? numVal;
      if (slots.containsKey('num')) {
        final numS = slots['num']!;
        numVal = numS.contains('.')
            ? double.tryParse(numS)
            : int.tryParse(numS);
        if (s != null) {
          data.charToNum[s] = numVal ?? 0;
        }
      }

      final isMinusSign = slots.containsKey('is-minus-sign');
      if (isMinusSign && s != null) data.minusSigns.add(s);

      final isPlusSign = slots.containsKey('is-plus-sign');
      if (isPlusSign && s != null) data.plusSigns.add(s);

      final isDecimalPoint = slots.containsKey('is-decimal-point');
      final isLargePower = slots.containsKey('is-large-power');

      final fractionConnector = slots['fraction-connector'];
      if (fractionConnector != null && s != null) {
        data.fractionConnectors.add(s);
      }

      final percentageMarker = slots['percentage-marker'];
      final intFracConnector = slots['int-frac-connector'];

      final lcodeS = slots['lcode'];
      final lcodes = lcodeS != null && lcodeS.isNotEmpty
          ? lcodeS.split(RegExp(r'[,;]\s*'))
          : const <String>[];

      final useOnlyAtStartOfWord = slots.containsKey(
        'use-only-at-start-of-word',
      );
      final dontUseAtStartOfWord = slots.containsKey(
        'dont-use-at-start-of-word',
      );
      final useOnlyAtEndOfWord = slots.containsKey('use-only-at-end-of-word');
      final dontUseAtEndOfWord = slots.containsKey('dont-use-at-end-of-word');
      final useOnlyForWholeWord = slots.containsKey('use-only-for-whole-word');

      final tAltS = slots['t-alt'];
      final tAlts = tAltS != null && tAltS.isNotEmpty
          ? tAltS.split(RegExp(r'[,;]\s*')).map(PyString.dequote).toList()
          : const <String>[];

      if (s != null) {
        final tMod = secondRomFilter(s, t, null);
        if (tMod != null && tMod != t) {
          t = tMod;
        }

        if (isLargePower) data.isLargePower.add(s);
        if (isMinusSign) data.isMinusSign.add(s);
        if (isPlusSign) data.isPlusSign.add(s);
        if (isDecimalPoint) data.isDecimalPoint.add(s);

        // In Python, any_not_none includes boolean flags which are False (not None),
        // so any_not_none is unconditionally True whenever s is not None.
        data.registerSPrefix(s);

        var nRestrictions = 0;
        if (lcodes.isNotEmpty) nRestrictions++;
        if (useOnlyAtStartOfWord) nRestrictions++;
        if (dontUseAtStartOfWord) nRestrictions++;
        if (useOnlyAtEndOfWord) nRestrictions++;
        if (dontUseAtEndOfWord) nRestrictions++;
        if (useOnlyForWholeWord) nRestrictions++;

        var prov2 = provenance;
        if (t == null && numVal != null && prov2 == 'rom') {
          prov2 = 'num';
        }

        final newRomRule = RomRule(
          s: s,
          t: t,
          prov: prov2,
          lcodes: lcodes,
          tAlts: tAlts,
          numValue: numVal,
          useOnlyAtStartOfWord: useOnlyAtStartOfWord,
          dontUseAtStartOfWord: dontUseAtStartOfWord,
          useOnlyAtEndOfWord: useOnlyAtEndOfWord,
          dontUseAtEndOfWord: dontUseAtEndOfWord,
          useOnlyForWholeWord: useOnlyForWholeWord,
          tAtEndOfSyllable: tAtEndOfSyllable,
          nRestr: nRestrictions,
          isMinusSign: isMinusSign,
          isPlusSign: isPlusSign,
          isDecimalPoint: isDecimalPoint,
          fractionConnector: fractionConnector,
          percentageMarker: percentageMarker,
          intFracConnector: intFracConnector,
          isLargePower: isLargePower,
        );

        final oldRules = data.romRules[s];
        if (oldRules != null &&
            oldRules.length == 1 &&
            (oldRules[0].prov == 'ud' || oldRules[0].prov == 'ow') &&
            lcodes.isEmpty &&
            !useOnlyAtStartOfWord &&
            !dontUseAtStartOfWord &&
            !useOnlyAtEndOfWord &&
            !dontUseAtEndOfWord &&
            !useOnlyForWholeWord) {
          data.romRules[s] = [newRomRule];
        } else {
          (data.romRules[s] ??= []).add(newRomRule);
        }
      }
    }

    // Synthesize Thai cancellation rules
    const thaiCancellationMark = '\u0E4C';
    for (var cp = 0x0E01; cp < 0x0E4C; cp++) {
      final s = String.fromCharCode(cp) + thaiCancellationMark;
      if (data.romRules[s] == null || data.romRules[s]!.isEmpty) {
        data.romRules[s] = [RomRule(s: s, t: '', prov: 'auto cancel letter')];
        data.registerSPrefix(s);
      }
    }

    final thaiConsonants = [
      for (var cp = 0x0E01; cp <= 0x0E2E; cp++) String.fromCharCode(cp),
    ];
    final thaiVowelModifiers = [
      '\u0E31',
      '\u0E47',
      for (var cp = 0x0E33; cp <= 0x0E3A; cp++) String.fromCharCode(cp),
    ];

    for (final c1 in thaiConsonants) {
      for (final v in thaiVowelModifiers) {
        final s = c1 + v + thaiCancellationMark;
        if (data.romRules[s] == null || data.romRules[s]!.isEmpty) {
          data.romRules[s] = [
            RomRule(s: s, t: '', prov: 'auto cancel syllable'),
          ];
          data.registerSPrefix(s);
        }
      }
    }
  }

  static void _loadChinesePinyinFile(UromanData data, String content) {
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final chinese = parts[0];
        final pinyin = parts[1];
        final rom = deAccentPinyin(pinyin);
        final newRomRule = RomRule(
          s: chinese,
          t: rom,
          prov: 'rom pinyin',
          lcodes: const [],
        );
        (data.romRules[chinese] ??= []).add(newRomRule);
        data.registerSPrefix(chinese);
      }
    }
  }

  static void _loadScriptFile(UromanData data, String content) {
    final lines = const LineSplitter().convert(content);
    var maxNComponents = 0;
    for (var line in lines) {
      if (line.startsWith('#') || line.trim().isEmpty) continue;
      line = line.replaceFirst(RegExp(r'\s{2,}#.*$'), '');

      final slots = parseSlots(line);
      final scriptName = slots['script-name'];
      if (scriptName != null && scriptName.isNotEmpty) {
        final lcName = scriptName.toLowerCase();
        if (!data.scripts.containsKey(lcName)) {
          final direction = slots['direction'];
          final abugidaDefVowels = slots['abugida-default-vowel'] != null
              ? slots['abugida-default-vowel']!.split(RegExp(r'[,;]\s*'))
              : const <String>[];
          final altScriptNames = slots['alt-script-name'] != null
              ? slots['alt-script-name']!.split(RegExp(r'[,;]\s*'))
              : const <String>[];
          final languages = slots['language'] != null
              ? slots['language']!.split(RegExp(r'[,;]\s*'))
              : const <String>[];

          final script = Script(
            scriptName: scriptName,
            direction: direction,
            abugidaDefaultVowels: abugidaDefVowels,
            altScriptNames: altScriptNames,
            languages: languages,
          );
          data.scripts[lcName] = script;

          for (final lang in languages) {
            (data.scriptLanguages[lang] ??= {}).add(scriptName);
          }

          for (final altName in altScriptNames) {
            final lcAlt = altName.toLowerCase();
            data.scripts.putIfAbsent(lcAlt, () => script);
          }
        }

        final nComp = scriptName.split(RegExp(r'\s+')).length;
        if (nComp > maxNComponents) {
          maxNComponents = nComp;
        }
      }
    }
    if (maxNComponents > 0) {
      data.maxNScriptNameComponents = maxNComponents;
    }
  }

  static void _loadNumProps(UromanData data, String content) {
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      final txt = map['txt'] as String?;
      if (txt != null) {
        final np = NumProp.fromMap(map);
        data.numProps[txt] = np;
        if (map['is-large-power'] == true) {
          data.isLargePower.add(txt);
        }
      }
    }
  }

  static void _loadUnicodeDataProps(UromanData data, String content) {
    final lines = const LineSplitter().convert(content);
    for (var line in lines) {
      if (line.startsWith('#') || line.trim().isEmpty) continue;
      line = line.replaceFirst(RegExp(r'\s{2,}#.*$'), '');

      final slots = parseSlots(line);
      final scriptName = slots['script-name'];
      if (scriptName != null && scriptName.isNotEmpty) {
        // Iterate code points to handle astral characters properly
        void addScriptChars(String? s) {
          if (s == null) return;
          for (final cp in s.runes) {
            data.charToScript[String.fromCharCode(cp)] = scriptName;
          }
        }

        void addFlagChars(String? s, Set<String> targetSet) {
          if (s == null) return;
          for (final cp in s.runes) {
            targetSet.add(String.fromCharCode(cp));
          }
        }

        addScriptChars(slots['char']);
        addScriptChars(slots['numeral']);
        addFlagChars(slots['vowel-sign'], data.isVowelSign);
        addFlagChars(
          slots['medial-consonant-sign'],
          data.isMedialConsonantSign,
        );
        addFlagChars(slots['sign-virama'], data.isVirama);
      }
    }
  }
}
