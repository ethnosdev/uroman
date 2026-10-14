/// Output format of romanization.
enum RomFormat {
  /// Simple string output (e.g. 'Tokyo').
  str('str'),

  /// List of edges including character offsets in original string.
  edges('edges'),

  /// Lattice including alternative edges for ambiguous romanizations.
  alts('alts'),

  /// Full lattice including alternative and superseded edges.
  lattice('lattice');

  final String value;
  const RomFormat(this.value);

  static RomFormat fromString(String val) {
    for (final fmt in RomFormat.values) {
      if (fmt.value == val) return fmt;
    }
    throw ArgumentError.value(val, 'val', 'Unknown romanization format');
  }

  @override
  String toString() => value;
}
