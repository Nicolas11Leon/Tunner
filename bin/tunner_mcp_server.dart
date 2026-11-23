import 'dart:async';
import 'dart:io';

import 'package:tunner/core/logging/infrastructure/studio_stderr_logger.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/ipc/tunner_ipc_bridge.dart';
import 'package:tunner/mcp/protocol/mcp_dispatcher.dart';
import 'package:tunner/mcp/protocol/mcp_stdio_transport.dart';
import 'package:tunner/mcp/tunner_mcp_bootstrap.dart';

/// Parsed CLI options for the native Dart Tunner MCP Server.
class _CliConfig {
  final String workspacePath;
  final int? ipcPort;
  final bool headlessOnly;

  const _CliConfig({
    required this.workspacePath,
    required this.ipcPort,
    required this.headlessOnly,
  });

  factory _CliConfig.parse(List<String> args) {
    String workspacePath = Directory.current.path;
    int? ipcPort;
    bool headlessOnly = false;

    for (final arg in args) {
      if (arg.startsWith('--workspace=')) {
        final value = arg.substring('--workspace='.length).trim();
        if (value.isNotEmpty) {
          workspacePath = value;
        }
      } else if (arg.startsWith('--ipc-port=')) {
        final rawPort = arg.substring('--ipc-port='.length).trim();
        final parsed = int.tryParse(rawPort);
        if (parsed != null && parsed > 0 && parsed <= 65535) {
          ipcPort = parsed;
        } else {
          stderr.writeln(
            '[WARN][TunnerMcpCli] Ignoring invalid --ipc-port value: $rawPort',
          );
        }
      } else if (arg == '--headless-only') {
        headlessOnly = true;
      }
    }

    return _CliConfig(
      workspacePath: workspacePath,
      ipcPort: headlessOnly ? null : ipcPort,
      headlessOnly: headlessOnly,
    );
  }
}

Future<void> main(List<String> args) async {
  final config = _CliConfig.parse(args);
  const logger = StudioStderrLogger();

  final workspaceDir = Directory(config.workspacePath).absolute;
  if (!workspaceDir.existsSync()) {
    workspaceDir.createSync(recursive: true);
  }

  final facade = TunnerHeadlessFacade.create(
    workspaceDirectory: workspaceDir,
    logger: logger,
  );

  TunnerIpcBridge? ipcBridge;
  if (!config.headlessOnly && config.ipcPort != null) {
    final bridge = TunnerIpcBridge(logger: logger);
    final connected = await bridge.connect(port: config.ipcPort!);
    if (connected) {
      ipcBridge = bridge;
      facade.onIpcEvent = bridge.emitEvent;
      stderr.writeln(
        '[INFO][TunnerMcpServer] Connected live IPC bridge on 127.0.0.1:${config.ipcPort}',
      );
    } else {
      await bridge.close();
    }
  }

  final registry = TunnerMcpBootstrap.createRegistry(
    facade: facade,
    headlessOnly: config.headlessOnly,
    ipcPort: ipcBridge?.connectedPort,
  );

  final dispatcher = McpDispatcher(
    registry: registry,
    logger: logger,
  );

  final transport = McpStdioTransport(
    dispatcher: dispatcher,
    logger: logger,
  );

  stderr.writeln(
    '[INFO][TunnerMcpServer] Starting tunner-mcp-server '
    '(workspace=${workspaceDir.path}, headlessOnly=${config.headlessOnly}, '
    'ipcPort=${ipcBridge?.connectedPort ?? 'disabled'}, '
    'modules=${registry.registeredModules.length}, '
    'resources=${registry.resourceCount}, '
    'tools=${registry.toolCount}, '
    'prompts=${registry.promptCount})',
  );

  bool shuttingDown = false;
  Future<void> shutdown(String signalName) async {
    if (shuttingDown) return;
    shuttingDown = true;
    stderr.writeln(
      '[INFO][TunnerMcpServer] Received $signalName; shutting down cleanly.',
    );
    await transport.stop();
    facade.onIpcEvent = null;
    await ipcBridge?.close();
    facade.dispose();
    exit(0);
  }

  StreamSubscription<ProcessSignal>? sigintSub;
  StreamSubscription<ProcessSignal>? sigtermSub;

  try {
    sigintSub = ProcessSignal.sigint.watch().listen((_) {
      unawaited(shutdown('SIGINT'));
    });
  } catch (_) {
    // Platform does not support SIGINT signal watching.
  }

  if (!Platform.isWindows) {
    try {
      sigtermSub = ProcessSignal.sigterm.watch().listen((_) {
        unawaited(shutdown('SIGTERM'));
      });
    } catch (_) {
      // Platform does not support SIGTERM signal watching.
    }
  }

  try {
    await transport.start();
  } finally {
    await sigintSub?.cancel();
    await sigtermSub?.cancel();
    facade.onIpcEvent = null;
    await ipcBridge?.close();
    facade.dispose();
  }
}
