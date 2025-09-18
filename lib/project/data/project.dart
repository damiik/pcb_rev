import '../../pcb_viewer/data/image_modification.dart';
import 'logical_models.dart';
import 'visual_models.dart';

// --- PCB Image View ---
// An image is a view with its own set of visual annotations.
typedef PCBImageView = ({
  String id,
  String path,
  String layer, // top/bottom
  Map<String, VisualSymbolPlacement>
  componentPlacements, // Annotations are just symbols on an image
  ImageModification modification,
});

Map<String, dynamic> pcbImageViewToJson(PCBImageView v) => {
  'id': v.id,
  'path': v.path,
  'layer': v.layer,
  'componentPlacements': v.componentPlacements.map(
    (k, v) => MapEntry(k, visualSymbolPlacementToJson(v)),
  ),
  'modification': imageModificationToJson(v.modification),
};

PCBImageView pcbImageViewFromJson(Map<String, dynamic> json) => (
  id: json['id'] as String,
  path: json['path'] as String,
  layer: json['layer'] as String,
  componentPlacements: (json['componentPlacements'] as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, visualSymbolPlacementFromJson(v as Map<String, dynamic>))),
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
  String? schematicFilePath, // Path to the KiCad schematic file
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
  'schematicFilePath': p.schematicFilePath,
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
  schematicFilePath: json['schematicFilePath'] as String?,
  pcbImages: (json['pcbImages'] as List<dynamic>)
      .map((v) => pcbImageViewFromJson(v as Map<String, dynamic>))
      .toList(),
);



extension ProjectCopyWith on Project {
  Project copyWith({
    String? id,
    String? name,
    DateTime? lastUpdated,
    Map<String, LogicalComponent>? logicalComponents,
    Map<String, LogicalNet>? logicalNets,
    String? schematicFilePath,
    List<PCBImageView>? pcbImages,
  }) {
    return (
      id: id ?? this.id,
      name: name ?? this.name,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      logicalComponents: logicalComponents ?? this.logicalComponents,
      logicalNets: logicalNets ?? this.logicalNets,
      schematicFilePath: schematicFilePath ?? this.schematicFilePath,
      pcbImages: pcbImages ?? this.pcbImages,
    );
  }
}
