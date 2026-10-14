import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:uroman/uroman.dart';

void main() {
  final uroman = Uroman();

  group('Phase 4: Golden STR tests across scripts', () {
    final fixturesDir = Directory('test/fixtures/text');
    final textFiles = fixturesDir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in textFiles) {
      final filename = file.uri.pathSegments.last;
      if (!filename.endsWith('.txt')) continue;
      final stem = filename.substring(0, filename.length - 4);
      final goldenFile = File('test/goldens/str/$stem.str');
      if (!goldenFile.existsSync()) continue;

      test('Script test: $stem', () {
        final inputLines = const LineSplitter().convert(
          file.readAsStringSync(),
        );
        final expectedLines = const LineSplitter().convert(
          goldenFile.readAsStringSync(),
        );

        final actualLines = <String>[];
        for (final line in inputLines) {
          actualLines.add(uroman.romanizeString(line, lcode: stem) as String);
        }

        expect(actualLines.length, equals(expectedLines.length));
        for (var i = 0; i < expectedLines.length; i++) {
          expect(
            actualLines[i],
            equals(expectedLines[i]),
            reason:
                'Line ${i + 1} mismatch in $stem:\n'
                'Input:    ${inputLines[i]}\n'
                'Expected: ${expectedLines[i]}\n'
                'Actual:   ${actualLines[i]}',
          );
        }
      });
    }

    test('Multi-script nocache test', () {
      final inputFile = File('test/fixtures/multi-script.txt');
      final goldenFile = File('test/goldens/str/multi-script.nocache.str');
      final inputLines = const LineSplitter().convert(
        inputFile.readAsStringSync(),
      );
      final expectedLines = const LineSplitter().convert(
        goldenFile.readAsStringSync(),
      );

      final actualLines = <String>[];
      final lcodeRegex = RegExp(r'^(::lcode[ \t]+)([a-z]{3})([ \t]+)(.*)$');

      for (final line in inputLines) {
        final m = lcodeRegex.firstMatch(line);
        if (m != null) {
          final prefix = '${m.group(1)}${m.group(2)}${m.group(3)}';
          final snt = m.group(4)!;
          final lcode = m.group(2);
          final res = uroman.romanizeString(snt, lcode: lcode) as String;
          actualLines.add(prefix + res);
        } else {
          final res = uroman.romanizeString(line) as String;
          actualLines.add(res);
        }
      }

      expect(actualLines.length, equals(expectedLines.length));
      for (var i = 0; i < expectedLines.length; i++) {
        expect(
          actualLines[i],
          equals(expectedLines[i]),
          reason:
              'Line ${i + 1} mismatch in multi-script.nocache:\n'
              'Input:    ${inputLines[i]}\n'
              'Expected: ${expectedLines[i]}\n'
              'Actual:   ${actualLines[i]}',
        );
      }
    });
  });
}
