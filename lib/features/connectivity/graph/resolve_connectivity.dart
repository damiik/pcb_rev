import '../models/core.dart';

/// Oblicza nets poprzez flood-fill na grafie.
/// resolveConnectivity jako parametr przyjmie ConnectivityGraph graph 
/// i wypełnia graph.subgraphs, a potem z nich buduje List<Net>.
List<Net> resolveConnectivity(ConnectivityGraph graph) {
  graph.subgraphs.clear();
  final visited = <String>{};
  var ix = 0;
  final nets = <Net>[];

  for (final item in graph.items.values) {
    if (visited.contains(item.id)) continue;

    final stack = <ConnectionItem>[item];
    final sub = ConnectionSubgraph(id: 'sg_$ix', itemIds: <String>{});
    ix++;

    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      if (visited.contains(cur.id)) continue;
      visited.add(cur.id);
      sub.itemIds.add(cur.id);

      for (final nb in graph.getNeighbors(cur.id)) {
        if (!visited.contains(nb.id)) stack.add(nb);
      }
    }

    graph.subgraphs.add(sub);

    // Rozwiąż nazwę netu dla subgraph (tymczasowo)
    // prefer label, potem power pin, inaczej auto
    String? netName;
    for (final id in sub.itemIds) {
      final it = graph.items[id];
      if (it is Label) { netName = it.netName; break; }
    }
    if (netName == null) {
      for (final id in sub.itemIds) {
        final it = graph.items[id];
        if (it is Pin && it.isPowerPin) { netName = it.pinName; break; }
      }
    }
    final finalName = netName ?? 'Net-$ix';

    final pins = sub.itemIds.map((id) => graph.items[id]).whereType<Pin>().toList();
    nets.add(Net(finalName, pins));
  }

  return nets;
}



/// Grupuje elementy w subgraphy (connected components)
/// i przypisuje im nazwy netów.
void buildSubgraphs(ConnectivityGraph graph) {
  final visited = <String>{};
  var subgraphIndex = 0;

  for (final item in graph.items.values) {
    if (visited.contains(item.id)) continue;

    final subgraph = ConnectionSubgraph(id: "ix_$subgraphIndex", resolvedNetName: "subgraph_$subgraphIndex", itemIds: <String>{});
    subgraphIndex++;

    final stack = <ConnectionItem>[item];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (visited.contains(current.id)) continue;

      visited.add(current.id);
      subgraph.itemIds.add(current.id);

      for (final neighbor in graph.getNeighbors(current.id)) {
        if (!visited.contains(neighbor.id)) {
          stack.add(neighbor);
        }
      }
    }

    graph.subgraphs.add(subgraph);
  }
}

/// Propaguje nazwy netów w subgraphach:
/// 1. Label ma najwyższy priorytet
/// 2. Power pin (jeśli zdefiniowany) ma drugi
/// 3. Auto-generated "Net-xxx" jeśli brak
void resolveNetNames(ConnectivityGraph graph) {
  for (final subgraph in graph.subgraphs) {
    String? netName;

    for (final itemId in subgraph.itemIds) {
      final item = graph.items[itemId];

      if (item is Label) {
        netName = item.netName;
        break;
      }

      if (item is Pin && item.isPowerPin) {
        netName = item.pinName; // np. VCC, GND
      }
    }

    subgraph.resolvedNetName = netName ?? "Net-${subgraph.id}";
  }
}
