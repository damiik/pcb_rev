// --- Position ---
typedef Position = ({double x, double y});
Map<String, dynamic> positionToJson(Position p) => {'x': p.x, 'y': p.y};
Position positionFromJson(Map<String, dynamic> json) => (x: json['x'] as double, y: json['y'] as double);

// --- VisualSymbolPlacement ---
// Represents a component instance on a schematic view.
typedef VisualSymbolPlacement = ({
  String id, // Unique ID for this symbol instance
  String logicalComponentId,
  Position position,
  double rotation,
});
Map<String, dynamic> visualSymbolPlacementToJson(VisualSymbolPlacement s) => {
  'id': s.id,
  'logicalComponentId': s.logicalComponentId,
  'position': positionToJson(s.position),
  'rotation': s.rotation,
};
VisualSymbolPlacement visualSymbolPlacementFromJson(Map<String, dynamic> json) => (
  id: json['id'] as String,
  logicalComponentId: json['logicalComponentId'] as String,
  position: positionFromJson(json['position'] as Map<String, dynamic>),
  rotation: json['rotation'] as double,
);