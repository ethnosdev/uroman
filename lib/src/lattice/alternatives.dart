import '../models/edge.dart';
import 'candidate_selector.dart';
import 'lattice.dart';

/// Manages alternative romanization edges (rom-alt, rom-alt2, rom-alt3).
class Alternatives {
  static void addAlternatives(Lattice lat, List<Edge> oldEdges) {
    final oldEdgeDict = <String, Edge>{};
    for (final edge in oldEdges) {
      oldEdgeDict['${edge.start}:${edge.end}:${edge.txt}'] = edge;
    }

    // We iterate by index, noting that oldEdges can grow during insertion
    for (var position = 0; position < oldEdges.length; position++) {
      final oldEdge = oldEdges[position];
      final type = oldEdge.type ?? '';
      if (type.startsWith('rom-alt')) continue;

      final start = oldEdge.start;
      final end = oldEdge.end;
      final origS = lat.substring(start, end);
      final oldRom = oldEdge.txt;

      String? oldRomCore;
      String? oldRomSuffix;
      final m = RegExp(r'\bc:([a-z]+)\s+s:([a-z]+)\b').firstMatch(type);
      if (m != null) {
        oldRomCore = m.group(1);
        oldRomSuffix = m.group(2);
      }

      final rules = lat.uroman.romRules[origS];
      if (rules != null) {
        for (final rule in rules) {
          final romT = rule.t;
          if (romT != null &&
              CandidateSelector.candIsValid(lat, rule, start, end, romT)) {
            final romAlts = rule.tAlts;
            final romEndOfSyllable = rule.tAtEndOfSyllable;

            if ((romT == oldRom || romT == oldRomCore) && romAlts.isNotEmpty) {
              for (var romAlt in romAlts) {
                if (oldRomSuffix != null && romT == oldRomCore) {
                  romAlt += oldRomSuffix;
                }
                _addNewEdge(
                  lat,
                  oldEdges,
                  start,
                  end,
                  romAlt,
                  'rom-alt',
                  position,
                  oldEdgeDict,
                );
              }
            }

            if (romT == oldRom && romEndOfSyllable != null) {
              _addNewEdge(
                lat,
                oldEdges,
                start,
                end,
                romT,
                'rom-alt2',
                position,
                oldEdgeDict,
              );
            }

            if (romEndOfSyllable == oldRom) {
              _addNewEdge(
                lat,
                oldEdges,
                start,
                end,
                romT,
                'rom-alt3',
                position,
                oldEdgeDict,
              );
            }
          }
        }
      }
    }
  }

  static void _addNewEdge(
    Lattice lat,
    List<Edge> oldEdges,
    int start,
    int end,
    String newRom,
    String newType,
    int? position,
    Map<String, Edge> oldEdgeDict,
  ) {
    final key = '$start:$end:$newRom';
    if (!oldEdgeDict.containsKey(key)) {
      final newEdge = lat.createEdge(start, end, newRom, newType);
      if (position == null) {
        oldEdges.add(newEdge);
      } else {
        oldEdges.insert(position + 1, newEdge);
      }
      oldEdgeDict[key] = newEdge;
    }
  }
}
