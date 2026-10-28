import 'dart:convert';

/// Muestra puntual de entonación y frecuencia en una marca de tiempo específica.
class TimedPitchSample {
  final int timeMs;
  final double frequencyHz;
  final double centsDeviation;
  final String targetNoteName;
  final bool isSilent;

  const TimedPitchSample({
    required this.timeMs,
    required this.frequencyHz,
    required this.centsDeviation,
    required this.targetNoteName,
    this.isSilent = false,
  });

  Map<String, dynamic> toMap() => {
    'timeMs': timeMs,
    'frequencyHz': frequencyHz,
    'centsDeviation': centsDeviation,
    'targetNoteName': targetNoteName,
    'isSilent': isSilent,
  };

  factory TimedPitchSample.fromMap(Map<String, dynamic> map) => TimedPitchSample(
    timeMs: map['timeMs'] as int? ?? 0,
    frequencyHz: (map['frequencyHz'] as num?)?.toDouble() ?? 0.0,
    centsDeviation: (map['centsDeviation'] as num?)?.toDouble() ?? 0.0,
    targetNoteName: map['targetNoteName'] as String? ?? '--',
    isSilent: map['isSilent'] as bool? ?? false,
  );
}

/// Muestra puntual de propiedades acústicas y brillo tímbrico en una marca de tiempo.
class TimedSpectralSample {
  final int timeMs;
  final double spectralCentroidHz;
  final double thdPercent;
  final double rmsEnergy;

  const TimedSpectralSample({
    required this.timeMs,
    required this.spectralCentroidHz,
    required this.thdPercent,
    required this.rmsEnergy,
  });

  Map<String, dynamic> toMap() => {
    'timeMs': timeMs,
    'spectralCentroidHz': spectralCentroidHz,
    'thdPercent': thdPercent,
    'rmsEnergy': rmsEnergy,
  };

  factory TimedSpectralSample.fromMap(Map<String, dynamic> map) => TimedSpectralSample(
    timeMs: map['timeMs'] as int? ?? 0,
    spectralCentroidHz: (map['spectralCentroidHz'] as num?)?.toDouble() ?? 0.0,
    thdPercent: (map['thdPercent'] as num?)?.toDouble() ?? 0.0,
    rmsEnergy: (map['rmsEnergy'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Representa una toma individual registrada en una sesión de práctica instrumental.
class PracticeTakeEntity {
  final String id;
  final String name;
  final DateTime timestamp;
  final Duration duration;
  final String filePath;
  final List<double> waveformPeaks;
  final List<TimedPitchSample> pitchTrack;
  final List<TimedSpectralSample> spectralTrack;
  final double gain;
  final bool isMuted;
  final bool isSolo;

  const PracticeTakeEntity({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.duration,
    required this.filePath,
    this.waveformPeaks = const [],
    this.pitchTrack = const [],
    this.spectralTrack = const [],
    this.gain = 1.0,
    this.isMuted = false,
    this.isSolo = false,
  });

  /// Promedio absoluto de error en cents a lo largo de las notas no silenciosas.
  double get averagePitchDeviationCents {
    final activeSamples = pitchTrack.where((s) => !s.isSilent && s.frequencyHz > 20);
    if (activeSamples.isEmpty) return 0.0;
    final totalDev = activeSamples.fold(0.0, (acc, s) => acc + s.centsDeviation.abs());
    return totalDev / activeSamples.length;
  }

  /// Centroide espectral promedio en Hz.
  double get averageSpectralCentroidHz {
    final activeSamples = spectralTrack.where((s) => s.rmsEnergy > 0.01);
    if (activeSamples.isEmpty) return 0.0;
    final totalCentroid = activeSamples.fold(0.0, (acc, s) => acc + s.spectralCentroidHz);
    return totalCentroid / activeSamples.length;
  }

  PracticeTakeEntity copyWith({
    String? id,
    String? name,
    DateTime? timestamp,
    Duration? duration,
    String? filePath,
    List<double>? waveformPeaks,
    List<TimedPitchSample>? pitchTrack,
    List<TimedSpectralSample>? spectralTrack,
    double? gain,
    bool? isMuted,
    bool? isSolo,
  }) {
    return PracticeTakeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      waveformPeaks: waveformPeaks ?? this.waveformPeaks,
      pitchTrack: pitchTrack ?? this.pitchTrack,
      spectralTrack: spectralTrack ?? this.spectralTrack,
      gain: gain ?? this.gain,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'timestamp': timestamp.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'filePath': filePath,
    'waveformPeaks': waveformPeaks,
    'pitchTrack': pitchTrack.map((p) => p.toMap()).toList(),
    'spectralTrack': spectralTrack.map((s) => s.toMap()).toList(),
    'gain': gain,
    'isMuted': isMuted,
    'isSolo': isSolo,
  };

  factory PracticeTakeEntity.fromMap(Map<String, dynamic> map) => PracticeTakeEntity(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? 'Toma',
    timestamp: map['timestamp'] != null
        ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
    duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
    filePath: map['filePath'] as String? ?? '',
    waveformPeaks: (map['waveformPeaks'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    pitchTrack: (map['pitchTrack'] as List<dynamic>?)
            ?.map((e) => TimedPitchSample.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [],
    spectralTrack: (map['spectralTrack'] as List<dynamic>?)
            ?.map((e) => TimedSpectralSample.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [],
    gain: (map['gain'] as num?)?.toDouble() ?? 1.0,
    isMuted: map['isMuted'] as bool? ?? false,
    isSolo: map['isSolo'] as bool? ?? false,
  );
}

/// Sesión Multi-Pista que agrupa todas las tomas registradas en un ensayo.
class MultiTrackSessionEntity {
  final String id;
  final String title;
  final DateTime createdAt;
  final int bpm;
  final List<PracticeTakeEntity> takes;
  final String? selectedTakeAId;
  final String? selectedTakeBId;

  const MultiTrackSessionEntity({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.bpm,
    this.takes = const [],
    this.selectedTakeAId,
    this.selectedTakeBId,
  });

  PracticeTakeEntity? get takeA {
    if (selectedTakeAId == null) {
      return takes.length >= 2 ? takes[takes.length - 2] : (takes.isNotEmpty ? takes.first : null);
    }
    try {
      return takes.firstWhere((t) => t.id == selectedTakeAId);
    } catch (_) {
      return takes.isNotEmpty ? takes.first : null;
    }
  }

  PracticeTakeEntity? get takeB {
    if (selectedTakeBId == null) {
      return takes.isNotEmpty ? takes.last : null;
    }
    try {
      return takes.firstWhere((t) => t.id == selectedTakeBId);
    } catch (_) {
      return takes.length >= 2 ? takes.last : null;
    }
  }

  MultiTrackSessionEntity copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    int? bpm,
    List<PracticeTakeEntity>? takes,
    String? selectedTakeAId,
    String? selectedTakeBId,
  }) {
    return MultiTrackSessionEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      bpm: bpm ?? this.bpm,
      takes: takes ?? this.takes,
      selectedTakeAId: selectedTakeAId ?? this.selectedTakeAId,
      selectedTakeBId: selectedTakeBId ?? this.selectedTakeBId,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'bpm': bpm,
    'takes': takes.map((t) => t.toMap()).toList(),
    'selectedTakeAId': selectedTakeAId,
    'selectedTakeBId': selectedTakeBId,
  };

  factory MultiTrackSessionEntity.fromMap(Map<String, dynamic> map) => MultiTrackSessionEntity(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? 'Sesión de Práctica',
    createdAt: map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    bpm: map['bpm'] as int? ?? 120,
    takes: (map['takes'] as List<dynamic>?)
            ?.map((e) => PracticeTakeEntity.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [],
    selectedTakeAId: map['selectedTakeAId'] as String?,
    selectedTakeBId: map['selectedTakeBId'] as String?,
  );

  String toJson() => jsonEncode(toMap());

  factory MultiTrackSessionEntity.fromJson(String source) =>
      MultiTrackSessionEntity.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
