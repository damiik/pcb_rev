import 'package:flutter_test/flutter_test.dart';
import 'package:pcb_rev/features/ai_integration/data/mcp_server.dart';
import 'package:pcb_rev/features/ai_integration/data/project_mcp.dart';
import 'package:pcb_rev/kicad/data/kicad_schematic_models.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart' as kicad_symbol;
import 'package:pcb_rev/project/data/project.dart';
import 'package:pcb_rev/project/data/logical_models.dart';
import 'package:pcb_rev/project/domain/project_operations.dart';

void main() {
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
      final initialProject = projectFromJson({
        'id': 'test-project',
        'name': 'Test Project',
        'lastUpdated': DateTime.now().toIso8601String(),
        'logicalComponents': <String, dynamic>{},
        'logicalNets': <String, dynamic>{},
        'schematicFilePath': null,
        'pcbImages': <dynamic>[],
      });
      
      testProject = syncProjectWithSchematic(initialProject, testSchematic);
    });
    
    test('buildLogicalComponentsFromSchematic creates components', () {
      final components = buildLogicalComponentsFromSchematic(testSchematic);
      
      expect(components, contains('TR1'));
      expect(components['TR1']?.type, 'Device:Q_NPN_BCE');
      expect(components['TR1']?.value, '2N2222');
    });
    
    test('select_component finds existing component', () async {
      LogicalComponent? selectedComponent;
      
      final handlers = _createTestHandlers(
        testProject,
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
      final handlers = _createTestHandlers(testProject);
      
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
    test('server registers select_component tool', () {
      final server = _createTestServer();
      
      final toolNames = server._availableTools.map((t) => t.name).toList();
      expect(toolNames, contains('select_component'));
    });
    
    test('select_component tool has correct schema', () {
      final server = _createTestServer();
      
      final tool = server._availableTools.firstWhere(
        (t) => t.name == 'select_component',
      );
      
      expect(tool.description, contains('reference designator'));
      expect(tool.inputSchema['properties'], contains('reference'));
      expect(tool.inputSchema['required'], contains('reference'));
    });
  });
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

MCPServer _createTestServer() {
  return MCPServer(
    getSchematic: () => null,
    updateSchematic: (_) {},
    getSymbolLibraries: () => [],
    getConnectivity: () => null,
  );
}