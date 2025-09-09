import '../models/core.dart';
import '../models/point.dart';
import '../../symbol_library/data/kicad_schematic_models.dart' as kicad_schematic;
import '../../symbol_library/data/kicad_symbol_models.dart' as kicad_symbol;
import '../../symbol_library/domain/kicad_schematic_helpers.dart';

/// Buduje graf connectivity z modelu schematu KiCad.
/// Obsługuje: symbole + piny, junctions, labels, wires.
ConnectivityGraph buildGraph({
  required kicad_schematic.KiCadSchematic schematic,
  required kicad_symbol.KiCadLibrary library,
}) {
  final Map<String, ConnectionItem> items = {};
  final Map<String, Set<String>> adjacencyMap = {};

  // 1. Piny symboli
  for (final instance in schematic.symbolInstances) {
    final libSymbol = library.librarySymbols
        .firstWhere((s) => s.name == instance.libId.split(':').last);

    for (final unit in libSymbol.units) {
      for (final pin in unit.pins) {
        final pos = getPinAbsolutePosition(instance, pin);
        final id = '${instance.uuid}:${pin.number}';
        items[id] = Pin(id, Point(pos.dx.toInt(), pos.dy.toInt()), instance.uuid, pin.name, 
          isPowerPin: pin.type == kicad_symbol.PinType.powerIn || pin.type == kicad_symbol.PinType.powerOut,
          isOutputPin: pin.type == kicad_symbol.PinType.output || pin.type == kicad_symbol.PinType.bidirectional,
          isInputPin: pin.type == kicad_symbol.PinType.input || pin.type == kicad_symbol.PinType.bidirectional,
        );
      }
    }
  }

  // 2. Junctions
  for (final junction in schematic.junctions) {
    final id = junction.uuid;
    items[id] = Junction(id, Point(junction.at.x.toInt(), junction.at.y.toInt()));
  }

  // 3. Labels
  for (final label in schematic.labels) {
    final id = label.uuid;
    items[id] = Label(id, Point(label.at.x.toInt(), label.at.y.toInt()), label.text);
  }

  for (final gLabel in schematic.globalLabels) {
    final id = gLabel.uuid;
    items[id] = Label(id, Point(gLabel.at.x.toInt(), gLabel.at.y.toInt()), gLabel.text);
  }

  // 4. Wires → segmenty
  for (final wire in schematic.wires) {
    for (var i = 0; i < wire.pts.length - 1; i++) {
      final start = Point(wire.pts[i].x.toInt(), wire.pts[i].y.toInt());
      final end = Point(wire.pts[i + 1].x.toInt(), wire.pts[i + 1].y.toInt());

      final startId = '${wire.uuid}_$i:start';
      final endId = '${wire.uuid}_$i:end';

      items[startId] = Wire(startId, start, end);
      items[endId] = Wire(endId, end, start); // odwrotne połączenie dla spójności

      // Dodajemy połączenie w adjacencyMap
      adjacencyMap.putIfAbsent(startId, () => {}).add(endId);
      adjacencyMap.putIfAbsent(endId, () => {}).add(startId);
    }
  }

  // 5. Tworzymy ConnectivityGraph
  return ConnectivityGraph(
    items: items,
    subgraphs: [],
    nets: {},
    lastUpdated: DateTime.now(),
    adjacencyMap: adjacencyMap,
  );
}


// /// Tworzy krawędzie między elementami grafu
// void _connectItems(ConnectivityGraph graph) {
//   final items = graph.items.values.toList();

//   for (final a in items) {
//     for (final b in items) {
//       if (a.id == b.id) continue;

//       // Wire-wire connection
//       if (a is Wire && b is Wire) {
//         if (a.start == b.start ||
//             a.start == b.end ||
//             a.end == b.start ||
//             a.end == b.end) {
//           a.neighbors.add(b.id);
//         }
//       }

//       // Wire-junction
//       if (a is Wire && b is Junction) {
//         if (a.start == b.position || a.end == b.position) {
//           a.neighbors.add(b.id);
//           b.neighbors.add(a.id);
//         }
//       }

//       // Wire-pin
//       if (a is Wire && b is PinItem) {
//         if (a.start == b.position || a.end == b.position) {
//           a.neighbors.add(b.id);
//           b.neighbors.add(a.id);
//         }
//       }

//       // Wire-label
//       if (a is Wire && b is Label) {
//         if (a.start == b.position || a.end == b.position) {
//           a.neighbors.add(b.id);
//           b.neighbors.add(a.id);
//         }
//       }

//       // Junction jako multiplexer – łączy wszystkie w tym samym punkcie
//       if (a is Junction && b is Junction) {
//         if (a.position == b.position) {
//           a.neighbors.add(b.id);
//           b.neighbors.add(a.id);
//         }
//       }
//     }
//   }
// }
