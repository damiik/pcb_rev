// --- Position ---
typedef Position = ({double x, double y});
Map<String, dynamic> positionToJson(Position p) => {'x': p.x, 'y': p.y};
Position positionFromJson(Map<String, dynamic> json) => (x: json['x'] as double, y: json['y'] as double);

// --- Size ---
typedef Size = ({double width, double height});
Map<String, dynamic> sizeToJson(Size s) => {'width': s.width, 'height': s.height};
Size sizeFromJson(Map<String, dynamic> json) => (width: json['width'] as double, height: json['height'] as double);

// --- SymbolInstance ---
// Represents a component instance on a schematic view.
typedef SymbolInstance = ({
  String id, // Unique ID for this symbol instance
  String logicalComponentId,
  Position position,
  double rotation,
});
Map<String, dynamic> symbolInstanceToJson(SymbolInstance s) => {
  'id': s.id,
  'logicalComponentId': s.logicalComponentId,
  'position': positionToJson(s.position),
  'rotation': s.rotation,
};
SymbolInstance symbolInstanceFromJson(Map<String, dynamic> json) => (
  id: json['id'] as String,
  logicalComponentId: json['logicalComponentId'] as String,
  position: positionFromJson(json['position'] as Map<String, dynamic>),
  rotation: json['rotation'] as double,
);

// --- Wire ---
// Represents a visual connection segment on a schematic view.
typedef Wire = ({
  String logicalNetId,
  List<Position> points
});
Map<String, dynamic> wireToJson(Wire w) => {
  'logicalNetId': w.logicalNetId,
  'points': w.points.map((p) => positionToJson(p)).toList(),
};
Wire wireFromJson(Map<String, dynamic> json) => (
  logicalNetId: json['logicalNetId'] as String,
  points: (json['points'] as List<dynamic>).map((p) => positionFromJson(p as Map<String, dynamic>)).toList(),
);

// --- SchematicView ---
typedef SchematicView = ({
  Map<String, SymbolInstance> symbolInstances,
  Map<String, Wire> wires, // Key is the logicalNetId
});

Map<String, dynamic> schematicViewToJson(SchematicView s) => {
  'symbolInstances': s.symbolInstances.map((k, v) => MapEntry(k, symbolInstanceToJson(v))),
  'wires': s.wires.map((k, v) => MapEntry(k, wireToJson(v))),
};

SchematicView schematicViewFromJson(Map<String, dynamic> json) => (
  symbolInstances: (json['symbolInstances'] as Map<String, dynamic>).map((k, v) => MapEntry(k, symbolInstanceFromJson(v as Map<String, dynamic>))),
  wires: (json['wires'] as Map<String, dynamic>).map((k, v) => MapEntry(k, wireFromJson(v as Map<String, dynamic>))),
);