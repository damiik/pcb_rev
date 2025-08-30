import 'dart:ui';

import 'kicad_symbol_models.dart';

// A KiCad schematic (.kicad_sch) file model
final class KiCadSchematic {
  final String version;
  final String generator;
  final String uuid;
  final KiCadLibrary? library; // Embedded symbols
  final List<SymbolInstance> symbols;
  final List<Wire> wires;
  final List<Bus> buses;
  final List<BusEntry> busEntries;
  final List<Junction> junctions;
  final List<GlobalLabel> globalLabels;
  final List<Label> labels;

  KiCadSchematic({
    required this.version,
    required this.generator,
    required this.uuid,
    this.library,
    required this.symbols,
    required this.wires,
    required this.buses,
    required this.busEntries,
    required this.junctions,
    required this.globalLabels,
    required this.labels,
  });
}

final class SymbolInstance {
  final String libId;
  final Position at;
  final String uuid;
  final List<Property> properties;
  final int unit;
  final bool inBom;
  final bool onBoard;
  final bool dnp;
  final bool mirrorx;
  final bool mirrory;

  SymbolInstance({
    required this.libId,
    required this.at,
    required this.uuid,
    required this.properties,
    required this.unit,
    required this.inBom,
    required this.onBoard,
    required this.dnp,
    this.mirrorx = false,
    this.mirrory = false,
  });
}

final class Wire {
  final List<Position> pts;
  final String uuid;
  final Stroke stroke;

  Wire({required this.pts, required this.uuid, required this.stroke});
}

final class Bus {
  final List<Position> pts;
  final String uuid;
  final Stroke stroke;

  Bus({required this.pts, required this.uuid, required this.stroke});
}

final class Junction {
  final Position at;
  final String uuid;
  final double diameter;

  Junction({required this.at, required this.uuid, required this.diameter});
}

final class BusEntry {
  final Position at;
  final Size size;
  final String uuid;
  final Stroke stroke;

  BusEntry({
    required this.at,
    required this.size,
    required this.uuid,
    required this.stroke,
  });
}

enum LabelShape { input, output, bidirectional, triState, passive }

class GlobalLabel {
  final String text;
  final LabelShape shape;
  final Position at;
  final String uuid;
  final TextEffects effects;

  GlobalLabel({
    required this.text,
    required this.shape,
    required this.at,
    required this.uuid,
    required this.effects,
  });
}

class Label {
  final String text;
  final Position at;
  final String uuid;
  final TextEffects effects;

  Label({
    required this.text,
    required this.at,
    required this.uuid,
    required this.effects,
  });
}