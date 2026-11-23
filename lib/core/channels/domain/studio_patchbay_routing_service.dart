import 'dart:async';
import 'dart:typed_data';
import '../../domain/i_studio_listenable.dart';
import 'studio_channel_bus.dart';
import 'studio_modular_plug.dart';
import 'studio_patchbay_matrix_entity.dart';
import 'i_studio_patchbay_routing_service.dart';

export 'i_studio_patchbay_routing_service.dart';

/// Tokens semanticos de identidad cromatica para buses y conectores de la matriz de parcheo.
/// Separados de la logica de enrutamiento para preservar fronteras limpias de dominio.
abstract final class StudioPatchbaySemanticTokens {
  /// Token semantico por defecto para un bus personalizado o canal activo (Cyan Studio).
  static const int defaultCustomChannelColorToken = 0xFF00E5FF;

  /// Token semantico para un conector modular desconectado o en reposo (Slate Neutral).
  static const int disconnectedPlugColorToken = 0xFF3A3F50;

  /// Duracion canónica en milisegundos del pulso de actividad por conector.
  static const int signalPulseWindowMs = 200;
}

/// Servicio de orquestación y enrutamiento en memoria de la matriz de parcheo.
/// Provee soporte full-duplex para sincronización reactiva de parámetros de reproducción
/// (BPM, tonalidad Camelot, título, transporte y buffers PCM) entre herramientas conectadas.
class StudioPatchbayRoutingService with StudioPureNotifierMixin implements IStudioPatchbayRoutingService {
  static final StudioPatchbayRoutingService _instance = StudioPatchbayRoutingService._internal();
  factory StudioPatchbayRoutingService() => _instance;

  /// Crea una instancia aislada sin estado global compartido para DI y pruebas.
  StudioPatchbayRoutingService.isolated({bool headless = false}) : _headless = headless {
    _matrix = StudioPatchbayMatrixEntity.initial();
  }

  StudioPatchbayRoutingService._internal({bool headless = false}) : _headless = headless {
    _matrix = StudioPatchbayMatrixEntity.initial();
  }

  final bool _headless;
  late StudioPatchbayMatrixEntity _matrix;
  final Map<String, StudioSignalDeliveryCallback> _sinkListeners = {};
  final Map<String, List<StudioChannelParamCallback>> _channelListeners = {};
  final Map<String, Timer> _plugPulseTimers = {};
  String? _activePulsePlugId;
  bool _isDisposed = false;

  /// Indica si el servicio opera en modo headless sin timers de pulso visual.
  bool get isHeadless => _headless;

  @override
  StudioPatchbayMatrixEntity get matrix => _matrix;
  @override
  List<StudioChannelBus> get channels => _matrix.channels.values.toList();
  @override
  Map<String, StudioModularPlug> get plugs => _matrix.plugs;
  @override
  String? get activePulsePlugId => _activePulsePlugId;

  /// Conjunto inmutable de conectores que presentan un pulso de señal activo simultáneamente.
  Set<String> get activePulsePlugIds => Set<String>.unmodifiable(_plugPulseTimers.keys);

  /// Verifica si un conector específico presenta actividad de pulso en curso.
  bool isPlugPulsing(String plugId) => _plugPulseTimers.containsKey(plugId);

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _cancelAllPulseTimers() {
    for (final timer in _plugPulseTimers.values) {
      timer.cancel();
    }
    _plugPulseTimers.clear();
    _activePulsePlugId = null;
  }

  /// Reinicia la matriz a su estado inicial canónico (para pruebas o reset de sesión).
  @override
  void resetToDefaults() {
    _cancelAllPulseTimers();
    _matrix = StudioPatchbayMatrixEntity.initial();
    _sinkListeners.clear();
    _channelListeners.clear();
    _safeNotify();
  }

  /// Registra un nuevo plug modular en la matriz si no existe.
  @override
  void registerPlug(StudioModularPlug plug) {
    if (_matrix.plugs.containsKey(plug.id)) return;
    _matrix = _matrix.registerPlug(plug);
    _safeNotify();
  }

  /// Conecta un plug a un canal troncal o personalizado.
  /// Si el plug es un receptor (Sink), le entrega de inmediato el estado actual de reproducción del canal.
  @override
  void connectPlugToChannel(String plugId, String channelId) {
    _matrix = _matrix.connectPlug(plugId, channelId);
    _triggerPlugPulse(plugId);

    // Auto-sincronización instantánea de parámetros para receptores
    final channel = _matrix.channels[channelId];
    if (channel != null && _sinkListeners.containsKey(plugId)) {
      final listener = _sinkListeners[plugId];
      listener?.call('system_sync', channelId, {
        'title': channel.activeTrackTitle,
        'bpm': channel.activeBpm,
        'key': channel.activeCamelotKey,
        'isPlaying': channel.isPlaying,
        'positionMs': channel.positionMs,
      });
    }

    _safeNotify();
  }

  /// Desconecta un plug de cualquier canal.
  @override
  void disconnectPlug(String plugId) {
    _matrix = _matrix.disconnectPlug(plugId);
    _safeNotify();
  }

  /// Crea un nuevo canal personalizado con nombre y color definidos por el usuario.
  @override
  StudioChannelBus createCustomChannel({
    required String name,
    String? shortCode,
    int? colorHex,
  }) {
    final channelId = 'canal_custom_${DateTime.now().millisecondsSinceEpoch}';
    final newBus = StudioChannelBus.createCustom(
      id: channelId,
      name: name,
      shortCode: shortCode,
      colorHex: colorHex ?? StudioPatchbaySemanticTokens.defaultCustomChannelColorToken,
    );
    _matrix = _matrix.addChannel(newBus);
    _safeNotify();
    return newBus;
  }

  /// Renombra un canal existente conservando su ID, color y conexiones.
  @override
  void renameChannel(String channelId, String newName) {
    _matrix = _matrix.renameChannel(channelId, newName);
    final updated = _matrix.channels[channelId];
    if (updated != null) {
      _notifyChannelSubscribers(updated);
    }
    _safeNotify();
  }

  /// Elimina un canal personalizado desconectando automáticamente los plugs vinculados.
  @override
  void removeCustomChannel(String channelId) {
    _matrix = _matrix.removeChannel(channelId);
    _channelListeners.remove(channelId);
    _safeNotify();
  }

  /// Publica y sincroniza reactivamente los parámetros de reproducción de un canal
  /// hacia todas las herramientas conectadas (Full-Duplex Parameter Sync).
  @override
  void publishChannelParameters(
    String channelId, {
    String? title,
    double? bpm,
    String? key,
    bool? isPlaying,
    int? positionMs,
    Float32List? pcmBuffer,
    String? initiatorPlugId,
  }) {
    final existing = _matrix.channels[channelId];
    if (existing == null) return;

    final updated = existing.withPlaybackParameters(
      title: title ?? existing.activeTrackTitle,
      bpm: bpm ?? existing.activeBpm,
      key: key ?? existing.activeCamelotKey,
      isPlaying: isPlaying ?? existing.isPlaying,
      positionMs: positionMs ?? existing.positionMs,
      pcmBuffer: pcmBuffer ?? existing.livePcmBuffer,
    );

    _matrix = _matrix.updateChannel(updated);

    // Notificar a oyentes de canal
    _notifyChannelSubscribers(updated);

    // Entregar parámetros actualizados a los plugs receptores conectados
    final sinks = _matrix.findSinksForChannel(channelId);
    for (final sink in sinks) {
      if (initiatorPlugId != null && sink.id == initiatorPlugId) continue;
      _triggerPlugPulse(sink.id);
      final listener = _sinkListeners[sink.id];
      listener?.call(initiatorPlugId ?? 'channel_bus', channelId, {
        'title': updated.activeTrackTitle,
        'bpm': updated.activeBpm,
        'key': updated.activeCamelotKey,
        'isPlaying': updated.isPlaying,
        'positionMs': updated.positionMs,
        'pcmBuffer': updated.livePcmBuffer,
      });
    }

    _safeNotify();
  }

  /// Registra una función de escucha ante cualquier cambio de estado del canal.
  @override
  void registerChannelListener(String channelId, StudioChannelParamCallback callback) {
    _channelListeners.putIfAbsent(channelId, () => []).add(callback);
  }

  /// Remueve una función de escucha previamente registrada.
  @override
  void unregisterChannelListener(String channelId, StudioChannelParamCallback callback) {
    _channelListeners[channelId]?.remove(callback);
  }

  void _notifyChannelSubscribers(StudioChannelBus bus) {
    final listeners = _channelListeners[bus.id];
    if (listeners != null) {
      for (final cb in List.of(listeners)) {
        cb(bus);
      }
    }
  }

  /// Actualiza la ganancia o estado de mute de un canal.
  @override
  void setChannelGain(String channelId, double gain) {
    final ch = _matrix.channels[channelId];
    if (ch == null) return;
    _matrix = _matrix.updateChannel(ch.copyWith(gain: gain.clamp(0.0, 2.0)));
    _safeNotify();
  }

  @override
  void toggleChannelMute(String channelId) {
    final ch = _matrix.channels[channelId];
    if (ch == null) return;
    _matrix = _matrix.updateChannel(ch.copyWith(isMuted: !ch.isMuted));
    _safeNotify();
  }

  /// Registra un oyente para recibir señales dirigidas a un plug receptor (Sink).
  @override
  void registerSinkListener(String sinkPlugId, StudioSignalDeliveryCallback callback) {
    _sinkListeners[sinkPlugId] = callback;
  }

  @override
  void unregisterSinkListener(String sinkPlugId) {
    _sinkListeners.remove(sinkPlugId);
  }

  /// Emite una señal (p. ej. melodía de partitura sintetizada, pista WAV) desde un plug emisor.
  @override
  void dispatchSignalFromPlug({
    required String sourcePlugId,
    required Map<String, dynamic> payload,
  }) {
    final sourcePlug = _matrix.plugs[sourcePlugId];
    if (sourcePlug == null || !sourcePlug.isConnected) return;

    final channelId = sourcePlug.connectedChannelId!;
    final channel = _matrix.channels[channelId];
    _triggerPlugPulse(sourcePlugId);

    // Ajustar payload según ganancia y estado de silencio (mute) del canal
    final effectivePayload = Map<String, dynamic>.from(payload);
    final bool isMuted = channel?.isMuted ?? false;
    if (channel != null) {
      effectivePayload['channelGain'] = isMuted ? 0.0 : channel.gain;
      effectivePayload['channelIsMuted'] = isMuted;
      if (effectivePayload['pcmBuffer'] is Float32List) {
        final pcm = effectivePayload['pcmBuffer'] as Float32List;
        if (isMuted) {
          effectivePayload['pcmBuffer'] = Float32List(pcm.length);
        } else if ((channel.gain - 1.0).abs() > 1e-4) {
          final scaled = Float32List(pcm.length);
          for (int i = 0; i < pcm.length; i++) {
            scaled[i] = (pcm[i] * channel.gain).clamp(-1.0, 1.0);
          }
          effectivePayload['pcmBuffer'] = scaled;
        }
      }
      if (isMuted) {
        effectivePayload['isPlaying'] = false;
        effectivePayload.remove('wavBytes');
        effectivePayload.remove('filePath');
      }
    }

    // Actualizar metadatos del canal sin re-despachar a los sinks (evita doble entrega)
    final title = effectivePayload['title'] as String?;
    final bpm = (effectivePayload['bpm'] as num?)?.toDouble();
    final key = effectivePayload['key'] as String?;
    final isPlaying = effectivePayload['isPlaying'] as bool?;
    final pcmBuffer = effectivePayload['pcmBuffer'] as Float32List?;

    if (channel != null && (title != null || bpm != null || key != null || isPlaying != null || pcmBuffer != null)) {
      _matrix = _matrix.updateChannel(
        channel.copyWith(
          activeTrackTitle: title,
          activeBpm: bpm,
          activeCamelotKey: key,
          isPlaying: isPlaying,
          livePcmBuffer: pcmBuffer,
        ),
      );
      _safeNotify();
    }

    // Despacho único a todos los plugs receptores conectados a este canal
    final sinks = _matrix.findSinksForChannel(channelId);
    for (final sink in sinks) {
      _triggerPlugPulse(sink.id);
      final listener = _sinkListeners[sink.id];
      listener?.call(sourcePlugId, channelId, effectivePayload);
    }
  }

  void _triggerPlugPulse(String plugId) {
    if (_headless || _isDisposed) return;
    _activePulsePlugId = plugId;
    _plugPulseTimers[plugId]?.cancel();
    _plugPulseTimers[plugId] = Timer(
      const Duration(milliseconds: StudioPatchbaySemanticTokens.signalPulseWindowMs),
      () {
        _plugPulseTimers.remove(plugId);
        if (_activePulsePlugId == plugId) {
          _activePulsePlugId = _plugPulseTimers.keys.isNotEmpty
              ? _plugPulseTimers.keys.last
              : null;
        }
        _safeNotify();
      },
    );
    _safeNotify();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _cancelAllPulseTimers();
    _sinkListeners.clear();
    _channelListeners.clear();
    super.dispose();
  }

  @override
  void loadFromMatrix(StudioPatchbayMatrixEntity savedMatrix) {
    _matrix = savedMatrix;
    _safeNotify();
  }

  /// Retorna el color asignado al canal conectado a un plug, o gris oscuro si está desconectado.
  @override
  int getColorForPlug(StudioModularPlug plug) {
    if (!plug.isConnected) {
      return StudioPatchbaySemanticTokens.disconnectedPlugColorToken;
    }
    final ch = _matrix.channels[plug.connectedChannelId];
    return ch?.colorHex ?? StudioPatchbaySemanticTokens.defaultCustomChannelColorToken;
  }
}
