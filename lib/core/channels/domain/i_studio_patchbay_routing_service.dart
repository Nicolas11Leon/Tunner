import 'package:flutter/foundation.dart';
import 'studio_channel_bus.dart';
import 'studio_modular_plug.dart';
import 'studio_patchbay_matrix_entity.dart';

/// Callback para entrega de señales de audio y eventos entre plugs conectados.
typedef StudioSignalDeliveryCallback = void Function(
  String sourcePlugId,
  String channelId,
  Map<String, dynamic> payload,
);

/// Callback para notificación reactiva de cambios en los parámetros del canal.
typedef StudioChannelParamCallback = void Function(StudioChannelBus bus);

/// Contrato abstracto de dominio para la matriz reactiva de enrutamiento y parcheo.
abstract class IStudioPatchbayRoutingService implements Listenable {
  StudioPatchbayMatrixEntity get matrix;
  List<StudioChannelBus> get channels;
  Map<String, StudioModularPlug> get plugs;
  String? get activePulsePlugId;

  void resetToDefaults();
  void registerPlug(StudioModularPlug plug);
  void connectPlugToChannel(String plugId, String channelId);
  void disconnectPlug(String plugId);

  StudioChannelBus createCustomChannel({
    required String name,
    String? shortCode,
    int? colorHex,
  });

  void renameChannel(String channelId, String newName);
  void removeCustomChannel(String channelId);

  void publishChannelParameters(
    String channelId, {
    String? title,
    double? bpm,
    String? key,
    bool? isPlaying,
    int? positionMs,
    Float32List? pcmBuffer,
    String? initiatorPlugId,
  });

  void registerChannelListener(String channelId, StudioChannelParamCallback callback);
  void unregisterChannelListener(String channelId, StudioChannelParamCallback callback);

  void setChannelGain(String channelId, double gain);
  void toggleChannelMute(String channelId);

  void registerSinkListener(String sinkPlugId, StudioSignalDeliveryCallback callback);
  void unregisterSinkListener(String sinkPlugId);

  void dispatchSignalFromPlug({
    required String sourcePlugId,
    required Map<String, dynamic> payload,
  });

  void loadFromMatrix(StudioPatchbayMatrixEntity savedMatrix);

  int getColorForPlug(StudioModularPlug plug);
}
