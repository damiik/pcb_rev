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
/// - TODO: dodać labels, global labels, itp.
String getNetlist(ConnectivityGraph graph) {
  final nets = <Map<String, dynamic>>[];

  for (final subgraph in graph.subgraphs) {
    final netName = subgraph.resolvedNetName ?? _autoNetName(subgraph);
    final pins = <String>[];

    for (final itemId in subgraph.itemIds) {
      final item = graph.items[itemId];
      if (item is Pin) {
        pins.add("${item.symbolDesignator}.${item.pinName}");
      }
    }

    nets.add({
      "net": netName,
      "pins": pins,
    });
  }

  // Dodatkowo można dołączyć listę symboli
  final symbols = _collectSymbols(graph);
  // final labels = _collectLabels(graph); // TODO: Implement labels collection

  final netlistJson = {
    "nets": nets,
    "symbols": symbols,
    // "labels": labels,
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

    if(item is SymbolInstance) {
      if (!symbols.containsKey(item.designator)) {
        // Jeśli symbol o takim designatorze jeszcze nie istnieje, dodajemy go  
        symbols.putIfAbsent(item.designator, () {
          return {
            "designator": item.designator,
            "libraryId": item.libraryId,
            "value": item.value,
            "description": item.description,
            "position": {
              "x": item.position.x,
              "y": item.position.y,
            },
            "pins": []
          };
        });
      }
      else {
        // Jeśli symbol o takim designatorze już istnieje, możemy zaktualizować jego pola
        symbols[item.designator]!["position"] = {
          "x": item.position.x,
          "y": item.position.y,
        };
        symbols[item.designator]!["designator"] = item.designator;
        symbols[item.designator]!["libraryId"] = item.libraryId;
        symbols[item.designator]!["value"] = item.value;
        symbols[item.designator]!["description"] = item.description;
      }
    }



    if (item is Pin) {
      final ref = item.symbolDesignator;

      if (!symbols.containsKey(ref)) {
        // SymbolInstance nie został znaleziony, pomijamy ten pin
        symbols.putIfAbsent(ref, () {

          return {
            "designator": ref,
            "libraryId": "", // brak danych
            "value": "",
            "description": "",
            "position": {
              "x": 0,
              "y": 0,
            },
            "pins": []
          };
        });
      }


      (symbols[ref]!["pins"] as List).add({
        "name": item.pinName,
        "type": pin2str(item),
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
      "symbolDesignator": item.symbolDesignator,
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
