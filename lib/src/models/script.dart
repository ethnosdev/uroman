/// Represents a writing script (e.g. Devanagari, Arabic, Latin) and its metadata.
class Script {
  final String scriptName;
  final String? direction;
  final List<String> abugidaDefaultVowels;
  final List<String> altScriptNames;
  final List<String> languages;

  const Script({
    required this.scriptName,
    this.direction,
    this.abugidaDefaultVowels = const [],
    this.altScriptNames = const [],
    this.languages = const [],
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'script-name': scriptName};
    if (direction != null) map['direction'] = direction;
    if (abugidaDefaultVowels.isNotEmpty) {
      map['abugida-default-vowels'] = abugidaDefaultVowels;
    }
    if (altScriptNames.isNotEmpty) map['alt-script-names'] = altScriptNames;
    if (languages.isNotEmpty) map['languages'] = languages;
    return map;
  }

  @override
  String toString() => 'Script($scriptName)';
}
