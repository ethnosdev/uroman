import 'package:test/test.dart';
import 'package:uroman/src/lattice/lattice.dart';
import 'package:uroman/uroman.dart';

void main() {
  final uroman = Uroman();

  group('Upstream Quirks Improvements: Old vs New Output Verification', () {
    test('1. Archaic Georgian Letters (data typo :::t -> ::t)', () {
      const input = 'ჳ Ⴣ Ჳ ⴣ';
      const oldOutput =
          'ჳ Ⴣ Ჳ ⴣ'; // Untranslated raw characters in Python uroman
      const expectedNewOutput = 'w W W w';

      final actualOutput = uroman.romanizeString(input);

      expect(
        actualOutput,
        equals(expectedNewOutput),
        reason: 'Archaic Georgian letters should be romanized to "w W W w", not left untouched as in upstream Python.',
      );
      expect(
        actualOutput,
        isNot(equals(oldOutput)),
        reason: 'Should not match the buggy upstream output.',
      );
    });

    test(
      '2. Trailing Space Trimming at String Boundary (end == len + 1 bug)',
      () {
        // In upstream Python uroman, end == len + 1 prevented trimming trailing space
        // at the end of strings/lines, leaving an extra space after CJK full stops (。 -> ". ").
        const inputZho = '加拿大。';
        const oldZhoOutput = 'jianada. ';
        const expectedZhoOutput = 'jianada.';

        final actualZho = uroman.romanizeString(inputZho, lcode: 'zho');
        expect(actualZho, equals(expectedZhoOutput));
        expect(actualZho, isNot(equals(oldZhoOutput)));

        const inputJpn = 'ちょっとまってください。';
        const oldJpnOutput = 'chottomattekudasai. ';
        const expectedJpnOutput = 'chottomattekudasai.';

        final actualJpn = uroman.romanizeString(inputJpn, lcode: 'jpn');
        expect(actualJpn, equals(expectedJpnOutput));
        expect(actualJpn, isNot(equals(oldJpnOutput)));

        // Mid-line CJK sentence spacing verification:
        // 1. Mid-line `。` followed immediately by another CJK character retains its space.
        // 2. Mid-line `。` followed by an existing space does not produce a double space.
        // 3. Only the final sentence-ending `。` at maxVertex has its trailing space trimmed.
        const multiNoSpace = '句子一。句子二。';
        const multiWithSpace = '句子一。 句子二。';
        const expectedMulti = 'juzi1. juzi2.';

        expect(
          uroman.romanizeString(multiNoSpace, lcode: 'zho'),
          equals(expectedMulti),
          reason: 'Mid-line full stop before next sentence must retain separating space, while terminal full stop has space trimmed.',
        );
        expect(
          uroman.romanizeString(multiWithSpace, lcode: 'zho'),
          equals(expectedMulti),
          reason: 'Mid-line full stop before existing space must not produce double space.',
        );

        // Verify non-numeric CJK sentences as well:
        expect(
          uroman.romanizeString('加拿大。日本。', lcode: 'zho'),
          equals('jianada. riben.'),
        );
        expect(
          uroman.romanizeString('加拿大。 日本。', lcode: 'zho'),
          equals('jianada. riben.'),
        );

        // Verify same behavior with cached instance:
        final uCached = Uroman(cacheSize: 65536);
        expect(
          uCached.romanizeString(multiNoSpace, lcode: 'zho'),
          equals(expectedMulti),
        );
        expect(
          uCached.romanizeString(multiWithSpace, lcode: 'zho'),
          equals(expectedMulti),
        );
      },
    );

    test('3. Cross-Script Gemination Protection (Japanese small tsu & Gurmukhi addak)', () {
      // Upstream checked chr_script_name(prev_char) == chr_script_name(prev_char) (always true),
      // which caused small tsu and Gurmukhi addak to double Latin consonants across scripts!
      const inputJpnLatin = 'っb';
      const oldJpnLatinOutput = 'bb'; // Erroneously doubled Latin b

      final actualJpnLatin = uroman.romanizeString(inputJpnLatin);
      expect(
        actualJpnLatin,
        isNot(equals(oldJpnLatinOutput)),
        reason: 'Japanese small tsu must not double a cross-script Latin consonant.',
      );
      expect(
        actualJpnLatin,
        equals('tsub'),
        reason: 'Small tsu must fall back to its table romanization "tsu", never leaking unromanized Kana "っ" into output.',
      );

      // Katakana small tsu and other cross-script consonants:
      expect(uroman.romanizeString('ッb'), equals('tsub'));
      expect(uroman.romanizeString('っд'), equals('tsud'));
      // Standalone small tsu:
      expect(uroman.romanizeString('っ'), equals('tsu'));
      expect(uroman.romanizeString('ッ'), equals('tsu'));

      const inputGurmukhiLatin = '\u0A71k';
      const oldGurmukhiLatinOutput = 'kk'; // Erroneously doubled Latin k

      final actualGurmukhiLatin = uroman.romanizeString(inputGurmukhiLatin);
      expect(
        actualGurmukhiLatin,
        isNot(equals(oldGurmukhiLatinOutput)),
        reason:
            'Gurmukhi addak must not double a cross-script Latin consonant.',
      );
      expect(
        actualGurmukhiLatin,
        equals("'k"),
        reason: 'Gurmukhi addak must fall back to its canonical table representation "\'", never leaking unromanized mark "\\u0A71" into output.',
      );

      // Standalone Gurmukhi addak:
      expect(uroman.romanizeString('\u0A71'), equals("'"));
      expect(uroman.romanizeString('ੱ'), equals("'"));

      // Verify that valid in-script gemination still works correctly:
      expect(uroman.romanizeString('ちょっと', lcode: 'jpn'), equals('chotto'));
      expect(uroman.romanizeString('マッチ', lcode: 'jpn'), equals('matchi'));
      expect(uroman.romanizeString('ਪੱਤਾ', lcode: 'pan'), equals('pattaa'));
      expect(uroman.romanizeString('ਬੱਚਾ', lcode: 'pan'), equals('baccaa'));
    });

    test(
      '4. Tibetan Syllable Consonant Cost Consistency (i == 0 vs relPos == 0)',
      () {
        // In upstream Python uroman, line 1613 checked i == 0 (global index in string)
        // instead of relative syllable position rel_pos == 0.
        // Both at the beginning of text and after whitespace/prefix, two-letter syllables
        // must consistently romanize with root-letter vowel placement:
        final atStart = uroman.romanizeString('གང', lcode: 'bod');
        final afterSpace = uroman.romanizeString(' གང', lcode: 'bod');

        expect(atStart, equals('gang'));
        expect(afterSpace, equals(' gang'));
      },
    );

    test('5. Thai Vowel O ANG Context Recognition (สอง -> song)', () {
      // O ANG (อ) acts as consonant carrier initially, but as vowel 'o' between consonants.
      // Accurate left-context lookup ensures correct vowel detection.
      expect(uroman.romanizeString('สอง', lcode: 'tha'), equals('song'));
    });

    test('6. Backwards Edge Traversal Contiguity (no skipped vertices)', () {
      // In upstream Python uroman line 2314, `if old_end2 >= end2: end2 -= 1`
      // unconditionally decremented end2 after finding an edge, skipping adjacent vertices.
      final lat = Lattice(
        originalString: 'hello',
        uroman: uroman.data,
        lcode: 'eng',
      );
      // Add consecutive single-character edges: [0,1], [1,2], [2,3], [3,4], [4,5]
      for (var i = 0; i < 5; i++) {
        lat.addEdge(Edge(i, i + 1, 'x', 'test'));
      }
      final backwardEdges = lat.findRomEdgePathBackwards(0, 5, minChar: 4);

      // In the improved implementation, backwards edges are contiguous [1..5]:
      final starts = backwardEdges.map((e) => e.start).toList();
      final ends = backwardEdges.map((e) => e.end).toList();

      expect(starts, equals([1, 2, 3, 4]), reason: 'Should not skip vertices');
      expect(ends, equals([2, 3, 4, 5]), reason: 'Should be contiguous');
    });

    test('7. Numeric Value 0 Preservation (Chinese 〇 and 零)', () {
      // In upstream Python uroman line 174, `0 in (None, [], False)` evaluated to True (0 == False),
      // silently dropping the ::num attribute from rules for Chinese 〇 and 零.
      expect(uroman.romanizeString('〇'), equals('0'));
      expect(uroman.romanizeString('零'), equals('0'));
      expect(uroman.romanizeString('三万零一', lcode: 'zho'), equals('30001'));
      expect(uroman.romanizeString('〇', lcode: 'zho'), equals('0'));
      expect(uroman.romanizeString('零', lcode: 'zho'), equals('0'));
    });

    test('8. Chinese Fraction/Percentage Parsing with Non-Numeric and Numeric Suffixes (PR #17 & Issue #16)', () {
      // In upstream Python uroman, best_right_neighbor_edge after 百分之 could return an Edge
      // instead of a NumEdge, raising `'Edge' object has no attribute 'value'`.
      const issue16Text =
          '前三个月的focus的经营率的百分之多少或者是生命周期的focus经营率的百分之多少前者点位高一些或者点位低一些然后我们内部核算差不多这个点位应该是能擦过我们手臂的倍量就ok了这样所以我们我觉得没问题我觉得就这么写就是nre跟认证的费用是要在项目启动开始之前我要收到对吧然后关于倍量的成本的问题我们需要再拿到';

      expect(
        () => uroman.romanizeString(issue16Text, lcode: 'zho'),
        returnsNormally,
      );
      final res = uroman.romanizeString(issue16Text, lcode: 'zho');
      expect(res, contains('baifenzhiduoshao'));

      // Also verify valid percentage conversion:
      expect(uroman.romanizeString('百分之五十', lcode: 'zho'), equals('50%'));
      expect(uroman.romanizeString('百分之百', lcode: 'zho'), equals('100%'));
    });

    test('9. Chinese Number Romanization (Issue #19)', () {
      // Verify Chinese numbers convert accurately to numerical digits
      expect(uroman.romanizeString('千', lcode: 'zho'), equals('1000'));
      expect(uroman.romanizeString('千', lcode: 'zh'), equals('1000'));
      expect(uroman.romanizeString('一千', lcode: 'zho'), equals('1000'));
      expect(uroman.romanizeString('百', lcode: 'zho'), equals('100'));
      expect(uroman.romanizeString('一百', lcode: 'zho'), equals('100'));
      expect(uroman.romanizeString('三万一', lcode: 'zho'), equals('31000'));
      expect(uroman.romanizeString('三万零一', lcode: 'zho'), equals('30001'));
    });

    test('10. Cham Script and Typographic Punctuation (Issue #25 & #26)', () {
      // Cham script transliteration
      expect(uroman.romanizeString('ꨀꨁꨂꨃꨄꨅ'), equals('aiueaio'));

      // Typographic apostrophe and punctuation preservation in Latin script
      expect(
        uroman.romanizeString('[384] Côte d’Ivoire', lcode: 'fra'),
        equals('[384] Cote d’Ivoire'),
      );
    });
  });
}
