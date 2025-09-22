import '../../../features/kicad/data/kicad_schematic_models.dart';
import '../../../project/api/application_api.dart';
import '../../../project/data/project.dart';
import '../data/core.dart';

/// Callback signature for when a project has been opened via an API call.
typedef OnProjectOpenedCallback = void Function(OpenedProject);

/// Callback signature for when a schematic has been loaded via an API call.
typedef OnSchematicLoadedCallback = void Function(KiCadSchematic);

/// Callback to get the current project state from the UI.
typedef GetProjectCallback = Project? Function();

/// Callback to update the entire project state in the UI.
typedef UpdateProjectCallback = void Function(Project);

/// Defines MCP tools related to project-level operations.
final List<ToolDefinition> projectTools = [
  ToolDefinition(
    name: 'open_project',
    description: 'Opens a PCBRev project from a specified file path and loads its associated schematic.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'The absolute path to the .pcbrev project file.',
        },
      },
      'required': ['path'],
    },
  ),
  ToolDefinition(
    name: 'add_image',
    description: 'Adds a new PCB image to the current project.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'The absolute path to the image file.',
        },
        'layer': {
          'type': 'string',
          'description': 'The layer of the PCB, either \'top\' or \'bottom\'.',
          'enum': ['top', 'bottom'],
        },
      },
      'required': ['path', 'layer'],
    },
  ),
  ToolDefinition(
    name: 'load_schematic',
    description: 'Loads a KiCad schematic from a specified file path.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'The absolute path to the .kicad_sch file.',
        },
      },
      'required': ['path'],
    },
  ),
];

/// Returns the handler functions for the project-related MCP tools.
Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> getProjectToolHandlers({
  required OnProjectOpenedCallback onProjectOpened,
  required OnSchematicLoadedCallback onSchematicLoaded,
  required GetProjectCallback getProject,
  required UpdateProjectCallback updateProject,
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
  };
}
