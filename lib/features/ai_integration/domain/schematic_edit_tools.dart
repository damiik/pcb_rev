import '../data/core.dart';

/// Schematic editing MCP tools for manipulating KiCad schematics
final List<ToolDefinition> schematicEditTools = [
  ToolDefinition(
    name: 'add_symbol',
    description: 'Add a symbol to the schematic',
    inputSchema: {
      'type': 'object',
      'properties': {
        'symbol_lib_id': {'type': 'string'},
        'reference': {'type': 'string'},
        'value': {'type': 'string'},
        'position': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
            'angle': {'type': 'number'},
          },
          'required': ['x', 'y'],
        },
        'angle': {'type': 'number'},
        'mirror_x': {'type': 'boolean'},
        'mirror_y': {'type': 'boolean'},
        'unit': {'type': 'integer'},
      },
      'required': ['symbol_lib_id', 'reference', 'value', 'position'],
    },
  ),
  ToolDefinition(
    name: 'update_symbol',
    description: 'Update an existing symbol',
    inputSchema: {
      'type': 'object',
      'properties': {
        'uuid': {'type': 'string'},
        'reference': {'type': 'string'},
        'value': {'type': 'string'},
        'position': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
            'angle': {'type': 'number'},
          },
        },
        'mirror_x': {'type': 'boolean'},
        'mirror_y': {'type': 'boolean'},
      },
      'required': ['uuid'],
    },
  ),
  ToolDefinition(
    name: 'remove_element',
    description: 'Remove an element by UUID',
    inputSchema: {
      'type': 'object',
      'properties': {
        'uuid': {'type': 'string'},
      },
      'required': ['uuid'],
    },
  ),
  ToolDefinition(
    name: 'add_wire',
    description: 'Add a wire connection',
    inputSchema: {
      'type': 'object',
      'properties': {
        'points': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'x': {'type': 'number'},
              'y': {'type': 'number'},
            },
            'required': ['x', 'y'],
          },
        },
        'stroke_width': {'type': 'number'},
      },
      'required': ['points'],
    },
  ),
  ToolDefinition(
    name: 'add_junction',
    description: 'Add a junction',
    inputSchema: {
      'type': 'object',
      'properties': {
        'position': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
          },
          'required': ['x', 'y'],
        },
        'diameter': {'type': 'number'},
      },
      'required': ['position'],
    },
  ),
  ToolDefinition(
    name: 'add_label',
    description: 'Add a label',
    inputSchema: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string'},
        'position': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
            'angle': {'type': 'number'},
          },
          'required': ['x', 'y'],
        },
      },
      'required': ['text', 'position'],
    },
  ),
  ToolDefinition(
    name: 'add_global_label',
    description: 'Add a global label',
    inputSchema: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string'},
        'position': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
            'angle': {'type': 'number'},
          },
          'required': ['x', 'y'],
        },
        'shape': {'type': 'string'},
      },
      'required': ['text', 'position'],
    },
  ),
  ToolDefinition(
    name: 'add_bus',
    description: 'Add a bus',
    inputSchema: {
      'type': 'object',
      'properties': {
        'points': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'x': {'type': 'number'},
              'y': {'type': 'number'},
            },
            'required': ['x', 'y'],
          },
        },
        'stroke_width': {'type': 'number'},
      },
      'required': ['points'],
    },
  ),
  ToolDefinition(
    name: 'add_bus_entry',
    description: 'Add a bus entry',
    inputSchema: {
      'type': 'object',
      'properties': {
        'position': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
          },
          'required': ['x', 'y'],
        },
        'size': {
          'type': 'object',
          'properties': {
            'width': {'type': 'number'},
            'height': {'type': 'number'},
          },
          'required': ['width', 'height'],
        },
        'stroke_width': {'type': 'number'},
      },
      'required': ['position', 'size'],
    },
  ),
  ToolDefinition(
    name: 'find_elements_at_position',
    description: 'Find elements at a position',
    inputSchema: {
      'type': 'object',
      'properties': {
        'position': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
          },
          'required': ['x', 'y'],
        },
        'tolerance': {'type': 'number'},
      },
      'required': ['position'],
    },
  ),
  ToolDefinition(
    name: 'batch_add_elements',
    description: 'Batch add multiple elements in a single operation',
    inputSchema: {
      'type': 'object',
      'properties': {
        'operations': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'type': {'type': 'string'},
              'data': {'type': 'object'},
            },
            'required': ['type', 'data'],
          },
        },
      },
      'required': ['operations'],
    },
  ),
];
