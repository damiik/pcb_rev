// Add this to your project/presentation/main_screen.dart or create a separate file
// like schematic/domain/schematic_api.dart

import 'package:uuid/uuid.dart';
import 'dart:ui';
import '../../features/kicad/data/kicad_schematic_models.dart';
import '../../features/kicad/data/kicad_symbol_models.dart' as symbol_models;

/// API functions for creating and updating KiCad schematic elements
class KiCadSchematicAPI {
  final _uuid = Uuid();

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
  KiCadSchematic addSymbolInstance({
    required KiCadSchematic schematic,
    required String symbolLibId,
    required String reference,
    required String value,
    required symbol_models.Position position,
    double angle = 0.0,
    bool mirrorX = false,
    bool mirrorY = false,
    int unit = 1,
  }) {
    // Create the symbol position with rotation
    final symbolPosition = symbol_models.Position(
      position.x,
      position.y,
      angle,
    );

    // Create standard properties for the symbol
    final properties = [
      symbol_models.Property(
        name: 'Reference',
        value: reference,
        position: symbol_models.Position(0, -5), // Offset above symbol
        effects: const symbol_models.TextEffects(
          font: symbol_models.Font(width: 1.27, height: 1.27),
          justify: symbol_models.Justify.center,
          hide: false,
        ),
      ),
      symbol_models.Property(
        name: 'Value',
        value: value,
        position: symbol_models.Position(0, 5), // Offset below symbol
        effects: const symbol_models.TextEffects(
          font: symbol_models.Font(width: 1.27, height: 1.27),
          justify: symbol_models.Justify.center,
          hide: false,
        ),
      ),
      symbol_models.Property(
        name: 'Footprint',
        value: '',
        position: symbol_models.Position(0, 0),
        effects: const symbol_models.TextEffects(
          font: symbol_models.Font(width: 1.27, height: 1.27),
          justify: symbol_models.Justify.left,
          hide: true,
        ),
      ),
      symbol_models.Property(
        name: 'Datasheet',
        value: '',
        position: symbol_models.Position(0, 0),
        effects: const symbol_models.TextEffects(
          font: symbol_models.Font(width: 1.27, height: 1.27),
          justify: symbol_models.Justify.left,
          hide: true,
        ),
      ),
    ];

    final newSymbol = SymbolInstance(
      libId: symbolLibId,
      at: symbolPosition,
      uuid: _uuid.v4(),
      properties: properties,
      unit: unit,
      inBom: true,
      onBoard: true,
      dnp: false,
      mirrorx: mirrorX,
      mirrory: mirrorY,
    );

    final updatedInstances = List<SymbolInstance>.from(schematic.symbolInstances)
      ..add(newSymbol);

    return schematic.copyWith(symbolInstances: updatedInstances);
  }

  /// Update an existing symbol instance's properties
  KiCadSchematic updateSymbolInstance({
    required KiCadSchematic schematic,
    required String symbolUuid,
    String? reference,
    String? value,
    symbol_models.Position? position,
    bool? mirrorX,
    bool? mirrorY,
  }) {
    final updatedInstances = schematic.symbolInstances.map((instance) {
      if (instance.uuid != symbolUuid) return instance;

      var updatedInstance = instance;
      
      if (position != null) {
        updatedInstance = updatedInstance.copyWith(at: position);
      }
      
      if (mirrorX != null) {
        updatedInstance = updatedInstance.copyWith(mirrorx: mirrorX);
      }
      
      if (mirrorY != null) {
        updatedInstance = updatedInstance.copyWith(mirrory: mirrorY);
      }
      
      if (reference != null || value != null) {
        final updatedProperties = instance.properties.map((prop) {
          if (prop.name == 'Reference' && reference != null) {
            return symbol_models.Property(
              name: prop.name,
              value: reference,
              position: prop.position,
              effects: prop.effects,
            );
          }
          if (prop.name == 'Value' && value != null) {
            return symbol_models.Property(
              name: prop.name,
              value: value,
              position: prop.position,
              effects: prop.effects,
            );
          }
          return prop;
        }).toList();
        
        updatedInstance = updatedInstance.copyWith(properties: updatedProperties);
      }
      
      return updatedInstance;
    }).toList();

    return schematic.copyWith(symbolInstances: updatedInstances);
  }

  /// Add a wire (connection) between two points
  /// 
  /// Parameters:
  /// - [schematic]: The current schematic
  /// - [points]: List of points defining the wire path
  /// - [strokeWidth]: Wire stroke width (default 0.0 for default width)
  KiCadSchematic addWire({
    required KiCadSchematic schematic,
    required List<symbol_models.Position> points,
    double strokeWidth = 0.0,
  }) {
    if (points.length < 2) {
      throw ArgumentError('Wire must have at least 2 points');
    }

    final newWire = Wire(
      pts: points,
      uuid: _uuid.v4(),
      stroke: symbol_models.Stroke(width: strokeWidth),
    );

    final updatedWires = List<Wire>.from(schematic.wires)..add(newWire);
    return schematic.copyWith(wires: updatedWires);
  }

  /// Add a junction (connection dot) at a specific point
  KiCadSchematic addJunction({
    required KiCadSchematic schematic,
    required symbol_models.Position position,
    double diameter = 0.0,
  }) {
    final newJunction = Junction(
      at: position,
      uuid: _uuid.v4(),
      diameter: diameter,
    );

    final updatedJunctions = List<Junction>.from(schematic.junctions)
      ..add(newJunction);
    return schematic.copyWith(junctions: updatedJunctions);
  }

  /// Add a label (net name) at a specific point
  KiCadSchematic addLabel({
    required KiCadSchematic schematic,
    required String text,
    required symbol_models.Position position,
    symbol_models.TextEffects? effects,
  }) {
    final newLabel = Label(
      text: text,
      at: position,
      uuid: _uuid.v4(),
      effects: effects ?? symbol_models.TextEffects(
        font: symbol_models.Font(width: 1.27, height: 1.27),
        justify: symbol_models.Justify.left,
      ),
    );

    final updatedLabels = List<Label>.from(schematic.labels)..add(newLabel);
    return schematic.copyWith(labels: updatedLabels);
  }

  /// Add a global label (net name visible across sheets)
  KiCadSchematic addGlobalLabel({
    required KiCadSchematic schematic,
    required String text,
    required symbol_models.Position position,
    LabelShape shape = LabelShape.passive,
    symbol_models.TextEffects? effects,
  }) {
    final newGlobalLabel = GlobalLabel(
      text: text,
      shape: shape,
      at: position,
      uuid: _uuid.v4(),
      effects: effects ?? symbol_models.TextEffects(
        font: symbol_models.Font(width: 1.27, height: 1.27),
        justify: symbol_models.Justify.left,
      ),
    );

    final updatedGlobalLabels = List<GlobalLabel>.from(schematic.globalLabels)
      ..add(newGlobalLabel);
    return schematic.copyWith(globalLabels: updatedGlobalLabels);
  }

  /// Add a bus (multi-wire connection)
  KiCadSchematic addBus({
    required KiCadSchematic schematic,
    required List<symbol_models.Position> points,
    double strokeWidth = 0.0,
  }) {
    if (points.length < 2) {
      throw ArgumentError('Bus must have at least 2 points');
    }

    final newBus = Bus(
      pts: points,
      uuid: _uuid.v4(),
      stroke: symbol_models.Stroke(width: strokeWidth),
    );

    final updatedBuses = List<Bus>.from(schematic.buses)..add(newBus);
    return schematic.copyWith(buses: updatedBuses);
  }

  /// Add a bus entry (connection from bus to wire)
  KiCadSchematic addBusEntry({
    required KiCadSchematic schematic,
    required symbol_models.Position position,
    required double width,
    required double height,
    double strokeWidth = 0.0,
  }) {
    final newBusEntry = BusEntry(
      at: position,
      size: Size(width, height),
      uuid: _uuid.v4(),
      stroke: symbol_models.Stroke(width: strokeWidth),
    );

    final updatedBusEntries = List<BusEntry>.from(schematic.busEntries)
      ..add(newBusEntry);
    return schematic.copyWith(busEntries: updatedBusEntries);
  }

  /// Remove a schematic element by UUID
  KiCadSchematic removeElement({
    required KiCadSchematic schematic,
    required String uuid,
  }) {
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

  /// Find elements at or near a position (for selection/editing)
  List<String> findElementsAtPosition({
    required KiCadSchematic schematic,
    required symbol_models.Position position,
    double tolerance = 2.54, // 100 mil in KiCad units
  }) {
    final foundUuids = <String>[];
    
    // Check symbol instances
    for (final symbol in schematic.symbolInstances) {
      final dx = (symbol.at.x - position.x).abs();
      final dy = (symbol.at.y - position.y).abs();
      if (dx <= tolerance && dy <= tolerance) {
        foundUuids.add(symbol.uuid);
      }
    }
    
    // Check junctions
    for (final junction in schematic.junctions) {
      final dx = (junction.at.x - position.x).abs();
      final dy = (junction.at.y - position.y).abs();
      if (dx <= tolerance && dy <= tolerance) {
        foundUuids.add(junction.uuid);
      }
    }
    
    // Check labels
    for (final label in schematic.labels) {
      final dx = (label.at.x - position.x).abs();
      final dy = (label.at.y - position.y).abs();
      if (dx <= tolerance && dy <= tolerance) {
        foundUuids.add(label.uuid);
      }
    }
    
    // Check global labels
    for (final globalLabel in schematic.globalLabels) {
      final dx = (globalLabel.at.x - position.x).abs();
      final dy = (globalLabel.at.y - position.y).abs();
      if (dx <= tolerance && dy <= tolerance) {
        foundUuids.add(globalLabel.uuid);
      }
    }
    
    // Check wires (check if position is on any segment)
    for (final wire in schematic.wires) {
      for (int i = 0; i < wire.pts.length - 1; i++) {
        if (_isPointOnSegment(
          position,
          wire.pts[i],
          wire.pts[i + 1],
          tolerance,
        )) {
          foundUuids.add(wire.uuid);
          break;
        }
      }
    }
    
    return foundUuids;
  }

  /// Check if a point is on a line segment
  bool _isPointOnSegment(
    symbol_models.Position point,
    symbol_models.Position segStart,
    symbol_models.Position segEnd,
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