import 'i_studio_audio_channel.dart';

/// Contrato central del motor de salida de audio de Tunner Studio.
/// Administra el pool de canales de audio nativos con enrutamiento por ID.
abstract class IStudioAudioEngine {
  /// Obtiene o inicializa de forma determinista un canal de audio por su ID.
  IStudioAudioChannel getChannel(String channelId);

  /// Pausa simultáneamente todos los canales activos del estudio.
  Future<void> pauseAll();

  /// Detiene simultáneamente todos los canales activos del estudio.
  Future<void> stopAll();

  /// Libera la totalidad de los canales y sinks de audio del motor.
  Future<void> dispose();
}
