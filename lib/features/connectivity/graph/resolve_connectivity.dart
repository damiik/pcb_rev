import '../models/core.dart';

/// Oblicza nets poprzez flood-fill na grafie.
List<Net> resolveConnectivity(ConnectivityGraph graph) {
  final nets = <Net>[];
  final visited = <String>{};
  var netIndex = 1;

  for (final item in graph.items.values) {
    if (visited.contains(item.id)) continue;

    final stack = <ConnectionItem>[item];
    final group = <ConnectionItem>[];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (visited.contains(current.id)) continue;

      visited.add(current.id);
      group.add(current);

      final neighbors = graph.getNeighbors(current.id);
      for (final n in neighbors) {
        if (!visited.contains(n.id)) stack.add(n);
      }
    }

    // Resolve net name: prefer labels, fallback to auto
    final label = group.whereType<Label>().firstOrNull;
    final netName = label?.netName ?? 'Net-$netIndex';

    final pins = group.whereType<Pin>().toList();

    nets.add(Net(netName, pins));

    netIndex++;
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
