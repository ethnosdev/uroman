import 'dart:convert';
import 'dart:io';

import 'package:uroman/uroman.dart';

void main() async {
  final uDart = Uroman();

  final cases = [
    ('1. Archaic Georgian Letters', 'ჳ Ⴣ Ჳ ⴣ', null, 'w W W w'),
    ('2. Japanese Small Tsu + Latin', 'っb', null, 'tsub'),
    ('3. Gurmukhi Addak + Latin', '\u0A71k', null, "'k"),
    ('4. Chinese Sentence Boundary', '加拿大。', 'zho', 'jianada.'),
    (
      '5. Japanese Sentence Boundary',
      'ちょっとまってください。',
      'jpn',
      'chottomattekudasai.',
    ),
    ('6. Mid-Line CJK Spacing (no space)', '句子一。句子二。', 'zho', 'juzi1. juzi2.'),
    (
      '7. Mid-Line CJK Spacing (with space)',
      '句子一。 句子二。',
      'zho',
      'juzi1. juzi2.',
    ),
  ];

  print('=' * 80);
  print('COMPARING UPSTREAM PYTHON vs IMPROVED DART');
  print('=' * 80);

  for (final (title, input, lcode, expected) in cases) {
    // Run Dart
    final dartOutput = uDart.romanizeString(input, lcode: lcode);

    // Run Python uroman via uv
    String pyOutput;
    try {
      final pyArgs = [
        'run',
        '--with',
        'regex',
        '/private/tmp/uroman-py/uroman/uroman.py',
      ];
      if (lcode != null) pyArgs.addAll(['-l', lcode]);

      final proc = await Process.start('uv', pyArgs);
      proc.stdin.writeln(input);
      await proc.stdin.close();

      var outStr = await proc.stdout.transform(utf8.decoder).join();
      if (outStr.endsWith('\n')) {
        outStr = outStr.substring(0, outStr.length - 1);
      }
      if (outStr.endsWith('\r')) {
        outStr = outStr.substring(0, outStr.length - 1);
      }
      pyOutput = outStr;
    } catch (e) {
      pyOutput = '(Python unavailable: $e)';
    }

    print('\nCase: $title');
    print('  Input:           "$input"');
    print('  Upstream Python: ${jsonEncode(pyOutput)}');
    print('  Improved Dart:   ${jsonEncode(dartOutput)}');
    print('  Expected:        ${jsonEncode(expected)}');
    if (pyOutput != dartOutput) {
      print('  -> Difference detected! Dart fixed the issue.');
    } else {
      print('  -> Identical.');
    }
  }

  print('\n${'=' * 80}');
}
