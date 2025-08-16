import './image_modification.dart';
import './pcb_models.dart';

// --- Size ---
typedef Size = ({double width, double height});
Map<String, dynamic> sizeToJson(Size s) => {'width': s.width, 'height': s.height};
Size sizeFromJson(Map<String, dynamic> json) => (width: json['width'] as double, height: json['height'] as double);

// --- Annotation ---
typedef Annotation = ({String componentId, Position position, Size size});
Map<String, dynamic> annotationToJson(Annotation a) => {
      'componentId': a.componentId,
      'position': positionToJson(a.position),
      'size': sizeToJson(a.size),
    };
Annotation annotationFromJson(Map<String, dynamic> json) => (
      componentId: json['componentId'] as String,
      position: positionFromJson(json['position'] as Map<String, dynamic>),
      size: sizeFromJson(json['size'] as Map<String, dynamic>),
    );

// --- ImageType ---
enum ImageType { components, traces, both }

// --- PCBImage ---
typedef PCBImage = ({
  String id,
  String path,
  String layer, // top/bottom
  ImageType type,
  List<Annotation> annotations
});

Map<String, dynamic> pcbImageToJson(PCBImage i) => {
      'id': i.id,
      'path': i.path,
      'layer': i.layer,
      'type': i.type.toString(),
      'annotations': i.annotations.map((a) => annotationToJson(a)).toList(),
    };
PCBImage pcbImageFromJson(Map<String, dynamic> json) => (
      id: json['id'] as String,
      path: json['path'] as String,
      layer: json['layer'] as String,
      type: ImageType.values.firstWhere((e) => e.toString() == json['type']),
      annotations: (json['annotations'] as List<dynamic>)
          .map((a) => annotationFromJson(a as Map<String, dynamic>))
          .toList(),
    );

// --- PCBBoard ---
typedef PCBBoard = ({
  String id,
  String name,
  Map<String, Component> components,
  Map<String, Net> nets,
  List<PCBImage> images,
  Map<String, ImageModification> imageModifications,
  DateTime lastUpdated
});

Map<String, dynamic> pcbBoardToJson(PCBBoard b) => {
      'id': b.id,
      'name': b.name,
      'components': b.components.map((k, v) => MapEntry(k, componentToJson(v))),
      'nets': b.nets.map((k, v) => MapEntry(k, netToJson(v))),
      'images': b.images.map((i) => pcbImageToJson(i)).toList(),
      'imageModifications': b.imageModifications.map((k, v) => MapEntry(k, imageModificationToJson(v))),
      'lastUpdated': b.lastUpdated.toIso8601String(),
    };

PCBBoard pcbBoardFromJson(Map<String, dynamic> json) => (
      id: json['id'] as String,
      name: json['name'] as String,
      components: (json['components'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, componentFromJson(v as Map<String, dynamic>)),
      ),
      nets: (json['nets'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, netFromJson(v as Map<String, dynamic>)),
      ),
      images: (json['images'] as List<dynamic>)
          .map((i) => pcbImageFromJson(i as Map<String, dynamic>))
          .toList(),
      imageModifications: (json['imageModifications'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, imageModificationFromJson(v as Map<String, dynamic>)),
      ),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );

// --- Netlist Generation ---
String generateNetlist(PCBBoard board) {
  final buffer = StringBuffer();

  // Component definitions
  buffer.writeln('* Components');
  for (final comp in board.components.values) {
    buffer.writeln('${comp.id} ${comp.type} ${comp.value ?? ""}');
  }

  buffer.writeln('\n* Nets');
  for (final net in board.nets.values) {
    final connections = net.connections.map((c) => connectionPointToString(c)).join(' ');
    buffer.writeln('NET ${net.name}: $connections');
  }

  return buffer.toString();
}

