import 'dart:math' as math;

/// Muestra discreta de entonación capturada durante la práctica.
class TimedCentsSample {
  final double timeSec;
  final double cents;

  const TimedCentsSample({
    required this.timeSec,
    required this.cents,
  });

  Map<String, dynamic> toJson() => {
    'timeSec': timeSec,
    'cents': cents,
  };

  factory TimedCentsSample.fromJson(Map<String, dynamic> json) => TimedCentsSample(
    timeSec: (json['timeSec'] as num).toDouble(),
    cents: (json['cents'] as num).toDouble(),
  );
}

/// Métricas acústicas y pedagógicas consolidadas de una sesión de práctica.
class PedagogicalSessionData {
  final String sessionTitle;
  final DateTime sessionDate;
  final Duration duration;
  final int totalEvaluatedNotes;
  final int inTuneNotesCount;
  final double tuningAccuracyPercentage;
  final double averageCentsDeviation;
  final double centsStabilityDelta;
  final double spectralCentroidHz;
  final double thdPercentage;
  final List<double> harmonicRatios;
  final double rhythmMeanBpm;
  final double rhythmJitterMs;
  final List<TimedCentsSample> timedPitchSamples;
  final String masteryLevel;
  final String pedagogicalDiagnostic;
  final List<String> recommendations;

  const PedagogicalSessionData({
    required this.sessionTitle,
    required this.sessionDate,
    required this.duration,
    required this.totalEvaluatedNotes,
    required this.inTuneNotesCount,
    required this.tuningAccuracyPercentage,
    required this.averageCentsDeviation,
    required this.centsStabilityDelta,
    required this.spectralCentroidHz,
    required this.thdPercentage,
    required this.harmonicRatios,
    required this.rhythmMeanBpm,
    required this.rhythmJitterMs,
    required this.timedPitchSamples,
    required this.masteryLevel,
    required this.pedagogicalDiagnostic,
    required this.recommendations,
  });

  /// Genera una sesión de muestra sintética equilibrada para previsualización o pruebas.
  factory PedagogicalSessionData.sample({
    String title = 'Estudio de Escala Mayor y Afinación Interválica',
    double accuracy = 88.5,
    double avgCents = 1.8,
    double stabilityDelta = 4.2,
    double centroid = 840.0,
    double thd = 12.4,
    double bpm = 92.0,
    double jitter = 11.6,
  }) {
    final samples = <TimedCentsSample>[];
    for (int i = 0; i <= 60; i++) {
      final t = i * 0.5;
      final cents = avgCents + math.sin(i * 0.35) * (stabilityDelta * 0.7);
      samples.add(TimedCentsSample(timeSec: t, cents: cents));
    }

    String level;
    if (accuracy >= 90.0 && jitter <= 12.0) {
      level = 'Virtuoso / Conservatorio';
    } else if (accuracy >= 80.0) {
      level = 'Avanzado';
    } else if (accuracy >= 65.0) {
      level = 'Intermedio';
    } else {
      level = 'Iniciación';
    }

    return PedagogicalSessionData(
      sessionTitle: title,
      sessionDate: DateTime.now(),
      duration: const Duration(minutes: 15, seconds: 42),
      totalEvaluatedNotes: 140,
      inTuneNotesCount: (140 * (accuracy / 100.0)).round(),
      tuningAccuracyPercentage: accuracy,
      averageCentsDeviation: avgCents,
      centsStabilityDelta: stabilityDelta,
      spectralCentroidHz: centroid,
      thdPercentage: thd,
      harmonicRatios: const [1.0, 0.65, 0.38, 0.22, 0.15, 0.08, 0.04, 0.02],
      rhythmMeanBpm: bpm,
      rhythmJitterMs: jitter,
      timedPitchSamples: samples,
      masteryLevel: level,
      pedagogicalDiagnostic:
          'Se observa una entonación centrada y con excelente contención en el centroide espectral. '
          'La dispersión temporal refleja un pulso motor consistente con variabilidad por debajo de 15 ms.',
      recommendations: const [
        'Mantener apoyo diafragmático constante en los registros agudos para evitar desvíos positivos en crescendo.',
        'Extender la práctica de notas tenidas con el Dron Armónico para solidificar las terceras y quintas justas.',
        'Realizar rutinas de metrónomo con subdivisiones en tresillos para afianzar la precisión rítmica.',
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionTitle': sessionTitle,
    'sessionDate': sessionDate.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'totalEvaluatedNotes': totalEvaluatedNotes,
    'inTuneNotesCount': inTuneNotesCount,
    'tuningAccuracyPercentage': tuningAccuracyPercentage,
    'averageCentsDeviation': averageCentsDeviation,
    'centsStabilityDelta': centsStabilityDelta,
    'spectralCentroidHz': spectralCentroidHz,
    'thdPercentage': thdPercentage,
    'harmonicRatios': harmonicRatios,
    'rhythmMeanBpm': rhythmMeanBpm,
    'rhythmJitterMs': rhythmJitterMs,
    'timedPitchSamples': timedPitchSamples.map((s) => s.toJson()).toList(),
    'masteryLevel': masteryLevel,
    'pedagogicalDiagnostic': pedagogicalDiagnostic,
    'recommendations': recommendations,
  };

  factory PedagogicalSessionData.fromJson(Map<String, dynamic> json) =>
      PedagogicalSessionData(
        sessionTitle: json['sessionTitle'] as String? ?? 'Sesión de Práctica',
        sessionDate: DateTime.tryParse(json['sessionDate'] as String? ?? '') ??
            DateTime.now(),
        duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
        totalEvaluatedNotes: json['totalEvaluatedNotes'] as int? ?? 0,
        inTuneNotesCount: json['inTuneNotesCount'] as int? ?? 0,
        tuningAccuracyPercentage:
            (json['tuningAccuracyPercentage'] as num?)?.toDouble() ?? 0.0,
        averageCentsDeviation:
            (json['averageCentsDeviation'] as num?)?.toDouble() ?? 0.0,
        centsStabilityDelta:
            (json['centsStabilityDelta'] as num?)?.toDouble() ?? 0.0,
        spectralCentroidHz:
            (json['spectralCentroidHz'] as num?)?.toDouble() ?? 0.0,
        thdPercentage: (json['thdPercentage'] as num?)?.toDouble() ?? 0.0,
        harmonicRatios: (json['harmonicRatios'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            const [1.0, 0.5, 0.3],
        rhythmMeanBpm: (json['rhythmMeanBpm'] as num?)?.toDouble() ?? 120.0,
        rhythmJitterMs: (json['rhythmJitterMs'] as num?)?.toDouble() ?? 0.0,
        timedPitchSamples: (json['timedPitchSamples'] as List<dynamic>?)
                ?.map((e) =>
                    TimedCentsSample.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        masteryLevel: json['masteryLevel'] as String? ?? 'Intermedio',
        pedagogicalDiagnostic: json['pedagogicalDiagnostic'] as String? ?? '',
        recommendations: (json['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

/// Parámetros de configuración para la emisión del reporte y certificado PDF.
class PedagogicalReportConfig {
  final String studentName;
  final String instrument;
  final String institution;
  final String teacherName;
  final bool includeIntonationGraph;
  final bool includeHarmonicsRadar;
  final bool includeRhythmJitter;
  final bool includeCertificate;

  const PedagogicalReportConfig({
    this.studentName = 'Estudiante Conservatorio',
    this.instrument = 'Flauta Traversa / Voz',
    this.institution = 'Tunner Acoustic Academy',
    this.teacherName = 'Cátedra de Instrumento y Acústica',
    this.includeIntonationGraph = true,
    this.includeHarmonicsRadar = true,
    this.includeRhythmJitter = true,
    this.includeCertificate = true,
  });

  PedagogicalReportConfig copyWith({
    String? studentName,
    String? instrument,
    String? institution,
    String? teacherName,
    bool? includeIntonationGraph,
    bool? includeHarmonicsRadar,
    bool? includeRhythmJitter,
    bool? includeCertificate,
  }) {
    return PedagogicalReportConfig(
      studentName: studentName ?? this.studentName,
      instrument: instrument ?? this.instrument,
      institution: institution ?? this.institution,
      teacherName: teacherName ?? this.teacherName,
      includeIntonationGraph:
          includeIntonationGraph ?? this.includeIntonationGraph,
      includeHarmonicsRadar:
          includeHarmonicsRadar ?? this.includeHarmonicsRadar,
      includeRhythmJitter: includeRhythmJitter ?? this.includeRhythmJitter,
      includeCertificate: includeCertificate ?? this.includeCertificate,
    );
  }

  Map<String, dynamic> toJson() => {
    'studentName': studentName,
    'instrument': instrument,
    'institution': institution,
    'teacherName': teacherName,
    'includeIntonationGraph': includeIntonationGraph,
    'includeHarmonicsRadar': includeHarmonicsRadar,
    'includeRhythmJitter': includeRhythmJitter,
    'includeCertificate': includeCertificate,
  };

  factory PedagogicalReportConfig.fromJson(Map<String, dynamic> json) =>
      PedagogicalReportConfig(
        studentName: json['studentName'] as String? ?? 'Estudiante Conservatorio',
        instrument: json['instrument'] as String? ?? 'Flauta Traversa / Voz',
        institution:
            json['institution'] as String? ?? 'Tunner Acoustic Academy',
        teacherName:
            json['teacherName'] as String? ?? 'Cátedra de Instrumento y Acústica',
        includeIntonationGraph:
            json['includeIntonationGraph'] as bool? ?? true,
        includeHarmonicsRadar: json['includeHarmonicsRadar'] as bool? ?? true,
        includeRhythmJitter: json['includeRhythmJitter'] as bool? ?? true,
        includeCertificate: json['includeCertificate'] as bool? ?? true,
      );
}
