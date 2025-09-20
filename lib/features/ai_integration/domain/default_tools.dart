import '../data/core.dart';

/// Default MCP tools for basic PCB reverse engineering operations
final List<ToolDefinition> defaultTools = [
  ToolDefinition(
    name: 'read_current_image',
    description:
        'Reads the pixel data of the currently visible and transformed (e.g., zoomed or panned) view of the PCB image. This captures the exact view as the user sees it and returns it in Base64 format.',
    inputSchema: {
      'type': 'object',
      'properties': {},
    },
  ),
  ToolDefinition(
    name: 'write_current_image_components',
    description:
        'Writes the component recognition results for the current image back to the project. The AI should call this after processing the image from `read_current_image`.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'components': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'designator': {'type': 'string'},
              'bounding_box': {
                'type': 'object',
                'properties': {
                  'x': {'type': 'number'},
                  'y': {'type': 'number'},
                  'w': {'type': 'number'},
                  'h': {'type': 'number'},
                },
                'required': ['x', 'y', 'w', 'h'],
              },
              'confidence': {'type': 'number'},
            },
            'required': ['designator', 'bounding_box'],
          },
        },
      },
      'required': ['components'],
    },
  ),
  ToolDefinition(
    name: 'get_kicad_schematic',
    description:
        'Retrieves the full KiCad schematic data for the current project, including all symbol instances, wires, and nets.',
    inputSchema: {
      'type': 'object',
      'properties': {},
    },
  ),
  ToolDefinition(
    name: 'get_symbol_libraries',
    description:
        'Retrieves the list of available KiCad symbol libraries and the symbols they contain, which can be used to place new components on the schematic.',
    inputSchema: {
      'type': 'object',
      'properties': {},
    },
  ),
  ToolDefinition(
    name: 'update_kicad_schematic',
    description:
        'Proposes and applies updates to the KiCad schematic, such as adding new symbol instances or creating new connections (wires/nets).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'updates': {
          'type': 'array',
          'items': {
            'type': 'object',
            'description':
                'A single update operation, e.g., adding a symbol.',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['add_symbol', 'add_wire']
              },
              'payload': {
                'type': 'object',
                'description':
                    'The data for the action, e.g., a SymbolInstance object.'
              },
            },
          },
        },
      },
      'required': ['updates'],
    },
  ),
  ToolDefinition(
    name: 'get_netlist',
    description:
        'Returns the current netlist, derived from the connectivity graph. Includes a list of nets and the pins they connect.',
    inputSchema: {
      'type': 'object',
      'properties': {},
    },
  ),
  ToolDefinition(
    name: 'get_symbol_instances',
    description:
        'Returns all symbol instances from the schematic, including their properties, pins, and positions.',
    inputSchema: {
      'type': 'object',
      'properties': {},
    },
  ),
  ToolDefinition(
    name: 'get_connectivity_graph',
    description:
        'Returns the raw connectivity graph, showing all items (wires, junctions, pins, labels) and their geometric connections.',
    inputSchema: {
      'type': 'object',
      'properties': {},
    },
  ),
  ToolDefinition(
    name: 'get_labels_and_ports',
    description:
        'Returns a list of all labels and hierarchical ports on the schematic.',
    inputSchema: {
      'type': 'object',
      'properties': {},
    },
  ),
];
