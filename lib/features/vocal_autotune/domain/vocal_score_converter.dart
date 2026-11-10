import 'dart:math' as math;
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../tuner/domain/note_entity.dart';
import '../../practice_recorder/domain/multitrack_session_entity.dart';
import 'autotune_config_entity.dart';

/// Metadata resumen de la conversión de una toma vocal a partitura editable.
class VocalScoreConversionResult {
  final SongPackage package;
  final int totalNotes;
  final double averageCentsError;
  final int autoTunedNotesCount;

  const VocalScoreConversionResult({
    required this.package,
    required this.totalNotes,
    required this.averageCentsError,
    required this.autoTunedNotesCount,
  });
}

/// Segmento interno intermedio de nota vocal continua antes de cuantización rítmica.
class _VocalSegment {
  final List<TimedPitchSample> samples;

  _VocalSegment(this.samples);

  int get startMs => samples.first.timeMs;
  int get endMs => samples.last.timeMs;
  int get durationMs => math.max(20, endMs - startMs);

  double averageFrequency({bool useCorrected = false}) {
    if (samples.isEmpty) return 0.0;
    double sum = 0.0;
    int count = 0;
    for (final s in samples) {
      final f = (useCorrected && s.correctedPitchHz != null && s.correctedPitchHz! > 20.0)
          ? s.correctedPitchHz!
          : s.frequencyHz;
      if (f > 20.0) {
        sum += f;
        count++;
      }
    }
    return count > 0 ? sum / count : 0.0;
  }

  double averageCents() {
    if (samples.isEmpty) return 0.0;
    double sum = 0.0;
    for (final s in samples) {
      sum += s.centsDeviation;
    }
    return sum / samples.length;
  }

  bool get hasAutoTuneData => samples.any((s) => s.isAutoTuned && s.correctedPitchHz != null);
}

/// Motor de conversión de tomas vocales a partituras y edición de tono tipo Melodyne.
class VocalScoreConverter {
  const VocalScoreConverter();

  /// Convierte una pista de muestras [TimedPitchSample] de una toma grabada a un [SongPackage].
  VocalScoreConversionResult convertTrackToScore({
    required List<TimedPitchSample> pitchTrack,
    String title = 'Toma Vocal Afinada',
    int bpm = 120,
    TimeSignature timeSignature = TimeSignature.commonTime44,
    bool preferCorrectedPitch = false,
  }) {
    final validBpm = (bpm > 30 && bpm < 320) ? bpm : 120;
    final msPerBeat = 60000.0 / validBpm;
    // En resolución de semicorcheas (16 sub-ticks por compás 4/4): 4 sub-ticks por pulso de negra
    final msPerTick = msPerBeat / 4.0;
    final ticksPerMeasure = timeSignature.totalTicks;

    if (pitchTrack.isEmpty) {
      final emptyScore = HierarchicalScore(
        title: title,
        baseBpm: validBpm,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: timeSignature,
            notes: [
              HierarchicalNote.rest(startTick: 0, durationTicks: ticksPerMeasure),
            ],
          ),
        ],
      );
      final emptyPkg = SongPackage(
        id: 'vocal_take_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        composer: 'Vocal Suite Melodyne Mode',
        genre: MusicGenre.contemporary,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: validBpm,
        score: emptyScore,
        tracks: const [],
      );
      return VocalScoreConversionResult(
        package: emptyPkg,
        totalNotes: 0,
        averageCentsError: 0.0,
        autoTunedNotesCount: 0,
      );
    }

    // 1. Segmentación de muestras en bloques continuos de notas vocales
    final segments = _segmentPitchTrack(pitchTrack);

    if (segments.isEmpty) {
      final emptyScore = HierarchicalScore(
        title: title,
        baseBpm: validBpm,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: timeSignature,
            notes: [
              HierarchicalNote.rest(startTick: 0, durationTicks: ticksPerMeasure),
            ],
          ),
        ],
      );
      final emptyPkg = SongPackage(
        id: 'vocal_take_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        composer: 'Vocal Suite Melodyne Mode',
        genre: MusicGenre.contemporary,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: validBpm,
        score: emptyScore,
        tracks: const [],
      );
      return VocalScoreConversionResult(
        package: emptyPkg,
        totalNotes: 0,
        averageCentsError: 0.0,
        autoTunedNotesCount: 0,
      );
    }

    // 2. Mapeo a compases jerárquicos
    final measures = <MeasureEntity>[];
    var currentMeasureIndex = 0;
    var currentTickInMeasure = 0;
    var measureNotes = <HierarchicalNote>[];

    int totalNotesCount = 0;
    double totalCentsSum = 0.0;
    int autoTunedNotes = 0;

    for (final seg in segments) {
      final freq = seg.averageFrequency(useCorrected: preferCorrectedPitch);
      if (freq <= 20.0) continue;

      final noteEntity = NoteEntity.fromFrequency(freq);
      if (noteEntity.name == '--') continue;

      // Duración cuantizada a sub-ticks
      final rawTicks = (seg.durationMs / msPerTick).round();
      final noteTicks = math.max(1, math.min(16, rawTicks));

      // Verificar si cabe en el compás actual
      if (currentTickInMeasure + noteTicks > ticksPerMeasure) {
        // Completar compás con silencio si quedan ticks
        final remaining = ticksPerMeasure - currentTickInMeasure;
        if (remaining > 0) {
          measureNotes.add(HierarchicalNote.rest(startTick: currentTickInMeasure, durationTicks: remaining));
        }
        measures.add(MeasureEntity(
          index: currentMeasureIndex,
          timeSignature: timeSignature,
          notes: List.unmodifiable(measureNotes),
        ));
        currentMeasureIndex++;
        currentTickInMeasure = 0;
        measureNotes = [];
      }

      measureNotes.add(
        HierarchicalNote.note(
          startTick: currentTickInMeasure,
          durationTicks: noteTicks,
          noteName: noteEntity.name,
        ),
      );

      currentTickInMeasure += noteTicks;
      totalNotesCount++;
      totalCentsSum += seg.averageCents().abs();
      if (seg.hasAutoTuneData) {
        autoTunedNotes++;
      }
    }

    // Finalizar último compás
    if (measureNotes.isNotEmpty) {
      final remaining = ticksPerMeasure - currentTickInMeasure;
      if (remaining > 0) {
        measureNotes.add(HierarchicalNote.rest(startTick: currentTickInMeasure, durationTicks: remaining));
      }
      measures.add(MeasureEntity(
        index: currentMeasureIndex,
        timeSignature: timeSignature,
        notes: List.unmodifiable(measureNotes),
      ));
    }

    if (measures.isEmpty) {
      measures.add(MeasureEntity(
        index: 0,
        timeSignature: timeSignature,
        notes: [HierarchicalNote.rest(startTick: 0, durationTicks: ticksPerMeasure)],
      ));
    }

    final score = HierarchicalScore(
      title: title,
      baseBpm: validBpm,
      measures: List.unmodifiable(measures),
    );

    final package = SongPackage(
      id: 'vocal_take_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      composer: 'Vocal Suite Melodyne Mode',
      genre: MusicGenre.contemporary,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: validBpm,
      score: score,
      tracks: const [],
    );

    return VocalScoreConversionResult(
      package: package,
      totalNotes: totalNotesCount,
      averageCentsError: totalNotesCount > 0 ? (totalCentsSum / totalNotesCount) : 0.0,
      autoTunedNotesCount: autoTunedNotes,
    );
  }

  /// Cuantiza todas las notas de un [SongPackage] a los grados exactos de la escala modal configurada (Melodyne 1-Tap Snap).
  SongPackage snapToScale({
    required SongPackage package,
    required int rootKey, // 0 = Do, 1 = Do#, ..., 11 = Si
    required VocalScaleType scaleType,
  }) {
    final scaleIntervals = scaleType.intervals;
    final inScalePitches = scaleIntervals.map((i) => (rootKey + i) % 12).toSet();

    final notes = const ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"];

    final updatedMeasures = <MeasureEntity>[];

    for (final measure in package.score.measures) {
      final updatedNotes = <HierarchicalNote>[];
      for (final note in measure.notes) {
        if (note.isRest || note.noteName.isEmpty || note.noteName == '--') {
          updatedNotes.add(note);
          continue;
        }

        final freq = NoteEntity.frequencyForNote(note.noteName);
        if (freq <= 0.0) {
          updatedNotes.add(note);
          continue;
        }

        final entity = NoteEntity.fromFrequency(freq);
        final currentPitchClass = entity.midiNumber % 12;

        if (inScalePitches.contains(currentPitchClass)) {
          updatedNotes.add(note);
          continue;
        }

        // Encontrar el grado de la escala más cercano
        int closestDistance = 999;
        int targetPitchClass = currentPitchClass;

        for (final validClass in inScalePitches) {
          // Distancia circular en el círculo de semitonos
          int diff = (validClass - currentPitchClass).abs();
          if (diff > 6) diff = 12 - diff;
          if (diff < closestDistance) {
            closestDistance = diff;
            targetPitchClass = validClass;
          }
        }

        // Calcular nuevo número MIDI preservando la octava
        final semitoneDelta = (targetPitchClass - currentPitchClass);
        final normalizedDelta = semitoneDelta > 6 ? semitoneDelta - 12 : (semitoneDelta < -6 ? semitoneDelta + 12 : semitoneDelta);
        final newMidi = entity.midiNumber + normalizedDelta;

        final newNoteName = notes[newMidi % 12];
        final newOctave = (newMidi / 12).floor() - 1;
        final newFullNoteName = '$newNoteName$newOctave';

        updatedNotes.add(
          HierarchicalNote.note(
            startTick: note.startTick,
            durationTicks: note.durationTicks,
            noteName: newFullNoteName,
          ),
        );
      }

      updatedMeasures.add(
        MeasureEntity(
          index: measure.index,
          timeSignature: measure.timeSignature,
          notes: List.unmodifiable(updatedNotes),
        ),
      );
    }

    final newScore = HierarchicalScore(
      title: package.score.title,
      baseBpm: package.score.baseBpm,
      measures: List.unmodifiable(updatedMeasures),
    );

    return package.copyWith(score: newScore);
  }

  /// Segmenta muestras continuas en notas separadas por saltos de semitono o silencios.
  List<_VocalSegment> _segmentPitchTrack(List<TimedPitchSample> samples) {
    final segments = <_VocalSegment>[];
    var currentGroup = <TimedPitchSample>[];

    double? lastFreq;
    int? lastTimeMs;

    for (final sample in samples) {
      if (sample.isSilent || sample.frequencyHz <= 20.0) {
        if (currentGroup.isNotEmpty) {
          final duration = math.max(currentGroup.length * 20, currentGroup.last.timeMs - currentGroup.first.timeMs);
          if (duration >= 50) {
            segments.add(_VocalSegment(List.unmodifiable(currentGroup)));
          }
          currentGroup = [];
          lastFreq = null;
        }
        continue;
      }

      final f = sample.frequencyHz;
      final t = sample.timeMs;

      if (lastFreq == null) {
        currentGroup.add(sample);
        lastFreq = f;
        lastTimeMs = t;
      } else {
        // Calcular salto de semitonos entre muestras
        final semitonesDiff = (12.0 * math.log(f / lastFreq).abs() / math.log(2.0));
        final timeGapMs = lastTimeMs != null ? (t - lastTimeMs) : 0;

        // Salto de tono significativo (> 0.8 semitonos) o corte de tiempo (> 120ms) marca un nuevo onset
        if (semitonesDiff >= 0.8 || timeGapMs > 120) {
          final duration = math.max(currentGroup.length * 20, currentGroup.last.timeMs - currentGroup.first.timeMs);
          if (duration >= 50) {
            segments.add(_VocalSegment(List.unmodifiable(currentGroup)));
          }
          currentGroup = [sample];
        } else {
          currentGroup.add(sample);
        }
        lastFreq = f;
        lastTimeMs = t;
      }
    }

    if (currentGroup.isNotEmpty) {
      final duration = math.max(currentGroup.length * 20, currentGroup.last.timeMs - currentGroup.first.timeMs);
      if (duration >= 50) {
        segments.add(_VocalSegment(List.unmodifiable(currentGroup)));
      }
    }

    return segments;
  }
}
