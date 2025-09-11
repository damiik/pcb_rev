import 'dart:convert';
import '../models/core.dart';



String pin2str (Pin p) => switch ((p.isPowerPin, p.isInputPin, p.isOutputPin)) {
  (true, false, false) => 'power',
  (false, true, false) => 'input',
  (false, false, true) => 'output',
  (true, true, false) => 'power-input',
  (true, false, true) => 'power-output',
  (false, true, true) => 'bidirectional',
  _ => 'unknown',
};

/// Generuje netlistę w formacie JSON gotowym do wysłania przez MCP-server.
///
/// - Przechodzi przez wszystkie subgraphy w `ConnectivityGraph`
/// - Rozwiązuje nazwę netu (label lub auto-generated)
/// - Zbiera wszystkie piny
/// - Zwraca serializowany JSON
String getNetlist(ConnectivityGraph graph) {
  final nets = <Map<String, dynamic>>[];

  for (final subgraph in graph.subgraphs) {
    final netName = subgraph.resolvedNetName ?? _autoNetName(subgraph);
    final pins = <Map<String, dynamic>>[];

    for (final itemId in subgraph.itemIds) {
      final item = graph.items[itemId];
      if (item is Pin) {
        pins.add({
          "symbolRef": item.symbolRef,
          "pinName": item.pinName,
          "pinType": pin2str(item)
        });
      }
    }

    nets.add({
      "name": netName,
      "pins": pins,
    });
  }

  // Dodatkowo można dołączyć listę symboli
  final symbols = _collectSymbols(graph);

  final netlistJson = {
    "nets": nets,
    "symbols": symbols,
  };

  return const JsonEncoder.withIndent('  ').convert(netlistJson);
}

/// Proste generowanie nazwy netu, jeśli brak labela
String _autoNetName(ConnectionSubgraph subgraph) {
  // np. Net-1, Net-2 albo Net-(U1-Pad3)
  return "Net-${subgraph.itemIds.first}";
}

/// Zbiera instancje symboli z grafu
List<Map<String, dynamic>> _collectSymbols(ConnectivityGraph graph) {
  final symbols = <String, Map<String, dynamic>>{};

  for (final item in graph.items.values) {
    if (item is Pin) {
      final ref = item.symbolRef;
      symbols.putIfAbsent(ref, () {
        return {
          "ref": ref,
          "libraryId": item.libraryId, // Use the libraryId from the pin
          "pins": [],
          "position": {
            "x": item.position.x,
            "y": item.position.y,
          }
        };
      });

      (symbols[ref]!["pins"] as List).add({
        "name": item.pinName,
        "type": pin2str(item),
        "position": {
          "x": item.position.x,
          "y": item.position.y,
        }
      });
    }
  }

  return symbols.values.toList();
}

/// Zwraca pełny graf connectivity w formacie JSON.
/// 
/// items = wszystkie elementy schematu (wire, pin, junction, label)
/// edges = jawne krawędzie między itemami
String getConnectivityGraph(ConnectivityGraph graph) {
  final items = <Map<String, dynamic>>[];
  final edges = <Map<String, dynamic>>[];

  for (final item in graph.items.values) {
    final jsonItem = _serializeItem(item);
    items.add(jsonItem);

    final neighbors = graph.adjacencyMap[item.id] ?? {};
    for (final neighborId in neighbors) {
      edges.add({
        "from": item.id,
        "to": neighborId,
      });
    }
  }

  final graphJson = {
    "items": items,
    "edges": edges,
  };

  return const JsonEncoder.withIndent('  ').convert(graphJson);
}

/// Serializuje pojedynczy element grafu do JSON.
Map<String, dynamic> _serializeItem(ConnectionItem item) {
  if (item is Wire) {
    return {
      "id": item.id,
      "type": "wire",
      "start": {"x": item.position.x, "y": item.position.y},
      "end": {"x": item.end.x, "y": item.end.y},

    };
  } else if (item is Junction) {
    return {
      "id": item.id,
      "type": "junction",
      "position": {"x": item.position.x, "y": item.position.y},

    };
  } else if (item is Pin) {
    return {
      "id": item.id,
      "type": "pin",
      "position": {"x": item.position.x, "y": item.position.y},
      "symbolRef": item.symbolRef,
      "pinName": item.pinName,

    };
  } else if (item is Label) {
    return {
      "id": item.id,
      "type": "label",
      "position": {"x": item.position.x, "y": item.position.y},
      "netName": item.netName,

    };
  } else {
    return {
      "id": item.id,
      "type": "unknown",
      "position": {"x": item.position.x, "y": item.position.y},

    };
  }
}
