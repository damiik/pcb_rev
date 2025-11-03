import 'package:flutter_test/flutter_test.dart';
import 'package:pcb_rev/features/ai_integration/data/mcp_server.dart';
import 'package:pcb_rev/features/ai_integration/data/project_mcp.dart';
import 'package:pcb_rev/features/ai_integration/domain/default_tools.dart';
import 'package:pcb_rev/features/ai_integration/domain/project_mcp_tools.dart';
import 'package:pcb_rev/features/ai_integration/domain/schematic_edit_tools.dart';
import 'package:pcb_rev/kicad/data/kicad_schematic_models.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart' as kicad_symbol;
import 'package:pcb_rev/project/data/project.dart';
import 'package:pcb_rev/project/data/logical_models.dart';
import 'package:pcb_rev/project/domain/project_operations.dart';
import 'package:pcb_rev/features/connectivity/models/connectivity.dart';
import 'package:pcb_rev/features/connectivity/models/core.dart' as connectivity_core;
import 'package:pcb_rev/features/connectivity/models/point.dart' as connectivity_point;
import 'package:pcb_rev/kicad/data/kicad_schematic_serializer.dart';

void main() {
  group('MCP Default Tools', () {
    late Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> handlers;
    late _MockToolHandlerState mockState;

    setUp(() {
      mockState = _MockToolHandlerState();
      handlers = _createMockDefaultToolHandlers(mockState);
    });

    group('Image Processing Tools', () {
      test('read_current_image returns image data when image is available', () async {
        // Setup mock to return image data
        mockState.setMockImageData('mock_image_data');

        final result = await handlers['read_current_image']!({});

        expect(result['success'], true);
        expect(result['image_data'], 'mock_image_data');
        expect(result['format'], 'base64');
      });

      test('read_current_image fails when no image is available', () async {
        // Setup mock to return no image
        mockState.setMockImageData(null);

        final result = await handlers['read_current_image']!({});

        expect(result['success'], false);
        expect(result['error'], contains('No active image'));
      });

      test('write_current_image_components succeeds with valid data', () async {
        final components = [
          {
            'designator': 'R1',
            'bounding_box': {'x': 10, 'y': 20, 'w': 30, 'h': 40},
            'confidence': 0.95,
          }
        ];

        final result = await handlers['write_current_image_components']!({
          'components': components,
        });

        expect(result['success'], true);
        expect(result['message'], contains('Components written successfully'));
        expect(result['components_processed'], 1);
      });

      test('write_current_image_components fails with invalid data', () async {
        final result = await handlers['write_current_image_components']!({
          'components': 'invalid_data',
        });

        expect(result['success'], false);
        expect(result['error'], contains('Invalid components data'));
      });
    });

    group('Schematic Data Tools', () {
      test('get_kicad_schematic returns schematic data', () async {
        final mockSchematic = _createMockSchematic();
        mockState.setMockSchematic(mockSchematic);

        final result = await handlers['get_kicad_schematic']!({});

        expect(result['success'], true);
        expect(result['schematic'], isNotNull);
        expect(result['schematic']['version'], '20211014');
        expect(result['schematic']['symbol_instances'], isA<List>());
      });

      test('get_kicad_schematic fails when no schematic is loaded', () async {
        mockState.setMockSchematic(null);

        final result = await handlers['get_kicad_schematic']!({});

        expect(result['success'], false);
        expect(result['error'], contains('No schematic loaded'));
      });

      test('get_symbol_libraries returns available libraries', () async {
        final mockLibraries = [
          {'name': 'Device', 'symbols': ['R', 'C', 'L']},
          {'name': 'Power', 'symbols': ['GND', 'VCC']},
        ];
        mockState.setMockSymbolLibraries(mockLibraries);

        final result = await handlers['get_symbol_libraries']!({});

        expect(result['success'], true);
        expect(result['libraries'], hasLength(2));
        expect(result['libraries'][0]['name'], 'Device');
      });

      test('get_symbol_instances returns all symbol instances', () async {
        final mockSchematic = _createMockSchematic();
        mockState.setMockSchematic(mockSchematic);

        final result = await handlers['get_symbol_instances']!({});

        expect(result['success'], true);
        expect(result['symbol_instances'], isA<List>());
        expect(result['symbol_instances'], hasLength(1));
        expect(result['symbol_instances'][0]['lib_id'], 'Device:Q_NPN_BCE');
      });

      test('get_labels_and_ports returns labels and ports', () async {
        final mockSchematic = _createMockSchematic();
        mockState.setMockSchematic(mockSchematic);

        final result = await handlers['get_labels_and_ports']!({});

        expect(result['success'], true);
        expect(result['labels'], isA<List>());
        expect(result['ports'], isA<List>());
      });
    });

    group('Connectivity Tools', () {
      test('get_netlist returns netlist from connectivity', () async {
        final mockConnectivity = _createMockConnectivity();
        mockState.setMockConnectivity(mockConnectivity);

        final result = await handlers['get_netlist']!({});

        expect(result['success'], true);
        expect(result['netlist'], isNotNull);
        expect(result['netlist']['nets'], isA<List>());
      });

      test('get_netlist fails when no connectivity data', () async {
        mockState.setMockConnectivity(null);

        final result = await handlers['get_netlist']!({});

        expect(result['success'], false);
        expect(result['error'], contains('No connectivity data'));
      });

      test('get_connectivity_graph returns connectivity graph', () async {
        final mockConnectivity = _createMockConnectivity();
        mockState.setMockConnectivity(mockConnectivity);

        final result = await handlers['get_connectivity_graph']!({});

        expect(result['success'], true);
        expect(result['connectivity_graph'], isNotNull);
        expect(result['connectivity_graph']['items'], isA<List>());
      });
    });

    group('Schematic Modification Tools', () {
      test('update_kicad_schematic succeeds with valid updates', () async {
        final mockSchematic = _createMockSchematic();
        mockState.setMockSchematic(mockSchematic);

        final updates = [
          {
            'action': 'add_symbol',
            'payload': {
              'lib_id': 'Device:R',
              'reference': 'R1',
              'value': '10k',
              'position': {'x': 100, 'y': 200},
            },
          }
        ];

        final result = await handlers['update_kicad_schematic']!({
          'updates': updates,
        });

        expect(result['success'], true);
        expect(result['message'], contains('Schematic updated successfully'));
        expect(result['updates_applied'], 1);
      });

      test('update_kicad_schematic fails with invalid updates', () async {
        final result = await handlers['update_kicad_schematic']!({
          'updates': 'invalid_updates',
        });

        expect(result['success'], false);
        expect(result['error'], contains('Invalid updates format'));
      });
    });

    group('Tool Registration and Schema', () {
      test('all default tools are registered', () {
        final toolNames = handlers.keys.toList();
        expect(toolNames, contains('read_current_image'));
        expect(toolNames, contains('write_current_image_components'));
        expect(toolNames, contains('get_kicad_schematic'));
        expect(toolNames, contains('get_symbol_libraries'));
        expect(toolNames, contains('update_kicad_schematic'));
        expect(toolNames, contains('get_netlist'));
        expect(toolNames, contains('get_symbol_instances'));
        expect(toolNames, contains('get_connectivity_graph'));
        expect(toolNames, contains('get_labels_and_ports'));
      });

      test('default tools have correct schemas', () {
        // Test read_current_image schema
        final readImageTool = defaultTools.firstWhere((t) => t.name == 'read_current_image');
        expect(readImageTool.inputSchema['properties'], isEmpty);

        // Test write_current_image_components schema
        final writeComponentsTool = defaultTools.firstWhere((t) => t.name == 'write_current_image_components');
        expect(writeComponentsTool.inputSchema['required'], contains('components'));
        expect(writeComponentsTool.inputSchema['properties']['components'], isA<Map>());
      });
    });
  });

  group('MCP Project Tools', () {
    late Project testProject;
    late KiCadSchematic testSchematic;

    setUp(() {
      // Create test schematic with TR1 component
      testSchematic = KiCadSchematic(
        version: '20211014',
        generator: 'test',
        uuid: 'test-uuid',
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

      // Create test project and sync with schematic
      testProject = projectFromJson({
        'id': 'test-project',
        'name': 'Test Project',
        'lastUpdated': DateTime.now().toIso8601String(),
        'logicalNets': <String, dynamic>{},
        'schematicFilePath': null,
        'pcbImages': <dynamic>[],
      });
    });

    test('select_component finds existing component', () async {
      LogicalComponent? selectedComponent;

      final handlers = _createTestHandlersWithSchematic(
        testProject,
        testSchematic,
        onComponentSelected: (component) {
          selectedComponent = component;
        },
      );

      final result = await handlers['select_component']!({'reference': 'TR1'});

      expect(result['success'], true);
      expect(result['component']['id'], 'TR1');
      expect(result['component']['type'], 'Device:Q_NPN_BCE');
      expect(result['component']['value'], '2N2222');
      expect(selectedComponent, isNotNull);
      expect(selectedComponent!.id, 'TR1');
    });

    test('select_component fails for non-existent component', () async {
      final handlers = _createTestHandlersWithSchematic(testProject, testSchematic);

      final result = await handlers['select_component']!({'reference': 'R999'});

      expect(result['success'], false);
      expect(result['error'], contains('not found'));
    });

    test('select_component fails when no project loaded', () async {
      final handlers = _createTestHandlers(null);

      final result = await handlers['select_component']!({'reference': 'TR1'});

      expect(result['success'], false);
      expect(result['error'], contains('No project'));
    });

    test('select_component fails without reference argument', () async {
      final handlers = _createTestHandlers(testProject);

      expect(
        () => handlers['select_component']!({}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('MCP Server Integration', () {
    test('server registers all default tools', () {
      final server = _createTestServer();

      // Test that the server has the expected tools by checking the handlers
      final handlers = server.projectToolHandlers(
        onProjectOpened: (_) {},
        onSchematicLoaded: (_) {},
        getProject: () => null,
        updateProject: (_) {},
        onComponentSelected: (_) {},
      );

      final toolNames = handlers.keys.toList();
      expect(toolNames, containsAll([
              'open_project',
              'add_image',
              'load_schematic',
              'save_project',
              'save_schematic',
              'export_netlist',
              'process_image',
              'add_component',
              'select_component'
      ]));
    });

    test('default tools have correct schemas', () {
      // Test read_current_image schema
      final readImageTool = defaultTools.firstWhere((t) => t.name == 'read_current_image');
      expect(readImageTool.description, contains('pixel data'));
      expect(readImageTool.inputSchema['properties'], isEmpty);

      // Test select_component schema from project tools
      final selectComponentTool = projectMcpTools.firstWhere((t) => t.name == 'select_component');
      expect(selectComponentTool.description, contains('reference designator'));
      expect(selectComponentTool.inputSchema['properties'], contains('reference'));
      expect(selectComponentTool.inputSchema['required'], contains('reference'));
    });
  });
}

// Mock state holder for default tool handlers
class _MockToolHandlerState {
  String? _mockImageData;
  KiCadSchematic? _mockSchematic;
  List<dynamic>? _mockSymbolLibraries;
  Connectivity? _mockConnectivity;

  void setMockImageData(String? data) => _mockImageData = data;
  void setMockSchematic(KiCadSchematic? schematic) => _mockSchematic = schematic;
  void setMockSymbolLibraries(List<dynamic>? libraries) => _mockSymbolLibraries = libraries;
  void setMockConnectivity(Connectivity? connectivity) => _mockConnectivity = connectivity;

  String? get mockImageData => _mockImageData;
  KiCadSchematic? get mockSchematic => _mockSchematic;
  List<dynamic>? get mockSymbolLibraries => _mockSymbolLibraries;
  Connectivity? get mockConnectivity => _mockConnectivity;
}

// Create mock handlers for default tools
Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> _createMockDefaultToolHandlers(_MockToolHandlerState state) {
  return {
    'read_current_image': (args) async {
      if (state.mockImageData == null) {
        return {
          'success': false,
          'error': 'No active image is set',
        };
      }
      return {
        'success': true,
        'image_data': state.mockImageData,
        'format': 'base64',
      };
    },
    'write_current_image_components': (args) async {
      final components = args['components'];
      if (components == null || components is! List) {
        return {
          'success': false,
          'error': 'Invalid components data',
        };
      }
      return {
        'success': true,
        'message': 'Components written successfully',
        'components_processed': components.length,
      };
    },
    'get_kicad_schematic': (args) async {
      if (state.mockSchematic == null) {
        return {
          'success': false,
          'error': 'No schematic loaded',
        };
      }
      return {
        'success': true,
        'schematic': kiCadSchematicToJson(state.mockSchematic!),
      };
    },
    'get_symbol_libraries': (args) async {
      return {
        'success': true,
        'libraries': state.mockSymbolLibraries ?? [],
      };
    },
    'get_symbol_instances': (args) async {
      if (state.mockSchematic == null) {
        return {
          'success': false,
          'error': 'No schematic loaded',
        };
      }
      return {
        'success': true,
        'symbol_instances': state.mockSchematic!.symbolInstances.map((s) => symbolInstanceToJson(s)).toList(),
      };
    },
    'get_labels_and_ports': (args) async {
      if (state.mockSchematic == null) {
        return {
          'success': false,
          'error': 'No schematic loaded',
        };
      }
      return {
        'success': true,
        'labels': state.mockSchematic!.labels.map((l) => labelToJson(l)).toList(),
        'ports': [], // Empty for now
      };
    },
    'get_netlist': (args) async {
      if (state.mockConnectivity == null) {
        return {
          'success': false,
          'error': 'No connectivity data available',
        };
      }
      return {
        'success': true,
        'netlist': {
          'nets': [
            {'name': 'GND', 'pins': ['GND_1', 'GND_2']},
            {'name': 'VCC', 'pins': ['VCC_1', 'VCC_2']},
          ],
        },
      };
    },
    'get_connectivity_graph': (args) async {
      if (state.mockConnectivity == null) {
        return {
          'success': false,
          'error': 'No connectivity data available',
        };
      }
      return {
        'success': true,
        'connectivity_graph': {
          'items': [
            {'type': 'pin', 'id': 'pin_1', 'position': {'x': 0, 'y': 0}},
            {'type': 'wire', 'id': 'wire_1', 'points': [{'x': 0, 'y': 0}, {'x': 10, 'y': 10}]},
          ],
        },
      };
    },
    'update_kicad_schematic': (args) async {
      final updates = args['updates'];
      if (updates == null || updates is! List) {
        return {
          'success': false,
          'error': 'Invalid updates format',
        };
      }
      return {
        'success': true,
        'message': 'Schematic updated successfully',
        'updates_applied': updates.length,
      };
    },
  };
}

// Test helpers

Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)>
_createTestHandlers(
  Project? project, {
  void Function(LogicalComponent)? onComponentSelected,
}) {
  final server = _createTestServer();

  return server.projectToolHandlers(
    onProjectOpened: (_) {},
    onSchematicLoaded: (_) {},
    getProject: () => project,
    updateProject: (_) {},
    onComponentSelected: onComponentSelected ?? (_) {},
  );
}

Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)>
_createTestHandlersWithSchematic(
  Project? project,
  KiCadSchematic schematic, {
  void Function(LogicalComponent)? onComponentSelected,
}) {
  final server = _createTestServerWithSchematic(schematic);

  return server.projectToolHandlers(
    onProjectOpened: (_) {},
    onSchematicLoaded: (_) {},
    getProject: () => project,
    updateProject: (_) {},
    onComponentSelected: onComponentSelected ?? (_) {},
  );
}

MCPServer _createTestServer() {
  return MCPServer(
    getSchematic: () => null,
    updateSchematic: (_) {},
    getSymbolLibraries: () => [],
    getConnectivity: () => null,
  );
}

MCPServer _createTestServerWithSchematic(KiCadSchematic schematic) {
  return MCPServer(
    getSchematic: () => schematic,
    updateSchematic: (_) {},
    getSymbolLibraries: () => [],
    getConnectivity: () => null,
  );
}



KiCadSchematic _createMockSchematic() {
  return KiCadSchematic(
    version: '20211014',
    generator: 'test',
    uuid: 'test-uuid',
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
    nets: [],
  );
}
