import 'dart:ui';

import 'kicad_symbol_models.dart';

// A KiCad schematic (.kicad_sch) file model
final class KiCadSchematic {
  final String version;
  final String generator;
  final String uuid;
  final KiCadLibrary? library; // Embedded symbols
  final List<SymbolInstance> symbolInstances;
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
    required this.symbolInstances,
    required this.wires,
    required this.buses,
    required this.busEntries,
    required this.junctions,
    required this.globalLabels,
    required this.labels,
  });

  KiCadSchematic copyWith({
    String? version,
    String? generator,
    String? uuid,
    KiCadLibrary? library,
    List<SymbolInstance>? symbolInstances,
    List<Wire>? wires,
    List<Bus>? buses,
    List<BusEntry>? busEntries,
    List<Junction>? junctions,
    List<GlobalLabel>? globalLabels,
    List<Label>? labels,
  }) {
    return KiCadSchematic(
      version: version ?? this.version,
      generator: generator ?? this.generator,
      uuid: uuid ?? this.uuid,
      library: library ?? this.library,
      symbolInstances: symbolInstances ?? this.symbolInstances,
      wires: wires ?? this.wires,
      buses: buses ?? this.buses,
      busEntries: busEntries ?? this.busEntries,
      junctions: junctions ?? this.junctions,
      globalLabels: globalLabels ?? this.globalLabels,
      labels: labels ?? this.labels,
    );
  }
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

  SymbolInstance copyWith({
    String? libId,
    Position? at,
    String? uuid,
    List<Property>? properties,
    int? unit,
    bool? inBom,
    bool? onBoard,
    bool? dnp,
    bool? mirrorx,
    bool? mirrory,
  }) {
    return SymbolInstance(
      libId: libId ?? this.libId,
      at: at ?? this.at,
      uuid: uuid ?? this.uuid,
      properties: properties ?? this.properties,
      unit: unit ?? this.unit,
      inBom: inBom ?? this.inBom,
      onBoard: onBoard ?? this.onBoard,
      dnp: dnp ?? this.dnp,
      mirrorx: mirrorx ?? this.mirrorx,
      mirrory: mirrory ?? this.mirrory,
    );
  }
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