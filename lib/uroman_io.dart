/// Universal Romanizer I/O extensions and filesystem support.
///
/// Use this library on Dart standalone platforms (command-line, server)
/// where `dart:io` is available.
library;

import 'dart:convert';
import 'dart:io';

import 'src/compat/py_json.dart';
import 'src/data/data_loader.dart';
import 'src/models/edge.dart';
import 'src/models/rom_format.dart';
import 'src/uroman_base.dart';

export 'uroman.dart';

/// I/O utilities for loading and running uroman with `dart:io`.
class UromanIo {
  /// Loads uroman data from a filesystem directory containing the resource files.
  static Uroman fromDataDir(Directory dataDir, {int cacheSize = 0}) {
    if (!dataDir.existsSync()) {
      throw ArgumentError('Directory does not exist: ${dataDir.path}');
    }
    final files = <String, String>{};
    for (final entity in dataDir.listSync()) {
      if (entity is File) {
        final filename = entity.uri.pathSegments.last;
        files[filename] = entity.readAsStringSync();
      }
    }
    final data = DataLoader.load(files);
    return Uroman(data: data, cacheSize: cacheSize);
  }

  /// Loads uroman data from a directory path.
  static Uroman fromDataDirPath(String path, {int cacheSize = 0}) =>
      fromDataDir(Directory(path), cacheSize: cacheSize);
}

/// Extension on [Uroman] providing file-based operations.
extension UromanIoOperations on Uroman {
  /// Romanizes text from an input file or stream to an output file or stream.
  void romanizeFile({
    String? inputFilename,
    String? outputFilename,
    List<String>? directInput,
    String? lcode,
    RomFormat format = RomFormat.str,
    int? maxLines,
    bool silent = false,
    bool decodeUnicode = false,
  }) {
    IOSink? fileOut;
    final out = outputFilename != null
        ? (fileOut = File(outputFilename).openWrite())
        : stdout;

    try {
      final lcodeRegex = RegExp(r'^(::lcode[ \t]+)([a-z]{3})([ \t]+)(.*)$');
      var lineCount = 0;
      var nonUtf8CharsCount = 0;
      var errorMessagesOutput = 0;
      var progressDotsOutput = false;

      void processLine(String line) {
        lineCount++;
        final cleanLine = line.endsWith('\r')
            ? line.substring(0, line.length - 1)
            : line;

        final m = lcodeRegex.firstMatch(cleanLine);
        if (m != null) {
          final lcodeKw = m.group(1)!;
          final lcode2 = m.group(2)!;
          final space = m.group(3)!;
          final snt = m.group(4)!;
          final effectiveLcode = lcode2.isNotEmpty ? lcode2 : lcode;

          final romRes = romanizeString(
            snt,
            lcode: effectiveLcode,
            format: format,
            decodeUnicode: decodeUnicode,
          );

          if (format == RomFormat.str) {
            out.writeln('$lcodeKw$lcode2$space$romRes');
          } else {
            final lcodeMeta = '[0, 0, "", "lcode: $lcode2"]';
            final edges = romRes as List<Edge>;
            final allSerialized = [
              lcodeMeta,
              ...edges.map((e) => e.toPythonJson()),
            ];
            out.writeln(pyJsonEdgeList(allSerialized));
          }
        } else {
          final romRes = romanizeString(
            cleanLine,
            lcode: lcode,
            format: format,
            decodeUnicode: decodeUnicode,
          );
          out.writeln(Uroman.formatResult(romRes));
        }

        if (!silent) {
          if (lineCount % 100 == 0) {
            if (lineCount % 1000 == 0) {
              stderr.write(lineCount.toString());
            } else {
              stderr.write('.');
            }
            progressDotsOutput = true;
          }
        }
      }

      if (directInput != null) {
        for (final line in directInput) {
          processLine(line);
          if (maxLines != null && lineCount >= maxLines) break;
        }
      } else if (inputFilename != null) {
        final inputFile = File(inputFilename);
        if (!inputFile.existsSync()) {
          stderr.writeln(
            'Error in romanize_file: Cannot open file $inputFilename',
          );
          return;
        }

        // Read bytes and decode with replacement character to match surrogateescape/errors handling
        final bytes = inputFile.readAsBytesSync();
        final decoded = const Utf8Decoder(allowMalformed: true).convert(bytes);
        final lines = const LineSplitter().convert(decoded);

        for (final line in lines) {
          if (line.contains('\uFFFD')) {
            final replCount = '\uFFFD'.allMatches(line).length;
            nonUtf8CharsCount += replCount;
            if (errorMessagesOutput < 10) {
              final ending = replCount == 1 ? '' : 's';
              stderr.writeln(
                'Detected encoding error: file $inputFilename line ${lineCount + 1} '
                'contains $replCount non-UTF-8 character$ending '
                '(replaced by \uFFFD): $line',
              );
              errorMessagesOutput++;
            } else if (errorMessagesOutput == 10) {
              stderr.writeln('Too many errors. No further errors reported.');
              errorMessagesOutput++;
            }
          }

          processLine(line);
          if (maxLines != null && lineCount >= maxLines) break;
        }

        if (nonUtf8CharsCount > 0) {
          stderr.writeln(
            'Total number of non-UTF-8 characters in $inputFilename: $nonUtf8CharsCount',
          );
        }
      } else {
        // Read lines from stdin
        String? line;
        while ((line = stdin.readLineSync(encoding: utf8)) != null) {
          processLine(line!);
          if (maxLines != null && lineCount >= maxLines) break;
        }
      }

      if (progressDotsOutput) {
        stderr.writeln();
      }
    } finally {
      if (fileOut != null) {
        fileOut.close();
      }
    }
  }
}
