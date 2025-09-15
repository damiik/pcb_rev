import '../models/core.dart';
import '../models/point.dart';
import 'tools.dart';
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
  // ignore: prefer_function_declarations_over_variables
  final mm2mill = (double x) => (x / 0.0254).round(); // = 39.37007874... where mil is 1/1000 of an inch

  // 1. Piny symboli
  for (final instance in schematic.symbolInstances) {
    final libSymbol = library.librarySymbols.firstWhere(
      (s) => s.name == instance.libId,
      orElse: () => throw Exception(
        'Symbol definition not found for "${instance.libId}". The library provided to ConnectivityAdapter is missing this symbol.',
      ),
    );

    items[instance.uuid] = SymbolInstance(
      instance.uuid,
      Point(mm2mill(instance.at.x), mm2mill(instance.at.y)), // convert from mm to mils
      instance.libId,
      instance.getProperty('Reference'),
      instance.getProperty('Value'),
      instance.getProperty('Description'),
    );

    for (final unit in libSymbol.units) {
      for (final pin in unit.pins) {
        final pos = getPinAbsolutePosition(instance, pin); // convert from mm to mils
        int x = mm2mill(pos.dx); // convert from mm to mils
        int y = mm2mill(pos.dy); // convert from mm to mils

        final pinName = pin.name.isEmpty || pin.name == "~" ? pin.number : pin.name;

        print ('Pin ${pinName} of ${instance.libId} at ($x, $y)');
        final id = '${instance.uuid}:${pin.number}';
        items[id] = Pin(id, Point(x, y), instance.uuid, pinName, instance.getProperty('Reference'),
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
    final px = mm2mill(junction.at.x); // convert from mm to mils
    final py = mm2mill(junction.at.y); // convert from mm to mils
    items[id] = Junction(id, Point(px, py));
  }

  // 3. Labels
  for (final label in schematic.labels) {
    final id = label.uuid;
    final px = mm2mill(label.at.x); // convert from mm to mils
    final py = mm2mill(label.at.y); // convert from mm to mils
    items[id] = Label(id, Point(px, py), label.text);
  }

  for (final gLabel in schematic.globalLabels) {
    final id = gLabel.uuid;
    final px = mm2mill(gLabel.at.x); // convert from mm to mils
    final py = mm2mill(gLabel.at.y); // convert from mm to mils
    items[id] = Label(id, Point(px, py), gLabel.text);
  }

  // 4. Wires → segmenty
  for (final wire in schematic.wires) {
    for (var i = 0; i < wire.pts.length - 1; i++) {
      final px = mm2mill(wire.pts[i].x); // convert from mm to mils
      final py = mm2mill(wire.pts[i].y); // convert from mm to mils
      final start = Point(px, py);
      final px2 = mm2mill(wire.pts[i + 1].x); // convert from mm to mils
      final py2 = mm2mill(wire.pts[i + 1].y); // convert from mm to mils
      final end = Point(px2, py2);

      final startId = '${wire.uuid}_$i:start';
      final endId = '${wire.uuid}_$i:end';

      items[startId] = Wire(startId, start, end);
      items[endId] = Wire(endId, end, start); // odwrotne połączenie dla spójności

      // Dodajemy połączenie w adjacencyMap
      adjacencyMap.putIfAbsent(startId, () => {}).add(endId);
      adjacencyMap.putIfAbsent(endId, () => {}).add(startId);
    }
  }

  // --- Po zbudowaniu items i adjacencyMap dla wewnętrznych par segmentu ---
  // Stwórz indeks współrzędnych dla szybkiego dopasowania elementów leżących w tym samym punkcie
  final Map<String, List<String>> coordIndex = {}; // "x:y" -> [itemId...]

  String keyOf(Point p) => '${p.x}:${p.y}';

  // Wypełnij indeks
  for (final entry in items.entries) {
    final id = entry.key;
    final it = entry.value;
    // Dla wires indeksujemy oba końce
    if (it is Wire) {
      coordIndex.putIfAbsent(keyOf(it.position), () => []).add(id);
      coordIndex.putIfAbsent(keyOf(it.end), () => []).add(id);
    } else {
      coordIndex.putIfAbsent(keyOf(it.position), () => []).add(id);
    }
  }

  // Połącz wszystko co leży w tym samym punkcie
  for (final list in coordIndex.values) {
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        adjacencyMap.putIfAbsent(list[i], () => {}).add(list[j]);
        adjacencyMap.putIfAbsent(list[j], () => {}).add(list[i]);
      }
    }
  }

  // Wykryj przecięcia segmentów, ale połącz je TYLKO jeśli w punkcie przecięcia
  // jest faktyczny Junction (kropka) lub inny element na tym punkcie.
  // Dzięki temu zachowujemy zgodność z KiCad: crossing without dot != connected.
  final wires = items.values.whereType<Wire>().toList();
  for (var i = 0; i < wires.length; i++) {
    for (var j = i + 1; j < wires.length; j++) {
      final a = wires[i];
      final b = wires[j];

      if (!segmentsIntersect(a.position, a.end, b.position, b.end)) continue;

      // Sprawdź, czy istnieje Junction leżący jednocześnie na obu segmentach.
      // Jeśli tak -> traktujemy jako rzeczywiste połączenie.
      var intersectionHasJunction = false;

      for (final it in items.values) {
        if (it is Junction) {
          if (pointOnSegment(it.position, a.position, a.end) &&
              pointOnSegment(it.position, b.position, b.end)) {
            intersectionHasJunction = true;
            break;
          }
        }
      }

      if (intersectionHasJunction) {
        adjacencyMap.putIfAbsent(a.id, () => {}).add(b.id);
        adjacencyMap.putIfAbsent(b.id, () => {}).add(a.id);
      }
      // w przeciwnym razie nic nie łączymy — wires przecinają się geometrycznie
      // ale nie mają kropki => nie są połączone elektrycznie.
    }
  }
  // ... po sekcji wykrywania przecięć z junctionami ...

  // === Łączenie elementów przez etykiety tekstowe ===
  //
  // W KiCad etykiety (Label, GlobalLabel) o tym samym napisie są połączone
  // elektrycznie, niezależnie od położenia na schemacie.
  final labelsByName = <String, List<ConnectionItem>>{};

  // Zbierz wszystkie etykiety lokalne i globalne
  for (final item in items.values) {
    if (item is Label /* lokalna */ /* || item is GlobalLabel */ /* globalna */) {
      final text = (item as dynamic).netName as String;
      labelsByName.putIfAbsent(text, () => []).add(item);
    }
  }

  // Dla każdej grupy etykiet o tej samej nazwie
  for (final entry in labelsByName.entries) {
    final labelList = entry.value;
    if (labelList.length < 2) continue; // nic do łączenia

    // Zbierz wszystkie elementy połączone fizycznie z tymi etykietami
    final connectedIds = <String>{};
    for (final label in labelList) {
      final neighbors = adjacencyMap[label.id];
      if (neighbors != null) {
        connectedIds.addAll(neighbors);
      }
    }

    // Połącz wszystko razem w pełny graf
    final allIds = connectedIds.toList();
    for (var i = 0; i < allIds.length; i++) {
      for (var j = i + 1; j < allIds.length; j++) {
        final a = allIds[i];
        final b = allIds[j];
        adjacencyMap.putIfAbsent(a, () => {}).add(b);
        adjacencyMap.putIfAbsent(b, () => {}).add(a);
      }
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
