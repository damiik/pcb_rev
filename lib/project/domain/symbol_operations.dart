
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../kicad/data/kicad_schematic_models.dart' ;
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../kicad/api/kicad_schematic_api_impl.dart';
import '../data/logical_models.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart' as sym;

typedef SymbolSelectionResult = ({SymbolInstance? symbolInstance, sym.LibrarySymbol? librarySymbol, sym.Position? position, String? uuid});
typedef SymbolSearchResult = ({
  bool success,
  SymbolInstance? symbol,
  sym.LibrarySymbol? librarySymbol,
  sym.Position? position,
  String? error,
});

SymbolSelectionResult selectComponent(
  KiCadSchematicAPIImpl schematicApi,
  LogicalComponent component,
  KiCadSchematic? schematic,
) {
  if (schematic == null) return (symbolInstance: null, librarySymbol: null, position: null, uuid: null);

  SymbolInstance? foundSymbolInstance = schematicApi.findSymbolInstanceByReference(schematic, component.id);

  if (foundSymbolInstance != null) {
    sym.LibrarySymbol? librarySymbol;
    try {
      librarySymbol = schematic.library?.librarySymbols
          .firstWhere((s) => s.name == foundSymbolInstance.libId);
    } catch (e) {
      librarySymbol = null;
    }

    return (symbolInstance: foundSymbolInstance, librarySymbol: librarySymbol, position: foundSymbolInstance.at, uuid: foundSymbolInstance.uuid);
  }
  return (symbolInstance: null, librarySymbol: null, position: null, uuid: null);
}

sym.LibrarySymbol? selectLibrarySymbol(
  sym.LibrarySymbol symbol,
) {
  return symbol;
}

KiCadSchematic? updateSymbolProperty(
  SymbolInstance symbol,
  sym.Property updatedProperty,
  KiCadSchematic? schematic,
) {
  if (schematic == null) return null;

  final symbolIndex = schematic.symbolInstances.indexWhere((s) => s.uuid == symbol.uuid);
  if (symbolIndex != -1) {
    final propertyIndex = schematic.symbolInstances[symbolIndex].properties.indexWhere((p) => p.name == updatedProperty.name);
    if (propertyIndex != -1) {
      final newProperties = List<sym.Property>.from(schematic.symbolInstances[symbolIndex].properties);
      newProperties[propertyIndex] = updatedProperty;
      final newSymbolInstances = List<SymbolInstance>.from(schematic.symbolInstances);
      newSymbolInstances[symbolIndex] = newSymbolInstances[symbolIndex].copyWith(properties: newProperties);
      return schematic.copyWith(symbolInstances: newSymbolInstances);
    }
  }
  return null;
}


SymbolSearchResult findSymbolByReference({
  required KiCadSchematic schematic,
  required KiCadSchematicAPIImpl schematicApi,
  required String reference,
}) {
  try {
    final foundSymbol = schematicApi.findSymbolInstanceByReference(
      schematic,
      reference,
    );
    
    if (foundSymbol == null) {
      return (
        success: false,
        symbol: null,
        librarySymbol: null,
        position: null,
        error: 'Symbol with reference "$reference" not found.',
      );
    }
    
    sym.LibrarySymbol? librarySymbol;
    try {
      librarySymbol = schematic.library?.librarySymbols
          .firstWhere((s) => s.name == foundSymbol.libId);
    } catch (e) {
      librarySymbol = null;
    }
    
    return (
      success: true,
      symbol: foundSymbol,
      librarySymbol: librarySymbol,
      position: foundSymbol.at,
      error: null,
    );
  } catch (e) {
    return (
      success: false,
      symbol: null,
      librarySymbol: null,
      position: null,
      error: e.toString(),
    );
  }
}