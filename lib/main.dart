import 'package:flutter/material.dart';
import 'features/ai_integration/data/mcp_server.dart';
import 'features/project/presentation/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start MCP server in background
  startMCPServer(baseUrl: 'http://localhost:8080');
  runApp(PCBAnalyzerApp());
}
