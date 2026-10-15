import 'package:test/test.dart';
import 'package:uroman/src/lattice/lattice.dart';
import 'package:uroman/uroman.dart';

void main() {
  final uroman = Uroman();

  group('Upstream Quirks Improvements: Old vs New Output Verification', () {
    test('1. Archaic Georgian Letters (data typo :::t -> ::t)', () {
      const input = 'ჳ Ⴣ Ჳ ⴣ';
      const oldOutput = 'ჳ Ⴣ Ჳ ⴣ'; // Untranslated raw characters in Python uroman
      const expectedNewOutput = 'w W W w';

      final actualOutput = uroman.romanizeString(input);

      expect(
        actualOutput,
        equals(expectedNewOutput),
        reason:
            'Archaic Georgian letters should be romanized to "w W W w", not left untouched as in upstream Python.',
      );
      expect(
        actualOutput,
        isNot(equals(oldOutput)),
        reason: 'Should not match the buggy upstream output.',
      );
    });

    test('2. Trailing Space Trimming at String Boundary (end == len + 1 bug)', () {
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
    });

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
        reason:
            'Small tsu must fall back to its table romanization "tsu", never leaking unromanized Kana "っ" into output.',
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
        reason: 'Gurmukhi addak must not double a cross-script Latin consonant.',
      );
      expect(
        actualGurmukhiLatin,
        equals("'k"),
        reason:
            'Gurmukhi addak must fall back to its canonical table representation "\'", never leaking unromanized mark "\\u0A71" into output.',
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

    test('4. Tibetan Syllable Consonant Cost Consistency (i == 0 vs relPos == 0)', () {
      // In upstream Python uroman, line 1613 checked i == 0 (global index in string)
      // instead of relative syllable position rel_pos == 0.
      // Both at the beginning of text and after whitespace/prefix, two-letter syllables
      // must consistently romanize with root-letter vowel placement:
      final atStart = uroman.romanizeString('གང', lcode: 'bod');
      final afterSpace = uroman.romanizeString(' གང', lcode: 'bod');

      expect(atStart, equals('gang'));
      expect(afterSpace, equals(' gang'));
    });

    test('5. Thai Vowel O ANG Context Recognition (สอง -> song)', () {
      // O ANG (อ) acts as consonant carrier initially, but as vowel 'o' between consonants.
      // Accurate left-context lookup ensures correct vowel detection.
      expect(uroman.romanizeString('สอง', lcode: 'tha'), equals('song'));
    });

    test('6. Backwards Edge Traversal Contiguity (no skipped vertices)', () {
      // In upstream Python uroman line 2314, `if old_end2 >= end2: end2 -= 1`
      // unconditionally decremented end2 after finding an edge, skipping adjacent vertices.
      final lat = Lattice(originalString: 'hello', uroman: uroman.data, lcode: 'eng');
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
  });
}
