import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
// import 'package:shelf_sse/shelf_sse.dart';


import 'package:pcb_rev/kicad/data/kicad_schematic_deserializer.dart';
import 'package:pcb_rev/kicad/data/kicad_schematic_models.dart';
import 'package:pcb_rev/kicad/data/kicad_schematic_serializer.dart';
import 'package:pcb_rev/kicad/data/kicad_symbol_models.dart';
import 'package:pcb_rev/pcb_viewer/data/capture_service.dart';
import 'package:pcb_rev/project/api/schematic_api.dart' ;

import '../../connectivity/models/connectivity.dart';
import '../../connectivity/api/netlist_api.dart' as netlist_api;
import '../../connectivity/models/core.dart' as connectivity_models;
import 'core.dart';
import '../domain/mcp_server_tools.dart';


// ============================================================================
// Type Definitions for Callbacks
// ============================================================================

typedef GetSchematicCallback = KiCadSchematic? Function();
typedef UpdateSchematicCallback = void Function(KiCadSchematic);
typedef GetSymbolLibrariesCallback = List<KiCadLibrary> Function();
typedef GetConnectivityCallback = Connectivity? Function();

// ============================================================================//
// MCP Server Implementation
// ============================================================================//

class MCPServer {
  late final HttpServer _server;
  final MCPServerConfig config;
  final StreamController<String> _logController = StreamController.broadcast();

  // Callbacks to interact with the main application state
  final GetSchematicCallback getSchematic;
  final UpdateSchematicCallback updateSchematic;
  final GetSymbolLibrariesCallback getSymbolLibraries;
  final GetConnectivityCallback getConnectivity;

    // Initialize the schematic API instance
  final _schematicAPI = KiCadSchematicAPI();

  KiCadSchematicAPI get schematicAPI => _schematicAPI;

  final Map<String, dynamic> serverInfo = const {
    'name': 'pcb-reverse-engineering-server',
    'version': '2.0.0',
  };

  Stream<String> get logs => _logController.stream;

  late Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> _toolHandlers;
  final List<ToolDefinition> _availableTools = [];

  MCPServer({
    this.config = const MCPServerConfig(),
    required this.getSchematic,
    required this.updateSchematic,
    required this.getSymbolLibraries,
    required this.getConnectivity,
  }) {
    _toolHandlers = {
      'read_current_image': _readCurrentImage,
      'write_current_image_components': _writeCurrentImageComponents,
      'get_kicad_schematic': _getKiCadSchematic,
      'get_symbol_libraries': _getSymbolLibraries,
      'update_kicad_schematic': _updateKiCadSchematic,
      'get_netlist': _getNetlist,
      'get_connectivity_graph': _getConnectivityGraph,
      'get_symbol_instances': _getSymbolInstances,
      'get_labels_and_ports': _getLabelsAndPorts,
    };
    _availableTools.addAll(defaultMcpTools);
  }

  void registerToolHandlers(
      Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)> handlers) {
    _toolHandlers.addAll(handlers);
  }

  void registerToolDefinitions(List<ToolDefinition> tools) {
    _availableTools.addAll(tools);
  }

  Future<void> start() async {
    _server = await HttpServer.bind(config.host, config.port);
    _log('Server started. Listening on http://${config.host}:${config.port}${config.basePath}');

    await for (HttpRequest request in _server) {
      _handleHttpRequest(request);
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    if (request.method == 'GET' && request.uri.path.startsWith('/images/')) {
      await _serveImage(request);
      return;
    }

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

  Future<void> _serveImage(HttpRequest request) async {
    final imageName = request.uri.pathSegments.last;
    if (imageName.contains('..')) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
      return;
    }

    final tempDir = Directory.systemTemp;
    final filePath = '${tempDir.path}/$imageName';
    final file = File(filePath);

    if (await file.exists()) {
      _log('Serving image: $filePath');
      request.response.headers.contentType = ContentType.parse('image/png');
      try {
        await file.openRead().pipe(request.response);
      } catch (e) {
        _log('Error piping image stream: $e');
      }
    } else {
      _log('Image not found: $filePath');
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found')
        ..close();
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
      'protocolVersion': '2025-06-18',
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

  Future<Map<String, dynamic>> _handleToolsList(Map<String, dynamic> params) async {
    return {
      'tools': _availableTools.map((t) => t.toJson()).toList(),
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

  Future<Map<String, dynamic>> _readCurrentImage(
      Map<String, dynamic> args) async {
    // This tool now needs a callback to get the current image bytes.
    // For now, it will use the existing ViewCaptureService, but ideally
    // the main app would provide the image bytes via a callback.
    try {
      _log('Requesting view capture from the UI...');
      final imageBytes = await ViewCaptureService()
          .capture()
          .timeout(const Duration(seconds: 10));
      _log('View capture successful.');

      final tempDir = Directory.systemTemp;
      final imageName =
          'pcb_capture_${DateTime.now().millisecondsSinceEpoch}.png';
      final imagePath = '${tempDir.path}/$imageName';
      await File(imagePath).writeAsBytes(imageBytes);
      _log('Image saved to temporary file: $imagePath');

      final imageUrl = 'http://${config.host}:${config.port}/images/$imageName';

      final decodedImage = img.decodeImage(imageBytes);
      final width = decodedImage?.width ?? 0;
      final height = decodedImage?.height ?? 0;

      return {
        'format': 'png',
        'width': width,
        'height': height,
        'url': imageUrl,
        'note':
            'The image data is available at the provided URL. The AI model should fetch this URL to get the image.',
      };
    } on TimeoutException {
      _log('Error: Timed out waiting for view capture from the UI.');
      throw Exception(
          'Timed out waiting for view capture. Is the UI responsive?');
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

  // TODO: move to domain/schematic_mcp_tools.dart  
  Future<Map<String, dynamic>> _getKiCadSchematic(
      Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'error': 'No schematic loaded in the current project.',
      };
    }
    return {
      'schematic': kiCadSchematicToJson(schematic),
    };
  }

  // TODO: move to domain/schematic_mcp_tools.dart
  Future<Map<String, dynamic>> _getSymbolLibraries(
      Map<String, dynamic> args) async {
    final libraries = getSymbolLibraries();
    return {
      'libraries': libraries.map((lib) => kiCadLibraryToJson(lib)).toList(),
    };
  }
  // TODO: to remove, repeated in domain/schematic_mcp_tools.dart
  Future<Map<String, dynamic>> _updateKiCadSchematic(
      Map<String, dynamic> args) async {
    final currentSchematic = getSchematic();
    if (currentSchematic == null) {
      throw Exception('Cannot update schematic, no schematic is loaded.');
    }

    final updates = args['updates'] as List<dynamic>? ?? [];
    int symbolsAdded = 0;
    int wiresAdded = 0;

    var newSymbolInstances = List<SymbolInstance>.from(currentSchematic.symbolInstances);
    var newWires = List<Wire>.from(currentSchematic.wires);

    for (final update in updates) {
      final action = update['action'] as String;
      final payload = update['payload'] as Map<String, dynamic>;

      switch (action) {
        case 'add_symbol_reference':
          final symbol = symbolInstanceFromJson(payload);
          newSymbolInstances.add(symbol);
          symbolsAdded++;
          break;
        case 'add_wire':
          final wire = wireFromJson(payload);
          newWires.add(wire);
          wiresAdded++;
          break;
        default:
          _log('Warning: Unknown update action "$action"');
      }
    }

    final newSchematic = currentSchematic.copyWith(
      symbolInstances: newSymbolInstances,
      wires: newWires,
    );

    updateSchematic(newSchematic);
    _log(
        'Schematic updated: $symbolsAdded symbols added, $wiresAdded wires added.');

    return {
      'success': true,
      'summary': {
        'symbols_added': symbolsAdded,
        'wires_added': wiresAdded,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _getNetlist(Map<String, dynamic> args) async {
    final connectivity = getConnectivity();
    if (connectivity == null) {
      return {
        'error': 'Connectivity data not available. Is a schematic loaded?',
      };
    }
    final netlistJson = netlist_api.getNetlist(connectivity.graph);
    return jsonDecode(netlistJson) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _getConnectivityGraph(Map<String, dynamic> args) async {
    
    final connectivity = getConnectivity();
    if (connectivity == null) {
      return {
        'error': 'Connectivity data not available. Is a schematic loaded?',
      };
    }
    final graphJson = netlist_api.getConnectivityGraph(connectivity.graph);
    return jsonDecode(graphJson) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _getSymbolInstances(
      Map<String, dynamic> args) async {
    final schematic = getSchematic();
    if (schematic == null) {
      return {
        'error': 'No schematic loaded.',
      };
    }
    return {
      'symbol_instances': schematic.symbolInstances
          .map((inst) => symbolInstanceToJson(inst))
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _getLabelsAndPorts(
      Map<String, dynamic> args) async {
    final connectivity = getConnectivity();
    if (connectivity == null) {
      return {
        'error': 'Connectivity data not available. Is a schematic loaded?',
      };
    }
    final labels = connectivity.graph.items.values
        .whereType<connectivity_models.Label>()
        .map((label) => {
              'id': label.id,
              'text': label.netName,
              'position': {'x': label.position.x, 'y': label.position.y},
            })
        .toList();

    // Ports are not implemented yet, returning empty list
    return {
      'labels': labels,
      'ports': [],
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
