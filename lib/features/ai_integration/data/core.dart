import 'package:pcb_rev/features/symbol_library/data/kicad_schematic_models.dart';

import '../../project/data/project.dart';


// ============================================================================
// JSON-RPC 2.0 Types
// ============================================================================

class JsonRpcRequest {
  final String jsonrpc;
  final dynamic id;
  final String method;
  final Map<String, dynamic>? params;

  JsonRpcRequest({
    required this.jsonrpc,
    this.id,
    required this.method,
    this.params,
  });

  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) {
    return JsonRpcRequest(
      jsonrpc: json['jsonrpc'] ?? '2.0',
      id: json['id'],
      method: json['method'] ?? '',
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'jsonrpc': jsonrpc,
        if (id != null) 'id': id,
        'method': method,
        if (params != null) 'params': params,
      };
}

class JsonRpcError {
  final int code;
  final String message;
  final dynamic data;

  JsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };
}

class JsonRpcResponse {
  final String jsonrpc;
  final dynamic id;
  final dynamic result;
  final JsonRpcError? error;

  JsonRpcResponse({
    this.jsonrpc = '2.0',
    this.id,
    this.result,
    this.error,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'jsonrpc': jsonrpc,
      'id': id,
    };
    
    if (error != null) {
      json['error'] = error!.toJson();
    } else if (result != null) {
      json['result'] = result;
    }
    
    return json;
  }
}


// ============================================================================
// MCP Server State & Configuration
// ============================================================================

class MCPServerState {
  Project currentProject;
  KiCadSchematic? schematicModel;
  // final Map<String, PcbImage> imageCache = {};
  final List<Map<String, dynamic>> analysisHistory = [];

  MCPServerState({required this.currentProject, this.schematicModel});
}

class MCPServerConfig {
  final String host;
  final int port;
  final String basePath;
  final bool enableLogging;
  
  const MCPServerConfig({
    this.host = 'localhost',
    this.port = 8080,
    this.basePath = '/mcp',
    this.enableLogging = true,
  });
}

// ============================================================================
// Tool Definitions
// ============================================================================

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  
  ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });
  
  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

