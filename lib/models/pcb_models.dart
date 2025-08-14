class Component {
  final String id;
  final String type;
  final String? value;
  final String? partNumber;
  final Map<String, Pin> pins;
  final Position position;
  final String layer; // top/bottom
  
  Component({
    required this.id,
    required this.type,
    this.value,
    this.partNumber,
    required this.pins,
    required this.position,
    required this.layer,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'value': value,
    'partNumber': partNumber,
    'pins': pins.map((k, v) => MapEntry(k, v.toJson())),
    'position': position.toJson(),
    'layer': layer,
  };

  factory Component.fromJson(Map<String, dynamic> json) {
    return Component(
      id: json['id'],
      type: json['type'],
      value: json['value'],
      partNumber: json['partNumber'],
      pins: (json['pins'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Pin.fromJson(v)),
      ),
      position: Position.fromJson(json['position']),
      layer: json['layer'],
    );
  }
}

class Pin {
  final String id;
  final String? function;
  final String? netName;
  final Position position;
  
  Pin({
    required this.id,
    this.function,
    this.netName,
    required this.position,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'function': function,
    'netName': netName,
    'position': position.toJson(),
  };

  factory Pin.fromJson(Map<String, dynamic> json) {
    return Pin(
      id: json['id'],
      function: json['function'],
      netName: json['netName'],
      position: Position.fromJson(json['position']),
    );
  }
}

class Net {
  final String name;
  final List<ConnectionPoint> connections;
  final double? measuredResistance;
  final double? measuredVoltage;
  
  Net({
    required this.name,
    required this.connections,
    this.measuredResistance,
    this.measuredVoltage,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'connections': connections.map((c) => c.toJson()).toList(),
    'measuredResistance': measuredResistance,
    'measuredVoltage': measuredVoltage,
  };

  factory Net.fromJson(Map<String, dynamic> json) {
    return Net(
      name: json['name'],
      connections: (json['connections'] as List<dynamic>)
          .map((c) => ConnectionPoint.fromJson(c))
          .toList(),
      measuredResistance: json['measuredResistance'],
      measuredVoltage: json['measuredVoltage'],
    );
  }
}

class ConnectionPoint {
  final String componentId;
  final String pinId;
  
  ConnectionPoint({
    required this.componentId,
    required this.pinId,
  });
  
  Map<String, dynamic> toJson() => {
    'componentId': componentId,
    'pinId': pinId,
  };

  factory ConnectionPoint.fromJson(Map<String, dynamic> json) {
    return ConnectionPoint(
      componentId: json['componentId'],
      pinId: json['pinId'],
    );
  }
  
  String toString() => '$componentId.$pinId';
}

class Position {
  final double x;
  final double y;
  
  Position({required this.x, required this.y});
  
  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      x: json['x'],
      y: json['y'],
    );
  }
}
