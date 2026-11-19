import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/studio_channel_bus.dart';
import '../domain/studio_modular_plug.dart';
import '../domain/studio_patchbay_matrix_entity.dart';

/// Callback para entrega de señales de audio y eventos entre plugs conectados.
typedef StudioSignalDeliveryCallback = void Function(
  String sourcePlugId,
  String channelId,
  Map<String, dynamic> payload,
);

/// Callback para notificación reactiva de cambios en los parámetros del canal.
typedef StudioChannelParamCallback = void Function(StudioChannelBus bus);

/// Servicio de orquestación y enrutamiento en memoria de la matriz de parcheo.
/// Provee soporte full-duplex para sincronización reactiva de parámetros de reproducción
/// (BPM, tonalidad Camelot, título, transporte y buffers PCM) entre herramientas conectadas.
class StudioPatchbayRoutingService extends ChangeNotifier {
  static final StudioPatchbayRoutingService _instance = StudioPatchbayRoutingService._internal();
  factory StudioPatchbayRoutingService() => _instance;

  StudioPatchbayRoutingService._internal() {
    _matrix = StudioPatchbayMatrixEntity.initial();
  }

  late StudioPatchbayMatrixEntity _matrix;
  final Map<String, StudioSignalDeliveryCallback> _sinkListeners = {};
  final Map<String, List<StudioChannelParamCallback>> _channelListeners = {};
  Timer? _signalPulseTimer;
  String? _activePulsePlugId;
  bool _isDisposed = false;

  StudioPatchbayMatrixEntity get matrix => _matrix;
  List<StudioChannelBus> get channels => _matrix.channels.values.toList();
  Map<String, StudioModularPlug> get plugs => _matrix.plugs;
  String? get activePulsePlugId => _activePulsePlugId;

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Reinicia la matriz a su estado inicial canónico (para pruebas o reset de sesión).
  void resetToDefaults() {
    _signalPulseTimer?.cancel();
    _signalPulseTimer = null;
    _activePulsePlugId = null;
    _matrix = StudioPatchbayMatrixEntity.initial();
    _sinkListeners.clear();
    _channelListeners.clear();
    _safeNotify();
  }

  /// Registra un nuevo plug modular en la matriz si no existe.
  void registerPlug(StudioModularPlug plug) {
    if (_matrix.plugs.containsKey(plug.id)) return;
    _matrix = _matrix.registerPlug(plug);
    notifyListeners();
  }

  /// Conecta un plug a un canal troncal o personalizado.
  /// Si el plug es un receptor (Sink), le entrega de inmediato el estado actual de reproducción del canal.
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

    notifyListeners();
  }

  /// Desconecta un plug de cualquier canal.
  void disconnectPlug(String plugId) {
    _matrix = _matrix.disconnectPlug(plugId);
    notifyListeners();
  }

  /// Crea un nuevo canal personalizado con nombre y color definidos por el usuario.
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
      colorHex: colorHex ?? 0xFF00E5FF,
    );
    _matrix = _matrix.addChannel(newBus);
    notifyListeners();
    return newBus;
  }

  /// Renombra un canal existente conservando su ID, color y conexiones.
  void renameChannel(String channelId, String newName) {
    _matrix = _matrix.renameChannel(channelId, newName);
    final updated = _matrix.channels[channelId];
    if (updated != null) {
      _notifyChannelSubscribers(updated);
    }
    notifyListeners();
  }

  /// Elimina un canal personalizado desconectando automáticamente los plugs vinculados.
  void removeCustomChannel(String channelId) {
    _matrix = _matrix.removeChannel(channelId);
    _channelListeners.remove(channelId);
    notifyListeners();
  }

  /// Publica y sincroniza reactivamente los parámetros de reproducción de un canal
  /// hacia todas las herramientas conectadas (Full-Duplex Parameter Sync).
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

    notifyListeners();
  }

  /// Registra una función de escucha ante cualquier cambio de estado del canal.
  void registerChannelListener(String channelId, StudioChannelParamCallback callback) {
    _channelListeners.putIfAbsent(channelId, () => []).add(callback);
  }

  /// Remueve una función de escucha previamente registrada.
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
  void setChannelGain(String channelId, double gain) {
    final ch = _matrix.channels[channelId];
    if (ch == null) return;
    _matrix = _matrix.updateChannel(ch.copyWith(gain: gain.clamp(0.0, 2.0)));
    notifyListeners();
  }

  void toggleChannelMute(String channelId) {
    final ch = _matrix.channels[channelId];
    if (ch == null) return;
    _matrix = _matrix.updateChannel(ch.copyWith(isMuted: !ch.isMuted));
    notifyListeners();
  }

  /// Registra un oyente para recibir señales dirigidas a un plug receptor (Sink).
  void registerSinkListener(String sinkPlugId, StudioSignalDeliveryCallback callback) {
    _sinkListeners[sinkPlugId] = callback;
  }

  void unregisterSinkListener(String sinkPlugId) {
    _sinkListeners.remove(sinkPlugId);
  }

  /// Emite una señal (p. ej. melodía de partitura sintetizada, pista WAV) desde un plug emisor.
  void dispatchSignalFromPlug({
    required String sourcePlugId,
    required Map<String, dynamic> payload,
  }) {
    final sourcePlug = _matrix.plugs[sourcePlugId];
    if (sourcePlug == null || !sourcePlug.isConnected) return;

    final channelId = sourcePlug.connectedChannelId!;
    _triggerPlugPulse(sourcePlugId);

    // Actualizar parámetros del canal si vienen provistos en el payload
    final title = payload['title'] as String?;
    final bpm = (payload['bpm'] as num?)?.toDouble();
    final key = payload['key'] as String?;
    final isPlaying = payload['isPlaying'] as bool?;
    final pcmBuffer = payload['pcmBuffer'] as Float32List?;

    if (title != null || bpm != null || key != null || isPlaying != null || pcmBuffer != null) {
      publishChannelParameters(
        channelId,
        title: title,
        bpm: bpm,
        key: key,
        isPlaying: isPlaying,
        pcmBuffer: pcmBuffer,
        initiatorPlugId: sourcePlugId,
      );
    }

    // Buscar todos los plugs receptores conectados a este mismo canal
    final sinks = _matrix.findSinksForChannel(channelId);
    for (final sink in sinks) {
      _triggerPlugPulse(sink.id);
      final listener = _sinkListeners[sink.id];
      listener?.call(sourcePlugId, channelId, payload);
    }
  }

  void _triggerPlugPulse(String plugId) {
    if (_isDisposed) return;
    _activePulsePlugId = plugId;
    _signalPulseTimer?.cancel();
    _signalPulseTimer = Timer(const Duration(milliseconds: 200), () {
      _activePulsePlugId = null;
      _safeNotify();
    });
    _safeNotify();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _signalPulseTimer?.cancel();
    _signalPulseTimer = null;
    _sinkListeners.clear();
    _channelListeners.clear();
    super.dispose();
  }

  /// Retorna el color asignado al canal conectado a un plug, o gris oscuro si está desconectado.
  int getColorForPlug(StudioModularPlug plug) {
    if (!plug.isConnected) return 0xFF3A3F50;
    final ch = _matrix.channels[plug.connectedChannelId];
    return ch?.colorHex ?? 0xFF00E5FF;
  }
}
