import 'dart:math' as math;

/// Sealed class representing a Python numeric value ([PyInt] or [PyFloat]).
///
/// This provides exact type-preservation on both the Dart VM and Dart Web (JavaScript),
/// where Dart's standard `is int` would otherwise treat `1.0 is int` as true.
sealed class PyNum implements Comparable<PyNum> {
  const PyNum();

  bool get isInt;
  bool get isFloat;

  int toInt();
  double toDouble();

  /// Converts the number to Python's exact `str(num)` representation.
  String toPyString();

  PyNum operator +(PyNum other);
  PyNum operator -(PyNum other);
  PyNum operator *(PyNum other);

  static PyNum? parse(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
    if (s.contains('.')) {
      final d = double.tryParse(s);
      return d == null ? null : PyFloat(d);
    } else {
      final i = int.tryParse(s);
      return i == null ? null : PyInt(i);
    }
  }

  static PyNum fromNum(num n) {
    if (n is int) return PyInt(n);
    if (n is double) {
      // In JS, check if it's an integer value or float
      if (identical(0, 0.0) && n == n.truncateToDouble()) {
        return PyInt(n.toInt());
      }
      return PyFloat(n);
    }
    return PyInt(n.toInt());
  }
}

/// Represents a Python integer value.
class PyInt extends PyNum {
  final int value;

  const PyInt(this.value);

  @override
  bool get isInt => true;

  @override
  bool get isFloat => false;

  @override
  int toInt() => value;

  @override
  double toDouble() => value.toDouble();

  @override
  String toPyString() => value.toString();

  @override
  PyNum operator +(PyNum other) {
    if (other is PyInt) return PyInt(value + other.value);
    return PyFloat(value + other.toDouble());
  }

  @override
  PyNum operator -(PyNum other) {
    if (other is PyInt) return PyInt(value - other.value);
    return PyFloat(value - other.toDouble());
  }

  @override
  PyNum operator *(PyNum other) {
    if (other is PyInt) return PyInt(value * other.value);
    return PyFloat(value * other.toDouble());
  }

  @override
  int compareTo(PyNum other) {
    if (other is PyInt) return value.compareTo(other.value);
    return toDouble().compareTo(other.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PyInt && value == other.value ||
      other is PyFloat && other.value.isFinite && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => toPyString();
}

/// Represents a Python floating-point value.
class PyFloat extends PyNum {
  final double value;

  const PyFloat(this.value);

  @override
  bool get isInt => false;

  @override
  bool get isFloat => true;

  @override
  int toInt() => value.toInt();

  @override
  double toDouble() => value;

  @override
  String toPyString() {
    if (value.isNaN) return 'nan';
    if (value.isInfinite) return value.isNegative ? '-inf' : 'inf';
    if (value == 0.0) return '0.0';

    final absVal = value.abs();
    String s;
    if (absVal < 1e-4 || absVal >= 1e16) {
      // Python uses scientific notation
      s = value.toStringAsExponential();
    } else {
      s = value.toString();
    }

    if (s.contains('e') || s.contains('E')) {
      final parts = s.split(RegExp(r'[eE]'));
      final mantissa = parts[0];
      var expStr = parts[1];
      var sign = '+';
      if (expStr.startsWith('-')) {
        sign = '-';
        expStr = expStr.substring(1);
      } else if (expStr.startsWith('+')) {
        expStr = expStr.substring(1);
      }
      final expInt = int.parse(expStr);
      final paddedExp = expInt < 10 ? '0$expInt' : '$expInt';
      return '${mantissa}e$sign$paddedExp';
    }
    if (!s.contains('.')) {
      return '$s.0';
    }
    return s;
  }

  @override
  PyNum operator +(PyNum other) => PyFloat(value + other.toDouble());

  @override
  PyNum operator -(PyNum other) => PyFloat(value - other.toDouble());

  @override
  PyNum operator *(PyNum other) => PyFloat(value * other.toDouble());

  @override
  int compareTo(PyNum other) => value.compareTo(other.toDouble());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PyFloat && value == other.value ||
      other is PyInt && value.isFinite && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => toPyString();
}

/// Formats a float according to Python's `f'{val:0.{nDecimals}f}'`.
String pyFormatFloat(double val, int nDecimals) {
  return val.toStringAsFixed(nDecimals);
}

/// Rounds a double according to Python's `round(val, nDecimals)` (round half to even / banker's rounding).
double pyRound(double val, int nDecimals) {
  if (val.isNaN || val.isInfinite) return val;
  final factor = math.pow(10, nDecimals).toDouble();
  final x = val * factor;
  final floor = x.floorToDouble();
  final diff = x - floor;

  double rounded;
  if ((diff - 0.5).abs() < 1e-12) {
    // Exactly half - round to nearest even
    final floorInt = floor.toInt();
    if (floorInt % 2 == 0) {
      rounded = floor;
    } else {
      rounded = floor + 1.0;
    }
  } else if (diff > 0.5) {
    rounded = floor + 1.0;
  } else {
    rounded = floor;
  }
  return rounded / factor;
}
