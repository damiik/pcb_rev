typedef Position = ({double x, double y});

Map<String, dynamic> positionToJson(Position p) => {'x': p.x, 'y': p.y};

Position positionFromJson(Map<String, dynamic> json) => (x: json['x'] as double, y: json['y'] as double);

typedef ConnectionPoint = ({String componentId, String pinId});

Map<String, dynamic> connectionPointToJson(ConnectionPoint cp) => {'componentId': cp.componentId, 'pinId': cp.pinId};
ConnectionPoint connectionPointFromJson(Map<String, dynamic> json) => (componentId: json['componentId'] as String, pinId: json['pinId'] as String);
String connectionPointToString(ConnectionPoint cp) => '${cp.componentId}.${cp.pinId}';


typedef Pin = ({String id, String? function, String? netName, Position position});

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

typedef Net = ({
  String name,
  List<ConnectionPoint> connections,
  double? measuredResistance,
  double? measuredVoltage
});

Map<String, dynamic> netToJson(Net n) => {
      'name': n.name,
      'connections': n.connections.map((c) => connectionPointToJson(c)).toList(),
      'measuredResistance': n.measuredResistance,
      'measuredVoltage': n.measuredVoltage,
    };
Net netFromJson(Map<String, dynamic> json) => (
      name: json['name'] as String,
      connections: (json['connections'] as List<dynamic>)
          .map((c) => connectionPointFromJson(c as Map<String, dynamic>))
          .toList(),
      measuredResistance: json['measuredResistance'] as double?,
      measuredVoltage: json['measuredVoltage'] as double?,
    );

typedef Component = ({
  String id,
  String type,
  String? value,
  String? partNumber,
  Map<String, Pin> pins,
  Position position,
  String layer, // top/bottom
});

Map<String, dynamic> componentToJson(Component c) => {
      'id': c.id,
      'type': c.type,
      'value': c.value,
      'partNumber': c.partNumber,
      'pins': c.pins.map((k, v) => MapEntry(k, pinToJson(v))),
      'position': positionToJson(c.position),
      'layer': c.layer,
    };
Component componentFromJson(Map<String, dynamic> json) => (
      id: json['id'] as String,
      type: json['type'] as String,
      value: json['value'] as String?,
      partNumber: json['partNumber'] as String?,
      pins: (json['pins'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, pinFromJson(v as Map<String, dynamic>)),
      ),
      position: positionFromJson(json['position'] as Map<String, dynamic>),
      layer: json['layer'] as String,
    );
