import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../domain/i_studio_audio_channel.dart';
import '../domain/studio_audio_track_state.dart';
import '../domain/studio_transport_status.dart';

/// Implementación de infraestructura para un canal de audio individual con [AudioPlayer].
/// Garantiza transiciones de transporte deterministas e inmunidad absoluta a reanudaciones
/// accidentales durante la aplicación de curvas de fader y volumen.
class StudioAudioChannel implements IStudioAudioChannel {
  @override
  final String channelId;

  AudioPlayer? _playerInstance;
  final AudioPlayer? _injectedPlayer;

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  AudioPlayer? get _player {
    if (_injectedPlayer != null) return _injectedPlayer;
    if (_isTestEnvironment) return null;
    return _playerInstance ??= AudioPlayer();
  }

  StudioTransportStatus _status = StudioTransportStatus.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  double _playbackRate = 1.0;
  bool _isLooping = false;
  String? _sourceTitle;

  String? _loadedFilePath;
  Uint8List? _loadedBytes;

  final StreamController<StudioAudioTrackState> _stateController =
      StreamController<StudioAudioTrackState>.broadcast();

  double? _queuedVolume;
  bool _isProcessingVolume = false;

  StudioAudioChannel({
    required this.channelId,
    AudioPlayer? injectedPlayer,
  }) : _injectedPlayer = injectedPlayer {
    _initPlayerListeners();
  }

  void _initPlayerListeners() {
    final p = _player;
    if (p == null) return;

    p.onPositionChanged.listen((pos) {
      _currentPosition = pos;
      _emitState();
    });

    p.onDurationChanged.listen((dur) {
      _totalDuration = dur;
      _emitState();
    });

    p.onPlayerComplete.listen((_) {
      if (!_isLooping) {
        _status = StudioTransportStatus.stopped;
        _currentPosition = Duration.zero;
        _emitState();
      }
    });
  }

  void _emitState() {
    if (_stateController.isClosed) return;
    _stateController.add(
      StudioAudioTrackState(
        channelId: channelId,
        status: _status,
        currentPositionMs: _currentPosition.inMilliseconds,
        durationMs: _totalDuration.inMilliseconds,
        volume: _volume,
        playbackRate: _playbackRate,
        isLooping: _isLooping,
        sourceTitle: _sourceTitle,
      ),
    );
  }

  @override
  StudioTransportStatus get status => _status;

  @override
  bool get isPlaying => _status == StudioTransportStatus.playing;

  @override
  bool get isPaused => _status == StudioTransportStatus.paused;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  double get volume => _volume;

  @override
  double get playbackRate => _playbackRate;

  @override
  Stream<StudioAudioTrackState> get stateStream => _stateController.stream;

  @override
  Future<void> loadSource({
    String? filePath,
    Uint8List? bytes,
    bool loop = false,
    String? title,
  }) async {
    _loadedFilePath = filePath;
    _loadedBytes = bytes;
    _isLooping = loop;
    _sourceTitle = title;
    _status = StudioTransportStatus.stopped;
    _currentPosition = Duration.zero;

    final p = _player;
    if (p == null) {
      _emitState();
      return;
    }

    try {
      await p.stop();
      await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);

      if (filePath != null && filePath.isNotEmpty) {
        await p.setSource(DeviceFileSource(filePath));
      } else if (bytes != null && bytes.isNotEmpty) {
        await p.setSource(BytesSource(bytes, mimeType: 'audio/wav'));
      }
    } catch (e) {
      debugPrint('StudioAudioChannel [$channelId] Error cargando fuente: $e');
    }
    _emitState();
  }

  @override
  Future<void> play() async {
    final p = _player;
    final wasPaused = _status == StudioTransportStatus.paused;

    // Actualización síncrona inmediata en el modelo de transporte
    _status = StudioTransportStatus.playing;
    _emitState();

    if (p == null) return;

    try {
      await p.setReleaseMode(_isLooping ? ReleaseMode.loop : ReleaseMode.stop);

      if (wasPaused) {
        // Reanudación fiel desde la posición en pausa sin rebobinar al inicio
        await p.resume();
      } else {
        // Iniciar desde fuente cargada
        if (_loadedFilePath != null && _loadedFilePath!.isNotEmpty) {
          await p.play(DeviceFileSource(_loadedFilePath!));
        } else if (_loadedBytes != null && _loadedBytes!.isNotEmpty) {
          await p.play(BytesSource(_loadedBytes!, mimeType: 'audio/wav'));
        } else {
          await p.resume();
        }
      }

      // Restaura el volumen efectivo de reproducción
      final effVol = _volume <= 0.001 ? 0.0001 : _volume;
      await p.setVolume(effVol.clamp(0.0, 1.0));
      await p.setPlaybackRate(_playbackRate.clamp(0.5, 2.0));
    } catch (e) {
      debugPrint('StudioAudioChannel [$channelId] Error en play: $e');
      _status = StudioTransportStatus.error;
      _emitState();
    }
  }

  @override
  Future<void> pause() async {
    // REGLA CARDINAL: Marcado síncrono e inmediato como pausado ANTES de cualquier await.
    // Esto garantiza que cualquier llamada concurrente a setVolume o sincronización de UI
    // sepa instantáneamente que el canal está en pausa determinista.
    _status = StudioTransportStatus.paused;
    _emitState();

    final p = _player;
    if (p == null) return;

    try {
      await p.pause();
    } catch (e) {
      debugPrint('StudioAudioChannel [$channelId] Error en pause: $e');
    }
  }

  @override
  Future<void> stop() async {
    _status = StudioTransportStatus.stopped;
    _currentPosition = Duration.zero;
    _emitState();

    final p = _player;
    if (p == null) return;

    try {
      await p.stop();
    } catch (e) {
      debugPrint('StudioAudioChannel [$channelId] Error en stop: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _currentPosition = position;
    _emitState();

    final p = _player;
    if (p == null) return;

    try {
      await p.seek(position);
    } catch (e) {
      debugPrint('StudioAudioChannel [$channelId] Error en seek: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _queuedVolume = _volume;

    if (_isProcessingVolume) return;
    _isProcessingVolume = true;

    final p = _player;
    if (p == null) {
      _isProcessingVolume = false;
      return;
    }

    while (_queuedVolume != null) {
      final target = _queuedVolume!;
      _queuedVolume = null;

      try {
        // En Linux GStreamer, si está reproduciendo activamente y target es 0,
        // usamos 0.0001 (-80 dBFS) para que no congele el sink.
        // Pero si el estado del canal está en PAUSA o STOPPED, se aplica target directamente.
        final effectiveVol = (_status == StudioTransportStatus.playing && target <= 0.001)
            ? 0.0001
            : target;

        await p.setVolume(effectiveVol.clamp(0.0, 1.0));

        // REGLA CARDINAL: Si el canal está en pausa o detenido, NUNCA ejecutar resume().
        // Solo si el canal está explícitamente en modo playing se asegura la fluidez acústica continua.
        if (target > 0.005 && _status == StudioTransportStatus.playing) {
          final state = p.state;
          if (state != PlayerState.playing) {
            try {
              await p.resume();
            } catch (_) {
              if (_loadedFilePath != null && _loadedFilePath!.isNotEmpty) {
                await p.play(DeviceFileSource(_loadedFilePath!));
              } else if (_loadedBytes != null && _loadedBytes!.isNotEmpty) {
                await p.play(BytesSource(_loadedBytes!, mimeType: 'audio/wav'));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('StudioAudioChannel [$channelId] Error en setVolume: $e');
      }
    }

    _isProcessingVolume = false;
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate.clamp(0.5, 2.0);
    _emitState();

    final p = _player;
    if (p == null) return;

    try {
      await p.setPlaybackRate(_playbackRate);
    } catch (e) {
      debugPrint('StudioAudioChannel [$channelId] Error en setPlaybackRate: $e');
    }
  }

  @override
  Future<void> dispose() async {
    try {
      final p = _playerInstance ?? _injectedPlayer;
      if (p != null) {
        await p.stop();
        await p.dispose();
      }
      _status = StudioTransportStatus.stopped;
      await _stateController.close();
    } catch (e) {
      debugPrint('StudioAudioChannel [$channelId] Error al liberar recursos: $e');
    }
  }
}
