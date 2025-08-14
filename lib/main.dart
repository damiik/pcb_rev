import 'package:flutter/material.dart';
import 'services/mcp_server.dart';
import 'ui/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start MCP server in background
  final mcpServer = MCPServer(baseUrl: 'http://localhost:8080');
  mcpServer.startServer();
  
  runApp(PCBAnalyzerApp());
}