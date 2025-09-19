import 'package:pcb_rev/features/kicad/data/kicad_schematic_models.dart';
import 'package:pcb_rev/features/kicad/data/kicad_symbol_models.dart';
import 'mcp_server.dart';

// Extended MCP Server implementation with schematic manipulation tools
extension SchematicManipulationTools on MCPServer {
  
  // Add this to your existing _toolHandlers map:
  Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> 
      get extendedToolHandlers => {
            // ... existing handlers ...
            'add_symbol': _addSymbol,
            'update_symbol': _updateSymbol,
            'remove_element': _removeElement,
            'add_wire': _addWire,
            'add_junction': _addJunction,
            'add_label': _addLabel,
            'add_global_label': _addGlobalLabel,
            'add_bus': _addBus,
            'add_bus_entry': _addBusEntry,
            'find_elements_at_position': _findElementsAtPosition,
            'batch_add_elements': _batchAddElements,
          };



  /// Add a symbol to the schematic
  Future<Map<String, dynamic>> _addSymbol(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final symbolLibId = args['symbol_lib_id'] as String;
      final reference = args['reference'] as String;
      final value = args['value'] as String;
      final positionData = args['position'] as Map<String, dynamic>;
      final position = Position(
        (positionData['x'] as num).toDouble(),
        (positionData['y'] as num).toDouble(),
        (positionData['angle'] as num?)?.toDouble() ?? 0.0,
      );
      
      final angle = (args['angle'] as num?)?.toDouble() ?? 0.0;
      final mirrorX = args['mirror_x'] as bool? ?? false;
      final mirrorY = args['mirror_y'] as bool? ?? false;
      final unit = args['unit'] as int? ?? 1;

      

      final updatedSchematic = schematicAPI.addSymbolInstance(
        schematic: schematic,
        symbolLibId: symbolLibId,
        reference: reference,
        value: value,
        position: position,
        angle: angle,
        mirrorX: mirrorX,
        mirrorY: mirrorY,
        unit: unit,
      );

      updateSchematic(updatedSchematic);

      // Find the newly added symbol
      final newSymbol = updatedSchematic.symbolInstances.last;

      return {
        'success': true,
        'symbol': {
          'uuid': newSymbol.uuid,
          'lib_id': newSymbol.libId,
          'reference': reference,
          'value': value,
          'position': {
            'x': position.x,
            'y': position.y,
            'angle': position.angle,
          },
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update an existing symbol
  Future<Map<String, dynamic>> _updateSymbol(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final symbolUuid = args['uuid'] as String;
      final reference = args['reference'] as String?;
      final value = args['value'] as String?;
      
      Position? position;
      if (args['position'] != null) {
        final posData = args['position'] as Map<String, dynamic>;
        position = Position(
          (posData['x'] as num).toDouble(),
          (posData['y'] as num).toDouble(),
          (posData['angle'] as num?)?.toDouble() ?? 0.0,
        );
      }
      
      final mirrorX = args['mirror_x'] as bool?;
      final mirrorY = args['mirror_y'] as bool?;

      final updatedSchematic = schematicAPI.updateSymbolInstance(
        schematic: schematic,
        symbolUuid: symbolUuid,
        reference: reference,
        value: value,
        position: position,
        mirrorX: mirrorX,
        mirrorY: mirrorY,
      );

      updateSchematic(updatedSchematic);

      return {
        'success': true,
        'uuid': symbolUuid,
        'updated_fields': {
          if (reference != null) 'reference': reference,
          if (value != null) 'value': value,
          if (position != null) 'position': {
            'x': position.x,
            'y': position.y,
            'angle': position.angle,
          },
          if (mirrorX != null) 'mirror_x': mirrorX,
          if (mirrorY != null) 'mirror_y': mirrorY,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add a wire connection
  Future<Map<String, dynamic>> _addWire(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final pointsList = args['points'] as List<dynamic>;
      final points = pointsList.map((p) {
        final point = p as Map<String, dynamic>;
        return Position(
          (point['x'] as num).toDouble(),
          (point['y'] as num).toDouble(),
          0.0,
        );
      }).toList();
      
      final strokeWidth = (args['stroke_width'] as num?)?.toDouble() ?? 0.0;

      final updatedSchematic = schematicAPI.addWire(
        schematic: schematic,
        points: points,
        strokeWidth: strokeWidth,
      );

      updateSchematic(updatedSchematic);
      
      final newWire = updatedSchematic.wires.last;

      return {
        'success': true,
        'wire': {
          'uuid': newWire.uuid,
          'points': points.map((p) => {'x': p.x, 'y': p.y}).toList(),
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add a junction
  Future<Map<String, dynamic>> _addJunction(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final positionData = args['position'] as Map<String, dynamic>;
      final position = Position(
        (positionData['x'] as num).toDouble(),
        (positionData['y'] as num).toDouble(),
        0.0,
      );
      
      final diameter = (args['diameter'] as num?)?.toDouble() ?? 0.0;

      final updatedSchematic = schematicAPI.addJunction(
        schematic: schematic,
        position: position,
        diameter: diameter,
      );

      updateSchematic(updatedSchematic);
      
      final newJunction = updatedSchematic.junctions.last;

      return {
        'success': true,
        'junction': {
          'uuid': newJunction.uuid,
          'position': {'x': position.x, 'y': position.y},
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add a label
  Future<Map<String, dynamic>> _addLabel(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final text = args['text'] as String;
      final positionData = args['position'] as Map<String, dynamic>;
      final position = Position(
        (positionData['x'] as num).toDouble(),
        (positionData['y'] as num).toDouble(),
        (positionData['angle'] as num?)?.toDouble() ?? 0.0,
      );

      final updatedSchematic = schematicAPI.addLabel(
        schematic: schematic,
        text: text,
        position: position,
      );

      updateSchematic(updatedSchematic);
      
      final newLabel = updatedSchematic.labels.last;

      return {
        'success': true,
        'label': {
          'uuid': newLabel.uuid,
          'text': text,
          'position': {
            'x': position.x,
            'y': position.y,
            'angle': position.angle,
          },
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add a global label
  Future<Map<String, dynamic>> _addGlobalLabel(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final text = args['text'] as String;
      final positionData = args['position'] as Map<String, dynamic>;
      final position = Position(
        (positionData['x'] as num).toDouble(),
        (positionData['y'] as num).toDouble(),
        (positionData['angle'] as num?)?.toDouble() ?? 0.0,
      );
      
      final shapeStr = args['shape'] as String? ?? 'passive';
      final shape = LabelShape.values.firstWhere(
        (s) => s.name == shapeStr,
        orElse: () => LabelShape.passive,
      );

      final updatedSchematic = schematicAPI.addGlobalLabel(
        schematic: schematic,
        text: text,
        position: position,
        shape: shape,
      );

      updateSchematic(updatedSchematic);
      
      final newLabel = updatedSchematic.globalLabels.last;

      return {
        'success': true,
        'global_label': {
          'uuid': newLabel.uuid,
          'text': text,
          'shape': shape.name,
          'position': {
            'x': position.x,
            'y': position.y,
            'angle': position.angle,
          },
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add a bus
  Future<Map<String, dynamic>> _addBus(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final pointsList = args['points'] as List<dynamic>;
      final points = pointsList.map((p) {
        final point = p as Map<String, dynamic>;
        return Position(
          (point['x'] as num).toDouble(),
          (point['y'] as num).toDouble(),
          0.0,
        );
      }).toList();
      
      final strokeWidth = (args['stroke_width'] as num?)?.toDouble() ?? 0.0;

      final updatedSchematic = schematicAPI.addBus(
        schematic: schematic,
        points: points,
        strokeWidth: strokeWidth,
      );

      updateSchematic(updatedSchematic);
      
      final newBus = updatedSchematic.buses.last;

      return {
        'success': true,
        'bus': {
          'uuid': newBus.uuid,
          'points': points.map((p) => {'x': p.x, 'y': p.y}).toList(),
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add a bus entry
  Future<Map<String, dynamic>> _addBusEntry(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final positionData = args['position'] as Map<String, dynamic>;
      final position = Position(
        (positionData['x'] as num).toDouble(),
        (positionData['y'] as num).toDouble(),
        0.0,
      );
      
      final sizeData = args['size'] as Map<String, dynamic>;
      // final size = Size(
      //   (sizeData['width'] as num).toDouble(),
      //   (sizeData['height'] as num).toDouble(),
      // );
      final width = (sizeData['width'] as num).toDouble();
      final height = (sizeData['height'] as num).toDouble();
      
      final strokeWidth = (args['stroke_width'] as num?)?.toDouble() ?? 0.0;

      final updatedSchematic = schematicAPI.addBusEntry(
        schematic: schematic,
        position: position,
        width: width,
        height: height,
        strokeWidth: strokeWidth,
      );

      updateSchematic(updatedSchematic);
      
      final newBusEntry = updatedSchematic.busEntries.last;

      return {
        'success': true,
        'bus_entry': {
          'uuid': newBusEntry.uuid,
          'position': {'x': position.x, 'y': position.y},
          'size': {'width': width, 'height': height},
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Remove an element by UUID
  Future<Map<String, dynamic>> _removeElement(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final uuid = args['uuid'] as String;

      final updatedSchematic = schematicAPI.removeElement(
        schematic: schematic,
        uuid: uuid,
      );

      updateSchematic(updatedSchematic);

      return {
        'success': true,
        'removed_uuid': uuid,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Find elements at a position
  Future<Map<String, dynamic>> _findElementsAtPosition(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final positionData = args['position'] as Map<String, dynamic>;
      final position = Position(
        (positionData['x'] as num).toDouble(),
        (positionData['y'] as num).toDouble(),
        0.0,
      );
      
      final tolerance = (args['tolerance'] as num?)?.toDouble() ?? 2.54;

      final foundUuids = schematicAPI.findElementsAtPosition(
        schematic: schematic,
        position: position,
        tolerance: tolerance,
      );

      // Get details of found elements
      final elements = <Map<String, dynamic>>[];
      
      for (final uuid in foundUuids) {
        // Check symbols
        final symbol = schematic.symbolInstances.firstWhereOrNull(
          (s) => s.uuid == uuid,
        );
        if (symbol != null) {
          elements.add({
            'type': 'symbol',
            'uuid': uuid,
            'lib_id': symbol.libId,
            'reference': symbol.getProperty('Reference'),
            'value': symbol.getProperty('Value'),
          });
          continue;
        }
        
        // Check wires
        final wire = schematic.wires.firstWhereOrNull(
          (w) => w.uuid == uuid,
        );
        if (wire != null) {
          elements.add({
            'type': 'wire',
            'uuid': uuid,
            'points': wire.pts.map((p) => {'x': p.x, 'y': p.y}).toList(),
          });
          continue;
        }
        
        // Check junctions
        final junction = schematic.junctions.firstWhereOrNull(
          (j) => j.uuid == uuid,
        );
        if (junction != null) {
          elements.add({
            'type': 'junction',
            'uuid': uuid,
            'position': {'x': junction.at.x, 'y': junction.at.y},
          });
          continue;
        }
        
        // Check labels
        final label = schematic.labels.firstWhereOrNull(
          (l) => l.uuid == uuid,
        );
        if (label != null) {
          elements.add({
            'type': 'label',
            'uuid': uuid,
            'text': label.text,
            'position': {'x': label.at.x, 'y': label.at.y},
          });
          continue;
        }
        
        // Check global labels
        final globalLabel = schematic.globalLabels.firstWhereOrNull(
          (gl) => gl.uuid == uuid,
        );
        if (globalLabel != null) {
          elements.add({
            'type': 'global_label',
            'uuid': uuid,
            'text': globalLabel.text,
            'shape': globalLabel.shape.name,
            'position': {'x': globalLabel.at.x, 'y': globalLabel.at.y},
          });
        }
      }

      return {
        'success': true,
        'position': {
          'x': position.x,
          'y': position.y,
        },
        'tolerance': tolerance,
        'elements': elements,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Batch add multiple elements in a single operation
  Future<Map<String, dynamic>> _batchAddElements(Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'success': false,
        'error': 'No schematic loaded',
      };
    }

    try {
      final operations = args['operations'] as List<dynamic>;
      var currentSchematic = schematic;
      final results = <Map<String, dynamic>>[];

      for (final op in operations) {
        final operation = op as Map<String, dynamic>;
        final type = operation['type'] as String;
        final data = operation['data'] as Map<String, dynamic>;

        switch (type) {
          case 'symbol':
            currentSchematic = schematicAPI.addSymbolInstance(
              schematic: currentSchematic,
              symbolLibId: data['symbol_lib_id'] as String,
              reference: data['reference'] as String,
              value: data['value'] as String,
              position: Position(
                (data['x'] as num).toDouble(),
                (data['y'] as num).toDouble(),
                (data['angle'] as num?)?.toDouble() ?? 0.0,
              ),
            );
            results.add({'type': 'symbol', 'uuid': currentSchematic.symbolInstances.last.uuid});
            break;

          case 'wire':
            final points = (data['points'] as List).map((p) =>
              Position(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
                0.0,
              ),
            ).toList();
            currentSchematic = schematicAPI.addWire(
              schematic: currentSchematic,
              points: points,
            );
            results.add({'type': 'wire', 'uuid': currentSchematic.wires.last.uuid});
            break;

          case 'junction':
            currentSchematic = schematicAPI.addJunction(
              schematic: currentSchematic,
              position: Position(
                (data['x'] as num).toDouble(),
                (data['y'] as num).toDouble(),
                0.0,
              ),
            );
            results.add({'type': 'junction', 'uuid': currentSchematic.junctions.last.uuid});
            break;

          case 'label':
            currentSchematic = schematicAPI.addLabel(
              schematic: currentSchematic,
              text: data['text'] as String,
              position: Position(
                (data['x'] as num).toDouble(),
                (data['y'] as num).toDouble(),
                (data['angle'] as num?)?.toDouble() ?? 0.0,
              ),
            );
            results.add({'type': 'label', 'uuid': currentSchematic.labels.last.uuid});
            break;
        }
      }

      updateSchematic(currentSchematic);

      return {
        'success': true,
        'elements_added': results.length,
        'results': results,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

// Extension helper method - add this if it doesn't exist
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
