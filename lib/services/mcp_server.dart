import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/project.dart';

// The server state can be managed in a simple state record or map.
var _currentProject_ = projectFromJson({
  'id': '1',
  'name': 'Initial Project',
  'logicalComponents': <String, dynamic>{},
  'logicalNets': <String, dynamic>{},
  'schematic': {
    'symbols': <String, dynamic>{},
    'wires': <String, dynamic>{},
  },
  'pcbImages': <dynamic>[],
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
    case '/project':
      if (request.method == 'GET') {
        response.write(jsonEncode(projectToJson(_currentProject_)));
      } else if (request.method == 'POST') {
        utf8.decodeStream(request).then((body) {
          final data = jsonDecode(body);
          _currentProject_ = projectFromJson(data);
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
      response.write(generateNetlistFromProject(_currentProject_));
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
  Project currentProject,
  String baseUrl,
) async {
  final requestBody = {
    'image': await File(imagePath).readAsBytes(),
    'currentState': jsonEncode(projectToJson(currentProject)),
    'prompt': _buildAnalysisPrompt(currentProject),
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

String _buildAnalysisPrompt(Project project) {
  return '''
  Analyze this PCB image and identify:
  1. Components visible (type, value, designator)
  2. Trace connections between components
  3. Any test points or connectors

  Current board state:
  ${generateNetlistFromProject(project)}

  Please provide updates in JSON format with new components and connections found.
  ''';
}

