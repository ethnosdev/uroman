import 'dart:convert';
import 'dart:io';

import 'package:uroman/uroman.dart';

void main() async {
  final uroman = Uroman();
  print('Running differential verification against Python uroman...');

  // 1. Gather all unique single characters from rules, num_props, and test fixtures
  final charsToTest = <String>{};
  for (final key in uroman.data.romRules.keys) {
    if (key.runes.length == 1) {
      charsToTest.add(key);
    }
  }
  for (final key in uroman.data.numProps.keys) {
    if (key.runes.length == 1) {
      charsToTest.add(key);
    }
  }

  // Also sample code points across blocks (every 100th code point up to 0x30000)
  for (var cp = 0x20; cp <= 0x30000; cp += 100) {
    // Avoid surrogate range
    if (cp >= 0xD800 && cp <= 0xDFFF) continue;
    charsToTest.add(String.fromCharCode(cp));
  }

  print('Total characters to test: ${charsToTest.length}');

  // Batch into lines of 50 characters to run fast through Python
  final charList = charsToTest.toList();
  const batchSize = 100;
  var mismatches = 0;
  var totalTested = 0;

  for (var i = 0; i < charList.length; i += batchSize) {
    final batch = charList.sublist(
      i,
      (i + batchSize).clamp(0, charList.length),
    );
    final pyProcess = await Process.start('uv', [
      'run',
      '--with',
      'regex',
      '--directory',
      'tool/python',
      'python',
      '-c',
      '''
import sys
from pathlib import Path
sys.path.insert(0, '/private/tmp/uroman-py/uroman')
from uroman import Uroman

u = Uroman(Path('../../data').resolve(), cache_size=0)
for line in sys.stdin:
    line = line.rstrip('\\r\\n')
    print(u.romanize_string(line))
''',
    ]);

    for (final char in batch) {
      pyProcess.stdin.writeln(char);
    }
    await pyProcess.stdin.close();

    final pyOutputs = await pyProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();

    for (var j = 0; j < batch.length; j++) {
      totalTested++;
      final char = batch[j];
      final expected = pyOutputs[j];
      final actual = uroman.romanizeString(char);
      if (actual != expected) {
        mismatches++;
        final cp = char.runes.first;
        print(
          'Mismatch on U+${cp.toRadixString(16).toUpperCase()} ($char): actual="$actual", expected="$expected"',
        );
        if (mismatches >= 20) {
          print('Stopping early after $mismatches mismatches.');
          exit(1);
        }
      }
    }
  }

  print('Differential verification complete!');
  print('Total tested: $totalTested, Mismatches: $mismatches');
  if (mismatches == 0) {
    print('ALL CHARACTERS MATCH 100%!');
  }
}
