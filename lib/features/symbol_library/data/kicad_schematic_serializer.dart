import 'dart:ui';

import 'kicad_schematic_models.dart';
import 'kicad_symbol_models.dart';

Map<String, dynamic> kiCadSchematicToJson(KiCadSchematic schematic) {
  return {
    'version': schematic.version,
    'generator': schematic.generator,
    'uuid': schematic.uuid,
    'library': schematic.library != null ? kiCadLibraryToJson(schematic.library!) : null,
    'symbol_instances': schematic.symbolInstances.map((e) => symbolInstanceToJson(e)).toList(),
    'wires': schematic.wires.map((e) => wireToJson(e)).toList(),
    'buses': schematic.buses.map((e) => busToJson(e)).toList(),
    'bus_entries': schematic.busEntries.map((e) => busEntryToJson(e)).toList(),
    'junctions': schematic.junctions.map((e) => junctionToJson(e)).toList(),
    'global_labels': schematic.globalLabels.map((e) => globalLabelToJson(e)).toList(),
    'labels': schematic.labels.map((e) => labelToJson(e)).toList(),
  };
}

Map<String, dynamic> symbolInstanceToJson(SymbolInstance instance) {
  return {
    'lib_id': instance.libId,
    'at': positionToJson(instance.at),
    'uuid': instance.uuid,
    'properties': instance.properties.map((e) => propertyToJson(e)).toList(),
    'unit': instance.unit,
    'in_bom': instance.inBom,
    'on_board': instance.onBoard,
    'dnp': instance.dnp,
    'mirrorx': instance.mirrorx,
    'mirrory': instance.mirrory,
  };
}

Map<String, dynamic> wireToJson(Wire wire) {
  return {
    'pts': wire.pts.map((e) => positionToJson(e)).toList(),
    'uuid': wire.uuid,
    'stroke': strokeToJson(wire.stroke),
  };
}

Map<String, dynamic> busToJson(Bus bus) {
  return {
    'pts': bus.pts.map((e) => positionToJson(e)).toList(),
    'uuid': bus.uuid,
    'stroke': strokeToJson(bus.stroke),
  };
}

Map<String, dynamic> junctionToJson(Junction junction) {
  return {
    'at': positionToJson(junction.at),
    'uuid': junction.uuid,
    'diameter': junction.diameter,
  };
}

Map<String, dynamic> busEntryToJson(BusEntry entry) {
  return {
    'at': positionToJson(entry.at),
    'size': sizeToJson(entry.size),
    'uuid': entry.uuid,
    'stroke': strokeToJson(entry.stroke),
  };
}

Map<String, dynamic> globalLabelToJson(GlobalLabel label) {
  return {
    'text': label.text,
    'shape': label.shape.name,
    'at': positionToJson(label.at),
    'uuid': label.uuid,
    'effects': textEffectsToJson(label.effects),
  };
}

Map<String, dynamic> labelToJson(Label label) {
  return {
    'text': label.text,
    'at': positionToJson(label.at),
    'uuid': label.uuid,
    'effects': textEffectsToJson(label.effects),
  };
}

// Helper functions from kicad_symbol_models serialization (should be shared)

Map<String, dynamic> kiCadLibraryToJson(KiCadLibrary library) {
  // For embedded libraries, there's no file name, so we invent one.
  final libraryName = library.name ?? '_embedded_';
  return {
    'name': libraryName,
    'symbols': library.librarySymbols.map((e) => librarySymbolToJson(e)).toList(),
  };
}

Map<String, dynamic> librarySymbolToJson(LibrarySymbol symbol) {
  final description = symbol.properties
      .firstWhere((p) => p.name == 'Description', orElse: () => Property(name: 'Description', value: '', position: Position(0,0), effects: TextEffects(font: Font(width: 0, height: 0), justify: Justify.center)))
      .value;

  return {
    'name': symbol.name,
    'description': description,
    'in_bom': symbol.inBom,
    'on_board': symbol.onBoard,
    'properties_count': symbol.properties.length,
    'units_count': symbol.units.length,
  };
}

Map<String, dynamic> propertyToJson(Property prop) {
  return {
    'name': prop.name,
    'value': prop.value,
    'position': positionToJson(prop.position),
    'effects': textEffectsToJson(prop.effects),
  };
}

Map<String, dynamic> positionToJson(Position pos) {
  return {'x': pos.x, 'y': pos.y, 'angle': pos.angle};
}

Map<String, dynamic> textEffectsToJson(TextEffects effects) {
  return {
    'font': {'width': effects.font.width, 'height': effects.font.height},
    'justify': effects.justify.name,
    'hide': effects.hide,
  };
}

Map<String, dynamic> strokeToJson(Stroke stroke) {
  return {
    'width': stroke.width,
  };
}

Map<String, dynamic> sizeToJson(Size size) {
  return {'width': size.width, 'height': size.height};
}
