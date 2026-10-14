import 'package:test/test.dart';
import 'package:uroman/src/unicode/unicode_props.dart';

void main() {
  group('UnicodeProps Category Tests', () {
    test('Nonspacing Mark (Mn)', () {
      expect(UnicodeProps.isNonspacingMark(0x0300), isTrue); // Combining grave
      expect(UnicodeProps.isNonspacingMark(0x0301), isTrue); // Combining acute
      expect(
        UnicodeProps.isNonspacingMark(0x094D),
        isTrue,
      ); // Devanagari virama
      expect(
        UnicodeProps.isNonspacingMark(0x0E4C),
        isTrue,
      ); // Thai cancellation mark
      expect(UnicodeProps.isNonspacingMark(0x0041), isFalse); // 'A'
    });

    test('Format Character (Cf)', () {
      expect(UnicodeProps.isFormatChar(0x200B), isTrue); // Zero-width space
      expect(UnicodeProps.isFormatChar(0x200C), isTrue); // ZWNJ
      expect(UnicodeProps.isFormatChar(0x200D), isTrue); // ZWJ
      expect(UnicodeProps.isFormatChar(0x0041), isFalse);
    });

    test('Space Separator (Zs)', () {
      expect(UnicodeProps.isSpaceSeparator(0x0020), isTrue); // Space
      expect(UnicodeProps.isSpaceSeparator(0x00A0), isTrue); // NBSP
      expect(
        UnicodeProps.isSpaceSeparator(0x3000),
        isTrue,
      ); // Ideographic space
      expect(UnicodeProps.isSpaceSeparator(0x000A), isFalse); // Newline
    });

    test('Private Use Area (Co)', () {
      expect(UnicodeProps.isPrivateUse(0xE000), isTrue);
      expect(UnicodeProps.isPrivateUse(0xF8F0), isTrue);
      expect(UnicodeProps.isPrivateUse(0x0041), isFalse);
    });

    test('Letter category (L*) and Mark category (M*)', () {
      expect(UnicodeProps.isLetter(0x0041), isTrue); // 'A'
      expect(UnicodeProps.isLetter(0x0061), isTrue); // 'a'
      expect(UnicodeProps.isLetter(0x03B1), isTrue); // Greek alpha
      expect(UnicodeProps.isLetter(0x0418), isTrue); // Cyrillic I
      expect(UnicodeProps.isLetter(0xAC00), isTrue); // Hangul ga
      expect(UnicodeProps.isLetter(0x0030), isFalse); // '0'

      expect(UnicodeProps.isMark(0x0301), isTrue); // Combining acute
      expect(UnicodeProps.isMark(0x094D), isTrue); // Virama
      expect(UnicodeProps.isMark(0x0041), isFalse);
    });

    test('Uppercase (Lu) and Lowercase (Ll)', () {
      expect(UnicodeProps.isUpper(0x0041), isTrue); // 'A'
      expect(UnicodeProps.isUpper(0x0061), isFalse); // 'a'
      expect(UnicodeProps.isUpper(0x03A9), isTrue); // Greek Omega
      expect(UnicodeProps.isLower(0x03C9), isTrue); // Greek omega
      expect(UnicodeProps.isLower(0x0061), isTrue); // 'a'
    });
  });

  group('UnicodeProps Name Flags', () {
    test('LETTER in name', () {
      expect(
        UnicodeProps.hasLetterInName(0x0041),
        isTrue,
      ); // LATIN CAPITAL LETTER A
      expect(UnicodeProps.hasLetterInName(0x0030), isFalse); // DIGIT ZERO
      expect(
        UnicodeProps.hasLetterInName(0x0F90),
        isTrue,
      ); // TIBETAN SUBJOINED LETTER KA
      expect(
        UnicodeProps.hasLetterInName(0x4E00),
        isFalse,
      ); // CJK UNIFIED IDEOGRAPH-4E00
    });

    test('SUBJOINED LETTER in name', () {
      expect(
        UnicodeProps.hasSubjoinedInName(0x0FB0),
        isTrue,
      ); // TIBETAN SUBJOINED LETTER -HA
      expect(
        UnicodeProps.hasSubjoinedInName(0x0F40),
        isFalse,
      ); // TIBETAN LETTER KA
    });

    test('NUKTA in name', () {
      expect(
        UnicodeProps.hasNuktaInName(0x093C),
        isTrue,
      ); // DEVANAGARI SIGN NUKTA
      expect(UnicodeProps.hasNuktaInName(0x0905), isFalse);
    });

    test('VOCALIC in name', () {
      expect(
        UnicodeProps.hasVocalicInName(0x090B),
        isTrue,
      ); // DEVANAGARI LETTER VOCALIC R
      expect(UnicodeProps.hasVocalicInName(0x0905), isFalse);
    });

    test('DIGIT in name', () {
      expect(UnicodeProps.hasDigitInName(0x0030), isTrue); // DIGIT ZERO
      expect(UnicodeProps.hasDigitInName(0x0041), isFalse);
    });
  });

  group('UnicodeProps Numeric & Decomposition Tables', () {
    test('udNumeric', () {
      expect(UnicodeProps.udNumeric(0x0035), equals(5));
      expect(UnicodeProps.udNumeric(0x4E07), equals(10000)); // 万
      expect(UnicodeProps.udNumeric(0x00BD), equals(0.5)); // ½
      expect(UnicodeProps.udNumeric(0x0041), isNull);
    });

    test('decompRom', () {
      expect(UnicodeProps.decompRom(0x00BD), equals('1⁄2')); // ½
      expect(UnicodeProps.decompRom(0x2102), equals('C')); // ℂ
      expect(UnicodeProps.decompRom(0x0041), isNull);
    });

    test('fractionDecomp', () {
      expect(UnicodeProps.fractionDecomp(0x00BD), equals([1, 2])); // ½
      expect(UnicodeProps.fractionDecomp(0x00BE), equals([3, 4])); // ¾
      expect(UnicodeProps.fractionDecomp(0x0041), isNull);
    });
  });
}
