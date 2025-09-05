import 'package:flutter/material.dart';
import 'features/ai_integration/data/mcp_server.dart';
import 'features/project/data/project.dart';
import 'features/project/presentation/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MCPServer? mcpServer;
  try {
    // Create a default project for the server
    final initialProject = projectFromJson({
      'id': '1',
      'name': 'Initial Project',
      'lastUpdated': DateTime.now().toIso8601String(),
      'logicalComponents': <String, dynamic>{},
      'logicalNets': <String, dynamic>{},
      'schematicFilePath': null,
      'pcbImages': <dynamic>[],
    });

    // Start the new MCP server in the background
    mcpServer = MCPServer(initialProject: initialProject);
    mcpServer.start();

    print("✅ MCP Server start initiated successfully.");
  } catch (e) {
    print("❌ FAILED TO START MCP SERVER: $e");
  }

  runApp(MyApp(mcpServer: mcpServer));
}

class MyApp extends StatefulWidget {
  final MCPServer? mcpServer;

  const MyApp({Key? key, this.mcpServer}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCB Reverse Engineering',
      theme: ThemeData.dark(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: PCBAnalyzerApp(mcpServer: widget.mcpServer),
    );
  }
}
