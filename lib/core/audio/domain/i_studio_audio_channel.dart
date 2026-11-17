import 'dart:typed_data';
import 'studio_audio_track_state.dart';
import 'studio_transport_status.dart';

/// Contrato formal para el control de transporte y emisión de un canal de audio individual.
abstract class IStudioAudioChannel {
  String get channelId;
  StudioTransportStatus get status;
  bool get isPlaying;
  bool get isPaused;
  Duration get currentPosition;
  double get volume;
  double get playbackRate;
  Stream<StudioAudioTrackState> get stateStream;

  /// Carga una fuente de audio (ruta a archivo local o bytes en memoria).
  Future<void> loadSource({
    String? filePath,
    Uint8List? bytes,
    bool loop = false,
    String? title,
  });

  /// Inicia o reanuda la reproducción. Si estaba en pausa, continúa sin reiniciar al byte cero.
  Future<void> play();

  /// Pausa de forma inmediata y determinista la reproducción.
  Future<void> pause();

  /// Detiene y rebobina la reproducción al milisegundo cero.
  Future<void> stop();

  /// Mueve el cabezal de lectura al punto temporal indicado.
  Future<void> seek(Duration position);

  /// Calibra el volumen del canal ([0.0, 1.0]). Si el canal está en pausa, nunca debe provocar reanudación.
  Future<void> setVolume(double volume);

  /// Calibra la velocidad de reproducción ([0.5, 2.0]).
  Future<void> setPlaybackRate(double rate);

  /// Libera los recursos del canal.
  Future<void> dispose();
}
