import 'package:test/test.dart';
import 'package:uroman/src/compat/py_num.dart';
import 'package:uroman/src/compat/rational.dart';
import 'package:uroman/src/compat/py_json.dart';
import 'package:uroman/src/compat/py_string.dart';

void main() {
  group('PyNum & Rational Tests', () {
    test('PyInt creation, arithmetic, string repr', () {
      final a = PyInt(42);
      final b = PyInt(8);
      expect(a.isInt, isTrue);
      expect(a.isFloat, isFalse);
      expect(a.toInt(), equals(42));
      expect(a.toDouble(), equals(42.0));
      expect(a.toPyString(), equals('42'));
      expect((a + b).toPyString(), equals('50'));
      expect((a - b).toPyString(), equals('34'));
      expect((a * b).toPyString(), equals('336'));
      expect(a.compareTo(b), isPositive);
    });

    test('PyFloat creation, arithmetic, string repr', () {
      final f = PyFloat(3.14);
      expect(f.isInt, isFalse);
      expect(f.isFloat, isTrue);
      expect(f.toDouble(), equals(3.14));
      expect(f.toPyString(), equals('3.14'));

      final wholeFloat = PyFloat(1.0);
      expect(wholeFloat.toPyString(), equals('1.0'));

      final sciSmall = PyFloat(1e-5);
      expect(sciSmall.toPyString(), equals('1e-05'));

      final sciBig = PyFloat(1e16);
      expect(sciBig.toPyString(), equals('1e+16'));
    });

    test('PyNum.parse', () {
      expect(PyNum.parse('100'), equals(PyInt(100)));
      expect(PyNum.parse('100.5'), equals(PyFloat(100.5)));
      expect(PyNum.parse('   -42  '), equals(PyInt(-42)));
      expect(PyNum.parse('abc'), isNull);
    });

    test('pyRound banker\'s rounding', () {
      expect(pyRound(2.5, 0), equals(2.0));
      expect(pyRound(3.5, 0), equals(4.0));
      expect(pyRound(1.25, 1), equals(1.2));
      expect(pyRound(1.35, 1), equals(1.4));
    });

    test('pyFormatFloat', () {
      expect(pyFormatFloat(3.14159, 2), equals('3.14'));
      expect(pyFormatFloat(2.0, 3), equals('2.000'));
      expect(pyFormatFloat(0.5, 1), equals('0.5'));
    });

    test('Rational reduction and representation', () {
      final r1 = Rational(6, 4);
      expect(r1.numerator, equals(3));
      expect(r1.denominator, equals(2));
      expect(r1.toString(), equals('3/2'));

      final r0 = Rational(0, 5);
      expect(r0.numerator, equals(0));
      expect(r0.denominator, equals(1));
      expect(r0.toString(), equals('0/1'));

      final rNeg = Rational(3, -6);
      expect(rNeg.numerator, equals(-1));
      expect(rNeg.denominator, equals(2));
    });
  });

  group('py_json Tests', () {
    test('pyJsonString escapes non-ascii and special chars', () {
      expect(pyJsonString('hello'), equals('"hello"'));
      expect(pyJsonString('quote " and \\ and \n'), equals(r'"quote \" and \\ and \n"'));
      expect(pyJsonString('И'), equals(r'"\u0418"'));
      expect(pyJsonString('й'), equals(r'"\u0439"'));
      expect(pyJsonString('𓍧'), equals(r'"\ud80c\udf67"'));
    });

    test('pyJsonEdge format', () {
      expect(pyJsonEdge(0, 1, 'И', 'rom'), equals(r'[0, 1, "\u0418", "rom"]'));
      expect(pyJsonEdge(0, 1, 'a', null), equals('[0, 1, "a", null]'));
    });

    test('pyJsonEdgeList format without commas between edges', () {
      final e1 = pyJsonEdge(0, 1, 'a', 'rom');
      final e2 = pyJsonEdge(1, 2, 'b', 'rom');
      expect(pyJsonEdgeList([e1, e2]), equals('[[0, 1, "a", "rom"][1, 2, "b", "rom"]]'));
    });
  });

  group('PyString Tests', () {
    test('toCodePoints and fromCodePoints', () {
      const s = 'Hello 𓍧 世界';
      final cps = PyString.toCodePoints(s);
      expect(PyString.fromCodePoints(cps), equals(s));
    });

    test('Python slice semantics', () {
      final list = [10, 20, 30, 40, 50];
      expect(PyString.slice(list, 1, 3), equals([20, 30]));
      expect(PyString.slice(list, -2), equals([40, 50]));
      expect(PyString.slice(list, 0, -1), equals([10, 20, 30, 40]));
      expect(PyString.slice(list, -10, 2), equals([10, 20]));
      expect(PyString.slice(list, 3, 2), isEmpty);
    });

    test('dequote', () {
      expect(PyString.dequote("'hello'"), equals('hello'));
      expect(PyString.dequote('"hello"'), equals('hello'));
      expect(PyString.dequote('“hello”'), equals('hello'));
      expect(PyString.dequote('hello'), equals('hello'));
    });

    test('lastChar and capitalize', () {
      expect(PyString.lastChar('abc'), equals('c'));
      expect(PyString.lastChar(''), equals(''));
      expect(PyString.capitalize('th'), equals('Th'));
      expect(PyString.capitalize('TH'), equals('Th'));
      expect(PyString.capitalize(''), equals(''));
    });

    test('decodeUnicodeEscapes', () {
      expect(PyString.decodeUnicodeEscapes(r'\u03C0\u03B9'), equals('πι'));
      expect(PyString.decodeUnicodeEscapes(r'prefix \x22 quote'), equals(r'prefix \x22 quote'));
      expect(PyString.decodeUnicodeEscapes(r'regular text'), equals('regular text'));
    });
  });
}
