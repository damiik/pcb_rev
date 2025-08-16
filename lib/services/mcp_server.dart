import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/pcb_board.dart';

// The server state can be managed in a simple state record or map.
var _currentBoard_ = pcbBoardFromJson({
  'id': '1',
  'name': 'Initial Board',
  'components': <String, dynamic>{},
  'nets': <String, dynamic>{},
  'images': <dynamic>[],
  'imageModifications': <String, dynamic>{},
  'lastUpdated': DateTime.now().toIso8601String(),
});

Future<void> startMCPServer({String baseUrl = 'http://localhost:8080', int port = 8080}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('MCP Server listening on port $port');

  await for (HttpRequest request in server) {
    _handleRequest(request, baseUrl);
  }
}

void _handleRequest(HttpRequest request, String baseUrl) {
  final response = request.response;
  response.headers.contentType = ContentType.json;

  switch (request.uri.path) {
    case '/board':
      if (request.method == 'GET') {
        response.write(jsonEncode(pcbBoardToJson(_currentBoard_)));
      } else if (request.method == 'POST') {
        utf8.decodeStream(request).then((body) {
          final data = jsonDecode(body);
          _currentBoard_ = pcbBoardFromJson(data);
          response.statusCode = 200;
          response.close();
        });
        return; // Avoid closing the response prematurely
      }
      break;

    case '/analyze':
      _handleAnalysis(request, response);
      break;

    case '/netlist':
      response.write(generateNetlist(_currentBoard_));
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

Future<Map<String, dynamic>> analyzeImageWithAI(
  String imagePath,
  PCBBoard currentBoard,
  String baseUrl,
) async {
  final requestBody = {
    'image': await File(imagePath).readAsBytes(),
    'currentState': jsonEncode(pcbBoardToJson(currentBoard)),
    'prompt': _buildAnalysisPrompt(currentBoard),
  };

  try {
    final aiResponse = await http.post(
      Uri.parse('$baseUrl/analyze'),
      body: jsonEncode(requestBody),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(aiResponse.body);
  } catch (e) {
    print('Error sending analysis request: $e');
    return {
      'error': 'Failed to connect to the analysis server.',
    };
  }
}

String _buildAnalysisPrompt(PCBBoard board) {
  return '''
  Analyze this PCB image and identify:
  1. Components visible (type, value, designator)
  2. Trace connections between components
  3. Any test points or connectors

  Current board state:
  ${generateNetlist(board)}

  Please provide updates in JSON format with new components and connections found.
  ''';
}

