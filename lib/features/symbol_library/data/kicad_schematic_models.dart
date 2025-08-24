import 'kicad_symbol_models.dart';

// A KiCad schematic (.kicad_sch) file model
final class KiCadSchematic {
  final String version;
  final String generator;
  final String uuid;
  final KiCadLibrary? library; // Embedded symbols
  final List<SymbolInstance> symbols;
  final List<Wire> wires;
  final List<Junction> junctions;

  KiCadSchematic({
    required this.version,
    required this.generator,
    required this.uuid,
    this.library,
    required this.symbols,
    required this.wires,
    required this.junctions,
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

final class Junction {
  final Position at;
  final String uuid;
  final double diameter;

  Junction({required this.at, required this.uuid, required this.diameter});
}
