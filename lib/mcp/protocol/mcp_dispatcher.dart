import '../../core/logging/domain/i_studio_logger.dart';
import '../../core/logging/infrastructure/studio_stderr_logger.dart';
import 'mcp_error_codes.dart';
import 'mcp_json_rpc_message.dart';
import 'mcp_registry.dart';

/// JSON-RPC 2.0 request dispatcher compliant with the Model Context Protocol
/// specification (`2024-11-05`).
///
/// Routes lifecycle methods (`initialize`, `notifications/initialized`, `ping`)
/// and MCP primitives (`resources/*`, `tools/*`, `prompts/*`) to [registry],
/// translating domain [McpException]s and unexpected errors into valid JSON-RPC
/// error responses without terminating the server process.
class McpDispatcher {
  static const String protocolVersion = '2024-11-05';
  static const String defaultServerName = 'tunner-mcp-server';
  static const String defaultServerVersion = '1.0.0';

  final McpRegistry registry;
  final IStudioLogger logger;
  final String serverName;
  final String serverVersion;

  bool _initialized = false;
  Map<String, dynamic>? _clientInfo;

  McpDispatcher({
    required this.registry,
    this.logger = StudioStderrLogger.instance,
    this.serverName = defaultServerName,
    this.serverVersion = defaultServerVersion,
  });

  /// Whether the MCP `initialize` handshake has completed.
  bool get isInitialized => _initialized;

  /// Optional client identity reported during `initialize`.
  Map<String, dynamic>? get clientInfo => _clientInfo;

  /// Dispatches a decoded [McpJsonRpcRequest] and returns a [McpJsonRpcResponse],
  /// or `null` when the incoming message is a JSON-RPC notification.
  Future<McpJsonRpcResponse?> dispatch(McpJsonRpcRequest request) async {
    try {
      final result = await _route(request);
      if (request.isNotification || result == null) {
        return null;
      }
      return McpJsonRpcResponse.success(
        id: request.id,
        result: result,
      );
    } on McpException catch (e) {
      if (request.isNotification) {
        logger.warning(
          'McpDispatcher',
          'Notification "${request.method}" failed with MCP error ${e.code}: ${e.message}',
        );
        return null;
      }
      return McpJsonRpcResponse.failure(
        id: request.id,
        error: McpJsonRpcError.fromException(e),
      );
    } catch (e, st) {
      logger.error(
        'McpDispatcher',
        'Unhandled exception while dispatching "${request.method}"',
        error: e,
        stackTrace: st,
      );
      if (request.isNotification) {
        return null;
      }
      return McpJsonRpcResponse.failure(
        id: request.id,
        error: McpJsonRpcError(
          code: McpErrorCodes.internalError,
          message: 'Internal server error: $e',
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _route(McpJsonRpcRequest request) async {
    switch (request.method) {
      case 'initialize':
        return _handleInitialize(request.params);
      case 'notifications/initialized':
        _initialized = true;
        return null;
      case 'notifications/cancelled':
        return null;
      case 'ping':
        return const {};
      case 'resources/list':
        return {
          'resources': registry.listResources(),
        };
      case 'resources/read':
        return _handleResourcesRead(request.params);
      case 'tools/list':
        return {
          'tools': registry.listTools(),
        };
      case 'tools/call':
        return _handleToolsCall(request.params);
      case 'prompts/list':
        return {
          'prompts': registry.listPrompts(),
        };
      case 'prompts/get':
        return _handlePromptsGet(request.params);
      default:
        if (request.isNotification) {
          logger.warning(
            'McpDispatcher',
            'Ignoring unsupported notification method: ${request.method}',
          );
          return null;
        }
        throw McpException.methodNotFound(
          'Unknown MCP method: ${request.method}',
        );
    }
  }

  Map<String, dynamic> _handleInitialize(Map<String, dynamic>? params) {
    _initialized = true;
    final rawClientInfo = params?['clientInfo'];
    if (rawClientInfo is Map<String, dynamic>) {
      _clientInfo = Map<String, dynamic>.unmodifiable(rawClientInfo);
    }

    return {
      'protocolVersion': protocolVersion,
      'capabilities': {
        'resources': {
          'subscribe': false,
          'listChanged': false,
        },
        'tools': {
          'listChanged': false,
        },
        'prompts': {
          'listChanged': false,
        },
      },
      'serverInfo': {
        'name': serverName,
        'version': serverVersion,
      },
    };
  }

  Future<Map<String, dynamic>> _handleResourcesRead(
    Map<String, dynamic>? params,
  ) async {
    final uri = params?['uri'];
    if (uri is! String || uri.trim().isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "uri" must be a non-empty string for resources/read.',
      );
    }

    final content = await registry.readResource(uri);
    return {
      'contents': [content.toJson()],
    };
  }

  Future<Map<String, dynamic>> _handleToolsCall(
    Map<String, dynamic>? params,
  ) async {
    final name = params?['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "name" must be a non-empty string for tools/call.',
      );
    }

    final rawArguments = params?['arguments'];
    if (rawArguments != null && rawArguments is! Map<String, dynamic>) {
      throw const McpException.invalidParams(
        'Parameter "arguments" must be a JSON object for tools/call.',
      );
    }

    final arguments =
        (rawArguments as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final result = await registry.callTool(name, arguments);
    return result.toJson();
  }

  Future<Map<String, dynamic>> _handlePromptsGet(
    Map<String, dynamic>? params,
  ) async {
    final name = params?['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "name" must be a non-empty string for prompts/get.',
      );
    }

    final rawArguments = params?['arguments'];
    final stringArguments = <String, String>{};
    if (rawArguments != null) {
      if (rawArguments is! Map) {
        throw const McpException.invalidParams(
          'Parameter "arguments" must be a JSON object for prompts/get.',
        );
      }
      for (final entry in rawArguments.entries) {
        if (entry.key is! String) {
          throw const McpException.invalidParams(
            'Prompt argument keys must be strings.',
          );
        }
        final value = entry.value;
        stringArguments[entry.key as String] =
            value == null ? '' : value.toString();
      }
    }

    final result = await registry.getPrompt(name, stringArguments);
    return result.toJson();
  }
}
