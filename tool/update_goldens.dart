import 'dart:convert';
import 'dart:io';

import 'package:uroman/src/data/data_loader.dart';
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
  print('Updating tables.json.gz...');
  final dataDir = Directory('data');
  final dataFiles = <String, String>{};
  for (final entity in dataDir.listSync()) {
    if (entity is File) {
      final filename = entity.uri.pathSegments.last;
      dataFiles[filename] = entity.readAsStringSync();
    }
  }

  final uData = DataLoader.load(dataFiles);
  final canonical = uData.toCanonicalMap();
  final jsonStr = jsonEncode(canonical);
  final gzBytes = gzip.encode(utf8.encode(jsonStr));
  File('test/goldens/tables.json.gz').writeAsBytesSync(gzBytes);
  print('Wrote test/goldens/tables.json.gz (${gzBytes.length} bytes)');

  print('Updating text fixture goldens...');
  final uNoCache = Uroman(cacheSize: 0);
  final uCached = Uroman(cacheSize: 65536);

  final fixturesDir = Directory('test/fixtures/text');
  final textFiles = fixturesDir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final formats = [
    ('str', RomFormat.str),
    ('edges', RomFormat.edges),
    ('alts', RomFormat.alts),
    ('lattice', RomFormat.lattice),
  ];

  for (final (fmtName, fmtVal) in formats) {
    final fmtDir = Directory('test/goldens/$fmtName');
    fmtDir.createSync(recursive: true);

    for (final file in textFiles) {
      final filename = file.uri.pathSegments.last;
      if (!filename.endsWith('.txt')) continue;
      final stem = filename.substring(0, filename.length - 4);
      final outFile = File('test/goldens/$fmtName/$stem.$fmtName');

      final inputLines = const LineSplitter().convert(_readTextFile(file));
      final actualLines = uNoCache.romanizeLines(
        inputLines,
        lcode: stem,
        format: fmtVal,
      );

      outFile.writeAsStringSync('${actualLines.join('\n')}\n');
    }

    // Multi-script
    final multiFile = File('test/fixtures/multi-script.txt');
    final multiLines = const LineSplitter().convert(_readTextFile(multiFile));

    final nocacheOut = File('test/goldens/$fmtName/multi-script.nocache.$fmtName');
    final nocacheLines = uNoCache.romanizeLines(multiLines, format: fmtVal);
    nocacheOut.writeAsStringSync('${nocacheLines.join('\n')}\n');

    final cachedOut = File('test/goldens/$fmtName/multi-script.cached.$fmtName');
    uCached.resetCache();
    final cachedLines = uCached.romanizeLines(multiLines, format: fmtVal);
    cachedOut.writeAsStringSync('${cachedLines.join('\n')}\n');
  }

  print('All goldens successfully updated.');
}
