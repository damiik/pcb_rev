import '../models/core.dart';
import '../models/point.dart';
import 'resolve_connectivity.dart';

/// Reprezentuje zmianę w schemacie
abstract class SchematicChange {
  String get type;
}

class AddWireChange extends SchematicChange {
  final Wire wire;
  AddWireChange(this.wire);
  @override
  String get type => "addWire";
}

class RemoveItemChange extends SchematicChange {
  final String itemId;
  RemoveItemChange(this.itemId);
  @override
  String get type => "removeItem";
}

/// Odświeża connectivity po wprowadzeniu zmian w schemacie.
///
/// - Aktualizuje graf tylko w zmodyfikowanych miejscach
/// - Przelicza subgraphy i netlistę od nowa
ConnectivityGraph refreshConnectivity(
  ConnectivityGraph oldGraph,
  List<SchematicChange> changes,
) {
  final graph = oldGraph.clone();

  for (final change in changes) {
    if (change is AddWireChange) {
      graph.items[change.wire.id] = change.wire.copyItem() as Wire;
      _connectNewWire(graph, change.wire);
    } else if (change is RemoveItemChange) {
      _removeItem(graph, change.itemId);
    }
    // TODO: AddJunctionChange, AddPinChange, MoveItemChange...
  }

  // przebuduj subgraphy i nety
  graph.subgraphs.clear();
  graph.nets.clear();

  final nets = resolveConnectivity(graph);
  for (final net in nets) {
    graph.nets[net.name] = net;
  }

  return ConnectivityGraph(
    items: graph.items,
    subgraphs: graph.subgraphs,
    nets: graph.nets,
    lastUpdated: DateTime.now(),
    adjacencyMap: graph.adjacencyMap,
  );
}

/// Usuwa węzeł z grafu oraz wszystkie jego krawędzie.
void _removeItem(ConnectivityGraph graph, String itemId) {
  // usuń z adjacency
  final neigh = graph.adjacencyMap[itemId];
  if (neigh != null) {
    for (final n in neigh) {
      graph.adjacencyMap[n]?.remove(itemId);
    }
  }
  graph.adjacencyMap.remove(itemId);

  // usuń węzeł z items
  graph.items.remove(itemId);
}


/// Po dodaniu nowego Wire – połącz go z elementami na jego końcach
/// oraz z elementami które leżą na segmencie lub przecinają się z nim.
void _connectNewWire(ConnectivityGraph graph, Wire wire) {
  void _ensureConnected(String aId, String bId) {
    graph.addEdge(aId, bId); // tylko adjacencyMap
  }

  for (final other in graph.items.values) {
    if (other.id == wire.id) continue;

    if (_pointOnSegment(other.position, wire.position, wire.end)) {
      _ensureConnected(wire.id, other.id);
      continue;
    }

    if (other is Wire &&
        _segmentsIntersect(wire.position, wire.end, other.position, other.end)) {
      _ensureConnected(wire.id, other.id);
    }
  }
}

/// Sprawdza, czy punkt p leży na odcinku a-b (włącznie z końcami).
bool _pointOnSegment(Point p, Point a, Point b) {
  // Najpierw sprawdź, czy punkty są kolinearne
  final orient = _orientation(a, b, p);
  if (orient != 0) return false;

  // Następnie sprawdź czy p leży w prostokącie ograniczającym a i b
  final minX = (a.x < b.x) ? a.x : b.x;
  final maxX = (a.x > b.x) ? a.x : b.x;
  final minY = (a.y < b.y) ? a.y : b.y;
  final maxY = (a.y > b.y) ? a.y : b.y;

  return (p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY);
}

/// Zwraca 0 jeśli kolinearne, 1 jeśli clockwise, 2 jeśli counterclockwise.
/// Wykorzystuje integerową arytmetykę (bez zaokrągleń).
int _orientation(Point a, Point b, Point c) {
  final val = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
  if (val == 0) return 0;
  return (val > 0) ? 1 : 2;
}

/// Sprawdza przecięcie odcinków (a1,a2) i (b1,b2).
bool _segmentsIntersect(Point a1, Point a2, Point b1, Point b2) {
  final o1 = _orientation(a1, a2, b1);
  final o2 = _orientation(a1, a2, b2);
  final o3 = _orientation(b1, b2, a1);
  final o4 = _orientation(b1, b2, a2);

  if (o1 != o2 && o3 != o4) return true;

  // Obsługa przypadków kolinearnych (punkt leży na odcinku)
  if (o1 == 0 && _pointOnSegment(b1, a1, a2)) return true;
  if (o2 == 0 && _pointOnSegment(b2, a1, a2)) return true;
  if (o3 == 0 && _pointOnSegment(a1, b1, b2)) return true;
  if (o4 == 0 && _pointOnSegment(a2, b1, b2)) return true;

  return false;
}
