import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/pcb_board.dart';

class MCPServer {
  final String baseUrl;
  final HttpServer? _server;
  PCBBoard? _currentBoard;
  
  MCPServer({required this.baseUrl}) : _server = null;
  
  // Start local MCP server
  Future<void> startServer({int port = 8080}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print('MCP Server listening on port $port');
    
    await for (HttpRequest request in server) {
      _handleRequest(request);
    }
  }
  
  void _handleRequest(HttpRequest request) {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    
    switch (request.uri.path) {
      case '/board':
        if (request.method == 'GET') {
          response.write(jsonEncode(_currentBoard?.toJson() ?? {}));
        } else if (request.method == 'POST') {
          // Update board data
          utf8.decodeStream(request).then((body) {
            final data = jsonDecode(body);
            // Update _currentBoard based on data
            response.statusCode = 200;
            response.close();
          });
        }
        break;
        
      case '/analyze':
        // Send to AI for analysis
        _handleAnalysis(request, response);
        break;
        
      case '/netlist':
        response.write(_currentBoard?.generateNetlist() ?? '');
        break;
        
      default:
        response.statusCode = 404;
    }
    
    response.close();
  }
  
  Future<void> _handleAnalysis(HttpRequest request, HttpResponse response) async {
    response.write(jsonEncode({
      "new_components": [],
      "new_connections": [],
      "suggested_nets": [],
      "architecture_notes": "Dummy analysis"
    }));
  }
  
  // Client methods for AI interaction
  Future<Map<String, dynamic>> analyzeImage(
    String imagePath,
    PCBBoard currentBoard,
  ) async {
    final formData = {
      'image': await File(imagePath).readAsBytes(),
      'currentState': jsonEncode(currentBoard.toJson()),
      'prompt': _buildAnalysisPrompt(currentBoard),
    };
    
    // Send to AI service
    final aiResponse = await http.post(
      Uri.parse('$baseUrl/analyze'),
      body: jsonEncode(formData),
    );
    
    return jsonDecode(aiResponse.body);
  }
  
  String _buildAnalysisPrompt(PCBBoard board) {
    return '''
    Analyze this PCB image and identify:
    1. Components visible (type, value, designator)
    2. Trace connections between components
    3. Any test points or connectors
    
    Current board state:
    ${board.generateNetlist()}
    
    Please provide updates in JSON format with new components and connections found.
    ''';
  }
}
