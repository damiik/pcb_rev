import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'core.dart';
import '../domain/mcp_server_tools.dart';

import '../../project/data/project.dart';


// ============================================================================
// MCP Server Implementation
// ============================================================================

class MCPServer {
  late final HttpServer _server;
  final MCPServerConfig config;
  final MCPServerState state;
  final StreamController<String> _logController = StreamController.broadcast();
  
  Stream<String> get logs => _logController.stream;
  
  MCPServer({
    MCPServerConfig? config,
    required Project initialProject,
  })  : config = config ?? const MCPServerConfig(),
        state = MCPServerState(currentProject: initialProject);
  
  Future<void> start() async {
    _server = await HttpServer.bind(config.host, config.port);
    _log('MCP Server started on http://${config.host}:${config.port}${config.basePath}');
    
    await for (HttpRequest request in _server) {
      _handleHttpRequest(request);
    }
  }
  
  void _handleHttpRequest(HttpRequest request) async {
    if (request.uri.path != config.basePath) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    
    if (request.method != 'POST') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..close();
      return;
    }
    
    try {
      final body = await utf8.decodeStream(request);
      _log('Received request: $body');
      
      final Map<String, dynamic> json = jsonDecode(body);
      final rpcRequest = JsonRpcRequest.fromJson(json);
      
      final response = await _dispatch(rpcRequest);
      
      final responseBody = jsonEncode(response.toJson());
      _log('Sending response: $responseBody');
      
      request.response
        ..headers.contentType = ContentType.json
        ..write(responseBody)
        ..close();
    } catch (e, stackTrace) {
      _log('Error handling request: $e\n$stackTrace');
      
      final errorResponse = JsonRpcResponse(
        id: null,
        error: JsonRpcError(
          code: -32700,
          message: 'Parse error',
          data: e.toString(),
        ),
      );
      
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(errorResponse.toJson()))
        ..close();
    }
  }
  
  Future<JsonRpcResponse> _dispatch(JsonRpcRequest request) async {
    try {
      final handler = _routes[request.method];
      
      if (handler == null) {
        return JsonRpcResponse(
          id: request.id,
          error: JsonRpcError(
            code: -32601,
            message: 'Method not found: ${request.method}',
          ),
        );
      }
      
      final result = await handler(request.params ?? {});
      
      return JsonRpcResponse(
        id: request.id,
        result: result,
      );
    } catch (e, stackTrace) {
      _log('Error in dispatch: $e\n$stackTrace');
      
      return JsonRpcResponse(
        id: request.id,
        error: JsonRpcError(
          code: -32603,
          message: 'Internal error',
          data: e.toString(),
        ),
      );
    }
  }
  
  Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> get _routes => {
        'initialize': _handleInitialize,
        'tools/list': _handleToolsList,
        'tools/call': _handleToolsCall,
        'notifications/initialized': _handleInitialized,
        'notifications/cancelled': _handleCancelled,
      };
  
  Future<Map<String, dynamic>> _handleInitialize(Map<String, dynamic> params) async {
    return {
      'protocolVersion': '2024-11-05',
      'capabilities': {
        'tools': {
          'listChanged': true,
        },
        'resources': {
          'subscribe': true,
          'listChanged': true,
        },
      },
      'serverInfo': {
        'name': 'pcb-reverse-engineering-server',
        'version': '2.0.0',
      },
    };
  }
  
  Future<Map<String, dynamic>> _handleToolsList(Map<String, dynamic> params) async {
    return {
      'tools': availableTools.map((t) => t.toJson()).toList(),
    };
  }
  
  Future<Map<String, dynamic>> _handleToolsCall(Map<String, dynamic> params) async {
    final toolName = params['name'] as String?;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};
    
    if (toolName == null) {
      throw ArgumentError('Tool name is required');
    }
    
    final toolHandler = _toolHandlers[toolName];
    
    if (toolHandler == null) {
      throw ArgumentError('Unknown tool: $toolName');
    }
    
    final result = await toolHandler(arguments);
    
    return {
      'content': [
        {
          'type': 'text',
          'text': jsonEncode(result),
        },
      ],
    };
  }
  
  Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> get _toolHandlers => {
        // 'analyze_pcb_image': _analyzeImage,
        'get_project_state': _getProjectState,
        'update_schematic': _updateSchematic,
        'generate_netlist': _generateNetlist,
        // 'add_pcb_image': _addImage,
        'detect_components': _detectComponents,
      };
  
  // Future<Map<String, dynamic>> _analyzeImage(Map<String, dynamic> args) async {
  //   final imageId = args['image_id'] as String;
  //   final analysisType = args['analysis_type'] as String? ?? 'full';
  //   final region = args['region'] as Map<String, dynamic>?;
    
  //   final image = state.imageCache[imageId];
  //   if (image == null) {
  //     throw ArgumentError('Image not found: $imageId');
  //   }
    
  //   // Perform AI-based analysis
  //   final analysisResult = await _performAIAnalysis(
  //     image: image,
  //     analysisType: analysisType,
  //     region: region,
  //   );
    
  //   // Store in history
  //   state.analysisHistory.add({
  //     'timestamp': DateTime.now().toIso8601String(),
  //     'image_id': imageId,
  //     'type': analysisType,
  //     'result': analysisResult,
  //   });
    
  //   return analysisResult;
  // }
  
  // Future<Map<String, dynamic>> _performAIAnalysis({
  //   required PcbImage image,
  //   required String analysisType,
  //   Map<String, dynamic>? region,
  // }) async {
  //   // Simulated AI analysis - in production, this would call actual CV/AI service
  //   await Future.delayed(Duration(milliseconds: 500));
    
  //   final components = <Map<String, dynamic>>[];
  //   final connections = <Map<String, dynamic>>[];
  //   final suggestions = <String>[];
    
  //   if (analysisType == 'components' || analysisType == 'full') {
  //     components.addAll([
  //       {
  //         'type': 'resistor',
  //         'value': '10k',
  //         'designator': 'R${DateTime.now().millisecondsSinceEpoch % 100}',
  //         'confidence': 0.95,
  //         'bbox': {'x': 100, 'y': 150, 'w': 30, 'h': 10},
  //       },
  //       {
  //         'type': 'capacitor',
  //         'value': '100nF',
  //         'designator': 'C${DateTime.now().millisecondsSinceEpoch % 100}',
  //         'confidence': 0.88,
  //         'bbox': {'x': 200, 'y': 180, 'w': 25, 'h': 25},
  //       },
  //     ]);
  //   }
    
  //   if (analysisType == 'traces' || analysisType == 'full') {
  //     connections.addAll([
  //       {
  //         'from': 'R1.1',
  //         'to': 'C1.1',
  //         'confidence': 0.92,
  //         'path': [
  //           {'x': 115, 'y': 155},
  //           {'x': 200, 'y': 155},
  //           {'x': 200, 'y': 180},
  //         ],
  //       },
  //     ]);
  //   }
    
  //   suggestions.addAll([
  //     'Detected potential power supply circuit',
  //     'Consider adding bypass capacitor near IC1',
  //     'Ground plane appears fragmented in region (300,200)',
  //   ]);
    
  //   return {
  //     'detected_components': components,
  //     'detected_connections': connections,
  //     'suggestions': suggestions,
  //     'confidence': 0.91,
  //     'processing_time_ms': 500,
  //   };
  // }
  
  Future<Map<String, dynamic>> _getProjectState(Map<String, dynamic> args) async {
    final includeImages = args['include_images'] as bool? ?? false;
    final includeHistory = args['include_history'] as bool? ?? false;

    final result = projectToJson(state.currentProject);

    if (!includeImages) {
      // Remove image data to reduce payload
      result['pcbImages'] = (result['pcbImages'] as List)
          .map((img) {
            img.remove('data');
            return img;
          })
          .toList();
    }
    
    if (includeHistory) {
      result['analysisHistory'] = state.analysisHistory;
    }
    
    return result;
  }
  
  Future<Map<String, dynamic>> _updateSchematic(Map<String, dynamic> args) async {
    final componentUpdates = args['components'] as List<dynamic>? ?? [];
    final netUpdates = args['nets'] as List<dynamic>? ?? [];
    
    int addedComponents = 0;
    int updatedComponents = 0;
    int removedComponents = 0;
    int addedNets = 0;
    int updatedNets = 0;
    int removedNets = 0;
    
    // Process component updates
    for (final update in componentUpdates) {
      final action = update['action'] as String;
      final id = update['id'] as String;
      
      switch (action) {
        case 'add':
          // if(state.schematicModel != null) {
          //   state.schematicModel!.symbolInstances. = symbolInstanceFromJson(update);
          // } else {
          //   state.schematicModel = KiCadSchematic(symbols: {id: symbolInstanceFromJson(update)}, wires: {});
          // }
          // state.currentProject.logicalComponents[id] = Component(
          //   id: id,
          //   type: update['type'],
          //   value: update['value'],
          //   designator: update['designator'],
          //   position: update['position'],
          // );
          addedComponents++;
          break;
        
        case 'update':
          // final existing = state.currentProject.logicalComponents[id];
          // if (existing != null) {
          //   state.currentProject.logicalComponents[id] = Component(
          //     id: id,
          //     type: update['type'] ?? existing.type,
          //     value: update['value'] ?? existing.value,
          //     designator: update['designator'] ?? existing.designator,
          //     position: update['position'] ?? existing.position,
          //   );
            // updatedComponents++;
          // }
          break;
        
        case 'remove':
          // if (state.currentProject.logicalComponents.remove(id) != null) {
          // removedComponents++;
          // }
          break;
      }
    }
    
    // Process net updates
    for (final update in netUpdates) {
      final action = update['action'] as String;
      final id = update['id'] as String;
      
      switch (action) {
        case 'add':
          // state.currentProject.logicalNets[id] = Net(
          //   id: id,
          //   name: update['name'],
          //   connectedPins: List<String>.from(update['connections'] ?? []),
          // );
          // addedNets++;
          break;
        
        case 'update':
          // final existing = state.currentProject.logicalNets[id];
          // if (existing != null) {
          //   state.currentProject.logicalNets[id] = Net(
          //     id: id,
          //     name: update['name'] ?? existing.name,
          //     connectedPins: update['connections'] != null
          //         ? List<String>.from(update['connections'])
          //         : existing.connectedPins,
          //   );
          //   updatedNets++;
          // }
          break;
        
        case 'remove':
          // if (state.currentProject.logicalNets.remove(id) != null) {
          //   removedNets++;
          // }
          break;
      }
    }
    
    // Update timestamp
    // state.currentProject = Project(
    //   id: state.currentProject.id,
    //   name: state.currentProject.name,
    //   logicalComponents: state.currentProject.logicalComponents,
    //   logicalNets: state.currentProject.logicalNets,
    //   schematic: state.currentProject.schematic,
    //   pcbImages: state.currentProject.pcbImages,
    //   lastUpdated: DateTime.now(),
    // );
    
    return {
      'success': true,
      'summary': {
        'components': {
          'added': addedComponents,
          'updated': updatedComponents,
          'removed': removedComponents,
        },
        'nets': {
          'added': addedNets,
          'updated': updatedNets,
          'removed': removedNets,
        },
      },
      'timestamp': state.currentProject.lastUpdated.toIso8601String(),
    };
  }
  
  Future<Map<String, dynamic>> _generateNetlist(Map<String, dynamic> args) async {
    final format = args['format'] as String? ?? 'kicad';
    
    String netlist = '';
    
    switch (format) {
      case 'kicad':
        netlist = _generateKiCadNetlist();
        break;
      
      case 'spice':
        netlist = _generateSpiceNetlist();
        break;
      
      case 'generic':
        // netlist = _generateGenericNetlist();
        break;
      
      default:
        throw ArgumentError('Unsupported format: $format');
    }
    
    return {
      'format': format,
      'netlist': netlist,
      'component_count': state.currentProject.logicalComponents.length,
      'net_count': state.currentProject.logicalNets.length,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }
  
  String _generateKiCadNetlist() {
    final buffer = StringBuffer();
    
    // buffer.writeln('(export (version D)');
    // buffer.writeln('  (design');
    // buffer.writeln('    (source "${state.currentProject.name}")');
    // buffer.writeln('    (date "${DateTime.now()}")');
    // buffer.writeln('    (tool "PCB Reverse Engineering MCP Server")');
    // buffer.writeln('  )');
    
    // // Components section
    // buffer.writeln('  (components');
    // for (final comp in state.currentProject.logicalComponents.values) {
    //   buffer.writeln('    (comp (ref ${comp.designator})');
    //   buffer.writeln('      (value ${comp.value})');
    //   buffer.writeln('      (footprint ${comp.type})');
    //   buffer.writeln('    )');
    // }
    // buffer.writeln('  )');
    
    // // Nets section
    // buffer.writeln('  (nets');
    // int netNum = 1;
    // for (final net in state.currentProject.logicalNets.values) {
    //   buffer.writeln('    (net (code $netNum) (name "${net.name}")');
    //   for (final pin in net.connectedPins) {
    //     final parts = pin.split('.');
    //     if (parts.length == 2) {
    //       buffer.writeln('      (node (ref ${parts[0]}) (pin ${parts[1]}))');
    //     }
    //   }
    //   buffer.writeln('    )');
    //   netNum++;
    // }
    // buffer.writeln('  )');
    
    // buffer.writeln(')');
    
    return buffer.toString();
  }
  
  String _generateSpiceNetlist() {
    final buffer = StringBuffer();
    
    // buffer.writeln('* SPICE netlist generated from ${state.currentProject.name}');
    // buffer.writeln('* Generated: ${DateTime.now()}');
    // buffer.writeln();
    
    // // Simple component listing
    // for (final comp in state.currentProject.logicalComponents.values) {
    //   final prefix = comp.designator[0];
      
    //   switch (prefix) {
    //     case 'R':
    //       buffer.writeln('${comp.designator} NET1 NET2 ${comp.value}');
    //       break;
    //     case 'C':
    //       buffer.writeln('${comp.designator} NET1 NET2 ${comp.value}');
    //       break;
    //     case 'L':
    //       buffer.writeln('${comp.designator} NET1 NET2 ${comp.value}');
    //       break;
    //     default:
    //       buffer.writeln('* ${comp.designator} ${comp.type} ${comp.value}');
    //   }
    // }
    
    // buffer.writeln('.END');
    
    return buffer.toString();
  }
  
  // String _generateGenericNetlist() {
  //   final result = {
  //     'project': state.currentProject.name,
  //     'timestamp': DateTime.now().toIso8601String(),
  //     'components': state.currentProject.logicalComponents.values
  //         .map((c) => c.toJson())
  //         .toList(),
  //     'nets': state.currentProject.logicalNets.values
  //         .map((n) => n.toJson())
  //         .toList(),
  //   };
    
  //   return const JsonEncoder.withIndent('  ').convert(result);
  // }
  
  // Future<Map<String, dynamic>> _addImage(Map<String, dynamic> args) async {
  //   final path = args['path'] as String;
  //   final data = args['data'] as String?;
  //   final metadata = args['metadata'] as Map<String, dynamic>?;
    
  //   final imageId = _generateImageId(path);
    
  //   Uint8List? imageData;
    
  //   if (data != null) {
  //     // Use provided base64 data
  //     imageData = base64Decode(data);
  //   } else if (path.startsWith('http://') || path.startsWith('https://')) {
  //     // Fetch from URL
  //     final response = await http.get(Uri.parse(path));
  //     if (response.statusCode == 200) {
  //       imageData = response.bodyBytes;
  //     } else {
  //       throw Exception('Failed to fetch image from URL: ${response.statusCode}');
  //     }
  //   } else {
  //     // Read from file system
  //     final file = File(path);
  //     if (await file.exists()) {
  //       imageData = await file.readAsBytes();
  //     } else {
  //       throw Exception('File not found: $path');
  //     }
  //   }
    
  //   final pcbImage = PcbImage(
  //     id: imageId,
  //     path: path,
  //     data: imageData,
  //     metadata: metadata,
  //     timestamp: DateTime.now(),
  //   );
    
  //   // Add to cache and project
  //   state.imageCache[imageId] = pcbImage;
  //   state.currentProject.pcbImages.add(pcbImage);
    
  //   return {
  //     'image_id': imageId,
  //     'size_bytes': imageData?.length ?? 0,
  //     'timestamp': pcbImage.timestamp.toIso8601String(),
  //     'cached': true,
  //   };
  // }
  
  Future<Map<String, dynamic>> _detectComponents(Map<String, dynamic> args) async {

    final imageId = args['image_id'] as String;
    final confidenceThreshold = (args['confidence_threshold'] as num?)?.toDouble() ?? 0.7;
    
    final image = null; //state.imageCache[imageId];
    if (image == null) {
      throw ArgumentError('Image not found: $imageId');
    }
    
    // Simulated CV detection - in production would use actual CV model
    await Future.delayed(Duration(milliseconds: 300));
    
    final detections = <Map<String, dynamic>>[];
    
    // Simulate different component detections based on confidence
    if (confidenceThreshold <= 0.95) {
      detections.add({
        'component_type': 'ic',
        'confidence': 0.95,
        'bbox': {'x': 150, 'y': 200, 'w': 80, 'h': 60},
        'attributes': {
          'package': 'SOIC-8',
          'orientation': 0,
        },
      });
    }
    
    if (confidenceThreshold <= 0.88) {
      detections.add({
        'component_type': 'resistor',
        'confidence': 0.88,
        'bbox': {'x': 50, 'y': 100, 'w': 40, 'h': 15},
        'attributes': {
          'package': '0805',
          'color_bands': ['brown', 'black', 'red'],
        },
      });
    }
    
    if (confidenceThreshold <= 0.75) {
      detections.add({
        'component_type': 'capacitor',
        'confidence': 0.75,
        'bbox': {'x': 250, 'y': 150, 'w': 30, 'h': 30},
        'attributes': {
          'package': '0603',
          'type': 'ceramic',
        },
      });
    }
    
    return {
      'image_id': imageId,
      'detections': detections,
      'total_detected': detections.length,
      'confidence_threshold': confidenceThreshold,
      'processing_time_ms': 300,
    };
  }
  
  Future<Map<String, dynamic>> _handleInitialized(Map<String, dynamic> params) async {
    _log('Client initialized');
    return {};
  }
  
  Future<Map<String, dynamic>> _handleCancelled(Map<String, dynamic> params) async {
    final requestId = params['requestId'];
    _log('Request cancelled: $requestId');
    return {};
  }
  
  String _generateImageId(String path) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = md5.convert(utf8.encode('$path$timestamp')).toString();
    return 'img_${hash.substring(0, 8)}';
  }
  
  void _log(String message) {
    if (config.enableLogging) {
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '[$timestamp] $message';
      print(logMessage);
      _logController.add(logMessage);
    }
  }
  
  Future<void> stop() async {
    _log('Stopping MCP Server...');
    await _server.close();
    await _logController.close();
  }
}














// ============================================================================
// Old MCP Server Implementation (For Reference / Migration)
// ============================================================================

// The server state can be managed in a simple state record or map.
var _currentProject_ = projectFromJson({
  'id': '1',
  'name': 'Initial Project',
  'logicalComponents': <String, dynamic>{},
  'logicalNets': <String, dynamic>{},
  'schematic': {'symbols': <String, dynamic>{}, 'wires': <String, dynamic>{}},
  'pcbImages': <dynamic>[],
  'lastUpdated': DateTime.now().toIso8601String(),
});

Future<void> startMCPServer({
  String baseUrl = 'http://localhost:8080',
  int port = 8080,
}) async {
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
  response.write(
    jsonEncode({
      "new_components": [],
      "new_connections": [],
      "suggested_nets": [],
      "architecture_notes": "Dummy analysis",
    }),
  );
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
    return {'error': 'Failed to connect to the analysis server.'};
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
