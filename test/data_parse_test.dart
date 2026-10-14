import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:uroman/src/data/data_loader.dart';

void main() {
  test('DataLoader produces tables identical to tables.json.gz', () {
    final dataDir = Directory('data');
    final files = <String, String>{};
    for (final entity in dataDir.listSync()) {
      if (entity is File) {
        final filename = entity.uri.pathSegments.last;
        files[filename] = entity.readAsStringSync();
      }
    }

    final stopwatch = Stopwatch()..start();
    final uData = DataLoader.load(files);
    stopwatch.stop();
    print('DataLoader loaded ${files.length} files in ${stopwatch.elapsedMilliseconds} ms');

    final canonical = uData.toCanonicalMap();

    // Read and decompress tables.json.gz
    final gzBytes = File('test/goldens/tables.json.gz').readAsBytesSync();
    final jsonStr = utf8.decode(gzip.decode(gzBytes));
    final expected = jsonDecode(jsonStr) as Map<String, dynamic>;

    expect(canonical['dict_int'], equals(expected['dict_int']), reason: 'dict_int mismatch');
    expect(canonical['dict_set'], equals(expected['dict_set']), reason: 'dict_set mismatch');
    expect(canonical['fraction_connectors'], equals(expected['fraction_connectors']), reason: 'fraction_connectors mismatch');
    expect(canonical['minus_signs'], equals(expected['minus_signs']), reason: 'minus_signs mismatch');
    expect(canonical['plus_signs'], equals(expected['plus_signs']), reason: 'plus_signs mismatch');

    // Check dict_bool keys and values
    final actualBool = canonical['dict_bool'] as Map<String, dynamic>;
    final expectedBool = expected['dict_bool'] as Map<String, dynamic>;
    expect(actualBool.keys.toSet(), equals(expectedBool.keys.toSet()), reason: 'dict_bool keys mismatch');
    for (final k in expectedBool.keys) {
      expect(
        (actualBool[k] as List).toSet(),
        equals((expectedBool[k] as List).toSet()),
        reason: 'dict_bool[$k] set mismatch',
      );
    }

    // Check scripts
    final actualScripts = canonical['scripts'] as Map<String, dynamic>;
    final expectedScripts = expected['scripts'] as Map<String, dynamic>;
    expect(actualScripts.keys.toSet(), equals(expectedScripts.keys.toSet()), reason: 'scripts keys mismatch');
    for (final k in expectedScripts.keys) {
      expect(actualScripts[k], equals(expectedScripts[k]), reason: 'scripts[$k] mismatch');
    }

    // Check num_props
    final actualNumProps = canonical['num_props'] as Map<String, dynamic>;
    final expectedNumProps = expected['num_props'] as Map<String, dynamic>;
    expect(actualNumProps.keys.toSet(), equals(expectedNumProps.keys.toSet()), reason: 'num_props keys mismatch');
    for (final k in expectedNumProps.keys) {
      expect(actualNumProps[k], equals(expectedNumProps[k]), reason: 'num_props[$k] mismatch');
    }

    // Check dict_str
    final actualStr = canonical['dict_str'] as Map<String, dynamic>;
    final expectedStr = expected['dict_str'] as Map<String, dynamic>;
    expect(actualStr.keys.toSet(), equals(expectedStr.keys.toSet()), reason: 'dict_str keys mismatch');
    for (final k in expectedStr.keys) {
      final actualMap = actualStr[k] as Map<String, dynamic>;
      final expectedMap = expectedStr[k] as Map<String, dynamic>;
      expect(actualMap.length, equals(expectedMap.length), reason: 'dict_str[$k] length mismatch');
      for (final entry in expectedMap.entries) {
        expect(actualMap[entry.key], equals(entry.value), reason: 'dict_str[$k][${entry.key}] mismatch');
      }
    }

    // Check rom_rules
    final actualRules = canonical['rom_rules'] as Map<String, dynamic>;
    final expectedRules = expected['rom_rules'] as Map<String, dynamic>;
    expect(actualRules.keys.toSet(), equals(expectedRules.keys.toSet()), reason: 'rom_rules keys mismatch');
    for (final k in expectedRules.keys) {
      expect(actualRules[k], equals(expectedRules[k]), reason: 'rom_rules[$k] mismatch');
    }
  });
}
