import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../features/connectivity/domain/connectivity_adapter.dart';
import '../../features/connectivity/models/connectivity.dart';

/// Manages connectivity-related operations
class ConnectivityManager {
  final ConnectivityAdapter _connectivityAdapter;

  ConnectivityManager(this._connectivityAdapter);

  /// Update connectivity based on schematic and symbol loader
  Connectivity? updateConnectivity({
    required KiCadSchematic? schematic,
    required KiCadLibrarySymbolLoader? symbolLoader,
  }) {
    if (schematic != null && symbolLoader != null) {
      return _connectivityAdapter.updateConnectivity(
        schematic: schematic,
        symbolLoader: symbolLoader,
      );
    }
    return null;
  }
}
