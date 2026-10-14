import 'package:test/test.dart';
import 'package:uroman/uroman.dart';

void main() {
  group('Uroman smoke tests', () {
    final uroman = Uroman();

    test('Greek romanization', () {
      expect(uroman.romanizeString('Καλημέρα'), equals('Kalemera'));
    });

    test('Russian romanization', () {
      expect(uroman.romanizeString('Привет'), equals('Privet'));
    });

    test('Arabic romanization', () {
      expect(uroman.romanizeString('مرحبا'), equals('mrhba'));
    });

    test('Korean Hangul romanization', () {
      expect(uroman.romanizeString('한국어'), equals('hangugeo'));
    });
  });
}
