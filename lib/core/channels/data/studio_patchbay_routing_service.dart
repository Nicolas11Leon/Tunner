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

/// Servicio de orquestación y enrutamiento en memoria de la matriz de parcheo.
class StudioPatchbayRoutingService extends ChangeNotifier {
  static final StudioPatchbayRoutingService _instance = StudioPatchbayRoutingService._internal();
  factory StudioPatchbayRoutingService() => _instance;

  StudioPatchbayRoutingService._internal() {
    _matrix = StudioPatchbayMatrixEntity.initial();
  }

  late StudioPatchbayMatrixEntity _matrix;
  final Map<String, StudioSignalDeliveryCallback> _sinkListeners = {};
  Timer? _signalPulseTimer;
  String? _activePulsePlugId;

  StudioPatchbayMatrixEntity get matrix => _matrix;
  List<StudioChannelBus> get channels => _matrix.channels.values.toList();
  Map<String, StudioModularPlug> get plugs => _matrix.plugs;
  String? get activePulsePlugId => _activePulsePlugId;

  /// Registra un nuevo plug modular en la matriz si no existe.
  void registerPlug(StudioModularPlug plug) {
    if (_matrix.plugs.containsKey(plug.id)) return;
    _matrix = _matrix.registerPlug(plug);
    notifyListeners();
  }

  /// Conecta un plug a un canal troncal (canal_a, canal_b, canal_c, canal_d).
  void connectPlugToChannel(String plugId, String channelId) {
    _matrix = _matrix.connectPlug(plugId, channelId);
    _triggerPlugPulse(plugId);
    notifyListeners();
  }

  /// Desconecta un plug de cualquier canal.
  void disconnectPlug(String plugId) {
    _matrix = _matrix.disconnectPlug(plugId);
    notifyListeners();
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

    // Buscar todos los plugs receptores conectados a este mismo canal
    final sinks = _matrix.findSinksForChannel(channelId);
    for (final sink in sinks) {
      _triggerPlugPulse(sink.id);
      final listener = _sinkListeners[sink.id];
      listener?.call(sourcePlugId, channelId, payload);
    }
  }

  void _triggerPlugPulse(String plugId) {
    _activePulsePlugId = plugId;
    _signalPulseTimer?.cancel();
    _signalPulseTimer = Timer(const Duration(milliseconds: 200), () {
      _activePulsePlugId = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Retorna el color asignado al canal conectado a un plug, o gris oscuro si está desconectado.
  int getColorForPlug(StudioModularPlug plug) {
    if (!plug.isConnected) return 0xFF3A3F50;
    final ch = _matrix.channels[plug.connectedChannelId];
    return ch?.colorHex ?? 0xFF3A3F50;
  }

  @override
  void dispose() {
    _signalPulseTimer?.cancel();
    super.dispose();
  }
}
