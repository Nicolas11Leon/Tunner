import 'dart:convert';

/// Entidad inmutable del dominio que representa una toma de audio grabada durante una sesión de práctica.
/// Totalmente pura: sin dependencias de Flutter UI ni plugins externos.
class PracticeRecordingEntity {
  final String id;
  final String filePath;
  final DateTime recordedAt;
  final Duration duration;
  final String songTitle;
  final int bpm;
  final List<double> waveformPeaks;

  const PracticeRecordingEntity({
    required this.id,
    required this.filePath,
    required this.recordedAt,
    required this.duration,
    required this.songTitle,
    required this.bpm,
    this.waveformPeaks = const [],
  });

  /// Duración formateada en minutos y segundos (ej. "01:15").
  String get formattedDuration {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  /// Fecha y hora formateada de manera compacta y legible.
  String get formattedDateTime {
    final year = recordedAt.year;
    final month = recordedAt.month.toString().padLeft(2, '0');
    final day = recordedAt.day.toString().padLeft(2, '0');
    final hour = recordedAt.hour.toString().padLeft(2, '0');
    final minute = recordedAt.minute.toString().padLeft(2, '0');
    return "$year-$month-$day $hour:$minute";
  }

  PracticeRecordingEntity copyWith({
    String? id,
    String? filePath,
    DateTime? recordedAt,
    Duration? duration,
    String? songTitle,
    int? bpm,
    List<double>? waveformPeaks,
  }) {
    return PracticeRecordingEntity(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      recordedAt: recordedAt ?? this.recordedAt,
      duration: duration ?? this.duration,
      songTitle: songTitle ?? this.songTitle,
      bpm: bpm ?? this.bpm,
      waveformPeaks: waveformPeaks ?? this.waveformPeaks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'recordedAt': recordedAt.toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'songTitle': songTitle,
      'bpm': bpm,
      'waveformPeaks': waveformPeaks,
    };
  }

  factory PracticeRecordingEntity.fromMap(Map<String, dynamic> map) {
    return PracticeRecordingEntity(
      id: map['id'] as String? ?? '',
      filePath: map['filePath'] as String? ?? '',
      recordedAt: map['recordedAt'] != null
          ? DateTime.tryParse(map['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
      songTitle: map['songTitle'] as String? ?? 'Práctica Libre',
      bpm: map['bpm'] as int? ?? 100,
      waveformPeaks: (map['waveformPeaks'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PracticeRecordingEntity.fromJson(String source) =>
      PracticeRecordingEntity.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
