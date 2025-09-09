import '../models/core.dart';
import '../models/connectivity.dart';

import '../graph/build_graph.dart';
import '../graph/resolve_connectivity.dart';

import '../../symbol_library/data/kicad_schematic_models.dart';
import '../../symbol_library/data/kicad_symbol_models.dart';

/// Adapter: konwertuje [KiCadSchematic] na [ConnectivityGraph].
///
/// Uproszczona wersja – bez hierarchii arkuszy.
/// Obsługuje: symbole, piny, przewody, junctions, etykiety.
class ConnectivityAdapter {
  /// Buduje pełną strukturę [Connectivity] z modelu schematu i biblioteki.
  static Connectivity fromSchematic(
    KiCadSchematic schematic,
    KiCadLibrary library,
  ) {
    final graph = buildGraph(schematic: schematic, library: library);
    final nets = resolveConnectivity(graph);

    return Connectivity(graph: graph, nets: nets);
  }
}
