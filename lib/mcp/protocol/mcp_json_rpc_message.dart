import 'dart:convert';

import 'package:meta/meta.dart';

import 'mcp_error_codes.dart';

/// Immutable JSON-RPC 2.0 error object embedded in failed responses.
@immutable
class McpJsonRpcError {
  final int code;
  final String message;
  final Object? data;

  const McpJsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  factory McpJsonRpcError.fromException(McpException exception) {
    return McpJsonRpcError(
      code: exception.code,
      message: exception.message,
      data: exception.data,
    );
  }

  factory McpJsonRpcError.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final message = json['message'];
    if (code is! int || message is! String) {
      throw const McpException.invalidRequest(
        'JSON-RPC error object requires integer code and string message.',
      );
    }
    return McpJsonRpcError(
      code: code,
      message: message,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };
}

/// Immutable JSON-RPC 2.0 request or notification message.
///
/// When [id] is `null`, the message represents a JSON-RPC notification that
/// must not produce a response frame on `stdout`.
@immutable
class McpJsonRpcRequest {
  final String jsonrpc;
  final Object? id;
  final String method;
  final Map<String, dynamic>? params;

  const McpJsonRpcRequest({
    this.jsonrpc = McpJsonRpcCodec.jsonRpcVersion,
    this.id,
    required this.method,
    this.params,
  });

  /// Returns `true` when this message is a JSON-RPC notification (no `id`).
  bool get isNotification => id == null;

  Map<String, dynamic> toJson() => {
        'jsonrpc': jsonrpc,
        if (id != null) 'id': id,
        'method': method,
        if (params != null) 'params': params,
      };
}

/// Immutable JSON-RPC 2.0 response message.
@immutable
class McpJsonRpcResponse {
  final Object? id;
  final Map<String, dynamic>? result;
  final McpJsonRpcError? error;

  String get jsonrpc => McpJsonRpcCodec.jsonRpcVersion;

  const McpJsonRpcResponse._({
    required this.id,
    this.result,
    this.error,
  });

  factory McpJsonRpcResponse.success({
    required Object? id,
    required Map<String, dynamic> result,
  }) {
    return McpJsonRpcResponse._(
      id: id,
      result: result,
    );
  }

  factory McpJsonRpcResponse.failure({
    required Object? id,
    required McpJsonRpcError error,
  }) {
    return McpJsonRpcResponse._(
      id: id,
      error: error,
    );
  }

  bool get isError => error != null;

  Map<String, dynamic> toJson() => {
        'jsonrpc': jsonrpc,
        'id': id,
        if (error != null) 'error': error!.toJson() else 'result': result ?? const {},
      };
}

/// Line-delimited JSON-RPC 2.0 codec for MCP `stdio` transport.
class McpJsonRpcCodec {
  static const String jsonRpcVersion = '2.0';

  const McpJsonRpcCodec();

  /// Decodes a single newline-delimited JSON-RPC 2.0 request frame.
  ///
  /// Throws [McpException] with [McpErrorCodes.parseError] on malformed JSON
  /// or [McpErrorCodes.invalidRequest] when structural invariants are violated.
  McpJsonRpcRequest decodeLine(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException catch (e) {
      throw McpException.parseError('Malformed JSON payload: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const McpException.invalidRequest(
        'JSON-RPC request must be a JSON object.',
      );
    }

    final version = decoded['jsonrpc'];
    if (version != jsonRpcVersion) {
      throw const McpException.invalidRequest(
        'Unsupported or missing jsonrpc version; expected "2.0".',
      );
    }

    final method = decoded['method'];
    if (method is! String || method.isEmpty) {
      throw const McpException.invalidRequest(
        'JSON-RPC request requires a non-empty string "method".',
      );
    }

    final id = decoded['id'];
    if (id != null && id is! int && id is! String) {
      throw const McpException.invalidRequest(
        'JSON-RPC "id" must be a string, integer, or null.',
      );
    }

    final rawParams = decoded['params'];
    if (rawParams != null && rawParams is! Map<String, dynamic>) {
      throw const McpException.invalidRequest(
        'JSON-RPC "params" must be a JSON object when provided.',
      );
    }

    return McpJsonRpcRequest(
      jsonrpc: jsonRpcVersion,
      id: id,
      method: method,
      params: rawParams as Map<String, dynamic>?,
    );
  }

  /// Encodes a [McpJsonRpcResponse] as a single-line JSON string.
  String encode(McpJsonRpcResponse response) {
    return jsonEncode(response.toJson());
  }
}
