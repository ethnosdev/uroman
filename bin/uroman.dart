import 'dart:io';

import 'package:args/args.dart';
import 'package:uroman/uroman_io.dart';

const String version = '1.3.1.1';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'data_dir',
      help: 'uroman resource directory (defaults to embedded data bundle)',
    )
    ..addOption(
      'input_filename',
      abbr: 'i',
      help: 'Input file (default: stdin)',
    )
    ..addOption(
      'output_filename',
      abbr: 'o',
      help: 'Output file (default: stdout)',
    )
    ..addOption('lcode', abbr: 'l', help: 'ISO 639-3 language code, e.g. eng')
    ..addOption(
      'rom_format',
      abbr: 'f',
      defaultsTo: 'str',
      allowed: ['str', 'edges', 'alts', 'lattice'],
      help: "Output format of romanization ('str', 'edges', 'alts', 'lattice')",
    )
    ..addOption(
      'cache_size',
      abbr: 'c',
      defaultsTo: '65536',
      help: 'Token cache size (0 to disable)',
    )
    ..addOption('max_lines', help: 'Limit uroman to first n lines')
    ..addFlag(
      'decode_unicode',
      abbr: 'd',
      negatable: false,
      help: r'Decodes Unicode escape notation, e.g. \u03B4 to δ',
    )
    ..addFlag('silent', negatable: false, help: 'Suppress progress dots')
    ..addFlag(
      'version',
      negatable: false,
      help: 'Print uroman version and exit',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this help message',
    );

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (results.flag('help')) {
    stdout.writeln('Universal Romanizer (uroman) - Dart port');
    stdout.writeln(parser.usage);
    return;
  }

  if (results.flag('version')) {
    stdout.writeln('uroman $version');
    return;
  }

  final dataDirPath = results.option('data_dir');
  final cacheSize = int.tryParse(results.option('cache_size') ?? '') ?? 65536;
  final maxLines = results.option('max_lines') != null
      ? int.tryParse(results.option('max_lines')!)
      : null;
  final lcode = results.option('lcode');
  final formatStr = results.option('rom_format') ?? 'str';
  final format = RomFormat.values.byName(formatStr);
  final decodeUnicode = results.flag('decode_unicode');
  final silent = results.flag('silent');
  final inputFilename = results.option('input_filename');
  final outputFilename = results.option('output_filename');
  final directInput = results.rest;

  final uroman = dataDirPath != null
      ? UromanIo.fromDataDirPath(dataDirPath, cacheSize: cacheSize)
      : Uroman(cacheSize: cacheSize);

  final romanizeFileP =
      inputFilename != null || outputFilename != null || directInput.isEmpty;

  // Process positional / direct input arguments
  for (final s in directInput) {
    final clean = s.endsWith('\n') ? s.substring(0, s.length - 1) : s;
    final res = uroman.romanizeString(
      clean,
      lcode: lcode,
      format: format,
      decodeUnicode: decodeUnicode,
    );
    final resultFormatted = Uroman.formatResult(res);
    if (romanizeFileP) {
      if (inputFilename != null) {
        stderr.writeln(resultFormatted);
      }
    } else {
      stdout.writeln(resultFormatted);
    }
  }

  // Process input file or stdin
  if (romanizeFileP) {
    uroman.romanizeFile(
      inputFilename: inputFilename,
      outputFilename: outputFilename,
      lcode: lcode,
      format: format,
      maxLines: maxLines,
      silent: silent,
      decodeUnicode: decodeUnicode,
    );
  }
}
