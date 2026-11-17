import 'dart:math' as math;

import 'media_asset_entity.dart';

/// Semantic role of each lane in the synchronized multi-track timeline.
enum TimelineTrackKind {
  deckA,
  deckB,
  scoreMidi,
  samplerSfx,
}

/// Immutable clip placed on a [TimelineTrackEntity] at a quantized or free offset.
class TimelineClipEntity {
  final String clipId;
  final String assetId;
  final String label;
  final MediaAssetKind assetKind;
  final int startMs;
  final int durationMs;
  final double gain;

  const TimelineClipEntity({
    required this.clipId,
    required this.assetId,
    required this.label,
    required this.assetKind,
    required this.startMs,
    required this.durationMs,
    this.gain = 1.0,
  });

  int get endMs => startMs + durationMs;

  TimelineClipEntity copyWith({
    String? clipId,
    String? assetId,
    String? label,
    MediaAssetKind? assetKind,
    int? startMs,
    int? durationMs,
    double? gain,
  }) {
    return TimelineClipEntity(
      clipId: clipId ?? this.clipId,
      assetId: assetId ?? this.assetId,
      label: label ?? this.label,
      assetKind: assetKind ?? this.assetKind,
      startMs: startMs ?? this.startMs,
      durationMs: durationMs ?? this.durationMs,
      gain: gain ?? this.gain,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'clipId': clipId,
      'assetId': assetId,
      'label': label,
      'assetKind': assetKind.name,
      'startMs': startMs,
      'durationMs': durationMs,
      'gain': gain,
    };
  }

  factory TimelineClipEntity.fromJson(Map<String, dynamic> json) {
    final kindName = json['assetKind'] as String? ?? MediaAssetKind.audioTrack.name;
    final parsedKind = MediaAssetKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => MediaAssetKind.audioTrack,
    );

    return TimelineClipEntity(
      clipId: json['clipId'] as String? ?? 'clip_unknown',
      assetId: json['assetId'] as String? ?? 'asset_unknown',
      label: json['label'] as String? ?? 'Clip',
      assetKind: parsedKind,
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 4000,
      gain: (json['gain'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Immutable track lane inside the synchronized timeline workspace.
class TimelineTrackEntity {
  final String trackId;
  final String name;
  final TimelineTrackKind kind;
  final bool isMuted;
  final bool isSolo;
  final double volume;
  final List<TimelineClipEntity> clips;

  const TimelineTrackEntity({
    required this.trackId,
    required this.name,
    required this.kind,
    this.isMuted = false,
    this.isSolo = false,
    this.volume = 1.0,
    this.clips = const <TimelineClipEntity>[],
  });

  TimelineTrackEntity copyWith({
    String? trackId,
    String? name,
    TimelineTrackKind? kind,
    bool? isMuted,
    bool? isSolo,
    double? volume,
    List<TimelineClipEntity>? clips,
  }) {
    return TimelineTrackEntity(
      trackId: trackId ?? this.trackId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      volume: volume ?? this.volume,
      clips: clips ?? this.clips,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'trackId': trackId,
      'name': name,
      'kind': kind.name,
      'isMuted': isMuted,
      'isSolo': isSolo,
      'volume': volume,
      'clips': clips.map((c) => c.toJson()).toList(growable: false),
    };
  }

  factory TimelineTrackEntity.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? TimelineTrackKind.deckA.name;
    final parsedKind = TimelineTrackKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => TimelineTrackKind.deckA,
    );

    return TimelineTrackEntity(
      trackId: json['trackId'] as String? ?? 'track_unknown',
      name: json['name'] as String? ?? 'Track',
      kind: parsedKind,
      isMuted: json['isMuted'] as bool? ?? false,
      isSolo: json['isSolo'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      clips: (json['clips'] as List<dynamic>?)
              ?.map(
                (c) => TimelineClipEntity.fromJson(c as Map<String, dynamic>),
              )
              .toList(growable: false) ??
          const <TimelineClipEntity>[],
    );
  }
}

/// Pure domain aggregate managing multi-track timeline arrangement,
/// beatgrid quantization, and non-overlapping clip placement.
class TimelineProjectEntity {
  /// Milliseconds in one minute, used for beatgrid duration: `60000 / bpm`.
  static const double msPerMinute = 60000.0;

  /// Fallback clip length (4 beats at 120 BPM = 2000 ms) for score/preset items
  /// whose intrinsic duration is zero.
  static const int defaultNonAudioClipDurationMs = 4000;

  final String projectId;
  final String title;
  final double masterBpm;
  final bool snapToBeatgrid;
  final List<TimelineTrackEntity> tracks;

  const TimelineProjectEntity({
    required this.projectId,
    required this.title,
    this.masterBpm = 124.0,
    this.snapToBeatgrid = true,
    required this.tracks,
  });

  factory TimelineProjectEntity.defaultWorkspace() {
    return const TimelineProjectEntity(
      projectId: 'tunner_timeline_main',
      title: 'Tunner Live Arrangement',
      masterBpm: 124.0,
      snapToBeatgrid: true,
      tracks: <TimelineTrackEntity>[
        TimelineTrackEntity(
          trackId: 'track_deck_a',
          name: 'Deck A / Audio',
          kind: TimelineTrackKind.deckA,
        ),
        TimelineTrackEntity(
          trackId: 'track_deck_b',
          name: 'Deck B / Stems',
          kind: TimelineTrackKind.deckB,
        ),
        TimelineTrackEntity(
          trackId: 'track_score_midi',
          name: 'Partitura / MIDI',
          kind: TimelineTrackKind.scoreMidi,
        ),
        TimelineTrackEntity(
          trackId: 'track_sampler_sfx',
          name: 'Sampler / SFX',
          kind: TimelineTrackKind.samplerSfx,
        ),
      ],
    );
  }

  double get beatDurationMs => msPerMinute / masterBpm.clamp(40.0, 240.0);

  int get totalDurationMs {
    int maxEnd = 0;
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.endMs > maxEnd) {
          maxEnd = clip.endMs;
        }
      }
    }
    return maxEnd;
  }

  bool get isEmpty => tracks.every((track) => track.clips.isEmpty);

  TimelineProjectEntity copyWith({
    String? projectId,
    String? title,
    double? masterBpm,
    bool? snapToBeatgrid,
    List<TimelineTrackEntity>? tracks,
  }) {
    return TimelineProjectEntity(
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      masterBpm: masterBpm ?? this.masterBpm,
      snapToBeatgrid: snapToBeatgrid ?? this.snapToBeatgrid,
      tracks: tracks ?? this.tracks,
    );
  }

  /// Snaps [rawMs] to the nearest beat boundary when [snapToBeatgrid] is enabled.
  int quantizeMs(int rawMs) {
    final clamped = math.max(0, rawMs);
    if (!snapToBeatgrid) {
      return clamped;
    }
    final beatMs = beatDurationMs;
    final beatIndex = (clamped / beatMs).round();
    return (beatIndex * beatMs).round();
  }

  /// Resolves non-overlapping start time on [track] by shifting forward past any
  /// colliding clip while keeping beatgrid alignment if enabled.
  int resolveNonOverlappingStartMs(
    TimelineTrackEntity track,
    int desiredStartMs,
    int durationMs, {
    String? ignoreClipId,
  }) {
    int candidate = quantizeMs(desiredStartMs);
    final sorted = track.clips
        .where((c) => c.clipId != ignoreClipId)
        .toList(growable: false)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    for (final existing in sorted) {
      final overlaps = candidate < existing.endMs &&
          (candidate + durationMs) > existing.startMs;
      if (overlaps) {
        candidate = snapToBeatgrid
            ? _ceilSnapMs(existing.endMs)
            : existing.endMs;
      }
    }
    return candidate;
  }

  int _ceilSnapMs(int rawMs) {
    final beatMs = beatDurationMs;
    final beatIndex = (rawMs / beatMs).ceil();
    return (beatIndex * beatMs).round();
  }

  /// Drops [asset] onto [trackId] at [rawStartMs], returning an updated immutable project.
  TimelineProjectEntity placeAssetOnTrack({
    required MediaAssetEntity asset,
    required String trackId,
    required int rawStartMs,
    required String clipId,
  }) {
    final clipDuration = asset.durationMs > 0
        ? asset.durationMs
        : defaultNonAudioClipDurationMs;

    final updatedTracks = tracks.map((track) {
      if (track.trackId != trackId) {
        return track;
      }
      final resolvedStart = resolveNonOverlappingStartMs(
        track,
        rawStartMs,
        clipDuration,
      );
      final newClip = TimelineClipEntity(
        clipId: clipId,
        assetId: asset.id,
        label: asset.title,
        assetKind: asset.kind,
        startMs: resolvedStart,
        durationMs: clipDuration,
      );
      final nextClips = <TimelineClipEntity>[...track.clips, newClip]
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      return track.copyWith(clips: nextClips);
    }).toList(growable: false);

    return copyWith(tracks: updatedTracks);
  }

  /// Moves an existing clip [clipId] inside [trackId] to [rawStartMs].
  TimelineProjectEntity moveClip({
    required String trackId,
    required String clipId,
    required int rawStartMs,
  }) {
    final updatedTracks = tracks.map((track) {
      if (track.trackId != trackId) {
        return track;
      }
      final idx = track.clips.indexWhere((c) => c.clipId == clipId);
      if (idx == -1) {
        return track;
      }
      final targetClip = track.clips[idx];
      final resolvedStart = resolveNonOverlappingStartMs(
        track,
        rawStartMs,
        targetClip.durationMs,
        ignoreClipId: clipId,
      );
      final nextClips = track.clips
          .map(
            (c) => c.clipId == clipId ? c.copyWith(startMs: resolvedStart) : c,
          )
          .toList(growable: false)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      return track.copyWith(clips: nextClips);
    }).toList(growable: false);

    return copyWith(tracks: updatedTracks);
  }

  TimelineProjectEntity removeClip({
    required String trackId,
    required String clipId,
  }) {
    final updatedTracks = tracks.map((track) {
      if (track.trackId != trackId) {
        return track;
      }
      return track.copyWith(
        clips: track.clips
            .where((c) => c.clipId != clipId)
            .toList(growable: false),
      );
    }).toList(growable: false);

    return copyWith(tracks: updatedTracks);
  }

  TimelineProjectEntity toggleTrackMute(String trackId) {
    return copyWith(
      tracks: tracks
          .map(
            (t) => t.trackId == trackId ? t.copyWith(isMuted: !t.isMuted) : t,
          )
          .toList(growable: false),
    );
  }

  TimelineProjectEntity toggleTrackSolo(String trackId) {
    return copyWith(
      tracks: tracks
          .map(
            (t) => t.trackId == trackId ? t.copyWith(isSolo: !t.isSolo) : t,
          )
          .toList(growable: false),
    );
  }

  /// Determines whether [track] is audible given global mute/solo states.
  bool isTrackAudible(TimelineTrackEntity track) {
    if (track.isMuted) {
      return false;
    }
    final anySolo = tracks.any((t) => t.isSolo);
    if (anySolo) {
      return track.isSolo;
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'projectId': projectId,
      'title': title,
      'masterBpm': masterBpm,
      'snapToBeatgrid': snapToBeatgrid,
      'tracks': tracks.map((t) => t.toJson()).toList(growable: false),
    };
  }

  factory TimelineProjectEntity.fromJson(Map<String, dynamic> json) {
    return TimelineProjectEntity(
      projectId: json['projectId'] as String? ?? 'tunner_timeline_main',
      title: json['title'] as String? ?? 'Tunner Live Arrangement',
      masterBpm: (json['masterBpm'] as num?)?.toDouble() ?? 124.0,
      snapToBeatgrid: json['snapToBeatgrid'] as bool? ?? true,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map(
                (t) => TimelineTrackEntity.fromJson(t as Map<String, dynamic>),
              )
              .toList(growable: false) ??
          TimelineProjectEntity.defaultWorkspace().tracks,
    );
  }
}
