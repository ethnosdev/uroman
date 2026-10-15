import 'compat/py_json.dart';
import 'compat/py_string.dart';
import 'data/data_loader.dart';
import 'data/embedded_data.g.dart';
import 'data/uroman_data.dart';
import 'lattice/lattice.dart';
import 'lattice/lattice_engine.dart';
import 'models/edge.dart';
import 'models/rom_format.dart';

/// Universal Romanizer engine.
class Uroman {
  /// The loaded linguistic and romanization tables.
  final UromanData data;

  /// Cache size for token romanization. If 0, token caching is disabled.
  final int cacheSize;

  final Map<String, dynamic> _romCache = {};
  int _romCacheSize = 0;

  static UromanData? _defaultData;

  /// Gets or lazily initializes the default shared [UromanData] from embedded resources.
  ///
  /// Initialization occurs once per isolate.
  static UromanData get defaultData =>
      _defaultData ??= DataLoader.load(embeddedResourceFiles);

  /// Clears the shared default data cache (useful for testing memory or benchmarks).
  static void clearDefaultData() {
    _defaultData = null;
  }

  /// Creates a [Uroman] instance.
  ///
  /// If [data] is omitted, the shared embedded [defaultData] is used lazily.
  Uroman({UromanData? data, this.cacheSize = 0}) : data = data ?? defaultData;

  /// Resets the internal token cache.
  void resetCache() {
    _romCache.clear();
    _romCacheSize = 0;
  }

  /// Romanizes an input string [s].
  ///
  /// [lcode] is an optional ISO 639-3 language code (e.g. `'fas'`, `'rus'`).
  /// [format] controls the output format:
  /// - [RomFormat.str]: returns the romanized string.
  /// - [RomFormat.edges]: returns the chosen lattice edges with offsets.
  /// - [RomFormat.alts]: returns chosen edges plus alternative edges.
  /// - [RomFormat.lattice]: returns full lattice of edges.
  /// [decodeUnicode] decodes escapes like `\u03C0` when enabled.
  dynamic romanizeString(
    String s, {
    String? lcode,
    RomFormat format = RomFormat.str,
    bool decodeUnicode = false,
  }) {
    if (decodeUnicode) {
      s = PyString.decodeUnicodeEscapes(s);
    }

    if (cacheSize > 0) {
      var rest = s;
      var offset = 0;
      var utf16Offset = 0;
      final resultStr = StringBuffer();
      final resultEdges = <Edge>[];
      final delimRegex = RegExp(r'^(.*?)([.,; ]*[ 。་][.,; ]*)(.*)$');

      while (true) {
        final m = delimRegex.firstMatch(rest);
        if (m == null) break;
        final pre = m.group(1)!;
        final delimiter = m.group(2)!;
        rest = m.group(3)!;

        final resPre = _romanizeStringCore(
          pre,
          lcode,
          format,
          offset,
          utf16Offset,
          isAtStringEnd: false,
        );
        if (format == RomFormat.str) {
          resultStr.write(resPre as String);
        } else {
          resultEdges.addAll(resPre as List<Edge>);
        }
        offset += PyString.toCodePoints(pre).length;
        utf16Offset += pre.length;

        final resDelim = _romanizeStringCore(
          delimiter,
          lcode,
          format,
          offset,
          utf16Offset,
          isAtStringEnd: rest.isEmpty,
        );
        if (format == RomFormat.str) {
          resultStr.write(resDelim as String);
        } else {
          resultEdges.addAll(resDelim as List<Edge>);
        }
        offset += PyString.toCodePoints(delimiter).length;
        utf16Offset += delimiter.length;
      }

      final resRest = _romanizeStringCore(
        rest,
        lcode,
        format,
        offset,
        utf16Offset,
        isAtStringEnd: true,
      );
      if (format == RomFormat.str) {
        resultStr.write(resRest as String);
        return resultStr.toString();
      } else {
        resultEdges.addAll(resRest as List<Edge>);
        return resultEdges;
      }
    } else {
      return _romanizeStringCore(s, lcode, format, 0, 0);
    }
  }

  dynamic _romanizeStringCore(
    String s,
    String? lcode,
    RomFormat format,
    int offset,
    int utf16Offset, {
    bool isAtStringEnd = true,
  }) {
    if (cacheSize > 0) {
      final cacheKey = '$s:$lcode:$format:$isAtStringEnd';
      final cached = _romCache[cacheKey];
      if (cached != null) {
        return _applyOffset(cached, offset, utf16Offset);
      }
    }

    final lat = Lattice(
      originalString: s,
      uroman: data,
      lcode: lcode,
      isAtStringEnd: isAtStringEnd,
    );
    final result = LatticeEngine.romanizeCore(lat, format: format);

    if (cacheSize > 0 && _romCacheSize < cacheSize) {
      final cacheKey = '$s:$lcode:$format:$isAtStringEnd';
      _romCache[cacheKey] = result;
      _romCacheSize++;
    }

    return _applyOffset(result, offset, utf16Offset);
  }

  static dynamic _applyOffset(dynamic res, int offset, int utf16Offset) {
    if (res is String || (offset == 0 && utf16Offset == 0)) {
      return res;
    }
    final edges = res as List<Edge>;
    return [
      for (final edge in edges)
        Edge(
          edge.start + offset,
          edge.end + offset,
          edge.txt,
          edge.type,
          edge.utf16Start + utf16Offset,
          edge.utf16End + utf16Offset,
        ),
    ];
  }

  /// Formats the result of [romanizeString] into a string.
  ///
  /// For [RomFormat.str], returns the string directly.
  /// For edge formats, returns Python's exact `Edge.json_str` format.
  static String formatResult(dynamic res) {
    if (res is String) return res;
    if (res is List<Edge>) {
      return pyJsonEdgeList(res.map((e) => e.toPythonJson()));
    }
    return res.toString();
  }

  /// Romanizes a list of text lines, preserving `::lcode` metadata.
  List<String> romanizeLines(
    List<String> lines, {
    String? lcode,
    RomFormat format = RomFormat.str,
    bool decodeUnicode = false,
  }) {
    final lcodeRegex = RegExp(r'^(::lcode[ \t]+)([a-z]{3})([ \t]+)(.*)$');
    final outLines = <String>[];
    for (final line in lines) {
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
        final res = romanizeString(
          snt,
          lcode: effectiveLcode,
          format: format,
          decodeUnicode: decodeUnicode,
        );
        if (format == RomFormat.str) {
          outLines.add('$lcodeKw$lcode2$space$res');
        } else {
          final lcodeMeta = '[0, 0, "", "lcode: $lcode2"]';
          final edges = res as List<Edge>;
          final allSerialized = [
            lcodeMeta,
            ...edges.map((e) => e.toPythonJson()),
          ];
          outLines.add(pyJsonEdgeList(allSerialized));
        }
      } else {
        final res = romanizeString(
          cleanLine,
          lcode: lcode,
          format: format,
          decodeUnicode: decodeUnicode,
        );
        outLines.add(formatResult(res));
      }
    }
    return outLines;
  }
}
