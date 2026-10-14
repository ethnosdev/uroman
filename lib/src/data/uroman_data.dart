import '../models/num_prop.dart';
import '../models/rom_rule.dart';
import '../models/script.dart';

/// Container for all parsed romanization rules, script tables, and numerical properties.
class UromanData {
  final Map<String, List<RomRule>> romRules = {};
  final Map<String, Script> scripts = {};
  final Map<String, NumProp> numProps = {};
  final Set<String> sPrefixes = {};

  // Properties equivalent to Python's dict_str
  final Map<String, String> charToScript = {};
  final Map<String, String> charToName = {};
  final Map<String, String> charToPic = {};
  final Map<String, String> charToToneMark = {};
  final Map<String, String> charToSyllableInfo = {};

  // Sets equivalent to Python's dict_bool
  final Set<String> isVowelSign = {};
  final Set<String> isMedialConsonantSign = {};
  final Set<String> isVirama = {};
  final Set<String> isLargePower = {};
  final Set<String> isMinusSign = {};
  final Set<String> isPlusSign = {};
  final Set<String> isDecimalPoint = {};

  // Equivalents to Python dict_num, dict_set, dict_int
  final Map<String, num> charToNum = {};
  final Set<String> fractionConnectors = {};
  final Set<String> minusSigns = {};
  final Set<String> plusSigns = {};
  final Map<String, Set<String>> scriptLanguages = {};
  int maxNScriptNameComponents = 0;

  void registerSPrefix(String s) {
    // In Python: for prefix_len in range(1, len(s) + 1): s[:prefix_len]
    // Python slices by code points!
    final cps = s.runes.toList(growable: false);
    for (var len = 1; len <= cps.length; len++) {
      final prefix = String.fromCharCodes(cps.sublist(0, len));
      sPrefixes.add(prefix);
    }
  }

  /// Exports the loaded data into the canonical JSON structure matching tables.json.gz.
  Map<String, dynamic> toCanonicalMap() {
    final dictBool = <String, List<String>>{};
    if (sPrefixes.isNotEmpty) dictBool['s-prefix'] = sPrefixes.toList()..sort();
    if (isLargePower.isNotEmpty) dictBool['is-large-power'] = isLargePower.toList()..sort();
    if (isMinusSign.isNotEmpty) dictBool['is-minus-sign'] = isMinusSign.toList()..sort();
    if (isDecimalPoint.isNotEmpty) dictBool['is-decimal-point'] = isDecimalPoint.toList()..sort();
    if (isVowelSign.isNotEmpty) dictBool['is-vowel-sign'] = isVowelSign.toList()..sort();
    if (isMedialConsonantSign.isNotEmpty) {
      dictBool['is-medial-consonant-sign'] = isMedialConsonantSign.toList()..sort();
    }
    if (isVirama.isNotEmpty) dictBool['is-virama'] = isVirama.toList()..sort();

    final dictStr = <String, Map<String, String>>{};
    if (charToSyllableInfo.isNotEmpty) dictStr['syllable-info'] = charToSyllableInfo;
    if (charToToneMark.isNotEmpty) dictStr['tone-mark'] = charToToneMark;
    if (charToName.isNotEmpty) dictStr['name'] = charToName;
    if (charToPic.isNotEmpty) dictStr['pic'] = charToPic;
    if (charToScript.isNotEmpty) dictStr['script'] = charToScript;

    final dictSet = <String, List<String>>{};
    for (final entry in scriptLanguages.entries) {
      dictSet['scripts:${entry.key}'] = entry.value.toList()..sort();
    }

    return {
      'rom_rules': {
        for (final entry in romRules.entries)
          entry.key: entry.value.map((r) => r.toMap()).toList(),
      },
      'scripts': {
        for (final entry in scripts.entries)
          entry.key: entry.value.toMap(),
      },
      'num_props': {
        for (final entry in numProps.entries)
          entry.key: entry.value.toMap(),
      },
      'dict_bool': dictBool,
      'dict_str': dictStr,
      'dict_int': {
        if (maxNScriptNameComponents > 0)
          'max_n_script_name_components': maxNScriptNameComponents,
      },
      'dict_set': dictSet,
      'fraction_connectors': fractionConnectors.toList()..sort(),
      'minus_signs': minusSigns.toList()..sort(),
      'plus_signs': plusSigns.toList()..sort(),
    };
  }
}
