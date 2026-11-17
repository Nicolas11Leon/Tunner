import 'dart:typed_data';

/// Categories of musical and session assets stored in the Multimedia Vault.
enum MediaAssetKind {
  audioTrack,
  stem,
  sheetMusic,
  midiSequence,
  practiceRecording,
  djSessionPreset,
}

extension MediaAssetKindMetadata on MediaAssetKind {
  String get displayName {
    switch (this) {
      case MediaAssetKind.audioTrack:
        return 'Audio Track';
      case MediaAssetKind.stem:
        return 'Stem';
      case MediaAssetKind.sheetMusic:
        return 'Partitura';
      case MediaAssetKind.midiSequence:
        return 'MIDI';
      case MediaAssetKind.practiceRecording:
        return 'Grabacion';
      case MediaAssetKind.djSessionPreset:
        return 'Preset DJ';
    }
  }
}

/// Immutable domain entity representing any musical asset indexed in the
/// Multimedia Vault for timeline arrangement, cross-tool sync, and export.
class MediaAssetEntity {
  final String id;
  final String title;
  final String fileName;
  final String extensionName;
  final MediaAssetKind kind;
  final int durationMs;
  final double bpm;
  final String camelotKey;
  final int sampleRate;
  final List<String> tags;
  final DateTime createdAt;

  /// Optional mono/interleaved normalized PCM samples for instant waveform
  /// preview, timeline mixdown, or direct deck loading.
  final Float64List? pcmSamples;

  /// Optional raw source bytes (e.g. MusicXML, ABC, MIDI, PDF, JSON).
  final Uint8List? rawBytes;

  /// Optional downsampled waveform peaks in [0.0, 1.0] for fast canvas rendering.
  final List<double> waveformPeaks;

  const MediaAssetEntity({
    required this.id,
    required this.title,
    required this.fileName,
    required this.extensionName,
    required this.kind,
    required this.durationMs,
    this.bpm = 120.0,
    this.camelotKey = '8A',
    this.sampleRate = 44100,
    this.tags = const <String>[],
    required this.createdAt,
    this.pcmSamples,
    this.rawBytes,
    this.waveformPeaks = const <double>[],
  });

  MediaAssetEntity copyWith({
    String? id,
    String? title,
    String? fileName,
    String? extensionName,
    MediaAssetKind? kind,
    int? durationMs,
    double? bpm,
    String? camelotKey,
    int? sampleRate,
    List<String>? tags,
    DateTime? createdAt,
    Float64List? pcmSamples,
    Uint8List? rawBytes,
    List<double>? waveformPeaks,
  }) {
    return MediaAssetEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      extensionName: extensionName ?? this.extensionName,
      kind: kind ?? this.kind,
      durationMs: durationMs ?? this.durationMs,
      bpm: bpm ?? this.bpm,
      camelotKey: camelotKey ?? this.camelotKey,
      sampleRate: sampleRate ?? this.sampleRate,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      pcmSamples: pcmSamples ?? this.pcmSamples,
      rawBytes: rawBytes ?? this.rawBytes,
      waveformPeaks: waveformPeaks ?? this.waveformPeaks,
    );
  }

  /// Checks whether this asset matches a free-text query and optional kind filter.
  bool matchesFilter({
    String query = '',
    MediaAssetKind? kindFilter,
  }) {
    if (kindFilter != null && kind != kindFilter) {
      return false;
    }
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(normalized) ||
        fileName.toLowerCase().contains(normalized) ||
        camelotKey.toLowerCase().contains(normalized) ||
        tags.any((tag) => tag.toLowerCase().contains(normalized));
  }

  Map<String, dynamic> toMetadataJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'fileName': fileName,
      'extensionName': extensionName,
      'kind': kind.name,
      'durationMs': durationMs,
      'bpm': bpm,
      'camelotKey': camelotKey,
      'sampleRate': sampleRate,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'waveformPeaks': waveformPeaks,
    };
  }

  factory MediaAssetEntity.fromMetadataJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? MediaAssetKind.audioTrack.name;
    final parsedKind = MediaAssetKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => MediaAssetKind.audioTrack,
    );

    return MediaAssetEntity(
      id: json['id'] as String? ?? 'asset_unknown',
      title: json['title'] as String? ?? 'Untitled Asset',
      fileName: json['fileName'] as String? ?? 'untitled.wav',
      extensionName: json['extensionName'] as String? ?? 'wav',
      kind: parsedKind,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      bpm: (json['bpm'] as num?)?.toDouble() ?? 120.0,
      camelotKey: json['camelotKey'] as String? ?? '8A',
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 44100,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      waveformPeaks: (json['waveformPeaks'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList(growable: false) ??
          const <double>[],
    );
  }
}
