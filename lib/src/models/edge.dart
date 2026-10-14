import '../compat/py_json.dart';
import '../compat/py_num.dart';
import '../compat/rational.dart';
import 'num_prop.dart';

/// Represents a span of text in the lattice with a specific romanization.
class Edge {
  final int start;
  final int end;
  String txt;
  String? type;

  /// Native Dart / Flutter UTF-16 code unit offsets.
  final int utf16Start;
  final int utf16End;

  Edge(
    this.start,
    this.end,
    this.txt, [
    this.type,
    this.utf16Start = 0,
    this.utf16End = 0,
  ]);

  /// Serializes the edge to Python's `Edge.json()` format:
  /// `[start, end, "txt", "type"]` with ensure_ascii escaping.
  String toPythonJson() => pyJsonEdge(start, end, txt, type);

  /// Standard RFC 8259 JSON map for modern Dart/Flutter APIs.
  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'txt': txt,
    'type': type,
    'utf16Start': utf16Start,
    'utf16End': utf16End,
  };

  @override
  String toString() => '[$start-$end] $txt ($type)';
}

/// Represents a numerical edge in the lattice used during number combination heuristics.
class NumEdge extends Edge {
  String origTxt;
  num? value;
  String? valueS;
  Rational? fraction;
  int? numBase;
  num? baseMultiplier;
  String? script;
  bool isLargePower;
  bool active;
  int? nDecimals;

  NumEdge(
    int start,
    int end,
    String s, {
    NumProp? numProp,
    this.active = false,
    int utf16Start = 0,
    int utf16End = 0,
  }) : origTxt = s,
       isLargePower = false,
       super(start, end, s, null, utf16Start, utf16End) {
    if (start + 1 == end && numProp != null) {
      active = true;
      value = numProp.value;
      if (numProp.fraction != null && numProp.fraction!.length >= 2) {
        fraction = Rational(numProp.fraction![0], numProp.fraction![1]);
      }
      numBase = numProp.base;
      baseMultiplier = numProp.mult;
      type = numProp.type;
      script = numProp.script;
      isLargePower = numProp.isLargePower ?? false;
      update();
    }
  }

  /// Updates edge numerical attributes and recomputes `txt`.
  String update({
    num? value,
    String? valueS,
    Rational? fraction,
    int? nDecimals,
    int? numBase,
    num? baseMultiplier,
    String? script,
    String? eType,
    String? origTxt,
  }) {
    if (value != null) this.value = value;
    if (valueS != null) this.valueS = valueS;
    if (fraction != null) this.fraction = fraction;
    if (nDecimals != null) this.nDecimals = nDecimals;
    if (numBase != null) this.numBase = numBase;
    if (baseMultiplier != null) this.baseMultiplier = baseMultiplier;
    if (script != null) this.script = script;
    if (eType != null) type = eType;
    if (origTxt != null) this.origTxt = origTxt;

    String vStr;
    if (this.valueS != null) {
      vStr = this.valueS!;
    } else if (this.value == null) {
      vStr = '';
    } else if (this.value is double && this.nDecimals != null) {
      vStr =
          this.valueS ?? pyFormatFloat(this.value as double, this.nDecimals!);
    } else {
      vStr = this.value.toString();
    }

    final fracStr = this.fraction == null
        ? ''
        : '${this.fraction!.numerator}/${this.fraction!.denominator}';
    final delim = (vStr.isNotEmpty && fracStr.isNotEmpty) ? ' ' : '';
    final combined = vStr + delim + fracStr;
    txt = combined.isNotEmpty ? combined : this.origTxt;
    return txt;
  }
}
