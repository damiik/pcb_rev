import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

import '../../pcb_viewer/data/capture_service.dart';
import 'core.dart';
import '../domain/mcp_server_tools.dart';

import '../../project/data/project.dart';


// ============================================================================
// MCP Server Implementation
// ============================================================================

class MCPServer {
  late final HttpServer _server;
  final MCPServerConfig config;
  MCPServerState state;
  final StreamController<String> _logController = StreamController.broadcast();

  final Map<String, dynamic> serverInfo = const {
    'name': 'pcb-reverse-engineering-server',
    'version': '2.0.0',
  };

  Stream<String> get logs => _logController.stream;

  MCPServer({
    MCPServerConfig? config,
    required Project initialProject,
  })  : config = config ?? const MCPServerConfig(),
        state = MCPServerState(currentProject: initialProject);

  Future<void> start() async {
    _server = await HttpServer.bind(config.host, config.port);
    _log('Server started. Listening on http://${config.host}:${config.port}${config.basePath}');

    await for (HttpRequest request in _server) {
      _handleHttpRequest(request);
    }
  }

  void updateProject(Project newProject) {
    state = state.copyWith(
      currentProject: newProject,
      activeImageId: newProject.pcbImages.isNotEmpty ? newProject.pcbImages.last.id : null,
    );
    _log('Project state updated. Active image ID: ${state.activeImageId}');
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
      _log('Received request body: $body');

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
      _log('Dispatching method: ${request.method}');
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

  Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> 
      get _routes => {
            'initialize': _handleInitialize,
            'tools/list': _handleToolsList,
            'tools/call': _handleToolsCall,
            'notifications/initialized': _handleInitialized,
            'notifications/cancelled': _handleCancelled,
          };

  Future<Map<String, dynamic>> _handleInitialize(
      Map<String, dynamic> params) async {
    _log('Handling "initialize" request.');
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
      'serverInfo': serverInfo,
    };
  }

  Future<Map<String, dynamic>> _handleToolsList(
      Map<String, dynamic> params) async {
    return {
      'tools': availableTools.map((t) => t.toJson()).toList(),
    };
  }

  Future<Map<String, dynamic>> _handleToolsCall(
      Map<String, dynamic> params) async {
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

  Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> 
      get _toolHandlers => {
            'read_current_image': _readCurrentImage,
            'write_current_image_components': _writeCurrentImageComponents,
            'get_kicad_schematic': _getKiCadSchematic,
            'get_symbol_libraries': _getSymbolLibraries,
            'update_kicad_schematic': _updateKiCadSchematic,
          };

  Future<Map<String, dynamic>> _readCurrentImage(
      Map<String, dynamic> args) async {
    final activeId = state.activeImageId;
    if (activeId == null) {
      throw ArgumentError('No active image is set in the application.');
    }

    try {
      _log('Requesting view capture from the UI...');
      // Use a timeout to prevent the server from hanging indefinitely
      final imageBytes = await ViewCaptureService().capture().timeout(const Duration(seconds: 10));
      _log('View capture successful.');

      final base64Data = base64Encode(imageBytes);

      final decodedImage = img.decodeImage(imageBytes);
      final width = decodedImage?.width ?? 0;
      final height = decodedImage?.height ?? 0;

      return {
        'image_id': activeId,
        'format': 'png', // We capture as PNG
        'width': width,
        'height': height,
        'data': base64Data,
        'note': 'The image data represents the current user view of the PCB.',
      };
    } on TimeoutException {
      _log('Error: Timed out waiting for view capture from the UI.');
      throw Exception('Timed out waiting for view capture. Is the UI responsive?');
    } catch (e) {
      _log('Error capturing view: $e');
      throw Exception('Failed to capture current view from the UI: $e');
    }
  }

  Future<Map<String, dynamic>> _writeCurrentImageComponents(
      Map<String, dynamic> args) async {
    final components = args['components'] as List<dynamic>? ?? [];

    // In a real implementation, you would take these component details
    // and update the project's data model, associating them with the
    // current image.
    _log('Received ${components.length} components from AI analysis.');
    for (final component in components) {
      _log('  - Component: ${jsonEncode(component)}');
    }

    return {
      'success': true,
      'components_written': components.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _getKiCadSchematic(
      Map<String, dynamic> args) async {
    if (state.schematicModel == null) {
      return {
        'error': 'No schematic loaded in the current project.',
      };
    }
    // In a real implementation, you would use a toJson function.
    // For now, we return a simplified, placeholder representation.
    return {
      'schematic': {
        'version': state.schematicModel!.version,
        'generator': state.schematicModel!.generator,
        'symbol_instances_count':
            state.schematicModel!.symbolInstances.length,
        'wires_count': state.schematicModel!.wires.length,
        'junctions_count': state.schematicModel!.junctions.length,
      }
    };
  }

  Future<Map<String, dynamic>> _getSymbolLibraries(
      Map<String, dynamic> args) async {
    // This is a placeholder. In a real implementation, you would load
    // the symbol libraries associated with the project.
    return {
      'libraries': [
        {
          'name': 'power',
          'symbols': [
            {'name': 'VCC', 'description': 'Power symbol for VCC'},
            {'name': 'GND', 'description': 'Power symbol for Ground'},
          ]
        },
        {
          'name': 'device',
          'symbols': [
            {'name': 'R', 'description': 'Resistor'},
            {'name': 'C', 'description': 'Capacitor'},
            {'name': 'L', 'description': 'Inductor'},
            {'name': 'D', 'description': 'Diode'},
          ]
        }
      ]
    };
  }

  Future<Map<String, dynamic>> _updateKiCadSchematic(
      Map<String, dynamic> args) async {
    final updates = args['updates'] as List<dynamic>? ?? [];
    int symbolsAdded = 0;
    int wiresAdded = 0;

    // This is a placeholder implementation.
    for (final update in updates) {
      final action = update['action'] as String;
      final payload = update['payload'] as Map<String, dynamic>;

      switch (action) {
        case 'add_symbol':
          // final symbol = symbolInstanceFromJson(payload);
          // state.schematicModel?.symbolInstances.add(symbol);
          symbolsAdded++;
          break;
        case 'add_wire':
          // final wire = wireFromJson(payload);
          // state.schematicModel?.wires.add(wire);
          wiresAdded++;
          break;
      }
    }

    return {
      'success': true,
      'summary': {
        'symbols_added': symbolsAdded,
        'wires_added': wiresAdded,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _handleInitialized(
      Map<String, dynamic> params) async {
    _log('Client initialized');
    return {};
  }

  Future<Map<String, dynamic>> _handleCancelled(
      Map<String, dynamic> params) async {
    final requestId = params['requestId'];
    _log('Request cancelled: $requestId');
    return {};
  }

  void _log(String message) {
    if (config.enableLogging) {
      final serverName = serverInfo['name'];
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '[$timestamp] [$serverName] $message';
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














