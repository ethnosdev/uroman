import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:uroman/uroman.dart';

String _readTextFile(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return '\uFEFF${utf8.decode(bytes.sublist(3))}';
  }
  return utf8.decode(bytes);
}

void main() {
  final uNoCache = Uroman(cacheSize: 0);
  final uCached = Uroman(cacheSize: 65536);

  final formats = [
    ('str', RomFormat.str),
    ('edges', RomFormat.edges),
    ('alts', RomFormat.alts),
    ('lattice', RomFormat.lattice),
  ];

  final textFiles =
      Directory('test/fixtures/text')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final (fmtName, fmtVal) in formats) {
    group('Format: $fmtName', () {
      for (final file in textFiles) {
        final stem = file.uri.pathSegments.last.replaceAll('.txt', '');
        final goldenFile = File('test/goldens/$fmtName/$stem.$fmtName');
        if (!goldenFile.existsSync()) continue;

        test('Script $stem in $fmtName', () {
          final inputLines = const LineSplitter().convert(_readTextFile(file));
          final expectedLines = const LineSplitter().convert(
            goldenFile.readAsStringSync(),
          );

          final actualLines = uNoCache.romanizeLines(
            inputLines,
            lcode: stem,
            format: fmtVal,
          );

          expect(actualLines.length, equals(expectedLines.length));
          for (var i = 0; i < expectedLines.length; i++) {
            if (fmtVal == RomFormat.lattice) {
              expect(
                _normalizeLatticeLine(actualLines[i]),
                equals(_normalizeLatticeLine(expectedLines[i])),
                reason:
                    'Line ${i + 1} mismatch in $stem ($fmtName):\n'
                    'Expected: ${expectedLines[i]}\n'
                    'Actual:   ${actualLines[i]}',
              );
            } else {
              expect(
                actualLines[i],
                equals(expectedLines[i]),
                reason:
                    'Line ${i + 1} mismatch in $stem ($fmtName):\n'
                    'Expected: ${expectedLines[i]}\n'
                    'Actual:   ${actualLines[i]}',
              );
            }
          }
        });
      }

      test('Multi-script nocache ($fmtName)', () {
        final inputFile = File('test/fixtures/multi-script.txt');
        final goldenFile = File(
          'test/goldens/$fmtName/multi-script.nocache.$fmtName',
        );
        final inputLines = const LineSplitter().convert(
          _readTextFile(inputFile),
        );
        final expectedLines = const LineSplitter().convert(
          goldenFile.readAsStringSync(),
        );

        final actualLines = uNoCache.romanizeLines(inputLines, format: fmtVal);

        expect(actualLines.length, equals(expectedLines.length));
        for (var i = 0; i < expectedLines.length; i++) {
          if (fmtVal == RomFormat.lattice) {
            expect(
              _normalizeLatticeLine(actualLines[i]),
              equals(_normalizeLatticeLine(expectedLines[i])),
              reason:
                  'Line ${i + 1} mismatch in multi-script.nocache ($fmtName):\n'
                  'Expected: ${expectedLines[i]}\n'
                  'Actual:   ${actualLines[i]}',
            );
          } else {
            expect(
              actualLines[i],
              equals(expectedLines[i]),
              reason:
                  'Line ${i + 1} mismatch in multi-script.nocache ($fmtName):\n'
                  'Expected: ${expectedLines[i]}\n'
                  'Actual:   ${actualLines[i]}',
            );
          }
        }
      });

      test('Multi-script cached ($fmtName)', () {
        final inputFile = File('test/fixtures/multi-script.txt');
        final goldenFile = File(
          'test/goldens/$fmtName/multi-script.cached.$fmtName',
        );
        final inputLines = const LineSplitter().convert(
          _readTextFile(inputFile),
        );
        final expectedLines = const LineSplitter().convert(
          goldenFile.readAsStringSync(),
        );

        uCached.resetCache();
        final actualLines = uCached.romanizeLines(inputLines, format: fmtVal);

        expect(actualLines.length, equals(expectedLines.length));
        for (var i = 0; i < expectedLines.length; i++) {
          if (fmtVal == RomFormat.lattice) {
            expect(
              _normalizeLatticeLine(actualLines[i]),
              equals(_normalizeLatticeLine(expectedLines[i])),
              reason:
                  'Line ${i + 1} mismatch in multi-script.cached ($fmtName):\n'
                  'Expected: ${expectedLines[i]}\n'
                  'Actual:   ${actualLines[i]}',
            );
          } else {
            expect(
              actualLines[i],
              equals(expectedLines[i]),
              reason:
                  'Line ${i + 1} mismatch in multi-script.cached ($fmtName):\n'
                  'Expected: ${expectedLines[i]}\n'
                  'Actual:   ${actualLines[i]}',
            );
          }
        }
      });
    });
  }
}

final _edgeRegex = RegExp(
  r'\[(\d+),\s*(\d+),\s*(?:"(?:[^"\\]|\\.)*"),\s*(?:"(?:[^"\\]|\\.)*"|null)\]',
);

String _normalizeLatticeLine(String line) {
  if (!line.startsWith('[[') || !line.endsWith(']]')) return line;
  final matches = _edgeRegex.allMatches(line);
  if (matches.isEmpty) return line;

  final spanEdges = <(int, int), List<String>>{};
  final spanOrder = <(int, int)>[];
  for (final m in matches) {
    final start = int.parse(m.group(1)!);
    final end = int.parse(m.group(2)!);
    final key = (start, end);
    if (!spanEdges.containsKey(key)) {
      spanEdges[key] = [];
      spanOrder.add(key);
    }
    spanEdges[key]!.add(m.group(0)!);
  }

  final buf = StringBuffer('[');
  for (final key in spanOrder) {
    final edges = spanEdges[key]!..sort();
    for (final e in edges) {
      buf.write(e);
    }
  }
  buf.write(']');
  return buf.toString();
}
