import '../compat/py_string.dart';
import '../data/uroman_data.dart';
import '../models/edge.dart';

/// Core lattice data structure representing all candidate romanization edges.
class Lattice {
  /// The input string as individual code points.
  final List<int> codePoints;

  /// Original string.
  final String originalString;

  /// Native UTF-16 code unit offsets corresponding to each code point index.
  /// Length is `codePoints.length + 1`.
  final List<int> utf16Offsets;

  /// The shared uroman data tables.
  final UromanData uroman;

  /// Optional ISO 639-3 language code.
  final String? lcode;

  /// Number of code points (max vertex index).
  final int maxVertex;

  /// Map from span `(start << 32) | end` to list of edges in insertion order.
  final Map<int, List<Edge>> _spanEdges = {};

  /// Set of right vertices (ends) for each start vertex.
  final Map<int, Set<int>> _rightEdges = {};

  /// Set of left vertices (starts) for each end vertex.
  final Map<int, Set<int>> _leftEdges = {};

  /// Cached simple top romanization results for spans.
  final Map<int, String?> simpleTopRomCache = {};

  /// General properties/flags cache for positions (e.g. `is-upper`, `preceded_by_alpha`).
  final Map<String, dynamic> props = {};

  /// Tracks which scripts are present in the input string.
  final Set<String> containsScript = {};

  /// Whether the string represented by this lattice ends at the end of the input stream.
  final bool isAtStringEnd;

  Lattice({
    required this.originalString,
    required this.uroman,
    this.lcode,
    this.isAtStringEnd = true,
  }) : codePoints = PyString.toCodePoints(originalString),
       utf16Offsets = _computeUtf16Offsets(originalString),
       maxVertex = PyString.toCodePoints(originalString).length {
    _checkForScripts();
  }

  static List<int> _computeUtf16Offsets(String s) {
    final offsets = <int>[];
    var currentUtf16 = 0;
    for (final rune in s.runes) {
      offsets.add(currentUtf16);
      currentUtf16 += rune > 0xFFFF ? 2 : 1;
    }
    offsets.add(currentUtf16);
    return offsets;
  }

  void _checkForScripts() {
    var hasBraille = false;
    for (final cp in codePoints) {
      if (cp >= 0x2800 && cp <= 0x28FF) {
        hasBraille = true;
      }
      final charStr = String.fromCharCode(cp);
      final scriptName = uroman.charToScript[charStr];
      if (scriptName != null && scriptName.isNotEmpty) {
        containsScript.add(scriptName);
      }
    }
    if (hasBraille) {
      containsScript.add('Braille');
    }
  }

  /// Adds an edge to the lattice and updates connectivity indices.
  void addEdge(Edge edge) {
    final key = _spanKey(edge.start, edge.end);
    (_spanEdges[key] ??= []).add(edge);
    (_rightEdges[edge.start] ??= {}).add(edge.end);
    (_leftEdges[edge.end] ??= {}).add(edge.start);
  }

  /// Gets all edges registered for a specific `(start, end)` span.
  List<Edge> edgesInSpan(int start, int end) =>
      _spanEdges[_spanKey(start, end)] ?? const [];

  /// Checks if any edges exist for `(start, end)`.
  bool hasEdgesInSpan(int start, int end) =>
      _spanEdges.containsKey(_spanKey(start, end));

  /// Gets all right neighbor ends for a start position, sorted descending.
  List<int> sortedRightEnds(int start) {
    final ends = _rightEdges[start];
    if (ends == null || ends.isEmpty) return const [];
    final list = ends.toList(growable: false);
    list.sort((a, b) => b.compareTo(a)); // Descending
    return list;
  }

  /// Gets all left neighbor starts for an end position, sorted ascending.
  List<int> sortedLeftStarts(int end) {
    final starts = _leftEdges[end];
    if (starts == null || starts.isEmpty) return const [];
    final list = starts.toList(growable: false);
    list.sort(); // Ascending
    return list;
  }

  /// Finds the best edge in span `[start, end]`.
  Edge? bestEdgeInSpan(int start, int end, {bool skipNumEdge = false}) {
    final edges = edgesInSpan(start, end);
    if (edges.isEmpty) return null;

    Edge? romEdge;
    Edge? decompEdge;
    Edge? otherEdge;

    for (final edge in edges) {
      if (edge is NumEdge) {
        if (skipNumEdge) continue;
        if (edge.active) return edge;
      }
      final type = edge.type ?? '';
      if (type.startsWith('rom decomp')) {
        decompEdge ??= edge;
      } else if (type.startsWith('rom') || type.startsWith('num')) {
        romEdge ??= edge;
      } else {
        otherEdge ??= edge;
      }
    }
    return romEdge ?? decompEdge ?? otherEdge;
  }

  /// Finds the best right neighbor edge starting at [start] (longest span first).
  Edge? bestRightNeighborEdge(int start, {bool skipNumEdge = false}) {
    for (final end in sortedRightEnds(start)) {
      final edge = bestEdgeInSpan(start, end, skipNumEdge: skipNumEdge);
      if (edge != null) return edge;
    }
    return null;
  }

  /// Finds the best left neighbor edge ending at [end] (longest span backwards first).
  Edge? bestLeftNeighborEdge(int end, {bool skipNumEdge = false}) {
    for (final start in sortedLeftStarts(end)) {
      final edge = bestEdgeInSpan(start, end, skipNumEdge: skipNumEdge);
      if (edge != null) return edge;
    }
    return null;
  }

  /// Finds the best romanization edge path from [start] to [end].
  List<Edge> bestRomEdgePath(int start, int end, {bool skipNumEdge = false}) {
    final result = <Edge>[];
    var current = start;
    while (current < end) {
      final bestEdge = bestRightNeighborEdge(current, skipNumEdge: skipNumEdge);
      if (bestEdge != null) {
        result.add(bestEdge);
        current = bestEdge.end;
      } else {
        // Fallback progress: single step
        current++;
      }
    }
    return result;
  }

  /// Finds a partial best path on the left from [end] backwards towards [start].
  List<Edge> findRomEdgePathBackwards(
    int start,
    int end, {
    int? minChar,
    bool skipNumEdge = false,
  }) {
    final resultEdges = <Edge>[];
    var romLen = 0;
    var currentEnd = end;
    while (start < currentEnd) {
      final newEdge = bestLeftNeighborEdge(
        currentEnd,
        skipNumEdge: skipNumEdge,
      );
      if (newEdge != null) {
        resultEdges.insert(0, newEdge);
        romLen += newEdge.txt.length;
        currentEnd = newEdge.start;
      } else {
        currentEnd--;
      }
      if (minChar != null && romLen >= minChar) break;
    }
    return resultEdges;
  }

  /// Gets backwards romanized string for left context.
  String findRomEdgePathBackwardsStr(
    int start,
    int end, {
    int? minChar,
    bool skipNumEdge = false,
  }) {
    final edges = findRomEdgePathBackwards(
      start,
      end,
      minChar: minChar,
      skipNumEdge: skipNumEdge,
    );
    return edgePathToSurf(edges);
  }

  /// Returns all edges across spans within `[start, end]`.
  List<Edge> allEdges(int start, int end) {
    final result = <Edge>[];
    for (var s = start; s < end; s++) {
      for (final e in sortedRightEnds(s)) {
        if (e <= end) {
          result.addAll(edgesInSpan(s, e));
        }
      }
    }
    return result;
  }

  /// Concatenates edge text along a path to produce the romanized surface string.
  static String edgePathToSurf(List<Edge> edges) {
    final buf = StringBuffer();
    for (final edge in edges) {
      buf.write(edge.txt);
    }
    return buf.toString();
  }

  /// Substring of input from code point [start] to [end].
  String substring(int start, int end) {
    if (start < 0) start = 0;
    if (end > maxVertex) end = maxVertex;
    if (start >= end) return '';
    return String.fromCharCodes(codePoints.sublist(start, end));
  }

  /// Code point at index [index].
  int charCodeAt(int index) => codePoints[index];

  /// Character string at code point [index].
  String charAt(int index) => String.fromCharCode(codePoints[index]);

  /// Creates a new [Edge] with both code-point and native UTF-16 offsets.
  Edge createEdge(int start, int end, String txt, [String? type]) {
    final u16Start = start < utf16Offsets.length ? utf16Offsets[start] : 0;
    final u16End = end < utf16Offsets.length ? utf16Offsets[end] : u16Start;
    return Edge(start, end, txt, type, u16Start, u16End);
  }

  /// Creates a new [NumEdge] with both code-point and native UTF-16 offsets.
  NumEdge createNumEdge(int start, int end, String s, {bool active = false}) {
    final u16Start = start < utf16Offsets.length ? utf16Offsets[start] : 0;
    final u16End = end < utf16Offsets.length ? utf16Offsets[end] : u16Start;
    return NumEdge(
      start,
      end,
      s,
      active: active,
      utf16Start: u16Start,
      utf16End: u16End,
    );
  }

  static int _spanKey(int start, int end) => (start << 32) | (end & 0xFFFFFFFF);
}
