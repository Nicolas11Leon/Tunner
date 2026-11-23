/// Standard JSON-RPC 2.0 and Tunner acoustic domain error codes for the MCP server.
abstract final class McpErrorCodes {
  // Standard JSON-RPC 2.0 error codes.
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;

  // Tunner domain error codes (-32000 to -32099).
  static const int acousticError = -32000;
  static const int fileNotFound = -32001;
  static const int securityViolation = -32002;
  static const int invalidMusicTheory = -32003;
  static const int dslExecutionError = -32004;
}

/// Structured exception carrying a JSON-RPC 2.0 / Tunner MCP error code.
class McpException implements Exception {
  final int code;
  final String message;
  final Object? data;

  const McpException(
    this.code,
    this.message, {
    this.data,
  });

  const McpException.parseError(String message, {Object? data})
      : this(McpErrorCodes.parseError, message, data: data);

  const McpException.invalidRequest(String message, {Object? data})
      : this(McpErrorCodes.invalidRequest, message, data: data);

  const McpException.methodNotFound(String message, {Object? data})
      : this(McpErrorCodes.methodNotFound, message, data: data);

  const McpException.invalidParams(String message, {Object? data})
      : this(McpErrorCodes.invalidParams, message, data: data);

  const McpException.internalError(String message, {Object? data})
      : this(McpErrorCodes.internalError, message, data: data);

  const McpException.acousticError(String message, {Object? data})
      : this(McpErrorCodes.acousticError, message, data: data);

  const McpException.fileNotFound(String message, {Object? data})
      : this(McpErrorCodes.fileNotFound, message, data: data);

  const McpException.securityViolation(String message, {Object? data})
      : this(McpErrorCodes.securityViolation, message, data: data);

  const McpException.invalidMusicTheory(String message, {Object? data})
      : this(McpErrorCodes.invalidMusicTheory, message, data: data);

  const McpException.dslExecutionError(String message, {Object? data})
      : this(McpErrorCodes.dslExecutionError, message, data: data);

  @override
  String toString() => 'McpException($code): $message';
}
