import '../data/core.dart';



final List<ToolDefinition> availableTools = [
  ToolDefinition(
    name: 'analyze_pcb_image',
    description: 'Analyze a PCB image to identify components and connections',
    inputSchema: {
      'type': 'object',
      'properties': {
        'image_id': {
          'type': 'string',
          'description': 'ID of the PCB image to analyze',
        },
        'analysis_type': {
          'type': 'string',
          'enum': ['components', 'traces', 'full'],
          'description': 'Type of analysis to perform',
        },
        'region': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
            'width': {'type': 'number'},
            'height': {'type': 'number'},
          },
          'description': 'Optional region of interest',
        },
      },
      'required': ['image_id'],
    },
  ),
  ToolDefinition(
    name: 'get_project_state',
    description: 'Get the current project state including components and nets',
    inputSchema: {
      'type': 'object',
      'properties': {
        'include_images': {
          'type': 'boolean',
          'description': 'Include base64 encoded images in response',
        },
        'include_history': {
          'type': 'boolean',
          'description': 'Include analysis history',
        },
      },
    },
  ),
  ToolDefinition(
    name: 'update_schematic',
    description: 'Update the KiCad schematic with new components or connections',
    inputSchema: {
      'type': 'object',
      'properties': {
        'components': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'action': {'type': 'string', 'enum': ['add', 'update', 'remove']},
              'id': {'type': 'string'},
              'type': {'type': 'string'},
              'value': {'type': 'string'},
              'designator': {'type': 'string'},
              'position': {'type': 'object'},
            },
          },
        },
        'nets': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'action': {'type': 'string', 'enum': ['add', 'update', 'remove']},
              'id': {'type': 'string'},
              'name': {'type': 'string'},
              'connections': {'type': 'array', 'items': {'type': 'string'}},
            },
          },
        },
      },
    },
  ),
  ToolDefinition(
    name: 'generate_netlist',
    description: 'Generate a KiCad netlist from the current project state',
    inputSchema: {
      'type': 'object',
      'properties': {
        'format': {
          'type': 'string',
          'enum': ['kicad', 'spice', 'generic'],
          'description': 'Netlist format to generate',
        },
      },
    },
  ),
  ToolDefinition(
    name: 'add_pcb_image',
    description: 'Add a new PCB image to the project',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'File path or URL of the image',
        },
        'data': {
          'type': 'string',
          'description': 'Base64 encoded image data',
        },
        'metadata': {
          'type': 'object',
          'description': 'Additional metadata about the image',
        },
      },
      'required': ['path'],
    },
  ),
  ToolDefinition(
    name: 'detect_components',
    description: 'Detect and classify components in PCB image using computer vision',
    inputSchema: {
      'type': 'object',
      'properties': {
        'image_id': {
          'type': 'string',
          'description': 'ID of the PCB image to analyze',
        },
        'confidence_threshold': {
          'type': 'number',
          'minimum': 0.0,
          'maximum': 1.0,
          'description': 'Minimum confidence threshold for detections',
        },
      },
      'required': ['image_id'],
    },
  ),
];
