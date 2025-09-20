import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../features/kicad/data/kicad_schematic_loader.dart';
import '../../features/kicad/data/kicad_schematic_models.dart';
import '../data/project.dart';
import '../../pcb_viewer/data/image_modification.dart';
import '../data/visual_models.dart';

/// A record to hold the result of opening a project, including the project data
/// and the loaded schematic.
typedef OpenedProject = ({Project project, KiCadSchematic? schematic});

/// API functions for application-level operations like managing projects and files.
class ApplicationAPI {
  final _uuid = Uuid();

  /// Opens a project from a given path, reads the project file, and loads the
  /// associated schematic if it exists.
  Future<OpenedProject> openProject(String path) async {
    print('Opening project from: $path');
    final content = await File(path).readAsString();
    final project = projectFromJson(jsonDecode(content));

    KiCadSchematic? schematic;
    if (project.schematicFilePath != null && project.schematicFilePath!.isNotEmpty) {
      final loader = KiCadSchematicLoader(project.schematicFilePath!);
      try {
        schematic = await loader.load();
      } catch (e) {
        print('Error loading schematic associated with project: $e');
        // Schematic remains null, the UI can handle this case.
      }
    }

    return (project: project, schematic: schematic);
  }

  /// Saves the current project state to a file.
  /// This is a side-effect and does not return a new state.
  Future<void> saveProject(Project project) async {
    // In a real implementation, this would serialize the project and write to a file.
    print('Saving project: ${project.name}');
    // final json = projectToJson(project);
    // await File(project.path_placeholder).writeAsString(jsonEncode(json));
  }

  /// Adds a new PCB image to the project.
  Project addImage({
    required Project project,
    required String path,
    required String layer, // "top" or "bottom"
  }) {
    final newImage = (
      id: _uuid.v4(),
      path: path,
      layer: layer,
      componentPlacements: <String, VisualSymbolPlacement>{},
      modification: createDefaultImageModification(),
    );

    final updatedImages = List<PCBImageView>.from(project.pcbImages)..add(newImage);
    return project.copyWith(pcbImages: updatedImages, lastUpdated: DateTime.now());
  }

  /// Sets the schematic file path for the project.
  Project openSchematic({
    required Project project,
    required String path,
  }) {
    return project.copyWith(schematicFilePath: path, lastUpdated: DateTime.now());
  }

  /// Saves the current schematic.
  /// The exact implementation depends on how schematics are managed.
  void saveSchematic(Project project) {
    // This might involve serializing the schematic part of the project
    // and writing it to the `schematicFilePath`.
    print('Saving schematic to: ${project.schematicFilePath}');
  }

  /// Opens a symbol library.
  /// The implementation depends on how libraries are managed globally or per-project.
  void openLibrary(String name) {
    // This might load symbols into a global cache or add a library path to the project.
    print('Opening library: $name');
  }
}