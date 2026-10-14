/// A rational number (equivalent to Python's [Fraction]) used in number processing.
class Rational implements Comparable<Rational> {
  final int numerator;
  final int denominator;

  /// Creates a [Rational] reduced to lowest terms with a positive denominator.
  factory Rational(int num, int den) {
    if (den == 0) {
      throw ArgumentError.value(
        den,
        'denominator',
        'Denominator cannot be zero',
      );
    }
    if (num == 0) {
      return const Rational._(0, 1);
    }
    var n = num;
    var d = den;
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final g = _gcd(n.abs(), d);
    return Rational._(n ~/ g, d ~/ g);
  }

  const Rational._(this.numerator, this.denominator);

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  double toDouble() => numerator / denominator;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rational &&
          numerator == other.numerator &&
          denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  String toString() => '$numerator/$denominator';
}
