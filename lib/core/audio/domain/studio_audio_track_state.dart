import 'studio_transport_status.dart';

/// Modelo inmutable del estado de un canal de audio en el motor de estudio.
class StudioAudioTrackState {
  final String channelId;
  final StudioTransportStatus status;
  final int currentPositionMs;
  final int durationMs;
  final double volume;
  final double playbackRate;
  final bool isLooping;
  final String? sourceTitle;

  const StudioAudioTrackState({
    required this.channelId,
    this.status = StudioTransportStatus.stopped,
    this.currentPositionMs = 0,
    this.durationMs = 0,
    this.volume = 1.0,
    this.playbackRate = 1.0,
    this.isLooping = false,
    this.sourceTitle,
  });

  bool get isPlaying => status == StudioTransportStatus.playing;
  bool get isPaused => status == StudioTransportStatus.paused;
  bool get isStopped => status == StudioTransportStatus.stopped;

  StudioAudioTrackState copyWith({
    String? channelId,
    StudioTransportStatus? status,
    int? currentPositionMs,
    int? durationMs,
    double? volume,
    double? playbackRate,
    bool? isLooping,
    String? sourceTitle,
  }) {
    return StudioAudioTrackState(
      channelId: channelId ?? this.channelId,
      status: status ?? this.status,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      durationMs: durationMs ?? this.durationMs,
      volume: volume ?? this.volume,
      playbackRate: playbackRate ?? this.playbackRate,
      isLooping: isLooping ?? this.isLooping,
      sourceTitle: sourceTitle ?? this.sourceTitle,
    );
  }
}
