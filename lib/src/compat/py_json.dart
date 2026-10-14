/// Encodes JSON strings with Python json.dumps(ensure_ascii=True) compatibility.
String pyJsonString(String s) {
  final buf = StringBuffer('"');
  for (final unit in s.codeUnits) {
    if (unit == 0x22) {
      buf.write(r'\"');
    } else if (unit == 0x5C) {
      buf.write(r'\\');
    } else if (unit == 0x08) {
      buf.write(r'\b');
    } else if (unit == 0x09) {
      buf.write(r'\t');
    } else if (unit == 0x0A) {
      buf.write(r'\n');
    } else if (unit == 0x0C) {
      buf.write(r'\f');
    } else if (unit == 0x0D) {
      buf.write(r'\r');
    } else if (unit >= 0x20 && unit <= 0x7E) {
      buf.writeCharCode(unit);
    } else {
      buf.write(r'\u');
      buf.write(unit.toRadixString(16).padLeft(4, '0'));
    }
  }
  buf.write('"');
  return buf.toString();
}

/// Encodes a single edge as Python `Edge.json()` format:
/// `[start, end, txt, annotation]` with ensure_ascii and space after comma.
String pyJsonEdge(int start, int end, String txt, String? annotation) {
  final annotJson = annotation == null ? 'null' : pyJsonString(annotation);
  return '[$start, $end, ${pyJsonString(txt)}, $annotJson]';
}

/// Encodes a list of edges according to Python's `Edge.json_str` quirk,
/// which wraps edges in outer brackets WITHOUT commas between edges.
String pyJsonEdgeList(Iterable<String> serializedEdges) {
  final buf = StringBuffer('[');
  for (final edge in serializedEdges) {
    buf.write(edge);
  }
  buf.write(']');
  return buf.toString();
}
