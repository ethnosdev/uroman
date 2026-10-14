import 'package:test/test.dart';
import 'package:uroman/uroman.dart';

void main() {
  test('Uroman initializes on web with embedded data', () {
    final uroman = Uroman();
    expect(uroman.data.scripts.length, greaterThan(100));
    expect(uroman.data.romRules.length, greaterThan(1000));
    expect(uroman.data.numProps.length, greaterThan(1000));
  });

  test('Uroman romanizes multiple scripts on web', () {
    final uroman = Uroman();

    // Russian
    expect(
      uroman.romanizeString('Игорь Стравинский'),
      equals('Igor Stravinsky'),
    );

    // Greek with lcode
    expect(
      uroman.romanizeString('Ντέιβις Καπ', lcode: 'ell'),
      equals('Deivis Kap'),
    );

    // Japanese
    expect(uroman.romanizeString('ちょっとまってください'), equals('chottomattekudasai'));

    // Arabic
    expect(uroman.romanizeString('كندا', lcode: 'ara'), equals('knda'));

    // Hindi
    expect(
      uroman.romanizeString('महात्मा गांधी', lcode: 'hin'),
      equals('mahaatmaa gaamdhii'),
    );

    // Thai
    expect(uroman.romanizeString('ออสเตรีย', lcode: 'tha'), equals('otteria'));

    // Chinese numbers
    expect(uroman.romanizeString('三千二百五十四'), equals('3254'));

    // Large number (10^16): verifies precision on web double/BigInt
    expect(uroman.romanizeString('一京'), equals('10000000000000000'));

    // Fractions
    expect(uroman.romanizeString('½'), equals('1/2'));

    // Edges format
    final edges =
        uroman.romanizeString('ちょっと', format: RomFormat.edges) as List<Edge>;
    expect(edges.length, equals(2));
    expect(edges[0].txt, equals('cho'));
    expect(edges[1].txt, equals('tto'));
    expect(edges[0].utf16Start, equals(0));
    expect(edges[0].utf16End, equals(2));
  });
}
