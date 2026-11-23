import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../../core/logging/domain/i_studio_logger.dart';
import '../../core/logging/infrastructure/studio_stderr_logger.dart';

/// Immutable event envelope exchanged over the local Tunner IPC loopback socket.
@immutable
class TunnerIpcEvent {
  final String event;
  final Map<String, dynamic> payload;
  final DateTime timestampUtc;

  const TunnerIpcEvent({
    required this.event,
    required this.payload,
    required this.timestampUtc,
  });

  factory TunnerIpcEvent.now({
    required String event,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    return TunnerIpcEvent(
      event: event,
      payload: Map<String, dynamic>.unmodifiable(payload),
      timestampUtc: DateTime.now().toUtc(),
    );
  }

  factory TunnerIpcEvent.fromJson(Map<String, dynamic> json) {
    final rawEvent = json['event'];
    if (rawEvent is! String || rawEvent.trim().isEmpty) {
      throw const FormatException('IPC event requires a non-empty "event" string.');
    }

    final rawPayload = json['payload'];
    final payload = rawPayload is Map<String, dynamic>
        ? Map<String, dynamic>.unmodifiable(rawPayload)
        : rawPayload is Map
            ? Map<String, dynamic>.unmodifiable(
                rawPayload.map((k, v) => MapEntry(k.toString(), v)),
              )
            : const <String, dynamic>{};

    final rawTimestamp = json['timestampUtc'];
    final timestampUtc = rawTimestamp is String
        ? (DateTime.tryParse(rawTimestamp)?.toUtc() ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    return TunnerIpcEvent(
      event: rawEvent,
      payload: payload,
      timestampUtc: timestampUtc,
    );
  }

  Map<String, dynamic> toJson() => {
        'event': event,
        'payload': payload,
        'timestampUtc': timestampUtc.toIso8601String(),
      };
}

/// Pure Dart local loopback IPC bridge (`127.0.0.1`) using newline-delimited
/// JSON frames over `dart:io` TCP sockets.
///
/// Supports two operational roles:
/// - **Server mode** (`startServer`): used by Tunner Desktop GUI or integration
///   tests to receive live synchronization events via [events].
/// - **Client mode** (`connect`, `emitEvent`): used by the headless MCP server
///   to notify a running GUI instance. If no GUI is listening on the target
///   port, connection and emission degrade silently (logging a warning to
///   [logger] -> `stderr`) while keeping the MCP server 100% operational.
class TunnerIpcBridge {
  static const String _logTag = 'TunnerIpcBridge';
  static const Duration defaultConnectTimeout = Duration(milliseconds: 500);

  final IStudioLogger logger;

  ServerSocket? _serverSocket;
  StreamSubscription<Socket>? _serverSub;
  final Set<Socket> _acceptedClients = <Socket>{};
  final List<StreamSubscription<String>> _clientLineSubs =
      <StreamSubscription<String>>[];
  final StreamController<TunnerIpcEvent> _eventsController =
      StreamController<TunnerIpcEvent>.broadcast();

  Socket? _clientSocket;
  StreamSubscription<List<int>>? _clientDrainSub;
  int? _connectedPort;
  bool _isClosed = false;

  TunnerIpcBridge({
    this.logger = StudioStderrLogger.instance,
  });

  /// Broadcast stream of incoming [TunnerIpcEvent]s received in server mode.
  Stream<TunnerIpcEvent> get events => _eventsController.stream;

  /// Bound local TCP port when running in server mode, or `null` if not listening.
  int? get boundPort => _serverSocket?.port;

  /// Whether the local loopback server socket is currently active.
  bool get isServerRunning => _serverSocket != null;

  /// Whether the client socket is currently connected to a loopback peer.
  bool get isConnected => _clientSocket != null;

  /// Target port currently connected in client mode, if any.
  int? get connectedPort => _connectedPort;

  /// Whether [close] has been invoked on this bridge.
  bool get isClosed => _isClosed;

  /// Starts a local loopback IPC server on `127.0.0.1:[port]`.
  ///
  /// Pass `port: 0` to request an ephemeral OS-assigned port. Returns the
  /// actual bound port.
  Future<int> startServer({int port = 0}) async {
    if (_isClosed) {
      throw StateError('Cannot start IPC server on a closed TunnerIpcBridge.');
    }
    if (_serverSocket != null) {
      return _serverSocket!.port;
    }

    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    _serverSocket = server;

    _serverSub = server.listen(
      _handleIncomingClient,
      onError: (Object error, StackTrace stackTrace) {
        logger.warning(
          _logTag,
          'IPC server socket error on port ${server.port}',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    return server.port;
  }

  void _handleIncomingClient(Socket socket) {
    if (_isClosed) {
      socket.destroy();
      return;
    }
    _acceptedClients.add(socket);

    late final StreamSubscription<String> subscription;
    subscription = utf8.decoder
        .bind(socket)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return;
            _decodeAndEmit(trimmed);
          },
          onError: (Object error, StackTrace stackTrace) {
            logger.warning(
              _logTag,
              'Error reading IPC frame from client socket',
              error: error,
              stackTrace: stackTrace,
            );
          },
          onDone: () {
            _acceptedClients.remove(socket);
            _clientLineSubs.remove(subscription);
          },
          cancelOnError: false,
        );
    _clientLineSubs.add(subscription);
  }

  void _decodeAndEmit(String jsonLine) {
    if (_isClosed || _eventsController.isClosed) return;
    try {
      final decoded = jsonDecode(jsonLine);
      if (decoded is! Map<String, dynamic>) {
        logger.warning(
          _logTag,
          'Ignoring non-object IPC payload frame.',
        );
        return;
      }
      final event = TunnerIpcEvent.fromJson(decoded);
      _eventsController.add(event);
    } catch (e, st) {
      logger.warning(
        _logTag,
        'Ignoring malformed JSON IPC frame',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Attempts to connect to a local Tunner GUI IPC server on `127.0.0.1:[port]`.
  ///
  /// Returns `true` if connected. If no server is listening or the connection
  /// fails/times out, logs a warning to [logger] (`stderr`) and returns `false`
  /// without throwing so the MCP server can continue operating headlessly.
  Future<bool> connect({
    required int port,
    Duration timeout = defaultConnectTimeout,
  }) async {
    if (_isClosed) {
      return false;
    }
    if (port <= 0 || port > 65535) {
      logger.warning(
        _logTag,
        'Invalid IPC port $port; continuing in headless mode without IPC.',
      );
      return false;
    }

    await disconnectClient();

    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: timeout,
      );
      if (_isClosed) {
        socket.destroy();
        return false;
      }

      _clientSocket = socket;
      _connectedPort = port;

      // Drain incoming bytes and detect remote disconnect cleanly.
      _clientDrainSub = socket.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          logger.warning(
            _logTag,
            'IPC client socket error on 127.0.0.1:$port; detaching IPC bridge.',
            error: error,
            stackTrace: stackTrace,
          );
          _detachDeadClientSocket();
        },
        onDone: () {
          _detachDeadClientSocket();
        },
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      logger.warning(
        _logTag,
        'No Tunner GUI IPC listener reachable on 127.0.0.1:$port; '
        'continuing in headless mode ($e).',
      );
      _clientSocket = null;
      _connectedPort = null;
      return false;
    }
  }

  /// Emits a newline-delimited JSON event to the connected IPC peer.
  ///
  /// Designed to match `McpIpcEventCallback`. When disconnected or if the peer
  /// closes unexpectedly, degrades silently without throwing.
  void emitEvent(String event, Map<String, dynamic> payload) {
    final socket = _clientSocket;
    if (_isClosed || socket == null) return;

    try {
      final envelope = TunnerIpcEvent.now(event: event, payload: payload);
      final encoded = '${jsonEncode(envelope.toJson())}\n';
      socket.add(utf8.encode(encoded));
    } catch (e, st) {
      logger.warning(
        _logTag,
        'Failed to write IPC event "$event"; detaching IPC bridge.',
        error: e,
        stackTrace: st,
      );
      _detachDeadClientSocket();
    }
  }

  /// Flushes pending outbound bytes on the client socket when connected.
  Future<void> flush() async {
    final socket = _clientSocket;
    if (socket == null) return;
    try {
      await socket.flush();
    } catch (e) {
      logger.warning(
        _logTag,
        'Failed to flush IPC client socket; detaching IPC bridge ($e).',
      );
      _detachDeadClientSocket();
    }
  }

  /// Disconnects only the client socket while preserving any active server.
  Future<void> disconnectClient() async {
    final sub = _clientDrainSub;
    _clientDrainSub = null;
    await sub?.cancel();

    final socket = _clientSocket;
    _clientSocket = null;
    _connectedPort = null;
    if (socket != null) {
      try {
        await socket.flush();
      } catch (_) {
        // Ignore broken-pipe flush errors during teardown.
      }
      try {
        await socket.close();
      } catch (_) {
        socket.destroy();
      }
    }
  }

  void _detachDeadClientSocket() {
    final sub = _clientDrainSub;
    _clientDrainSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    final socket = _clientSocket;
    _clientSocket = null;
    _connectedPort = null;
    socket?.destroy();
  }

  /// Closes both client and server sockets and releases all stream resources.
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    await _clientDrainSub?.cancel();
    _clientDrainSub = null;
    await disconnectClient();

    await _serverSub?.cancel();
    _serverSub = null;

    final subs = List<StreamSubscription<String>>.from(_clientLineSubs);
    _clientLineSubs.clear();
    for (final sub in subs) {
      await sub.cancel();
    }

    final clients = List<Socket>.from(_acceptedClients);
    _acceptedClients.clear();
    for (final client in clients) {
      try {
        await client.close();
      } catch (_) {
        client.destroy();
      }
    }

    final server = _serverSocket;
    _serverSocket = null;
    if (server != null) {
      await server.close();
    }

    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
  }
}
