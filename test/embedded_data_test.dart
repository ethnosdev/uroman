import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:uroman/uroman_io.dart';

void main() {
  test('Embedded data produces identical canonical map to disk files', () {
    final embeddedWatch = Stopwatch()..start();
    final embeddedUroman = Uroman();
    embeddedWatch.stop();
    print(
      'Embedded Uroman initialized in ${embeddedWatch.elapsedMilliseconds} ms',
    );

    final diskWatch = Stopwatch()..start();
    final diskUroman = UromanIo.fromDataDir(Directory('data'));
    diskWatch.stop();
    print('Disk Uroman initialized in ${diskWatch.elapsedMilliseconds} ms');

    final embeddedMap = embeddedUroman.data.toCanonicalMap();
    final diskMap = diskUroman.data.toCanonicalMap();

    // Verify exact equality of canonical maps
    expect(jsonEncode(embeddedMap), equals(jsonEncode(diskMap)));
  });
}
