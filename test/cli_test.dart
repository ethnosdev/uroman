import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final cliCasesFile = File('test/goldens/cli/cli_cases.json');
  if (!cliCasesFile.existsSync()) return;

  final cases =
      jsonDecode(cliCasesFile.readAsStringSync()) as Map<String, dynamic>;

  group('CLI Tests against goldens', () {
    for (final entry in cases.entries) {
      final name = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final args = (data['args'] as List).cast<String>();
      final flags = (data['flags'] as Map).cast<String, dynamic>();
      final expectedStdout = data['stdout'] as String;
      final expectedExitCode = data['exit_code'] as int;

      test(name, () async {
        final cmdArgs = <String>[];
        for (final flagEntry in flags.entries) {
          final flag = flagEntry.key;
          final val = flagEntry.value.toString();
          if (val.isEmpty) {
            cmdArgs.add(flag);
          } else {
            cmdArgs.addAll([flag, val]);
          }
        }
        cmdArgs.addAll(args);

        final result = await Process.run(Platform.executable, [
          'run',
          'bin/uroman.dart',
          ...cmdArgs,
        ]);

        expect(
          result.exitCode,
          equals(expectedExitCode),
          reason: 'Exit code mismatch for $name:\n${result.stderr}',
        );
        expect(
          result.stdout,
          equals(expectedStdout),
          reason: 'Stdout mismatch for $name',
        );
      });
    }

    test('--version displays version', () async {
      final result = await Process.run(Platform.executable, [
        'run',
        'bin/uroman.dart',
        '--version',
      ]);
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('uroman 1.3.1.1'));
    });

    test('--help displays usage', () async {
      final result = await Process.run(Platform.executable, [
        'run',
        'bin/uroman.dart',
        '--help',
      ]);
      expect(result.exitCode, equals(0));
      expect(
        result.stdout,
        contains('Universal Romanizer (uroman) - Dart port'),
      );
      expect(result.stdout, contains('-i, --input_filename'));
    });

    test('invalid option exits with code 1', () async {
      final result = await Process.run(Platform.executable, [
        'run',
        'bin/uroman.dart',
        '--unknown_option_xyz',
      ]);
      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('Could not find an option'));
    });
  });
}
