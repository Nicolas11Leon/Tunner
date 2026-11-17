import '../domain/i_studio_audio_channel.dart';
import '../domain/i_studio_audio_engine.dart';
import 'studio_audio_channel.dart';

/// Implementación oficial del motor central de salida de audio de Tunner Studio.
/// Administra un pool unificado de canales de audio nativos con asignación bajo demanda.
class StudioAudioEngine implements IStudioAudioEngine {
  static final StudioAudioEngine _instance = StudioAudioEngine._internal();
  factory StudioAudioEngine() => _instance;

  StudioAudioEngine._internal();

  final Map<String, StudioAudioChannel> _channels = {};

  @override
  IStudioAudioChannel getChannel(String channelId) {
    final normalizedId = channelId.trim().toLowerCase();
    return _channels.putIfAbsent(
      normalizedId,
      () => StudioAudioChannel(channelId: normalizedId),
    );
  }

  @override
  Future<void> pauseAll() async {
    for (final channel in _channels.values) {
      if (channel.isPlaying) {
        await channel.pause();
      }
    }
  }

  @override
  Future<void> stopAll() async {
    for (final channel in _channels.values) {
      await channel.stop();
    }
  }

  @override
  Future<void> dispose() async {
    for (final channel in _channels.values) {
      await channel.dispose();
    }
    _channels.clear();
  }
}
