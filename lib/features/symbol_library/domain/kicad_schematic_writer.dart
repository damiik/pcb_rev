import '../data/kicad_schematic_models.dart';
import '../data/kicad_symbol_models.dart' as symbol_models;

String justifyToString(symbol_models.Justify j) =>
  switch (j) {
    symbol_models.Justify.left => 'left',
    symbol_models.Justify.right => 'right',
    symbol_models.Justify.center => 'center',
    symbol_models.Justify.top => 'top',
    symbol_models.Justify.bottom => 'bottom',
    symbol_models.Justify.topLeft => 'top left',
    symbol_models.Justify.topRight => 'top right',
    symbol_models.Justify.bottomLeft => 'bottom left',
    symbol_models.Justify.bottomRight => 'bottom right',
  };

String pinTypeToString(symbol_models.PinType type) => switch (type) {
  symbol_models.PinType.input => 'input',
  symbol_models.PinType.output => 'output',
  symbol_models.PinType.bidirectional => 'bidirectional',
  symbol_models.PinType.tristate => 'tri_state',
  symbol_models.PinType.passive => 'passive',
  symbol_models.PinType.powerIn => 'power_in',
  symbol_models.PinType.powerOut => 'power_out',
  symbol_models.PinType.openCollector => 'open_collector',
  symbol_models.PinType.openEmitter => 'open_emitter',
  symbol_models.PinType.notConnected => 'no_connect',
  _ => 'unknown',
};

String generateKiCadSchematicFileContent(KiCadSchematic schematic) {
  final buffer = StringBuffer();

  buffer.writeln('(kicad_sch (version ${schematic.version}) (generator ${schematic.generator}) (generator_version "9.0")');
  buffer.writeln('  (uuid ${schematic.uuid})');
  buffer.writeln('  (paper "A4")');

  // TODO: Add title block, etc.

  if (schematic.library != null) {
    buffer.write(_generateLibrarySymbols(schematic.library!));
  }

  for (final symbol in schematic.symbols) {
    buffer.write(_generateSymbolInstance(symbol));
  }

  for (final wire in schematic.wires) {
    buffer.write(_generateWire(wire));
  }
  
  for (final bus in schematic.buses) {
    buffer.write(_generateBus(bus));
  }

  for (final entry in schematic.busEntries) {
    buffer.write(_generateBusEntry(entry));
  }

  for (final junction in schematic.junctions) {
    buffer.write(_generateJunction(junction));
  }

  for (final label in schematic.globalLabels) {
    buffer.write(_generateGlobalLabel(label));
  }
  
  for (final label in schematic.labels) {
    buffer.write(_generateLabel(label));
  }

  buffer.writeln(')');

  return buffer.toString();
}

String _generateLibrarySymbols(symbol_models.KiCadLibrary library) {
  final buffer = StringBuffer();
  buffer.writeln('  (lib_symbols');
  for (final symbol in library.symbols) {
    buffer.write(_generateSymbolDefinition(symbol));
  }
  buffer.writeln('  )');
  return buffer.toString();
}

String _generateSymbolDefinition(symbol_models.Symbol symbol) {
  final buffer = StringBuffer();
  buffer.writeln('    (symbol "${symbol.name}" (pin_names (offset ${symbol.pinNames.offset})) (in_bom ${symbol.inBom ? 'yes' : 'no'}) (on_board ${symbol.onBoard ? 'yes' : 'no'})');

  for (final prop in symbol.properties) {
    buffer.write(_generateProperty(prop));
  }

  for (final unit in symbol.units) {
    buffer.write(_generateSymbolUnit(unit));
  }

  buffer.writeln('    )');
  return buffer.toString();
}

String _generateSymbolUnit(symbol_models.SymbolUnit unit) {
  final buffer = StringBuffer();
  buffer.writeln('      (symbol "${unit.name}"');

  for (final graphic in unit.graphics) {
    buffer.write(_generateGraphicElement(graphic));
  }

  for (final pin in unit.pins) {
    buffer.write(_generatePin(pin));
  }

  buffer.writeln('      )');
  return buffer.toString();
}

String _generateGraphicElement(symbol_models.GraphicElement element) {
  switch (element) {
    case symbol_models.Rectangle():
      return _generateRectangle(element);
    case symbol_models.Circle():
      return _generateCircle(element);
    case symbol_models.Polyline():
      return _generatePolyline(element);
    case symbol_models.Arc():
      return _generateArc(element);
    default:
      return '';
  }
}

String _generateRectangle(symbol_models.Rectangle rect) {
  return '''        (rectangle (start ${rect.start.x} ${rect.start.y}) (end ${rect.end.x} ${rect.end.y})
          ${_generateStroke(rect.stroke)}
          ${_generateFill(rect.fill)}
        )
''';
}

String _generateCircle(symbol_models.Circle circle) {
  return '''        (circle (center ${circle.center.x} ${circle.center.y}) (radius ${circle.radius})
          ${_generateStroke(circle.stroke)}
          ${_generateFill(circle.fill)}
        )
''';
}

String _generatePolyline(symbol_models.Polyline poly) {
  final ptsString = poly.points.map(_generateXY).join(' ');
  return '''        (polyline (pts $ptsString)
          ${_generateStroke(poly.stroke)}
          ${_generateFill(poly.fill)}
        )
''';
}

String _generateArc(symbol_models.Arc arc) {
    return '''        (arc (start ${arc.start.x} ${arc.start.y}) (mid ${arc.mid.x} ${arc.mid.y}) (end ${arc.end.x} ${arc.end.y})
          ${_generateStroke(arc.stroke)}
          ${_generateFill(arc.fill)}
        )
''';
}

String _generatePin(symbol_models.Pin pin) {
  // final type = pin.type.toString().split('.').last.replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_' + match.group(0)!.toLowerCase());
  final style = pin.style.toString().split('.').last;
  return '''        (pin ${pinTypeToString(pin.type)} $style (at ${pin.position.x} ${pin.position.y} ${pin.angle}) (length ${pin.length})
          (name "${pin.name}" ${_generateTextEffects(pin.nameEffects)})
          (number "${pin.number}" ${_generateTextEffects(pin.numberEffects)})
        )
''';
}

String _generateFill(symbol_models.Fill fill) {
  return '(fill (type ${fill.type.name}))';
}

String _quote(String value) {
  if (value.contains(' ') && !value.startsWith('"') && !value.endsWith('"')) {
    return '"$value"';
  }
  return value;
}


String _generateSymbolInstance(SymbolInstance symbol) {
  final buffer = StringBuffer();
  buffer.writeln('  (symbol (lib_id "${symbol.libId}") ${_generatePosition(symbol.at)} (unit ${symbol.unit})');
  buffer.writeln('    (in_bom ${symbol.inBom ? 'yes' : 'no'}) (on_board ${symbol.onBoard ? 'yes' : 'no'}) (dnp ${symbol.dnp ? 'yes' : 'no'})');
  buffer.writeln('    (uuid ${symbol.uuid})');

  for (final prop in symbol.properties) {
    buffer.write(_generateProperty(prop));
  }

  // TODO: Add pin mappings if necessary, as the data model does not currently support them.

  buffer.writeln('  )');
  return buffer.toString();
}

String _generateProperty(symbol_models.Property prop) {
  final propertyValue = prop.value.contains('"') ? prop.value.replaceAll('"', '\\"') : prop.value;
  return '''    (property "${prop.name}" "${propertyValue}" (id ${prop.id}) ${_generatePosition(prop.position)}
      ${_generateTextEffects(prop.effects)}
    )
''';
}

String _generateWire(Wire wire) {
  final ptsString = wire.pts.map(_generateXY).join(' ');
  return '''  (wire (pts $ptsString) (uuid ${wire.uuid})
    ${_generateStroke(wire.stroke)}
  )
''';
}

String _generateBus(Bus bus) {
    final ptsString = bus.pts.map(_generateXY).join(' ');
    return '''  (bus (pts $ptsString) (uuid ${bus.uuid})
    ${_generateStroke(bus.stroke)}
  )
''';
}

String _generateBusEntry(BusEntry entry) {
    return '''  (bus_entry ${_generateXYPosition(entry.at)} (size ${entry.size.width} ${entry.size.height}) (uuid ${entry.uuid})
    ${_generateStroke(entry.stroke)}
  )
''';
}

String _generateJunction(Junction junction) {
  return '  (junction ${_generateXYPosition(junction.at)} (diameter ${junction.diameter}) (uuid ${junction.uuid}))\n';
}

String _generateGlobalLabel(GlobalLabel label) {
  return '''  (global_label "${label.text}" (shape ${label.shape.name}) ${_generatePosition(label.at)} (uuid ${label.uuid})
    ${_generateTextEffects(label.effects)}
  )
''';
}

String _generateLabel(Label label) {
    return '''  (label "${label.text}" ${_generatePosition(label.at)} (uuid ${label.uuid})
      ${_generateTextEffects(label.effects)}
  )
''';
}


String _generatePosition(symbol_models.Position pos) {
  return '(at ${pos.x} ${pos.y} ${pos.angle})';
}

String _generateXYPosition(symbol_models.Position pos) {
  return '(at ${pos.x} ${pos.y})';
}

String _generateXY(symbol_models.Position pos) {
    return '(xy ${pos.x} ${pos.y})';
}

String _generateStroke(symbol_models.Stroke stroke) {
  return '(stroke (width ${stroke.width}) (type default) )';
}

String _generateTextEffects(symbol_models.TextEffects effects) {
  final hide = effects.hide ? ' hide' : '';
  return '(effects (font (size ${effects.font.width} ${effects.font.height})) $hide)';
}
String _generateTextEffects2(symbol_models.TextEffects effects) {
  final hide = effects.hide ? ' (hide yes)' : '';
  return '(effects (font (size ${effects.font.width} ${effects.font.height})) (justify ${justifyToString(effects.justify)}) $hide)';
}
