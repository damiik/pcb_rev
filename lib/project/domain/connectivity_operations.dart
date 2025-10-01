
import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../features/connectivity/domain/connectivity_adapter.dart';
import '../../features/connectivity/models/connectivity.dart';

Connectivity? updateConnectivity({
  required KiCadSchematic? schematic,
  required KiCadLibrarySymbolLoader? symbolLoader,
}) {
  if (schematic != null && symbolLoader != null) {
    final connectivityAdapter = ConnectivityAdapter();
    return connectivityAdapter.updateConnectivity(
      schematic: schematic,
      symbolLoader: symbolLoader,
    );
  }
  return null;
}
