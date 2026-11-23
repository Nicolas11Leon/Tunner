import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logging/domain/i_studio_logger.dart';
import '../../core/logging/infrastructure/studio_stderr_logger.dart';
import 'mcp_dispatcher.dart';
import 'mcp_error_codes.dart';
import 'mcp_json_rpc_message.dart';

/// Reactive `stdio` JSON-RPC 2.0 transport for the Tunner MCP Server.
///
/// Consumes newline-delimited JSON-RPC frames from [input] (defaulting to [stdin])
/// using native asynchronous Dart streams (zero busy-waiting) and writes strictly
/// valid JSON-RPC 2.0 responses to [output] (defaulting to [stdout]).
/// All internal diagnostics are routed exclusively to [logger] (`stderr`).
class McpStdioTransport {
  final McpDispatcher _dispatcher;
  final Stream<List<int>> _input;
  final IOSink _output;
  final IStudioLogger _logger;
  final McpJsonRpcCodec _codec;

  StreamIterator<String>? _lineIterator;
  Future<void>? _activeLoop;
  bool _isRunning = false;

  McpStdioTransport({
    required McpDispatcher dispatcher,
    Stream<List<int>>? input,
    IOSink? output,
    IStudioLogger logger = StudioStderrLogger.instance,
    McpJsonRpcCodec codec = const McpJsonRpcCodec(),
  })  : _dispatcher = dispatcher,
        _input = input ?? stdin,
        _output = output ?? stdout,
        _logger = logger,
        _codec = codec;

  /// Returns `true` while the transport is actively listening on [_input].
  bool get isRunning => _isRunning;

  /// Starts listening for JSON-RPC frames and completes when [_input] reaches
  /// EOF or [stop] is invoked.
  Future<void> start() {
    if (_isRunning && _activeLoop != null) {
      return _activeLoop!;
    }

    _isRunning = true;
    final lines = _input
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final iterator = StreamIterator<String>(lines);
    _lineIterator = iterator;

    _activeLoop = _consumeLoop(iterator);
    return _activeLoop!;
  }

  Future<void> _consumeLoop(StreamIterator<String> iterator) async {
    try {
      while (_isRunning) {
        final bool hasNext;
        try {
          hasNext = await iterator.moveNext();
        } catch (error, stackTrace) {
          if (!_isRunning) break;
          _logger.error(
            'McpStdioTransport',
            'Input stream error on stdio transport',
            error: error,
            stackTrace: stackTrace,
          );
          break;
        }
        if (!hasNext || !_isRunning) break;
        await _processLine(iterator.current);
      }
    } finally {
      _isRunning = false;
      _lineIterator = null;
      _activeLoop = null;
      await iterator.cancel();
    }
  }

  /// Gracefully stops listening on [_input] and waits for the stream iterator
  /// to cancel cleanly.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    final iterator = _lineIterator;
    _lineIterator = null;
    if (iterator != null) {
      await iterator.cancel();
    }
  }

  Future<void> _processLine(String rawLine) async {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final McpJsonRpcRequest request;
    try {
      request = _codec.decodeLine(trimmed);
    } on McpException catch (e) {
      await _writeResponse(
        McpJsonRpcResponse.failure(
          id: null,
          error: McpJsonRpcError.fromException(e),
        ),
      );
      return;
    } catch (e, st) {
      _logger.error(
        'McpStdioTransport',
        'Unexpected error decoding JSON-RPC frame',
        error: e,
        stackTrace: st,
      );
      await _writeResponse(
        McpJsonRpcResponse.failure(
          id: null,
          error: McpJsonRpcError(
            code: McpErrorCodes.parseError,
            message: 'Failed to decode JSON-RPC frame: $e',
          ),
        ),
      );
      return;
    }

    final response = await _dispatcher.dispatch(request);
    if (response != null) {
      await _writeResponse(response);
    }
  }

  Future<void> _writeResponse(McpJsonRpcResponse response) async {
    try {
      _output.writeln(_codec.encode(response));
      await _output.flush();
    } catch (e, st) {
      _logger.error(
        'McpStdioTransport',
        'Failed to write JSON-RPC response to output stream',
        error: e,
        stackTrace: st,
      );
    }
  }
}
