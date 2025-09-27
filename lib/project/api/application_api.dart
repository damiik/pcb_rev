import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../kicad/data/kicad_schematic_loader.dart';
import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_models.dart' as kicad_symbol;
import '../../kicad/data/kicad_symbol_loader.dart';
import '../../kicad/domain/kicad_schematic_writer.dart' as kicad_writer;
import '../../kicad/api/kicad_schematic_api_impl.dart';
import '../data/project.dart';
import '../../pcb_viewer/data/image_modification.dart';
import '../../pcb_viewer/data/image_processor.dart' as image_processor;
import '../data/visual_models.dart';
import '../../features/connectivity/models/connectivity.dart';
import '../../features/connectivity/api/netlist_api.dart' as netlist_api;

/// A record to hold the result of opening a project, including the project data
/// and the loaded schematic.
typedef OpenedProject = ({Project project, KiCadSchematic? schematic});

/// API functions for application-level operations like managing projects and files.
class ApplicationAPI {
  final _uuid = Uuid();
  final _schematicApi = KiCadSchematicAPIImpl();

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
  Future<void> saveProject(Project project, String path) async {
    final json = projectToJson(project);
    await File(path).writeAsString(jsonEncode(json));
    print('Project saved to: $path');
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

  /// Saves the current schematic to a KiCad .kicad_sch file.
  Future<void> saveKiCadSchematic(KiCadSchematic schematic, String path) async {
    final content = kicad_writer.generateKiCadSchematicFileContent(schematic);
    await File(path).writeAsString(content);
    print('KiCad schematic saved to: $path');
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

  /// Loads a KiCad schematic file from a given path.
  Future<KiCadSchematic> loadSchematic(String path) async {
    final loader = KiCadSchematicLoader(path);
    final schematic = await loader.load();
    return schematic;
  }

  /// Exports the connectivity graph as a netlist.
  String exportNetlist(Connectivity connectivity, {String format = 'json'}) {
    final netlist = netlist_api.getNetlist(connectivity.graph);
    if (format == 'spice') {
      // TODO: Implement SPICE format conversion
      return netlist; // For now, return JSON format
    }
    return netlist;
  }

  /// Processes and enhances a PCB image for analysis.
  Future<String> processImage(String imagePath) async {
    return await image_processor.enhanceImage(imagePath);
  }

  /// Updates image modification settings.
  PCBImageView updateImageModification(PCBImageView image, ImageModification modification) {
    return pcbImageViewFromJson({
      ...pcbImageViewToJson(image),
      'modification': imageModificationToJson(modification),
    });
  }

  /// Adds a component to the schematic.
  KiCadSchematic addComponentX({
    required KiCadSchematic schematic,
    required String type,
    required String value,
    required String reference,
    required kicad_symbol.Position position,
    required kicad_symbol.LibrarySymbol? librarySymbol,
  }) {
    if (librarySymbol == null) {
      throw ArgumentError('Library symbol is required to add a component');
    }

    // Check if reference is unique
    if (reference.isNotEmpty && schematic.symbolInstances.any((inst) =>
        inst.properties.any((prop) =>
            prop.name == 'Reference' && prop.value == reference))) {
      throw ArgumentError('Component with reference "$reference" already exists');
    }

    kicad_symbol.Property? maybeProperty;
    try {
      maybeProperty = librarySymbol.properties.firstWhere(
        (p) => p.name == 'Reference',
      );
    } catch (e) {
      maybeProperty = null;
    }
    final prefix = maybeProperty?.value.replaceAll(RegExp(r'\d'), '') ?? 'X';
    final newRef = reference.isNotEmpty ? reference : _schematicApi.generateNewRef(schematic, prefix);

    final newSymbolInstance = SymbolInstance(
      libId: librarySymbol.name,
      at: position,
      uuid: _uuid.v4(),
      unit: 1,
      inBom: true,
      onBoard: true,
      dnp: false,
      properties: [
        kicad_symbol.Property(
          name: 'Reference',
          value: newRef,
          position: const kicad_symbol.Position(0, 0),
          effects: const kicad_symbol.TextEffects(
            font: kicad_symbol.Font(width: 1.27, height: 1.27),
            justify: kicad_symbol.Justify.left,
            hide: false
          )
        ),
        kicad_symbol.Property(
          name: 'Value',
          value: value,
          position: const kicad_symbol.Position(0, 0),
          effects: const kicad_symbol.TextEffects(
            font: kicad_symbol.Font(width: 1.27, height: 1.27),
            justify: kicad_symbol.Justify.left,
            hide: false
          )
        ),
        kicad_symbol.Property(
          name: 'Footprint',
          value: "",
          position: const kicad_symbol.Position(0, 0),
          effects: const kicad_symbol.TextEffects(
            font: kicad_symbol.Font(width: 1.27, height: 1.27),
            justify: kicad_symbol.Justify.left,
            hide: true
          )
        ),
        kicad_symbol.Property(
          name: 'Datasheet',
          value: "",
          position: const kicad_symbol.Position(0, 0),
          effects: const kicad_symbol.TextEffects(
            font: kicad_symbol.Font(width: 1.27, height: 1.27),
            justify: kicad_symbol.Justify.left,
            hide: true
          )
        ),
      ],
    );

    final updatedInstances = List<SymbolInstance>.from(schematic.symbolInstances)
      ..add(newSymbolInstance);

    return schematic.copyWith(symbolInstances: updatedInstances);
  }

}


