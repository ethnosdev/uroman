/// Represents numerical properties of a character loaded from NumProps.jsonl.
class NumProp {
  final String txt;
  final String? rom;
  final num? value;
  final List<int>? fraction;
  final int? base;
  final num? mult;
  final String? type;
  final String? script;
  final bool? isLargePower;
  final String? name;

  const NumProp({
    required this.txt,
    this.rom,
    this.value,
    this.fraction,
    this.base,
    this.mult,
    this.type,
    this.script,
    this.isLargePower,
    this.name,
  });

  factory NumProp.fromMap(Map<String, dynamic> map) {
    List<int>? frac;
    if (map['fraction'] != null) {
      final list = map['fraction'] as List;
      frac = list.map((e) => (e as num).toInt()).toList(growable: false);
    }
    return NumProp(
      txt: map['txt'] as String,
      rom: map['rom'] as String?,
      value: map['value'] as num?,
      fraction: frac,
      base: (map['base'] as num?)?.toInt(),
      mult: map['mult'] as num?,
      type: map['type'] as String?,
      script: map['script'] as String?,
      isLargePower: map['is-large-power'] as bool?,
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'txt': txt};
    if (rom != null) map['rom'] = rom;
    if (value != null) map['value'] = value;
    if (fraction != null) map['fraction'] = fraction;
    if (base != null) map['base'] = base;
    if (mult != null) map['mult'] = mult;
    if (type != null) map['type'] = type;
    if (script != null) map['script'] = script;
    if (isLargePower != null) map['is-large-power'] = isLargePower;
    if (name != null) map['name'] = name;
    return map;
  }

  @override
  String toString() => 'NumProp($txt: $value [$type])';
}
