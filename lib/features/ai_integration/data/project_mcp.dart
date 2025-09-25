import '../../kicad/data/kicad_schematic_models.dart';
import '../../kicad/data/kicad_symbol_models.dart' as kicad_symbol_models;
import '../../../project/api/application_api.dart';
import '../../../project/data/project.dart';
import '../../connectivity/models/connectivity.dart';
import '../data/mcp_server.dart';

/// Callback signature for when a project has been opened via an API call.
typedef OnProjectOpenedCallback = void Function(OpenedProject);

/// Callback signature for when a schematic has been loaded via an API call.
typedef OnSchematicLoadedCallback = void Function(KiCadSchematic);

/// Callback to get the current project state from the UI.
typedef GetProjectCallback = Project? Function();

/// Callback to update the entire project state in the UI.
typedef UpdateProjectCallback = void Function(Project);

/// Callback to get the current schematic state from the UI.
typedef GetSchematicCallback = KiCadSchematic? Function();

/// Callback to get the current connectivity state from the UI.
typedef GetConnectivityCallback = Connectivity? Function();


/// Extension for project-related MCP tool handlers
extension ProjectMCPTools on MCPServer {


  /// Returns the handler functions for the project-related MCP tools.
  Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> projectToolHandlers({
    required OnProjectOpenedCallback onProjectOpened,
    required OnSchematicLoadedCallback onSchematicLoaded,
    required GetProjectCallback getProject,
    required UpdateProjectCallback updateProject
  }) {
    final api = ApplicationAPI();

    return {
      'open_project': (args) async {
        final path = args['path'] as String?;
        if (path == null) {
          throw ArgumentError('The "path" argument is required.');
        }

        try {
          // 1. Call the API to load the project data
          final openedProject = await api.openProject(path);

          // 2. Use the callback to update the UI state
          onProjectOpened(openedProject);

          // 3. Return a success message to the AI
          return {
            'success': true,
            'message': 'Project "${openedProject.project.name}" opened successfully.',
            'project_id': openedProject.project.id,
            'schematic_loaded': openedProject.schematic != null,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to open project: ${e.toString()}',
          };
        }
      },
      'add_image': (args) async {
        final path = args['path'] as String?;
        final layer = args['layer'] as String?;

        if (path == null || layer == null) {
          throw ArgumentError('The "path" and "layer" arguments are required.');
        }

        final currentProject = getProject();
        if (currentProject == null) {
          return {
            'success': false,
            'error': 'No project is currently open.',
          };
        }

        try {
          final updatedProject = api.addImage(
            project: currentProject,
            path: path,
            layer: layer,
          );

          updateProject(updatedProject);

          return {
            'success': true,
            'message': 'Image added successfully to project ${currentProject.name}.',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to add image: ${e.toString()}',
          };
        }
      },
      'load_schematic': (args) async {
        final path = args['path'] as String?;
        if (path == null) {
          throw ArgumentError('The "path" argument is required.');
        }

        try {
          final schematic = await api.loadSchematic(path);
          onSchematicLoaded(schematic);
          return {
            'success': true,
            'message': 'Schematic loaded successfully from $path',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to load schematic: ${e.toString()}',
          };
        }
      },
      'save_project': (args) async {
        final path = args['path'] as String?;
        if (path == null) {
          throw ArgumentError('The "path" argument is required.');
        }

        final currentProject = getProject();
        if (currentProject == null) {
          return {
            'success': false,
            'error': 'No project is currently open.',
          };
        }

        try {
          await api.saveProject(currentProject, path);
          return {
            'success': true,
            'message': 'Project saved successfully to $path',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to save project: ${e.toString()}',
          };
        }
      },
      'save_schematic': (args) async {
        final path = args['path'] as String?;
        if (path == null) {
          throw ArgumentError('The "path" argument is required.');
        }

        final currentSchematic = getSchematic();
        if (currentSchematic == null) {
          return {
            'success': false,
            'error': 'No schematic is currently loaded.',
          };
        }

        try {
          await api.saveKiCadSchematic(currentSchematic, path);
          return {
            'success': true,
            'message': 'Schematic saved successfully to $path',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to save schematic: ${e.toString()}',
          };
        }
      },
      'export_netlist': (args) async {
        final format = args['format'] as String? ?? 'json';

        final currentConnectivity = getConnectivity();
        if (currentConnectivity == null) {
          return {
            'success': false,
            'error': 'No connectivity data is available.',
          };
        }

        try {
          final netlist = api.exportNetlist(currentConnectivity, format: format);
          return {
            'success': true,
            'message': 'Netlist exported successfully',
            'netlist': netlist,
            'format': format,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to export netlist: ${e.toString()}',
          };
        }
      },
      'process_image': (args) async {
        final path = args['path'] as String?;
        final layer = args['layer'] as String?;

        if (path == null || layer == null) {
          throw ArgumentError('The "path" and "layer" arguments are required.');
        }

        try {
          final enhancedPath = await api.processImage(path);
          return {
            'success': true,
            'message': 'Image processed successfully',
            'original_path': path,
            'enhanced_path': enhancedPath,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to process image: ${e.toString()}',
          };
        }
      },
      'add_component': (args) async {
        final type = args['type'] as String?;
        final value = args['value'] as String?;
        final reference = args['reference'] as String?;
        final position = args['position'] as Map<String, dynamic>?;

        if (type == null || value == null || reference == null || position == null) {
          throw ArgumentError('The "type", "value", "reference", and "position" arguments are required.');
        }

        final currentProject = getProject();
        if (currentProject == null) {
          return {
            'success': false,
            'error': 'No project is currently open.',
          };
        }

        try {
          // Create position object
          final pos = kicad_symbol_models.Position(
            position['x'] as double,
            position['y'] as double,
          );

          // For now, we'll use a placeholder library symbol
          // In a real implementation, this would be resolved from the symbol library
          final librarySymbol = kicad_symbol_models.LibrarySymbol(
            name: type,
            pinNames: const kicad_symbol_models.PinNames(offset: 0.0),
            inBom: true,
            hidePinNumbers: false,
            onBoard: true,
            properties: [
              kicad_symbol_models.Property(
                name: 'Reference',
                value: 'U',
                position: kicad_symbol_models.Position(0, 0),
                effects: kicad_symbol_models.TextEffects(
                  font: kicad_symbol_models.Font(width: 1.27, height: 1.27),
                  justify: kicad_symbol_models.Justify.left,
                  hide: false,
                ),
              ),
            ],
            units: [
              kicad_symbol_models.SymbolUnit(
                name: 'Unit1',
                unitNumber: 1,
                graphics: [],
                pins: [],
              ),
            ],
          );

          final currentSchematic = getSchematic();
          if (currentSchematic == null) {
            return {
              'success': false,
              'error': 'No schematic is currently loaded.',
            };
          }

          final updatedSchematic = api.addComponent(
            schematic: currentSchematic,
            type: type,
            value: value,
            reference: reference,
            position: pos,
            librarySymbol: librarySymbol,
          );

          updateSchematic(updatedSchematic);

          return {
            'success': true,
            'message': 'Component added successfully',
            'component_reference': reference,
            'component_type': type,
            'component_value': value,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to add component: ${e.toString()}',
          };
        }
      },
    };
  }
}
