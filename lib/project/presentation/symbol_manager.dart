import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../kicad/data/kicad_schematic_models.dart' ;
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../kicad/api/kicad_schematic_api_impl.dart';
import '../data/logical_models.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart' as sym;

/// Manages symbol-related operations like selection, addition, and property updates
class SymbolManager {
  final KiCadSchematicAPIImpl _schematicApi;

  SymbolManager(this._schematicApi);

  /// Select a component and find its corresponding symbol instance
  SymbolInstance? selectComponent(
    LogicalComponent component,
    KiCadSchematic? schematic,
    Function(SymbolInstance, sym.LibrarySymbol?, sym.Position, String) onSelection,
  ) {
    if (schematic == null) return null;

    SymbolInstance? foundSymbolInstance = _schematicApi.findSymbolInstanceByReference(schematic, component.id);

    if (foundSymbolInstance != null) {
      sym.LibrarySymbol? librarySymbol;
      try {
        librarySymbol = schematic.library?.librarySymbols
            .firstWhere((s) => s.name == foundSymbolInstance.libId);
      } catch (e) {
        librarySymbol = null;
      }

      onSelection(
        foundSymbolInstance,
        librarySymbol,
        foundSymbolInstance.at,
        foundSymbolInstance.uuid,
      );
      return foundSymbolInstance;
    }
    return null;
  }

  /// Select a library symbol
  void selectLibrarySymbol(
    sym.LibrarySymbol symbol,
    Function(sym.LibrarySymbol) onSelection,
  ) {
    onSelection(symbol);
  }

  /// Update symbol property
  void updateSymbolProperty(
    SymbolInstance symbol,
    sym.Property updatedProperty,
    KiCadSchematic? schematic,
    VoidCallback onUpdate,
  ) {
    if (schematic == null) return;

    final symbolIndex = schematic.symbolInstances.indexWhere((s) => s.uuid == symbol.uuid);
    if (symbolIndex != -1) {
      final propertyIndex = schematic.symbolInstances[symbolIndex].properties.indexWhere((p) => p.name == updatedProperty.name);
      if (propertyIndex != -1) {
        onUpdate();
      }
    }
  }



  void _showErrorSnackBar(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }
}
