import 'lib/features/ai_integration/domain/mcp_server_tools.dart';

void main() {
  print('Domain tools loaded successfully!');
  print('Total tools available: ${availableTools.length}');
  print('Default tools: ${defaultMcpTools.length}');
  print('Schematic edit tools: ${schematicEditMcpTools.length}');

  print('\nFirst few default tools:');
  for (var i = 0; i < 3 && i < defaultMcpTools.length; i++) {
    print('  - ${defaultMcpTools[i].name}');
  }

  print('\nFirst few schematic edit tools:');
  for (var i = 0; i < 3 && i < schematicEditMcpTools.length; i++) {
    print('  - ${schematicEditMcpTools[i].name}');
  }
}
