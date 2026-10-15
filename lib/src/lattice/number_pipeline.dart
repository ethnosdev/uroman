import '../compat/rational.dart';
import '../models/edge.dart';
import '../unicode/unicode_props.dart';
import 'lattice.dart';

/// Implements number combination heuristics matching Python uroman (D1, G1-G6, F1).
class NumberPipeline {
  /// Runs the full numerical romanization pipeline on the lattice.
  static void addNumbers(Lattice lat) {
    var numEdges = <NumEdge>[];

    // 0. Initialize initial NumEdges from num_props
    for (var start = 0; start < lat.maxVertex; start++) {
      final charStr = lat.charAt(start);
      final prop = lat.uroman.numProps[charStr];
      if (prop != null) {
        final edge = lat.createNumEdge(
          start,
          start + 1,
          charStr,
          active: false,
        );
        edge.value = prop.value;
        if (prop.fraction != null && prop.fraction!.length >= 2) {
          edge.fraction = Rational(prop.fraction![0], prop.fraction![1]);
        }
        edge.numBase = prop.base;
        edge.baseMultiplier = prop.mult;
        edge.type = prop.type;
        edge.script = prop.script;
        edge.isLargePower = prop.isLargePower ?? false;
        edge.active = true;
        edge.update();
        numEdges.add(edge);
        lat.addEdge(edge);
      }
    }

    // D1 sequence of digits: 1234, 12.34
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      if (_edgeIsDigit(edge) && edge.active) {
        var nDecimalPoints = 0;
        int? nDecimals;
        var newValueS = edge.value.toString();
        final subEdges = <Edge>[edge];
        var prevEdge = edge;

        while (true) {
          final rightEdge = lat.bestRightNeighborEdge(prevEdge.end);
          if (_edgeIsDigit(rightEdge)) {
            final rightNumEdge = rightEdge as NumEdge;
            subEdges.add(rightNumEdge);
            newValueS += rightNumEdge.value.toString();
            if (nDecimals != null) nDecimals++;
            prevEdge = rightNumEdge;
          } else if (prevEdge.end < lat.maxVertex &&
              lat.codePoints[prevEdge.end] == 0x2E && // '.'
              nDecimalPoints == 0) {
            final rightEdge2 = lat.bestRightNeighborEdge(prevEdge.end + 1);
            if (_edgeIsDigit(rightEdge2)) {
              final dotEdge = lat.createEdge(
                prevEdge.end,
                prevEdge.end + 1,
                '.',
                'decimal period',
              );
              lat.addEdge(dotEdge);
              subEdges.add(dotEdge);
              final rightNumEdge2 = rightEdge2 as NumEdge;
              subEdges.add(rightNumEdge2);
              newValueS += '.${rightNumEdge2.value}';
              nDecimalPoints++;
              nDecimals = 1;
              prevEdge = rightNumEdge2;
            } else {
              break;
            }
          } else {
            break;
          }
        }

        if (subEdges.length >= 2) {
          final num newValue = newValueS.contains('.')
              ? double.parse(newValueS)
              : int.parse(newValueS);
          final lastEdge = subEdges.last;
          final lastScript = lastEdge is NumEdge ? lastEdge.script : null;

          final newEdge = lat.createNumEdge(
            subEdges.first.start,
            subEdges.last.end,
            newValue.toString(),
            active: true,
          );
          newEdge.update(
            value: newValue,
            valueS: newValueS,
            nDecimals: nDecimals,
            numBase: 1,
            eType: 'D1',
            script: lastScript,
          );
          lat.addEdge(newEdge);
          numEdges = _updateEdgeList(numEdges, newEdge, subEdges);
        }
      }
    }

    // G1 combine (*) "single digits": 2 * 100 = 200, 3 * 10 = 30
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      if (edge.active &&
          edge.numBase == 1 &&
          edge.value is int &&
          (edge.value as int) >= 1) {
        final rightEdge = lat.bestRightNeighborEdge(
          edge.end,
          skipNumEdge: false,
        );
        if (rightEdge is NumEdge &&
            rightEdge.active &&
            rightEdge.value is int &&
            (rightEdge.numBase ?? 0) > 1 &&
            !rightEdge.isLargePower) {
          final newValue = (edge.value as int) * (rightEdge.value as int);
          final newEdge = lat.createNumEdge(
            edge.start,
            rightEdge.end,
            newValue.toString(),
            active: true,
          );
          newEdge.update(
            value: newValue,
            numBase: rightEdge.numBase,
            eType: 'G1',
            origTxt: edge.origTxt + rightEdge.origTxt,
            script: rightEdge.script,
          );
          lat.addEdge(newEdge);
          numEdges = _updateEdgeList(numEdges, newEdge, [edge, rightEdge]);
        }
      }
    }

    // G2 combine (+) G1 single digits: 200 + 30 + 4 = 234
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      if (edge.active && edge.value is int && !edge.isLargePower) {
        final subEdges = <NumEdge>[edge];
        var prevEdge = edge;
        var prevNonEdge = edge;

        while (true) {
          final rightEdge = lat.bestRightNeighborEdge(
            prevEdge.end,
            skipNumEdge: false,
          );
          if (rightEdge is NumEdge &&
              rightEdge.active &&
              rightEdge.value is int &&
              !rightEdge.isLargePower &&
              (_isGapNullEdge(prevNonEdge) ||
                  ((prevNonEdge.numBase ?? 0) > (rightEdge.value as int) &&
                      (prevNonEdge.numBase ?? 0) > (rightEdge.numBase ?? 0)))) {
            subEdges.add(rightEdge);
            prevEdge = rightEdge;
            if (!_isGapNullEdge(rightEdge)) {
              prevNonEdge = rightEdge;
            }
          } else {
            break;
          }
        }

        if (subEdges.length >= 2) {
          var newValue = 0;
          final origTxtBuf = StringBuffer();
          for (final e in subEdges) {
            newValue += (e.value as int);
            origTxtBuf.write(e.origTxt);
          }
          final newEdge = lat.createNumEdge(
            subEdges.first.start,
            subEdges.last.end,
            newValue.toString(),
            active: true,
          );
          newEdge.update(
            value: newValue,
            numBase: subEdges.last.numBase,
            eType: 'G2',
            origTxt: origTxtBuf.toString(),
            script: subEdges.last.script,
          );
          newEdge.type = 'G2';
          lat.addEdge(newEdge);
          numEdges = _updateEdgeList(numEdges, newEdge, subEdges);
        }
      }
    }

    // G3 combine (*) G2 blocks with large powers: 234 * 1000 = 234000
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      if (edge.active &&
          !edge.isLargePower &&
          (edge.value is int || edge.value is double)) {
        final rightEdge = lat.bestRightNeighborEdge(
          edge.end,
          skipNumEdge: false,
        );
        if (rightEdge is NumEdge &&
            rightEdge.active &&
            rightEdge.value is int &&
            (rightEdge.numBase ?? 0) > 1 &&
            rightEdge.isLargePower) {
          final num newValue;
          if (edge.value is int) {
            newValue = (edge.value as int) * (rightEdge.value as int);
          } else {
            final rawVal = edge.value!.toDouble() * (rightEdge.value as int);
            // Python: round(x, 5), if is_integer() -> int
            final rounded = (rawVal * 100000).round() / 100000;
            newValue = rounded == rounded.truncateToDouble()
                ? rounded.toInt()
                : rounded;
          }

          final newEdge = lat.createNumEdge(
            edge.start,
            rightEdge.end,
            newValue.toString(),
            active: true,
          );
          newEdge.update(
            value: newValue,
            numBase: rightEdge.numBase,
            eType: 'G3',
            origTxt: edge.origTxt + rightEdge.origTxt,
            script: rightEdge.script,
          );
          lat.addEdge(newEdge);
          numEdges = _updateEdgeList(numEdges, newEdge, [edge, rightEdge]);
        }
      }
    }

    // G4 combine (+) G3 blocks: 234000 + 567 = 234567
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      if (edge.active && edge.value is int) {
        final subEdges = <NumEdge>[edge];

        while (true) {
          final prevEdge = subEdges.last;
          final rightEdge = lat.bestRightNeighborEdge(
            prevEdge.end,
            skipNumEdge: false,
          );
          if (rightEdge is NumEdge &&
              rightEdge.active &&
              rightEdge.value is int &&
              (prevEdge.numBase ?? 0) > (rightEdge.value as int) &&
              (prevEdge.numBase ?? 0) > (rightEdge.numBase ?? 0)) {
            if (prevEdge.script == 'CJK' &&
                (prevEdge.numBase ?? 0) >= 1000 &&
                !(prevEdge.type?.contains('tag') ?? false) &&
                RegExp(r'10+$').hasMatch(prevEdge.numBase.toString()) &&
                (rightEdge.value as int) >= 1 &&
                (rightEdge.value as int) <= 9 &&
                rightEdge.start + 1 == rightEdge.end) {
              final newNumBase = (prevEdge.numBase ?? 0) ~/ 10;
              final newVal = newNumBase * (rightEdge.value as int);
              rightEdge.value = newVal;
              rightEdge.numBase = newNumBase;
              rightEdge.type = 'G4tag';
            }
            subEdges.add(rightEdge);
          } else {
            break;
          }
        }

        if (subEdges.length >= 2) {
          var newValue = 0;
          final origTxtBuf = StringBuffer();
          for (final e in subEdges) {
            newValue += (e.value as int);
            origTxtBuf.write(e.origTxt);
          }
          final newEdge = lat.createNumEdge(
            subEdges.first.start,
            subEdges.last.end,
            newValue.toString(),
            active: true,
          );
          newEdge.update(
            value: newValue,
            numBase: subEdges.last.numBase,
            eType: 'G4',
            origTxt: origTxtBuf.toString(),
            script: subEdges.last.script,
          );
          lat.addEdge(newEdge);
          numEdges = _updateEdgeList(numEdges, newEdge, subEdges);
        }
      }
    }

    // G5 (Chinese) fractions, percentages
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      if (edge.value is! int) continue;

      for (final fractionConnector in lat.uroman.fractionConnectors) {
        final connectorEnd = edge.end + fractionConnector.length;
        if (connectorEnd <= lat.maxVertex &&
            lat.substring(edge.end, connectorEnd) == fractionConnector) {
          final rightEdge = lat.bestRightNeighborEdge(connectorEnd);
          if (rightEdge is! NumEdge ||
              !rightEdge.active ||
              rightEdge.value == null) {
            continue;
          }

          if (edge.value == 100) {
            if ((rightEdge.value is int || rightEdge.value is double) &&
                (edge.value as int) >= 0) {
              final newEdge = lat.createEdge(
                edge.start,
                rightEdge.end,
                '${rightEdge.value}%',
                'percentage',
              );
              lat.addEdge(newEdge);
              numEdges = _updateEdgeList(numEdges, null, [edge, rightEdge]);
            }
          } else {
            if (rightEdge.value is int && (edge.value as int) > 0) {
              final newEdge = lat.createNumEdge(
                edge.start,
                rightEdge.end,
                '${rightEdge.value}/${edge.value}',
                active: true,
              );
              newEdge.fraction = Rational(
                rightEdge.value as int,
                edge.value as int,
              );
              newEdge.type = 'fraction';
              lat.addEdge(newEdge);
              numEdges = _updateEdgeList(numEdges, newEdge, [edge, rightEdge]);
            }
          }
        }
      }
    }

    // G6 plus/minus signs
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      for (final minusSign in lat.uroman.minusSigns) {
        final signStart = edge.start - minusSign.length;
        if (signStart >= 0 &&
            lat.substring(signStart, edge.start) == minusSign) {
          final newEdge = lat.createEdge(
            signStart,
            edge.end,
            '-${edge.txt}',
            '${edge.type} -',
          );
          lat.addEdge(newEdge);
        }
      }
      for (final plusSign in lat.uroman.plusSigns) {
        final signStart = edge.start - plusSign.length;
        if (signStart >= 0 &&
            lat.substring(signStart, edge.start) == plusSign) {
          final newEdge = lat.createEdge(
            signStart,
            edge.end,
            '+${edge.txt}',
            '${edge.type} +',
          );
          lat.addEdge(newEdge);
        }
      }
    }

    // F1 fraction cushioning
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      if (RegExp(r'\d').hasMatch(edge.txt)) {
        final leftEdge = lat.bestLeftNeighborEdge(edge.start);
        if (leftEdge != null && RegExp(r'\d$').hasMatch(leftEdge.txt)) {
          final sep = edge.fraction != null ? ' ' : '·';
          edge.txt = sep + edge.txt;
        }
      }
    }

    // Exceptions
    for (var i = 0; i < numEdges.length; i++) {
      final edge = numEdges[i];
      if (edge.active && edge.value != null) {
        final val = edge.value!;
        if ((val > 1000 && edge.start + 1 == edge.end) ||
            const {'兩', '參', '参', '伍', '陆', '陸', '什'}.contains(edge.origTxt) ||
            const {'京', '兆'}.contains(edge.origTxt)) {
          edge.active = false;
        }
      }
    }

    // Unicode numeric fallback for digits
    for (var start = 0; start < lat.maxVertex; start++) {
      final best = lat.bestEdgeInSpan(start, start + 1);
      if (best is NumEdge) continue;

      final cp = lat.codePoints[start];
      final num = UnicodeProps.udNumeric(cp);
      if (num != null &&
          UnicodeProps.hasDigitInName(cp) &&
          num is int &&
          num >= 0 &&
          num <= 9) {
        lat.addEdge(lat.createEdge(start, start + 1, num.toString(), 'num'));
      }
    }
  }

  static bool _edgeIsDigit(Edge? edge) {
    if (edge is NumEdge) {
      return edge.type == 'digit';
    }
    return false;
  }

  static bool _isGapNullEdge(Edge edge) {
    if (edge is NumEdge) {
      return edge.origTxt == '零' || edge.origTxt == '〇';
    }
    return false;
  }

  static List<NumEdge> _updateEdgeList(
    List<NumEdge> edges,
    NumEdge? newEdge,
    List<Edge> oldEdges,
  ) {
    var newEdgeNotYetAdded = true;
    final result = <NumEdge>[];
    for (final edge in edges) {
      if (oldEdges.contains(edge)) {
        edge.active = false;
        if (newEdgeNotYetAdded) {
          if (newEdge != null) {
            result.add(newEdge);
          }
          newEdgeNotYetAdded = false;
        }
      } else {
        result.add(edge);
      }
    }
    if (newEdgeNotYetAdded && newEdge != null) {
      result.add(newEdge);
    }
    return result;
  }
}
