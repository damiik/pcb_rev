import '../models/core.dart';
import 'tools.dart';
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
  graph.nets.clear();
  for (final net in nets) {
    graph.nets[net.name] = net;
  }
  // graph.subgraphs powinien być już wypełniony przez resolveConnectivity

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

    if (pointOnSegment(other.position, wire.position, wire.end)) {
      _ensureConnected(wire.id, other.id);
      continue;
    }

    if (other is Wire &&
        segmentsIntersect(wire.position, wire.end, other.position, other.end)) {
      // Podobnie jak wyżej: łącz tylko, gdy istnieje Junction na przecięciu
      var hasJunctionAtIntersection = false;
      for (final it in graph.items.values) {
        if (it is Junction) {
          if (pointOnSegment(it.position, wire.position, wire.end) &&
              pointOnSegment(it.position, other.position, other.end)) {
            hasJunctionAtIntersection = true;
            break;
          }
        }
      }
      if (hasJunctionAtIntersection) {
        _ensureConnected(wire.id, other.id);
      }
    }
  }
}
