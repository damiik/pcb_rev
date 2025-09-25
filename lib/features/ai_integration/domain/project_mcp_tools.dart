import '../data/core.dart';

/// Project management MCP tools definitions
final List<ToolDefinition> projectMcpTools = [
  ToolDefinition(
    name: 'open_project',
    description: 'Opens a PCBRev project from a specified file path and loads its associated schematic.',
    inputSchema: {
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
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'The absolute path to the image file.',
        },
        'layer': {
          'type': 'string',
          'description': 'The layer of the PCB, either "top" or "bottom".',
          'enum': ['top', 'bottom'],
        },
      },
      'required': ['path', 'layer'],
    },
  ),
  ToolDefinition(
    name: 'load_schematic',
    description: 'Loads a KiCad schematic from a specified file path.',
    inputSchema: {
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
  ToolDefinition(
    name: 'save_project',
    description: 'Saves the current project to a specified file path.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'The absolute path where to save the project file.',
        },
      },
      'required': ['path'],
    },
  ),
  ToolDefinition(
    name: 'save_schematic',
    description: 'Saves the current schematic to a KiCad .kicad_sch file.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'The absolute path where to save the schematic file.',
        },
      },
      'required': ['path'],
    },
  ),
  ToolDefinition(
    name: 'export_netlist',
    description: 'Exports the connectivity graph as a netlist.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'format': {
          'type': 'string',
          'description': 'The netlist format (e.g., "json", "spice").',
          'enum': ['json', 'spice'],
        },
      },
      'required': ['format'],
    },
  ),
  ToolDefinition(
    name: 'process_image',
    description: 'Processes and enhances a PCB image for analysis.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'The absolute path to the image file.',
        },
      },
      'required': ['path'],
    },
  ),
  ToolDefinition(
    name: 'add_component',
    description: 'Adds a component to the schematic.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'type': {
          'type': 'string',
          'description': 'The component type (symbol library ID).',
        },
        'value': {
          'type': 'string',
          'description': 'The component value.',
        },
        'reference': {
          'type': 'string',
          'description': 'The component reference designator.',
        },
        'position': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
          },
          'required': ['x', 'y'],
        },
      },
      'required': ['type', 'value', 'reference', 'position'],
    },
  ),
];