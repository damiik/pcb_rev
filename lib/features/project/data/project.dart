import '../../pcb_viewer/data/image_modification.dart';
import '../../schematic/data/logical_models.dart';
import '../../schematic/data/visual_models.dart';

// --- PCB Image View ---
// An image is a view with its own set of visual annotations.
typedef PCBImageView = ({
  String id,
  String path,
  String layer, // top/bottom
  Map<String, Symbol>
  componentPlacements, // Annotations are just symbols on an image
  ImageModification modification,
});

Map<String, dynamic> pcbImageViewToJson(PCBImageView v) => {
  'id': v.id,
  'path': v.path,
  'layer': v.layer,
  'componentPlacements': v.componentPlacements.map(
    (k, v) => MapEntry(k, symbolToJson(v)),
  ),
  'modification': imageModificationToJson(v.modification),
};

PCBImageView pcbImageViewFromJson(Map<String, dynamic> json) => (
  id: json['id'] as String,
  path: json['path'] as String,
  layer: json['layer'] as String,
  componentPlacements: (json['componentPlacements'] as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, symbolFromJson(v as Map<String, dynamic>))),
  modification: imageModificationFromJson(
    json['modification'] as Map<String, dynamic>,
  ),
);

// --- Project ---
// The main container for the entire project state.
typedef Project = ({
  String id,
  String name,
  DateTime lastUpdated,
  // Logical Model
  Map<String, LogicalComponent> logicalComponents,
  Map<String, LogicalNet> logicalNets,
  // Visual Models (Views)
  SchematicView schematic,
  List<PCBImageView> pcbImages,
});

Map<String, dynamic> projectToJson(Project p) => {
  'id': p.id,
  'name': p.name,
  'lastUpdated': p.lastUpdated.toIso8601String(),
  'logicalComponents': p.logicalComponents.map(
    (k, v) => MapEntry(k, logicalComponentToJson(v)),
  ),
  'logicalNets': p.logicalNets.map((k, v) => MapEntry(k, logicalNetToJson(v))),
  'schematic': schematicViewToJson(p.schematic),
  'pcbImages': p.pcbImages.map((v) => pcbImageViewToJson(v)).toList(),
};

Project projectFromJson(Map<String, dynamic> json) => (
  id: json['id'] as String,
  name: json['name'] as String,
  lastUpdated: DateTime.parse(json['lastUpdated'] as String),
  logicalComponents: (json['logicalComponents'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, logicalComponentFromJson(v as Map<String, dynamic>)),
  ),
  logicalNets: (json['logicalNets'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, logicalNetFromJson(v as Map<String, dynamic>)),
  ),
  schematic: schematicViewFromJson(json['schematic'] as Map<String, dynamic>),
  pcbImages: (json['pcbImages'] as List<dynamic>)
      .map((v) => pcbImageViewFromJson(v as Map<String, dynamic>))
      .toList(),
);

// --- Netlist Generation ---
String generateNetlistFromProject(Project project) {
  final buffer = StringBuffer();
  buffer.writeln('* Components');
  for (final comp in project.logicalComponents.values) {
    buffer.writeln('${comp.id} ${comp.type} ${comp.value ?? ""}');
  }
  buffer.writeln('\n* Nets');
  for (final net in project.logicalNets.values) {
    final connections = net.connections
        .map((c) => connectionPointToString(c))
        .join(' ');
    buffer.writeln('NET ${net.name}: $connections');
  }
  return buffer.toString();
}

extension ProjectCopyWith on Project {
  Project copyWith({
    String? id,
    String? name,
    DateTime? lastUpdated,
    Map<String, LogicalComponent>? logicalComponents,
    Map<String, LogicalNet>? logicalNets,
    SchematicView? schematic,
    List<PCBImageView>? pcbImages,
  }) {
    return (
      id: id ?? this.id,
      name: name ?? this.name,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      logicalComponents: logicalComponents ?? this.logicalComponents,
      logicalNets: logicalNets ?? this.logicalNets,
      schematic: schematic ?? this.schematic,
      pcbImages: pcbImages ?? this.pcbImages,
    );
  }
}
