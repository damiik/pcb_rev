// lib/kicad/domain/kicad_schematic_api_impl.dart

import 'dart:io';
import 'dart:ui';
import 'package:uuid/uuid.dart';
import '../api/kicad_schematic_api.dart';
import '../data/kicad_schematic_loader.dart';
import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart' as symbol;
import '../data/kicad_symbol_loader.dart';
import '../domain/kicad_schematic_writer.dart' as writer;

/// Concrete implementation of [KiCadSchematicAPI].
///
/// This class is internal to the `kicad` module and should not be imported
/// by external modules. Use the abstract [KiCadSchematicAPI] interface instead.
class KiCadSchematicAPIImpl implements KiCadSchematicAPI {
  final _uuid = const Uuid();

  @override
  Future<KiCadSchematic> loadFromFile(String path) async {
    final loader = KiCadSchematicLoader(path);
    return await loader.load();
  }

  @override
  Future<void> saveToFile(KiCadSchematic schematic, String path) async {
    final content = writer.generateKiCadSchematicFileContent(schematic);
    await File(path).writeAsString(content);
  }

  @override
  KiCadSchematic addComponent({
    required KiCadSchematic schematic,
    required String type, // Symbol name in library
    required String value,
    required symbol.Position position,
    String reference = '',
    symbol.LibrarySymbol? librarySymbol,
    int unit = 1,
    bool mirrorX = false,
    bool mirrorY = false,
  }) {
    if (librarySymbol == null) {
      final libSymbols = schematic.library!.librarySymbols;
      final matches = libSymbols.where((s) => s.name == type);
      if (matches.isNotEmpty) {
        librarySymbol = matches.first;
      }
    }

    // Check if reference is unique
    if (reference.isNotEmpty && schematic.symbolInstances.any((inst) =>
        inst.properties.any((prop) =>
            prop.name == 'Reference' && prop.value == reference))) {
      throw ArgumentError('Component with reference "$reference" already exists');
    }

    symbol.Property? maybeProperty;
    try {
      maybeProperty = librarySymbol!.properties.firstWhere(
        (p) => p.name == 'Reference',
      );
    } catch (e) {
      maybeProperty = null;
    }
    final prefix = maybeProperty?.value.replaceAll(RegExp(r'\d'), '') ?? 'X';
    final newRef = reference.isNotEmpty ? reference : generateNewRef(schematic, prefix);


    return addSymbolInstance(
      schematic: schematic,
      libId: librarySymbol!.name,
      reference: newRef,
      value: value,
      position: position,
      unit: unit,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
    );
  }
  
  /// Add a symbol instance to the schematic
  /// 
  /// Parameters:
  /// - [schematic]: The current schematic
  /// - [symbolLibId]: Library ID of the symbol (e.g., "Device:R")
  /// - [reference]: Reference designator (e.g., "R1")
  /// - [value]: Component value (e.g., "10k")
  /// - [position]: Position on schematic
  /// - [angle]: Rotation angle (default 0)
  /// - [mirrorX]: Mirror horizontally (default false)
  /// - [mirrorY]: Mirror vertically (default false)
  /// - [unit]: Unit number for multi-unit symbols (default 1)
  @override
  KiCadSchematic addSymbolInstance({
    required KiCadSchematic schematic,
    required String libId,
    required String reference,
    required String value,
    required symbol.Position position,
    int unit = 1,
    bool mirrorX = false,
    bool mirrorY = false,
  }) {
    final properties = [
      symbol.Property(
        name: 'Reference',
        value: reference,
        position: const symbol.Position(0, 0),
        effects: const symbol.TextEffects(
          font: symbol.Font(width: 1.27, height: 1.27),
          justify: symbol.Justify.left,
          hide: false,
        ),
      ),
      symbol.Property(
        name: 'Value',
        value: value,
        position: const symbol.Position(0, 0),
        effects: const symbol.TextEffects(
          font: symbol.Font(width: 1.27, height: 1.27),
          justify: symbol.Justify.center,
          hide: false,
        ),
      ),
      symbol.Property(
        name: 'Footprint',
        value: '',
        position: const symbol.Position(0, 0),
        effects: const symbol.TextEffects(
          font: symbol.Font(width: 1.27, height: 1.27),
          justify: symbol.Justify.left,
          hide: true,
        ),
      ),
      symbol.Property(
        name: 'Datasheet',
        value: '',
        position: const symbol.Position(0, 0),
        effects: const symbol.TextEffects(
          font: symbol.Font(width: 1.27, height: 1.27),
          justify: symbol.Justify.left,
          hide: true,
        ),
      ),
    ];

    final newSymbol = SymbolInstance(
      libId: libId,
      at: position,
      uuid: _uuid.v4(),
      properties: properties,
      unit: unit,
      inBom: true,
      onBoard: true,
      dnp: false,
      mirrorx: mirrorX,
      mirrory: mirrorY,
    );

    return schematic.copyWith(
      symbolInstances: List<SymbolInstance>.from(schematic.symbolInstances)..add(newSymbol),
    );
  }

  @override
  KiCadSchematic updateSymbolInstance({
    required KiCadSchematic schematic,
    required String uuid,
    String? reference,
    String? value,
    symbol.Position? position,
    bool? mirrorX,
    bool? mirrorY,
  }) {
    final updatedInstances = schematic.symbolInstances.map((instance) {
      if (instance.uuid != uuid) return instance;

      var updated = instance;
      if (position != null) updated = updated.copyWith(at: position);
      if (mirrorX != null) updated = updated.copyWith(mirrorx: mirrorX);
      if (mirrorY != null) updated = updated.copyWith(mirrory: mirrorY);

      if (reference != null || value != null) {
        final updatedProps = instance.properties.map((prop) {
          if (prop.name == 'Reference' && reference != null) {
            return symbol.Property(
              name: prop.name,
              value: reference,
              position: prop.position,
              effects: prop.effects,
            );
          }
          if (prop.name == 'Value' && value != null) {
            return symbol.Property(
              name: prop.name,
              value: value,
              position: prop.position,
              effects: prop.effects,
            );
          }
          return prop;
        }).toList();
        updated = updated.copyWith(properties: updatedProps);
      }
      return updated;
    }).toList();

    return schematic.copyWith(symbolInstances: updatedInstances);
  }



  @override
  KiCadSchematic addWire({
    required KiCadSchematic schematic,
    required List<symbol.Position> points,
    double strokeWidth = 0.0,
  }) {
    if (points.length < 2) {
      throw ArgumentError('Wire must have at least 2 points');
    }
    final newWire = Wire(
      pts: points,
      uuid: _uuid.v4(),
      stroke: symbol.Stroke(width: strokeWidth),
    );
    return schematic.copyWith(
      wires: List<Wire>.from(schematic.wires)..add(newWire),
    );
  }

  @override
  KiCadSchematic addJunction({
    required KiCadSchematic schematic,
    required symbol.Position position,
    double diameter = 0.0,
  }) {
    final newJunction = Junction(
      at: position,
      uuid: _uuid.v4(),
      diameter: diameter,
    );
    return schematic.copyWith(
      junctions: List<Junction>.from(schematic.junctions)..add(newJunction),
    );
  }

  @override
  KiCadSchematic addLabel({
    required KiCadSchematic schematic,
    required String text,
    required symbol.Position position,
    symbol.TextEffects? effects,
  }) {
    final newLabel = Label(
      text: text,
      at: position,
      uuid: _uuid.v4(),
      effects: effects ?? const symbol.TextEffects(
        font: symbol.Font(width: 1.27, height: 1.27),
        justify: symbol.Justify.left,
      ),
    );
    return schematic.copyWith(
      labels: List<Label>.from(schematic.labels)..add(newLabel),
    );
  }

  @override
  KiCadSchematic addGlobalLabel({
    required KiCadSchematic schematic,
    required String text,
    required symbol.Position position,
    LabelShape shape = LabelShape.passive,
    symbol.TextEffects? effects,
  }) {
    final newGlobalLabel = GlobalLabel(
      text: text,
      shape: shape,
      at: position,
      uuid: _uuid.v4(),
      effects: effects ?? const symbol.TextEffects(
        font: symbol.Font(width: 1.27, height: 1.27),
        justify: symbol.Justify.left,
      ),
    );
    return schematic.copyWith(
      globalLabels: List<GlobalLabel>.from(schematic.globalLabels)..add(newGlobalLabel),
    );
  }

  @override
  KiCadSchematic addBus({
    required KiCadSchematic schematic,
    required List<symbol.Position> points,
    double strokeWidth = 0.0,
  }) {
    if (points.length < 2) {
      throw ArgumentError('Bus must have at least 2 points');
    }
    final newBus = Bus(
      pts: points,
      uuid: _uuid.v4(),
      stroke: symbol.Stroke(width: strokeWidth),
    );
    return schematic.copyWith(
      buses: List<Bus>.from(schematic.buses)..add(newBus),
    );
  }

  @override
  KiCadSchematic addBusEntry({
    required KiCadSchematic schematic,
    required symbol.Position position,
    required double width,
    required double height,
    double strokeWidth = 0.0,
  }) {
    final newBusEntry = BusEntry(
      at: position,
      size: Size(width, height),
      uuid: _uuid.v4(),
      stroke: symbol.Stroke(width: strokeWidth),
    );
    return schematic.copyWith(
      busEntries: List<BusEntry>.from(schematic.busEntries)..add(newBusEntry),
    );
  }
    @override
  KiCadSchematic removeElement(KiCadSchematic schematic, String uuid) {
    return schematic.copyWith(
      symbolInstances: schematic.symbolInstances.where((s) => s.uuid != uuid).toList(),
      wires: schematic.wires.where((w) => w.uuid != uuid).toList(),
      buses: schematic.buses.where((b) => b.uuid != uuid).toList(),
      busEntries: schematic.busEntries.where((be) => be.uuid != uuid).toList(),
      junctions: schematic.junctions.where((j) => j.uuid != uuid).toList(),
      globalLabels: schematic.globalLabels.where((gl) => gl.uuid != uuid).toList(),
      labels: schematic.labels.where((l) => l.uuid != uuid).toList(),
    );
  }

  @override
  SymbolInstance? findSymbolInstanceByReference(KiCadSchematic schematic, String reference) {
    for (final symbolInstance in schematic.symbolInstances) {
      final ref = getPropertyValue(symbolInstance.properties, 'Reference');
      if (ref == reference) return symbolInstance;
    }
    return null;
  }

  @override
  List<String> findElementsAt({
    required KiCadSchematic schematic,
    required symbol.Position position,
    double tolerance = 2.54,
  }) {
    final found = <String>[];

    // Symbols
    for (final s in schematic.symbolInstances) {
      if ((s.at.x - position.x).abs() <= tolerance && (s.at.y - position.y).abs() <= tolerance) {
        found.add(s.uuid);
      }
    }

    // Junctions
    for (final j in schematic.junctions) {
      if ((j.at.x - position.x).abs() <= tolerance && (j.at.y - position.y).abs() <= tolerance) {
        found.add(j.uuid);
      }
    }

    // Labels
    for (final l in schematic.labels) {
      if ((l.at.x - position.x).abs() <= tolerance && (l.at.y - position.y).abs() <= tolerance) {
        found.add(l.uuid);
      }
    }

    // Global labels
    for (final gl in schematic.globalLabels) {
      if ((gl.at.x - position.x).abs() <= tolerance && (gl.at.y - position.y).abs() <= tolerance) {
        found.add(gl.uuid);
      }
    }

    // Wires (simplified: check endpoints only)
    for (final w in schematic.wires) {
      //for (final pt in w.pts) {
        //if ((pt.x - position.x).abs() <= tolerance && (pt.y - position.y).abs() <= tolerance) {
      for (int i = 0; i < w.pts.length - 1; i++) {  
        if(isPointOnSegment(position, w.pts[i], w.pts[i + 1], tolerance)) {
          found.add(w.uuid);
          break;
        }
      }
    }

    return found;
  }

  @override
  String generateNewRef(KiCadSchematic? schematic, String prefix) {
    int maxNum = 0;
    if (schematic == null) return '$prefix${maxNum + 1}';

    for (final inst in schematic.symbolInstances) {
      final ref = inst.properties
          .firstWhere((p) => p.name == 'Reference', orElse: () => symbol.Property(name: '', value: '', position: symbol.Position(0,0), effects: symbol.TextEffects(font: symbol.Font(width: 1, height: 1), justify: symbol.Justify.left)))
          .value;
      if (ref.startsWith(prefix)) {
        try {
          final num = int.parse(ref.substring(prefix.length));
          if (num > maxNum) maxNum = num;
        } catch (_) {
          // Ignore non-numeric suffixes
        }
      }
    }
    return '$prefix${maxNum + 1}';
  }

  /// Resolve library symbol from various sources
  @override
  symbol.LibrarySymbol? resolveLibrarySymbol({
    required String symbolId,
    // kicad_symbol.LibrarySymbol? selectedSymbol,
    KiCadLibrarySymbolLoader? symbolLoader,
    KiCadSchematic? schematic,
  }) {
    // First check if we have a selected symbol
    // if (selectedSymbol != null && selectedSymbol.name == symbolId) {
    //   return selectedSymbol;
    // }
    
    // Then check the symbol loader
    if (symbolLoader != null) {
      final symbol = symbolLoader.getSymbolByName(symbolId);
      if (symbol != null) return symbol;
    }
    
    // Finally check the schematic's library
    if (schematic?.library?.librarySymbols != null) {
      final matches = schematic!.library!.librarySymbols
          .where((s) => s.name == symbolId);
      if (matches.isNotEmpty) return matches.first;
    }
    
    return null;
  }

  /// Get property value from a list of properties
  @override
  String? getPropertyValue(List<symbol.Property> properties, String propertyName) {
    for (final p in properties) {
      if (p.name == propertyName) return p.value;
    }
    return null;
  }
  /// Check if a point is on a line segment
  @override
  bool isPointOnSegment(
    symbol.Position point,
    symbol.Position segStart,
    symbol.Position segEnd,
    double tolerance,
  ) {
    // Calculate distance from point to line segment
    final dx = segEnd.x - segStart.x;
    final dy = segEnd.y - segStart.y;
    final segLengthSq = dx * dx + dy * dy;
    
    if (segLengthSq == 0) {
      // Segment is a point
      final dist = ((point.x - segStart.x) * (point.x - segStart.x) + 
                    (point.y - segStart.y) * (point.y - segStart.y));
      return dist <= tolerance * tolerance;
    }
    
    var t = ((point.x - segStart.x) * dx + (point.y - segStart.y) * dy) / segLengthSq;
    t = t.clamp(0.0, 1.0);
    
    final projX = segStart.x + t * dx;
    final projY = segStart.y + t * dy;
    final dist = ((point.x - projX) * (point.x - projX) + 
                  (point.y - projY) * (point.y - projY));
    
    return dist <= tolerance * tolerance;
  }
}