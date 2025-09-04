import 'package:flutter/material.dart';
import 'features/ai_integration/data/mcp_server.dart';
import 'features/project/presentation/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start MCP server in background
  startMCPServer(baseUrl: 'http://localhost:8080');
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
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
      home: PCBAnalyzerApp(),
    );
  }
}
