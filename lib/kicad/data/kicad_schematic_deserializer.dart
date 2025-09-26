import 'dart:ui';

import 'kicad_schematic_models.dart';
import 'kicad_symbol_models.dart';

// Note: These deserializers assume the JSON format produced by kicad_schematic_serializer.dart

SymbolInstance symbolInstanceFromJson(Map<String, dynamic> json) {
  return SymbolInstance(
    libId: json['lib_id'] as String,
    at: positionFromJson(json['at'] as Map<String, dynamic>),
    uuid: json['uuid'] as String,
    properties: (json['properties'] as List<dynamic>)
        .map((e) => propertyFromJson(e as Map<String, dynamic>))
        .toList(),
    unit: json['unit'] as int,
    inBom: json['in_bom'] as bool,
    onBoard: json['on_board'] as bool,
    dnp: json['dnp'] as bool,
    mirrorx: json['mirrorx'] as bool? ?? false,
    mirrory: json['mirrory'] as bool? ?? false,
  );
}

Wire wireFromJson(Map<String, dynamic> json) {
  return Wire(
    pts: (json['pts'] as List<dynamic>)
        .map((e) => positionFromJson(e as Map<String, dynamic>))
        .toList(),
    uuid: json['uuid'] as String,
    stroke: strokeFromJson(json['stroke'] as Map<String, dynamic>),
  );
}

// Helper Deserializers

Position positionFromJson(Map<String, dynamic> json) {
  return Position(
    (json['x'] as num).toDouble(),
    (json['y'] as num).toDouble(),
    (json['angle'] as num?)?.toDouble() ?? 0.0,
  );
}

Property propertyFromJson(Map<String, dynamic> json) {
  return Property(
    name: json['name'] as String,
    value: json['value'] as String,
    position: positionFromJson(json['position'] as Map<String, dynamic>),
    effects: textEffectsFromJson(json['effects'] as Map<String, dynamic>),
  );
}

TextEffects textEffectsFromJson(Map<String, dynamic> json) {
  return TextEffects(
    font: fontFromJson(json['font'] as Map<String, dynamic>),
    justify: Justify.values.firstWhere((e) => e.name == json['justify'] as String, orElse: () => Justify.center),
    hide: json['hide'] as bool? ?? false,
  );
}

Font fontFromJson(Map<String, dynamic> json) {
  return Font(
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );
}

Stroke strokeFromJson(Map<String, dynamic> json) {
  return Stroke(
    width: (json['width'] as num).toDouble(),
    // type and color are not in the model, so we ignore them for now.
  );
}
