import 'package:flutter_test/flutter_test.dart';
import 'package:pcb_rev/features/ai_integration/domain/default_tools.dart';
import 'package:pcb_rev/features/ai_integration/data/core.dart';
import 'package:pcb_rev/features/ai_integration/data/mcp_server.dart';
import 'package:pcb_rev/kicad/data/kicad_schematic_models.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart' as kicad_symbol;
import 'package:pcb_rev/features/connectivity/models/connectivity.dart';
import 'package:pcb_rev/features/connectivity/models/core.dart' as connectivity_core;
import 'package:pcb_rev/features/connectivity/models/point.dart' as connectivity_point;

void main() {
  group('Default MCP Tools', () {
    late MCPServer mcpServer;

    setUp(() {
      mcpServer = _createTestMCPServer();
    });

    group('Tool Definitions', () {
      test('all default tools are properly defined', () {
        expect(defaultTools, hasLength(9));

        final toolNames = defaultTools.map((tool) => tool.name).toList();
        expect(toolNames, containsAll([
          'read_current_image',
          'write_current_image_components',
          'get_kicad_schematic',
          'get_symbol_libraries',
          'update_kicad_schematic',
          'get_netlist',
          'get_symbol_instances',
          'get_connectivity_graph',
          'get_labels_and_ports',
        ]));
      });

      test('read_current_image tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'read_current_image');

        expect(tool.description, contains('pixel data'));
        expect(tool.description, contains('Base64 format'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['properties'], isEmpty);
      });

      test('write_current_image_components tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'write_current_image_components');

        expect(tool.description, contains('component recognition results'));
        expect(tool.description, contains('AI should call this'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['required'], contains('components'));

        final componentsSchema = tool.inputSchema['properties']['components'];
        expect(componentsSchema['type'], 'array');
        expect(componentsSchema['items']['properties'], contains('designator'));
        expect(componentsSchema['items']['properties'], contains('bounding_box'));
        expect(componentsSchema['items']['properties'], contains('confidence'));
      });

      test('get_kicad_schematic tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'get_kicad_schematic');

        expect(tool.description, contains('full KiCad schematic data'));
        expect(tool.description, contains('symbol instances'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['properties'], isEmpty);
      });

      test('get_symbol_libraries tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'get_symbol_libraries');

        expect(tool.description, contains('available KiCad symbol libraries'));
        expect(tool.description, contains('place new components'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['properties'], isEmpty);
      });

      test('update_kicad_schematic tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'update_kicad_schematic');

        expect(tool.description, contains('Proposes and applies updates'));
        expect(tool.description, contains('adding new symbol instances'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['required'], contains('updates'));

        final updatesSchema = tool.inputSchema['properties']['updates'];
        expect(updatesSchema['type'], 'array');
        expect(updatesSchema['items']['properties'], contains('action'));
        expect(updatesSchema['items']['properties'], contains('payload'));
      });

      test('get_netlist tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'get_netlist');

        expect(tool.description, contains('current netlist'));
        expect(tool.description, contains('connectivity graph'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['properties'], isEmpty);
      });

      test('get_symbol_instances tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'get_symbol_instances');

        expect(tool.description, contains('all symbol instances'));
        expect(tool.description, contains('properties, pins, and positions'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['properties'], isEmpty);
      });

      test('get_connectivity_graph tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'get_connectivity_graph');

        expect(tool.description, contains('raw connectivity graph'));
        expect(tool.description, contains('wires, junctions, pins, labels'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['properties'], isEmpty);
      });

      test('get_labels_and_ports tool definition', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'get_labels_and_ports');

        expect(tool.description, contains('labels and hierarchical ports'));
        expect(tool.inputSchema['type'], 'object');
        expect(tool.inputSchema['properties'], isEmpty);
      });
    });

    group('MCP Server Integration', () {
      test('server is properly initialized', () {
        expect(mcpServer, isNotNull);
        expect(mcpServer.serverInfo['name'], 'pcb-reverse-engineering-server');
        expect(mcpServer.serverInfo['version'], '2.0.0');
      });

      test('server has expected tool definitions', () {
        // Test that the server would register all the expected tools
        final expectedTools = [
          'read_current_image',
          'write_current_image_components',
          'get_kicad_schematic',
          'get_symbol_libraries',
          'update_kicad_schematic',
          'get_netlist',
          'get_symbol_instances',
          'get_connectivity_graph',
          'get_labels_and_ports',
        ];

        for (final toolName in expectedTools) {
          final tool = defaultTools.firstWhere((t) => t.name == toolName);
          expect(tool, isNotNull, reason: 'Tool definition for $toolName should exist');
          expect(tool.description, isNotEmpty, reason: 'Tool $toolName should have a description');
        }
      });
    });

    group('Tool Schema Validation', () {
      test('all tools have valid schema structure', () {
        for (final tool in defaultTools) {
          expect(tool.inputSchema, isNotNull);
          expect(tool.inputSchema['type'], 'object');
          expect(tool.inputSchema.containsKey('properties'), true);

          if (tool.inputSchema.containsKey('required')) {
            expect(tool.inputSchema['required'], isA<List>());
          }
        }
      });

      test('tools with required parameters have correct schema', () {
        final toolsWithRequiredParams = defaultTools.where(
          (tool) => tool.inputSchema.containsKey('required')
        );

        for (final tool in toolsWithRequiredParams) {
          expect(tool.inputSchema['required'], isA<List>());
          expect(tool.inputSchema['required'], isNotEmpty);

          for (final requiredParam in tool.inputSchema['required']) {
            expect(requiredParam, isA<String>());
            expect(tool.inputSchema['properties'], contains(requiredParam));
          }
        }
      });

      test('component bounding box schema is correctly defined', () {
        final tool = defaultTools.firstWhere((t) => t.name == 'write_current_image_components');
        final boundingBoxSchema = tool.inputSchema['properties']['components']['items']['properties']['bounding_box'];

        expect(boundingBoxSchema['type'], 'object');
        expect(boundingBoxSchema['properties'], contains('x'));
        expect(boundingBoxSchema['properties'], contains('y'));
        expect(boundingBoxSchema['properties'], contains('w'));
        expect(boundingBoxSchema['properties'], contains('h'));
        expect(boundingBoxSchema['required'], contains('x'));
        expect(boundingBoxSchema['required'], contains('y'));
        expect(boundingBoxSchema['required'], contains('w'));
        expect(boundingBoxSchema['required'], contains('h'));
      });
    });
  });
}

// Create test MCP server
MCPServer _createTestMCPServer() {
  return MCPServer(
    getSchematic: () => null, // No schematic loaded by default
    updateSchematic: (_) {},
    getSymbolLibraries: () => [],
    getConnectivity: () => null, // No connectivity data by default
  );
}

// Test helper functions
Map<String, dynamic> _createTestToolHandler(String toolName, Map<String, dynamic> args) {
  // This is a simplified test helper that validates tool definitions
  // Real handler testing should be done in integration tests
  return {
    'tool_name': toolName,
    'args_received': args,
    'test_mode': true,
  };
}

// Helper functions for JSON conversion (simplified versions)
Map<String, dynamic> _schematicToJson(KiCadSchematic schematic) {
  return {
    'version': schematic.version,
    'generator': schematic.generator,
    'uuid': schematic.uuid,
    'symbol_instances': schematic.symbolInstances.map((s) => _symbolInstanceToJson(s)).toList(),
    'wires': schematic.wires.map((w) => _wireToJson(w)).toList(),
    'buses': schematic.buses.map((b) => _busToJson(b)).toList(),
    'bus_entries': schematic.busEntries.map((be) => _busEntryToJson(be)).toList(),
    'junctions': schematic.junctions.map((j) => _junctionToJson(j)).toList(),
    'global_labels': schematic.globalLabels.map((gl) => _globalLabelToJson(gl)).toList(),
    'labels': schematic.labels.map((l) => _labelToJson(l)).toList(),
  };
}

Map<String, dynamic> _symbolInstanceToJson(SymbolInstance instance) {
  return {
    'lib_id': instance.libId,
    'at': {'x': instance.at.x, 'y': instance.at.y},
    'uuid': instance.uuid,
    'properties': instance.properties.map((p) => _propertyToJson(p)).toList(),
    'unit': instance.unit,
    'in_bom': instance.inBom,
    'on_board': instance.onBoard,
    'dnp': instance.dnp,
  };
}

Map<String, dynamic> _propertyToJson(kicad_symbol.Property property) {
  return {
    'name': property.name,
    'value': property.value,
    'position': {'x': property.position.x, 'y': property.position.y},
    'effects': {
      'font': {
        'width': property.effects.font.width,
        'height': property.effects.font.height,
      },
      'justify': property.effects.justify.name,
    },
  };
}

Map<String, dynamic> _wireToJson(Wire wire) {
  return {
    'pts': wire.pts.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'stroke': {
      'width': wire.stroke.width,
    },
    'uuid': wire.uuid,
  };
}

Map<String, dynamic> _busToJson(Bus bus) {
  return {
    'pts': bus.pts.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'stroke': {
      'width': bus.stroke.width,
    },
    'uuid': bus.uuid,
  };
}

Map<String, dynamic> _busEntryToJson(BusEntry busEntry) {
  return {
    'at': {'x': busEntry.at.x, 'y': busEntry.at.y},
    'size': {'width': busEntry.size.width, 'height': busEntry.size.height},
    'uuid': busEntry.uuid,
  };
}

Map<String, dynamic> _junctionToJson(Junction junction) {
  return {
    'at': {'x': junction.at.x, 'y': junction.at.y},
    'diameter': junction.diameter,
    'uuid': junction.uuid,
  };
}

Map<String, dynamic> _globalLabelToJson(GlobalLabel globalLabel) {
  return {
    'text': globalLabel.text,
    'at': {'x': globalLabel.at.x, 'y': globalLabel.at.y},
    'shape': globalLabel.shape.name,
    'effects': {
      'font': {
        'width': globalLabel.effects.font.width,
        'height': globalLabel.effects.font.height,
      },
      'justify': globalLabel.effects.justify.name,
    },
    'uuid': globalLabel.uuid,
  };
}

Map<String, dynamic> _labelToJson(Label label) {
  return {
    'text': label.text,
    'at': {'x': label.at.x, 'y': label.at.y},
    'effects': {
      'font': {
        'width': label.effects.font.width,
        'height': label.effects.font.height,
      },
      'justify': label.effects.justify.name,
    },
    'uuid': label.uuid,
  };
}

// Create mock schematic for testing
KiCadSchematic _createMockSchematic() {
  return KiCadSchematic(
    version: '20211014',
    generator: 'pcb_rev_test',
    uuid: 'test-schematic-uuid',
    symbolInstances: [
      SymbolInstance(
        libId: 'Device:Q_NPN_BCE',
        at: const kicad_symbol.Position(100, 100),
        uuid: 'tr1-uuid',
        properties: [
          kicad_symbol.Property(
            name: 'Reference',
            value: 'TR1',
            position: const kicad_symbol.Position(0, 0),
            effects: const kicad_symbol.TextEffects(
              font: kicad_symbol.Font(width: 1.27, height: 1.27),
              justify: kicad_symbol.Justify.left,
            ),
          ),
          kicad_symbol.Property(
            name: 'Value',
            value: '2N2222',
            position: const kicad_symbol.Position(0, 0),
            effects: const kicad_symbol.TextEffects(
              font: kicad_symbol.Font(width: 1.27, height: 1.27),
              justify: kicad_symbol.Justify.left,
            ),
          ),
        ],
        unit: 1,
        inBom: true,
        onBoard: true,
        dnp: false,
      ),
    ],
    wires: [],
    buses: [],
    busEntries: [],
    junctions: [],
    globalLabels: [],
    labels: [],
  );
}

// Create mock connectivity for testing
Connectivity _createMockConnectivity() {
  final mockGraph = connectivity_core.ConnectivityGraph(
    items: {
      'item_1': connectivity_core.Pin(
        'item_1',
        const connectivity_point.Point(0, 0),
        'symbol_ref',
        'pin_name',
        'symbol_designator',
      ),
    },
    subgraphs: [],
    nets: {},
    lastUpdated: DateTime.now(),
  );

  return Connectivity(
    graph: mockGraph,
    nets: [
      connectivity_core.Net(
        'GND',
        [
          connectivity_core.Pin('GND_1', const connectivity_point.Point(0, 0), 'GND', '1', 'GND'),
          connectivity_core.Pin('GND_2', const connectivity_point.Point(0, 0), 'GND', '2', 'GND'),
        ],
      ),
      connectivity_core.Net(
        'VCC',
        [
          connectivity_core.Pin('VCC_1', const connectivity_point.Point(0, 0), 'VCC', '1', 'VCC'),
          connectivity_core.Pin('VCC_2', const connectivity_point.Point(0, 0), 'VCC', '2', 'VCC'),
        ],
      ),
    ],
  );
}
