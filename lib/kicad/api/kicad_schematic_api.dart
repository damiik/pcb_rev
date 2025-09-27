import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart' as symbol;
import '../data/kicad_symbol_loader.dart';

/// Public, modular API for all KiCad schematic operations.
///
/// This is the **only** interface external modules (e.g., `project/`, `app/`) should use
/// to interact with KiCad schematic data. All internal logic is encapsulated.
abstract class KiCadSchematicAPI {
  // === Loading & Saving ===

  /// Loads a KiCad schematic from the given file path.
  Future<KiCadSchematic> loadFromFile(String path);

  /// Saves the given schematic to the specified file path in `.kicad_sch` format.
  Future<void> saveToFile(KiCadSchematic schematic, String path);

  // === Symbol Instance Management ===

  /// Adds a new symbol instance to the schematic.
  KiCadSchematic addComponent({
    required KiCadSchematic schematic,
    required String type,
    required String value,
    required symbol.Position position,
    String reference = '',
    symbol.LibrarySymbol? librarySymbol,
    int unit = 1,
    bool mirrorX = false,
    bool mirrorY = false,
  });

  /// Adds a new symbol instance to the schematic.
  ///
  /// [libId] must correspond to a symbol name resolvable by a [KiCadSymbolAPI].
  /// [reference] should be unique; if empty, a new reference will be generated.
  KiCadSchematic addSymbolInstance({
    required KiCadSchematic schematic,
    required String libId,
    required String reference,
    required String value,
    required symbol.Position position,
    int unit = 1,
    bool mirrorX = false,
    bool mirrorY = false,
  });

  /// Updates properties or position of an existing symbol instance.
  KiCadSchematic updateSymbolInstance({
    required KiCadSchematic schematic,
    required String uuid,
    String? reference,
    String? value,
    symbol.Position? position,
    bool? mirrorX,
    bool? mirrorY,
  });

  /// Removes a schematic element (symbol, wire, label, etc.) by its UUID.
  KiCadSchematic removeElement(KiCadSchematic schematic, String uuid);

  // === Wire & Connection Elements ===

  /// Adds a wire between a series of points.
  KiCadSchematic addWire({
    required KiCadSchematic schematic,
    required List<symbol.Position> points,
    double strokeWidth = 0.0,
  });

  /// Adds a junction (connection dot) at the given position.
  KiCadSchematic addJunction({
    required KiCadSchematic schematic,
    required symbol.Position position,
    double diameter = 0.0,
  });

  // === Labels ===

  /// Adds a local net label.
  KiCadSchematic addLabel({
    required KiCadSchematic schematic,
    required String text,
    required symbol.Position position,
    symbol.TextEffects? effects,
  });

  /// Adds a global net label (visible across schematic sheets).
  KiCadSchematic addGlobalLabel({
    required KiCadSchematic schematic,
    required String text,
    required symbol.Position position,
    LabelShape shape = LabelShape.passive,
    symbol.TextEffects? effects,
  });

  // === Bus Elements ===

  /// Adds a bus (multi-wire bundle).
  KiCadSchematic addBus({
    required KiCadSchematic schematic,
    required List<symbol.Position> points,
    double strokeWidth = 0.0,
  });

  /// Adds a bus entry (connection point from bus to wire).
  KiCadSchematic addBusEntry({
    required KiCadSchematic schematic,
    required symbol.Position position,
    required double width,
    required double height,
    double strokeWidth = 0.0,
  });

  // === Querying & Selection ===

  /// Finds a symbol instance by its reference designator (e.g., "R1").
  SymbolInstance? findSymbolInstanceByReference(KiCadSchematic schematic, String ref);

  /// Finds all element UUIDs near the given position (within tolerance).
  ///
  /// Useful for hit-testing during user interaction (e.g., clicks).
  List<String> findElementsAt({
    required KiCadSchematic schematic,
    required symbol.Position position,
    double tolerance = 2.54, // 100 mil
  });

  /// Generates a new unique reference designator (e.g., "R3") for a given prefix.
  String generateNewRef(KiCadSchematic? schematic, String prefix);

  /// Resolve library symbol from various sources
  symbol.LibrarySymbol? resolveLibrarySymbol({
    required String symbolId,
    // kicad_symbol.LibrarySymbol? selectedSymbol,
    KiCadLibrarySymbolLoader? symbolLoader,
    KiCadSchematic? schematic,
  }); 
  
  /// Get property value from a list of properties
  String? getPropertyValue(List<symbol.Property> properties, String propertyName);


  bool isPointOnSegment(
    symbol.Position point,
    symbol.Position segStart,
    symbol.Position segEnd,
    double tolerance,
  );
}