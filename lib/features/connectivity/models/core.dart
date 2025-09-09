import 'point.dart';

class ConnectivityGraph {
  final Map<String, ConnectionItem> items;       // wszystkie elementy po ID
  final List<ConnectionSubgraph> subgraphs;      // lista spójnych komponentów
  final Map<String, Net> nets;                   // nazwa netu → Net

  final DateTime lastUpdated;                    // znacznik odświeżenia

  /// (Opcjonalnie) mapa sąsiadów dla szybkiego dostępu
  final Map<String, Set<String>> adjacencyMap;

 ConnectivityGraph({
    required this.items,
    required this.subgraphs,
    required this.nets,
    required this.lastUpdated,
    Map<String, Set<String>>? adjacencyMap,
  }) : adjacencyMap = adjacencyMap ?? {};

  /// Dodaje połączenie między dwoma węzłami
  void addEdge(String fromId, String toId) {
    adjacencyMap.putIfAbsent(fromId, () => {}).add(toId);
    adjacencyMap.putIfAbsent(toId, () => {}).add(fromId);
  }

  /// Zwraca sąsiadów dla danego nodeId
  List<ConnectionItem> getNeighbors(String nodeId) {
    final neighbors = <ConnectionItem>[];
    final ids = adjacencyMap[nodeId];
    if (ids != null) {
      for (final id in ids) {
        final item = items[id];
        if (item != null) neighbors.add(item);
      }
    }
    return neighbors;
  }

  /// Tworzy głęboką kopię grafu
  ConnectivityGraph clone() {
    // deep copy items
    final newItems = <String, ConnectionItem>{};
    for (final e in items.entries) {
      newItems[e.key] = e.value.copyItem();
    }

    // deep copy subgraphs
    final newSubgraphs = <ConnectionSubgraph>[];
    for (final sg in subgraphs) {
      newSubgraphs.add(ConnectionSubgraph(
        // jeśli masz pole `id` w subgrafie – przekaż je; jeśli nie, pomiń
        id: sg.id,
        itemIds: {...sg.itemIds},
        resolvedNetName: sg.resolvedNetName,
      ));
    }

    // deep copy nets
    final newNets = <String, Net>{};
    for (final e in nets.entries) {
      newNets[e.key] = Net(
        e.value.name,
        e.value.pins.map((p) => Pin(p.id, p.position, p.symbolRef, p.pinName)).toList(),
      );
    }

    // deep copy adjacency
    final newAdj = <String, Set<String>>{};
    for (final e in adjacencyMap.entries) {
      newAdj[e.key] = {...e.value};
    }

    return ConnectivityGraph(
      items: newItems,
      subgraphs: newSubgraphs,
      nets: newNets,
      lastUpdated: lastUpdated, // lub DateTime.now() jeśli chcesz znacznik nowej kopii
      adjacencyMap: newAdj,
    );
  }

}

sealed class ConnectionItem {
  final String id;
  final Point position;           // współrzędne w schemacie
  // final List<String> neighbors;   // ID sąsiadów

  ConnectionItem(this.id, this.position, /*this.neighbors*/);

  ConnectionItem copyItem() {
    final pos = Point(position.x, position.y);
    // final neigh = List<String>.from(neighbors);

    switch (runtimeType) {
      case Wire:
        final w = this as Wire;
        return Wire(w.id, pos, Point(w.end.x, w.end.y));
      case Pin:
        final p = this as Pin;
        return Pin(
          p.id,
          pos,
          p.symbolRef,
          p.pinName,
          isPowerPin: p.isPowerPin,
          isOutputPin: p.isOutputPin,
          isInputPin: p.isInputPin,
        );
      case Junction:
        final j = this as Junction;
        return Junction(j.id, pos);
      case Label:
        final l = this as Label;
        return Label(l.id, pos, l.netName);
      default:
        // fallback – gdyby pojawił się nowy typ
        throw UnimplementedError('copyItem not implemented for ${runtimeType}');
    }
  }
}

class Wire extends ConnectionItem {
  final Point end; // start=position, end=end
  Wire(super.id, super.position, this.end);
}

class Junction extends ConnectionItem {
  Junction(super.id, super.position);
}

class Pin extends ConnectionItem {
  final String symbolRef;
  final String pinName;
  bool isPowerPin = false; // czy pin jest pinem zasilania (np. VCC, GND)
  bool isOutputPin = false; // czy pin jest pinem wyjściowym (np. sygnał)
  bool isInputPin = false;  // czy pin jest pinem wejściowym (np. sygnał)

  Pin(super.id, super.position, this.symbolRef, this.pinName, {
    this.isPowerPin = false,
    this.isOutputPin = false,
    this.isInputPin = false,
  });
}

class Label extends ConnectionItem {
  final String netName;
  Label(super.id, super.position, this.netName,);
}

class ConnectionSubgraph {
  final String id;
  final Set<String> itemIds;
  String? resolvedNetName;   // po propagacji nazw

  ConnectionSubgraph({
    required this.id,
    required this.itemIds,
    this.resolvedNetName,
  });
}

class Net {
  final String name;
  final List<Pin> pins;

  Net(this.name, this.pins);
}

class PinRef {
  final String symbolRef;
  final String pinName;

  PinRef(this.symbolRef, this.pinName);
}
