import './image_modification.dart';
import './pcb_models.dart';

class PCBBoard {
  final String id;
  final String name;
  final Map<String, Component> components;
  final Map<String, Net> nets;
  final List<PCBImage> images;
  final Map<String, ImageModification> imageModifications;
  final DateTime lastUpdated;
  
  PCBBoard({
    required this.id,
    required this.name,
    Map<String, Component>? components,
    Map<String, Net>? nets,
    List<PCBImage>? images,
    Map<String, ImageModification>? imageModifications,
    DateTime? lastUpdated,
  }) : components = components ?? {},
       nets = nets ?? {},
       images = images ?? [],
       imageModifications = imageModifications ?? {},
       lastUpdated = lastUpdated ?? DateTime.now();
  
  // Metoda do generowania netlisty
  String generateNetlist() {
    final buffer = StringBuffer();
    
    // Component definitions
    buffer.writeln('* Components');
    for (final comp in components.values) {
      buffer.writeln('${comp.id} ${comp.type} ${comp.value ?? ""}');
    }
    
    buffer.writeln('\n* Nets');
    for (final net in nets.values) {
      final connections = net.connections.map((c) => c.toString()).join(' ');
      buffer.writeln('NET ${net.name}: $connections');
    }
    
    return buffer.toString();
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'components': components.map((k, v) => MapEntry(k, v.toJson())),
    'nets': nets.map((k, v) => MapEntry(k, v.toJson())),
    'images': images.map((i) => i.toJson()).toList(),
    'imageModifications': imageModifications.map((k, v) => MapEntry(k, v.toJson())),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory PCBBoard.fromJson(Map<String, dynamic> json) {
    return PCBBoard(
      id: json['id'],
      name: json['name'],
      components: (json['components'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Component.fromJson(v)),
      ),
      nets: (json['nets'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Net.fromJson(v)),
      ),
      images: (json['images'] as List<dynamic>)
          .map((i) => PCBImage.fromJson(i))
          .toList(),
      imageModifications: (json['imageModifications'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, ImageModification.fromJson(v)),
      ),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

class PCBImage {
  final String id;
  final String path;
  final String layer; // top/bottom
  final ImageType type;
  final List<Annotation> annotations;
  
  PCBImage({
    required this.id,
    required this.path,
    required this.layer,
    required this.type,
    List<Annotation>? annotations,
  }) : annotations = annotations ?? [];
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'layer': layer,
    'type': type.toString(),
    'annotations': annotations.map((a) => a.toJson()).toList(),
  };

  factory PCBImage.fromJson(Map<String, dynamic> json) {
    return PCBImage(
      id: json['id'],
      path: json['path'],
      layer: json['layer'],
      type: ImageType.values.firstWhere((e) => e.toString() == json['type']),
      annotations: (json['annotations'] as List<dynamic>)
          .map((a) => Annotation.fromJson(a))
          .toList(),
    );
  }
}

enum ImageType { components, traces, both }

class Annotation {
  final String componentId;
  final Position position;
  final Size size;
  
  Annotation({
    required this.componentId,
    required this.position,
    required this.size,
  });
  
  Map<String, dynamic> toJson() => {
    'componentId': componentId,
    'position': position.toJson(),
    'size': size.toJson(),
  };

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      componentId: json['componentId'],
      position: Position.fromJson(json['position']),
      size: Size.fromJson(json['size']),
    );
  }
}

class Size {
  final double width;
  final double height;
  
  Size({required this.width, required this.height});
  
  Map<String, dynamic> toJson() => {'width': width, 'height': height};

  factory Size.fromJson(Map<String, dynamic> json) {
    return Size(
      width: json['width'],
      height: json['height'],
    );
  }
}
