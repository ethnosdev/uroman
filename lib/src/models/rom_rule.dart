/// Represents a romanization rule loaded from resource files or generated dynamically.
class RomRule {
  final String s;
  final String? t;
  final String prov;
  final List<String> lcodes;
  final List<String> tAlts;
  final num? numValue;
  final bool useOnlyAtStartOfWord;
  final bool dontUseAtStartOfWord;
  final bool useOnlyAtEndOfWord;
  final bool dontUseAtEndOfWord;
  final bool useOnlyForWholeWord;
  final String? tAtEndOfSyllable;
  final int nRestr;
  final bool isMinusSign;
  final bool isPlusSign;
  final bool isDecimalPoint;
  final String? fractionConnector;
  final String? percentageMarker;
  final String? intFracConnector;
  final bool isLargePower;

  const RomRule({
    required this.s,
    this.t,
    required this.prov,
    this.lcodes = const [],
    this.tAlts = const [],
    this.numValue,
    this.useOnlyAtStartOfWord = false,
    this.dontUseAtStartOfWord = false,
    this.useOnlyAtEndOfWord = false,
    this.dontUseAtEndOfWord = false,
    this.useOnlyForWholeWord = false,
    this.tAtEndOfSyllable,
    this.nRestr = 0,
    this.isMinusSign = false,
    this.isPlusSign = false,
    this.isDecimalPoint = false,
    this.fractionConnector,
    this.percentageMarker,
    this.intFracConnector,
    this.isLargePower = false,
  });

  /// Serializes to a map matching Python's `DictClass.__dict__` format
  /// (omitting null, empty lists, and false values).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'s': s};
    if (t != null) map['t'] = t;
    map['prov'] = prov;
    if (lcodes.isNotEmpty) map['lcodes'] = lcodes;
    if (tAlts.isNotEmpty) map['t-alts'] = tAlts;
    if (numValue != null && numValue != 0) map['num'] = numValue;
    if (useOnlyAtStartOfWord) map['use-only-at-start-of-word'] = true;
    if (dontUseAtStartOfWord) map['dont-use-at-start-of-word'] = true;
    if (useOnlyAtEndOfWord) map['use-only-at-end-of-word'] = true;
    if (dontUseAtEndOfWord) map['dont-use-at-end-of-word'] = true;
    if (useOnlyForWholeWord) map['use-only-for-whole-word'] = true;
    if (tAtEndOfSyllable != null) map['t-at-end-of-syllable'] = tAtEndOfSyllable;
    if (nRestr > 0) map['n-restr'] = nRestr;
    if (isMinusSign) map['is-minus-sign'] = true;
    if (isPlusSign) map['is-plus-sign'] = true;
    if (isDecimalPoint) map['is-decimal-point'] = true;
    if (fractionConnector != null && fractionConnector!.isNotEmpty) {
      map['fraction-connector'] = fractionConnector;
    }
    if (percentageMarker != null && percentageMarker!.isNotEmpty) {
      map['percentage-marker'] = percentageMarker;
    }
    if (intFracConnector != null && intFracConnector!.isNotEmpty) {
      map['int-frac-connector'] = intFracConnector;
    }
    if (isLargePower) map['is-large-power'] = true;
    return map;
  }

  @override
  String toString() => 'RomRule($s -> $t [$prov])';
}
