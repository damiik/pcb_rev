import '../models/core.dart';
import '../models/connectivity.dart';

import '../graph/build_graph.dart';
import '../graph/resolve_connectivity.dart';

import '../../../kicad/data/kicad_schematic_models.dart';
import '../../../kicad/data/kicad_symbol_models.dart';
import '../../../kicad/data/kicad_symbol_loader.dart';

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

    Connectivity updateConnectivity({required KiCadSchematic schematic, KiCadLibrarySymbolLoader? symbolLoader}) {
    // Combine symbols from the schematic's library and the external loader
    final allSymbols = <LibrarySymbol>[];
    if (schematic.library != null) {
      allSymbols.addAll(schematic.library!.librarySymbols);
    }
    allSymbols.addAll(symbolLoader!.getSymbols());

    // Create a new library with all symbols, removing duplicates
    final uniqueSymbols = <LibrarySymbol>[];
    final seenNames = <String>{};
    for (final symbol in allSymbols) {
      if (seenNames.add(symbol.name)) {
        uniqueSymbols.add(symbol);
      }
    }

    final completeLibrary = KiCadLibrary(
      version: schematic.version,
      generator: schematic.generator,
      librarySymbols: uniqueSymbols,
    );

    final connectivity = ConnectivityAdapter.fromSchematic(
      schematic,
      completeLibrary,
    );
    return connectivity;
  }
}
