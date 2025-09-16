import 'visual_models.dart';

// --- ConnectionPoint ---
typedef ConnectionPoint = ({String componentId, String pinId});
Map<String, dynamic> connectionPointToJson(ConnectionPoint cp) => {
  'componentId': cp.componentId,
  'pinId': cp.pinId,
};
ConnectionPoint connectionPointFromJson(Map<String, dynamic> json) => (
  componentId: json['componentId'] as String,
  pinId: json['pinId'] as String,
);


// --- Pin ---
typedef Pin = ({
  String id,
  String? function,
  String? netName,
  Position position,
});
Map<String, dynamic> pinToJson(Pin p) => {
  'id': p.id,
  'function': p.function,
  'netName': p.netName,
  'position': positionToJson(p.position),
};
Pin pinFromJson(Map<String, dynamic> json) => (
  id: json['id'] as String,
  function: json['function'] as String?,
  netName: json['netName'] as String?,
  position: positionFromJson(json['position'] as Map<String, dynamic>),
);

// --- LogicalComponent ---
typedef LogicalComponent = ({
  String id,
  String type,
  String? variant,
  String? value,
  String? partNumber,
  Map<String, Pin> pins,
});
Map<String, dynamic> logicalComponentToJson(LogicalComponent c) => {
      'id': c.id,
      'type': c.type,
      'variant': c.variant,
      'value': c.value,
      'partNumber': c.partNumber,
      'pins': c.pins.map((k, v) => MapEntry(k, pinToJson(v))),
    };
LogicalComponent logicalComponentFromJson(Map<String, dynamic> json) => (
      id: json['id'] as String,
      type: json['type'] as String,
      variant: json['variant'] as String?,
      value: json['value'] as String?,
      partNumber: json['partNumber'] as String?,
      pins: (json['pins'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, pinFromJson(v as Map<String, dynamic>)),
      ),
    );

// --- LogicalNet ---
typedef LogicalNet = ({
  String id,
  String name,
  List<ConnectionPoint> connections,
});
Map<String, dynamic> logicalNetToJson(LogicalNet n) => {
  'id': n.id,
  'name': n.name,
  'connections': n.connections.map((c) => connectionPointToJson(c)).toList(),
};
LogicalNet logicalNetFromJson(Map<String, dynamic> json) => (
  id: json['id'] as String,
  name: json['name'] as String,
  connections: (json['connections'] as List<dynamic>)
      .map((c) => connectionPointFromJson(c as Map<String, dynamic>))
      .toList(),
);
