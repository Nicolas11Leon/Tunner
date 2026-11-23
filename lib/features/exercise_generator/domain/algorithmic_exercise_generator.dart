import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../universal_importer/domain/canonical_pitch_notation_codec.dart';
import 'i_exercise_generator.dart';

/// Tipo de estudio técnico o patrón interválico a generar.
enum ExerciseType {
  majorScale("Escala Mayor"),
  naturalMinorScale("Escala Menor Natural"),
  harmonicMinorScale("Escala Menor Armónica"),
  melodicMinorScale("Escala Menor Melódica"),
  pentatonicScale("Escala Pentatónica"),
  majorArpeggio("Arpegio Mayor"),
  minorArpeggio("Arpegio Menor"),
  thirdsIntervals("Intervalos de Terceras"),
  longTones("Notas Largas (Afinación)");

  final String displayName;
  const ExerciseType(this.displayName);
}

/// Figura rítmica base para el ejercicio.
enum ExerciseRhythm {
  quarter("Negras (1 pulso)", 4),
  eighth("Corcheas (1/2 pulso)", 2),
  sixteenth("Semicorcheas (1/4 pulso)", 1),
  half("Blancas (2 pulsos)", 8),
  whole("Redondas (4 pulsos)", 16);

  final String displayName;
  final int ticks;
  const ExerciseRhythm(this.displayName, this.ticks);
}

/// Generador procedural determinista de material de estudio y escalas de conservatorio.
/// Pure Dart: Cero dependencias de Flutter UI.
class AlgorithmicExerciseGenerator implements IExerciseGenerator {
  const AlgorithmicExerciseGenerator();

  /// Genera un paquete de estudio pedagógico [SongPackage] en función de la tónica, tipo y rítmica.
  @override
  SongPackage generate({
    required String rootNote, // e.g., "Do4", "Re4", "Mi4", "Fa4", "Sol4", "La4", "Si4"
    required ExerciseType type,
    ExerciseRhythm rhythm = ExerciseRhythm.quarter,
    int bpm = 80,
  }) {
    final semitonesPattern = _getSemitonePattern(type);
    final effectiveRhythm = type == ExerciseType.longTones ? ExerciseRhythm.whole : rhythm;
    final durationTicks = effectiveRhythm.ticks;

    final parsedRoot = CanonicalPitchNotationCodec.parseOrDefault(
      rootNote,
      fallbackStep: 'C',
      fallbackOctave: 4,
    );
    final preferFlats = _shouldPreferFlats(parsedRoot, type);

    // Generar nombres de notas a partir del patron intervalico con ortografia enarmonica coherente
    final generatedNoteNames = <String>[];
    for (final delta in semitonesPattern) {
      final midi = (parsedRoot.midiNumber + delta).clamp(0, 127);
      generatedNoteNames.add(
        CanonicalPitchNotationCodec.midiToSolfege(midi, preferFlats: preferFlats),
      );
    }

    // Empaquetar en compases de 4/4 (16 ticks)
    final measures = <MeasureEntity>[];
    var currentMeasureNotes = <HierarchicalNote>[];
    int currentTick = 0;
    int measureIndex = 0;

    for (final noteName in generatedNoteNames) {
      currentMeasureNotes.add(HierarchicalNote(
        startTick: currentTick,
        durationTicks: durationTicks,
        noteName: noteName,
      ));

      currentTick += durationTicks;
      if (currentTick >= 16) {
        measures.add(MeasureEntity(
          index: measureIndex,
          timeSignature: TimeSignature.commonTime44,
          notes: List.unmodifiable(currentMeasureNotes),
        ));
        measureIndex++;
        currentMeasureNotes = <HierarchicalNote>[];
        currentTick = 0;
      }
    }

    // Si el último compás quedó incompleto, rellenar con silencio para mantener la métrica canónica
    if (currentTick > 0 && currentTick < 16) {
      final remainingTicks = 16 - currentTick;
      currentMeasureNotes.add(HierarchicalNote(
        startTick: currentTick,
        durationTicks: remainingTicks,
        noteName: "--",
        isRest: true,
      ));
      measures.add(MeasureEntity(
        index: measureIndex,
        timeSignature: TimeSignature.commonTime44,
        notes: List.unmodifiable(currentMeasureNotes),
      ));
    }

    // Si no hubo notas, crear al menos un compás vacío
    if (measures.isEmpty) {
      measures.add(const MeasureEntity(
        index: 0,
        timeSignature: TimeSignature.commonTime44,
        notes: [
          HierarchicalNote(startTick: 0, durationTicks: 16, noteName: "--", isRest: true),
        ],
      ));
    }

    final title = "$rootNote - ${type.displayName}";

    return SongPackage(
      id: "gen_${rootNote.toLowerCase()}_${type.name}",
      title: title,
      composer: "Tunner Algorithmic Studio",
      genre: MusicGenre.classical,
      difficulty: _getDifficultyForType(type),
      defaultBpm: bpm,
      tracks: const [],
      score: HierarchicalScore(
        title: title,
        baseBpm: bpm,
        measures: measures,
      ),
    );
  }

  static bool _shouldPreferFlats(ParsedPitchNotation root, ExerciseType type) {
    if (root.alter < 0) return true;
    if (root.alter == 0 && root.step == 'F') return true;
    final isMinorMode = type == ExerciseType.naturalMinorScale ||
        type == ExerciseType.harmonicMinorScale ||
        type == ExerciseType.melodicMinorScale ||
        type == ExerciseType.minorArpeggio;
    if (isMinorMode && root.alter == 0 && (root.step == 'C' || root.step == 'D' || root.step == 'G')) {
      return true;
    }
    return false;
  }

  static List<int> _getSemitonePattern(ExerciseType type) {
    switch (type) {
      case ExerciseType.majorScale:
        return const [0, 2, 4, 5, 7, 9, 11, 12, 11, 9, 7, 5, 4, 2, 0];
      case ExerciseType.naturalMinorScale:
        return const [0, 2, 3, 5, 7, 8, 10, 12, 10, 8, 7, 5, 3, 2, 0];
      case ExerciseType.harmonicMinorScale:
        return const [0, 2, 3, 5, 7, 8, 11, 12, 11, 8, 7, 5, 3, 2, 0];
      case ExerciseType.melodicMinorScale:
        return const [0, 2, 3, 5, 7, 9, 11, 12, 10, 8, 7, 5, 3, 2, 0];
      case ExerciseType.pentatonicScale:
        return const [0, 2, 4, 7, 9, 12, 9, 7, 4, 2, 0];
      case ExerciseType.majorArpeggio:
        return const [0, 4, 7, 12, 7, 4, 0];
      case ExerciseType.minorArpeggio:
        return const [0, 3, 7, 12, 7, 3, 0];
      case ExerciseType.thirdsIntervals:
        return const [
          0, 4, 2, 5, 4, 7, 5, 9, 7, 11, 9, 12,
          12, 9, 11, 7, 9, 5, 7, 4, 5, 2, 4, 0
        ];
      case ExerciseType.longTones:
        return const [0, 4, 7, 12];
    }
  }

  static SongDifficulty _getDifficultyForType(ExerciseType type) {
    switch (type) {
      case ExerciseType.longTones:
      case ExerciseType.majorScale:
      case ExerciseType.pentatonicScale:
        return SongDifficulty.beginner;
      case ExerciseType.naturalMinorScale:
      case ExerciseType.majorArpeggio:
      case ExerciseType.minorArpeggio:
        return SongDifficulty.intermediate;
      case ExerciseType.harmonicMinorScale:
      case ExerciseType.melodicMinorScale:
      case ExerciseType.thirdsIntervals:
        return SongDifficulty.advanced;
    }
  }
}
