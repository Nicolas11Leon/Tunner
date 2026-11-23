import 'dart:isolate';
import 'dart:math' as math;

import '../../mixer/domain/mixer_track_entity.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
import '../../guided_lessons/domain/instrument_pedagogy_adapter_engine.dart';
import '../../tuner/domain/note_entity.dart';
import 'song_package_entity.dart';
import 'i_song_decomposer_service.dart';

export 'i_song_decomposer_service.dart';

/// Servicio de datos / repositorio para la gestión de la biblioteca de canciones y descomposición de pistas.
class SongDecomposerService {
  const SongDecomposerService();

  /// Biblioteca canónica de canciones curadas y descompuestas por capas offline.
  static List<SongPackage> getCuratedLibrary() {
    return [
      SongPackage(
        id: "pachelbel_canon",
        title: "Canon en Re Mayor",
        composer: "Johann Pachelbel",
        genre: MusicGenre.baroque,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: 68,
        tracks: const [
          AudioTrack(id: "violins", title: "Violín Principal", instrumentIcon: "music_note", volume: 0.9),
          AudioTrack(id: "continuo", title: "Bajo Continuo / Cello", instrumentIcon: "piano", volume: 0.75),
          AudioTrack(id: "harpsichord", title: "Clave / Armonía", instrumentIcon: "piano", volume: 0.70),
        ],
        score: HierarchicalScore(
          title: "Canon en Re Mayor",
          baseBpm: 68,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Fa#5"), // Negra
                HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "Mi5"),  // Negra
                HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: "Re5"),  // Negra
                HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: "Do#5"),// Negra
              ],
            ),
            MeasureEntity(
              index: 1,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Si4"),  // Negra
                HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "La4"),  // Negra
                HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: "Si4"),  // Negra
                HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: "Do#5"),// Negra
              ],
            ),
          ],
        ),
      ),
      SongPackage(
        id: "beethoven_fur_elise",
        title: "Para Elisa (Für Elise)",
        composer: "Ludwig van Beethoven",
        genre: MusicGenre.romantic,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: 126,
        tracks: const [
          AudioTrack(id: "melody", title: "Melodía Principal / Solista", instrumentIcon: "music_note", volume: 0.9),
          AudioTrack(id: "left_hand", title: "Piano Mano Izquierda", instrumentIcon: "piano", volume: 0.8),
          AudioTrack(id: "strings_pad", title: "Cuerdas de Acompañamiento", instrumentIcon: "piano", volume: 0.65),
        ],
        score: HierarchicalScore(
          title: "Para Elisa (Für Elise)",
          baseBpm: 126,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.waltzTime34,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 2, noteName: "Mi5"),  // Corchea
                HierarchicalNote.note(startTick: 2, durationTicks: 2, noteName: "Re#5"), // Corchea
                HierarchicalNote.note(startTick: 4, durationTicks: 2, noteName: "Mi5"),  // Corchea
                HierarchicalNote.note(startTick: 6, durationTicks: 2, noteName: "Re#5"), // Corchea
                HierarchicalNote.note(startTick: 8, durationTicks: 2, noteName: "Mi5"),  // Corchea
                HierarchicalNote.note(startTick: 10, durationTicks: 2, noteName: "Si4"), // Corchea
              ],
            ),
            MeasureEntity(
              index: 1,
              timeSignature: TimeSignature.waltzTime34,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 2, noteName: "Re5"),  // Corchea
                HierarchicalNote.note(startTick: 2, durationTicks: 2, noteName: "Do5"),  // Corchea
                HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "La4"),  // Negra
                HierarchicalNote.rest(startTick: 8, durationTicks: 4),                   // Silencio negra
              ],
            ),
          ],
        ),
      ),
      SongPackage(
        id: "ode_to_joy",
        title: "Himno a la Alegría",
        composer: "Ludwig van Beethoven",
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.beginner,
        defaultBpm: 112,
        tracks: const [
          AudioTrack(id: "lead_vocal", title: "Voz Solista", instrumentIcon: "mic", volume: 0.85),
          AudioTrack(id: "orchestra_brass", title: "Metales & Maderas", instrumentIcon: "music_note", volume: 0.75),
          AudioTrack(id: "timpani_bass", title: "Bajo & Timbales", instrumentIcon: "piano", volume: 0.70),
        ],
        score: HierarchicalScore(
          title: "Himno a la Alegría",
          baseBpm: 112,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Si4"), // Negra
                HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "Si4"), // Negra
                HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: "Do5"), // Negra
                HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: "Re5"),// Negra
              ],
            ),
            MeasureEntity(
              index: 1,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Re5"), // Negra
                HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "Do5"), // Negra
                HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: "Si4"), // Negra
                HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: "La4"),// Negra
              ],
            ),
          ],
        ),
      ),
    ];
  }

  /// Colección de obras populares y ejercicios listos para descomponer interactivamente.
  static List<SongDecompositionTemplate> getDecompositionTemplates() {
    return const [
      SongDecompositionTemplate(
        title: "Estrellita, ¿Dónde Estás?",
        composer: "W. A. Mozart / Tradicional",
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.beginner,
        bpm: 100,
        timeSignature: TimeSignature.commonTime44,
        melodyNotation: "Do4:4 Do4:4 Sol4:4 Sol4:4 | La4:4 La4:4 Sol4:8 | Fa4:4 Fa4:4 Mi4:4 Mi4:4 | Re4:4 Re4:4 Do4:8",
      ),
      SongDecompositionTemplate(
        title: "Greensleeves (Fantasía Tradicional)",
        composer: "Anónimo Inglés (Siglo XVI)",
        genre: MusicGenre.traditional,
        difficulty: SongDifficulty.intermediate,
        bpm: 96,
        timeSignature: TimeSignature.waltzTime34,
        melodyNotation: "La4:4 Do5:4 Re5:4 | Mi5:6 Fa5:2 Mi5:4 | Re5:4 Si4:4 Sol4:4 | Mi4:6 Fa#4:2 Sol#4:4",
      ),
      SongDecompositionTemplate(
        title: "Minuet en Sol Mayor (BWV Anh. 114)",
        composer: "Johann Sebastian Bach",
        genre: MusicGenre.baroque,
        difficulty: SongDifficulty.intermediate,
        bpm: 116,
        timeSignature: TimeSignature.waltzTime34,
        melodyNotation: "Re5:4 Sol4:2 La4:2 Si4:2 Do5:2 | Re5:4 Sol4:4 Sol4:4 | Mi5:4 Do5:2 Re5:2 Mi5:2 Fa#5:2 | Sol5:4 Sol4:4 Sol4:4",
      ),
      SongDecompositionTemplate(
        title: "Escala Mayor Didáctica (Do Mayor)",
        composer: "Conservatorio / Ejercicio Técnico",
        genre: MusicGenre.contemporary,
        difficulty: SongDifficulty.beginner,
        bpm: 80,
        timeSignature: TimeSignature.commonTime44,
        melodyNotation: "Do4:4 Re4:4 Mi4:4 Fa4:4 | Sol4:4 La4:4 Si4:4 Do5:4 | Do5:4 Si4:4 La4:4 Sol4:4 | Fa4:4 Mi4:4 Re4:4 Do4:4",
      ),
      SongDecompositionTemplate(
        title: "Las Cuatro Estaciones: Otoño",
        composer: "Antonio Vivaldi",
        genre: MusicGenre.baroque,
        difficulty: SongDifficulty.intermediate,
        bpm: 108,
        timeSignature: TimeSignature.commonTime44,
        melodyNotation: "Fa4:4 Fa4:2 Sol4:2 Fa4:4 Do5:4 | Fa4:4 Fa4:2 Sol4:2 Fa4:4 Do5:4 | Sib4:4 La4:4 Sol4:4 Fa4:4 | Do5:8 Fa4:8",
      ),
      SongDecompositionTemplate(
        title: "Riff Pentatónico y Blues (Guitarra & Bajo)",
        composer: "Tradicional Blues / Rock",
        genre: MusicGenre.contemporary,
        difficulty: SongDifficulty.beginner,
        bpm: 110,
        timeSignature: TimeSignature.commonTime44,
        melodyNotation: "Mi3:4 Sol3:4 La3:4 Si3:4 | Re4:4 Si3:4 La3:4 Sol3:4 | Mi3:8 Mi3:8",
      ),
      SongDecompositionTemplate(
        title: "Fanfarria Clásica (Trompeta & Metales)",
        composer: "Tema Heroico de Conservatorio",
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.intermediate,
        bpm: 120,
        timeSignature: TimeSignature.commonTime44,
        melodyNotation: "Do4:4 Mi4:4 Sol4:4 Do5:4 | Sol4:4 Mi4:4 Do4:8 | Do4:4 Sol4:4 Do5:8",
      ),
      SongDecompositionTemplate(
        title: "Elegía Grave en Clave de Fa (Cello & Trombón)",
        composer: "Lírica Instrumental",
        genre: MusicGenre.romantic,
        difficulty: SongDifficulty.intermediate,
        bpm: 76,
        timeSignature: TimeSignature.commonTime44,
        melodyNotation: "Do3:4 Re3:4 Mi3:4 Fa3:4 | Sol3:6 Fa3:2 Mi3:4 Re3:4 | Do3:8 Sol2:8",
      ),
    ];
  }

  /// Normaliza nombres de notas internacionales (C, D, E...) o solfeo (Do, Re, Mi...) a formato canónico.
  static String normalizeNoteName(String raw) {
    String clean = raw.trim();
    if (clean.isEmpty || clean == "_" || clean.toLowerCase() == "r" || clean.toLowerCase() == "sil") {
      return "";
    }

    final lower = clean.toLowerCase();

    // 1. Prioridad: Verificar si ya es solfeo estándar (Do, Re, Mi, Fa, Sol, La, Si)
    const solfege = ['sol', 'do', 're', 'mi', 'fa', 'la', 'si'];
    for (final s in solfege) {
      if (lower.startsWith(s)) {
        final syllable = s[0].toUpperCase() + s.substring(1);
        final remainder = clean.substring(s.length);
        return "$syllable$remainder";
      }
    }

    // 2. Mapeo inglés internacional (C, D, E, F, G, A, B) -> Solfeo
    final letterMap = {
      'c': 'Do',
      'd': 'Re',
      'e': 'Mi',
      'f': 'Fa',
      'g': 'Sol',
      'a': 'La',
      'b': 'Si',
    };

    final firstChar = lower[0];
    if (letterMap.containsKey(firstChar)) {
      String accidental = "";
      String octave = "4";
      String rest = clean.substring(1);

      if (rest.startsWith('#')) {
        accidental = "#";
        rest = rest.substring(1);
      } else if (rest.startsWith('b') || rest.startsWith('♭')) {
        accidental = "b";
        rest = rest.substring(1);
      }

      if (rest.isNotEmpty && int.tryParse(rest[0]) != null) {
        octave = rest[0];
      }

      return "${letterMap[firstChar]}$accidental$octave";
    }

    if (clean.length >= 2) {
      return clean[0].toUpperCase() + clean.substring(1);
    }
    return clean;
  }

  /// Parsea una cadena de texto melódico libre y la estructura en compases matemáticamente válidos.
  /// Formato soportado:
  /// - Con duraciones explícitas: "Do4:4 Re4:4 Mi4:8"
  /// - Sin duraciones (asume negras :4): "Do4 Re4 Mi4 Fa4"
  /// - Con barras de compás: "Do4 Re4 | Mi4 Fa4"
  /// - Silencios: "_:4" o "Sil:4" o "R:4"
  static List<MeasureEntity> parseMelodyText(String input, TimeSignature timeSignature) {
    final measures = <MeasureEntity>[];
    final ticksPerMeasure = timeSignature.totalTicks;

    // Si viene separado explícitamente por barras '|'
    final rawMeasureBlocks = input.split('|');

    int currentMeasureIndex = 0;
    int currentTickInMeasure = 0;
    var currentMeasureNotes = <HierarchicalNote>[];

    void commitCurrentMeasure() {
      if (currentTickInMeasure < ticksPerMeasure) {
        // Rellenar automáticamente el compás con silencio para cumplir con la métrica
        currentMeasureNotes.add(
          HierarchicalNote.rest(
            startTick: currentTickInMeasure,
            durationTicks: ticksPerMeasure - currentTickInMeasure,
          ),
        );
      }
      measures.add(
        MeasureEntity(
          index: currentMeasureIndex++,
          timeSignature: timeSignature,
          notes: List.unmodifiable(currentMeasureNotes),
        ),
      );
      currentTickInMeasure = 0;
      currentMeasureNotes = [];
    }

    // Procesa tokens
    for (final block in rawMeasureBlocks) {
      final tokens = block.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

      for (final token in tokens) {
        // Extraer nota y duración (ej: "Do4:4" o "Mi5:2")
        String notePart = token;
        int durationTicks = 4; // Por defecto: negra = 4 sub-ticks

        if (token.contains(':')) {
          final parts = token.split(':');
          notePart = parts[0];
          final parsedDuration = int.tryParse(parts[1]);
          if (parsedDuration != null && parsedDuration > 0) {
            durationTicks = parsedDuration;
          }
        }

        final normalized = normalizeNoteName(notePart);
        final isRest = normalized.isEmpty;

        // Si agregar esta nota excede el compás actual, cerrar el compás
        if (currentTickInMeasure + durationTicks > ticksPerMeasure) {
          commitCurrentMeasure();
        }

        currentMeasureNotes.add(
          isRest
              ? HierarchicalNote.rest(
                  startTick: currentTickInMeasure,
                  durationTicks: durationTicks,
                )
              : HierarchicalNote.note(
                  startTick: currentTickInMeasure,
                  durationTicks: durationTicks,
                  noteName: normalized,
                ),
        );

        currentTickInMeasure += durationTicks;

        if (currentTickInMeasure == ticksPerMeasure) {
          commitCurrentMeasure();
        }
      }

      // Si el bloque terminó con una barra explícita '|' y hay notas pendientes
      if (rawMeasureBlocks.length > 1 && currentMeasureNotes.isNotEmpty) {
        commitCurrentMeasure();
      }
    }

    // Si quedaron notas pendientes en el último compás
    if (currentMeasureNotes.isNotEmpty) {
      commitCurrentMeasure();
    }

    // Si no se pudo generar ningún compás (entrada vacia o invalida), retornar un compás de silencio
    if (measures.isEmpty) {
      measures.add(
        MeasureEntity(
          index: 0,
          timeSignature: timeSignature,
          notes: [
            HierarchicalNote.rest(
              startTick: 0,
              durationTicks: timeSignature.totalTicks,
            ),
          ],
        ),
      );
    }

    return measures;
  }

  static String _transposeNoteBySemitones(String noteName, int semitones) {
    final baseFreq = NoteEntity.frequencyForNote(noteName);
    if (baseFreq <= 20.0) return noteName;
    final targetFreq = baseFreq * math.pow(2.0, semitones / 12.0);
    return NoteEntity.fromFrequency(targetFreq).name;
  }

  static String _toBassRegister(String noteName) {
    final baseFreq = NoteEntity.frequencyForNote(noteName);
    if (baseFreq <= 20.0) return 'Do2';
    int midi = NoteEntity.fromFrequency(baseFreq).midiNumber;
    while (midi > 47) {
      midi -= 12;
    }
    while (midi < 36) {
      midi += 12;
    }
    final bassFreq = 440.0 * math.pow(2.0, (midi - 69) / 12.0);
    return NoteEntity.fromFrequency(bassFreq).name;
  }

  /// Calcula los intervalos diatónicos (tercera y quinta en semitonos) de la tríada
  /// correspondiente a [rootMidi] dentro de la escala definida por [keySignatureFifths] y [isMinorMode].
  static (int thirdInterval, int fifthInterval) _resolveDiatonicTriadIntervals({
    required int rootMidi,
    required int keySignatureFifths,
    required bool isMinorMode,
  }) {
    final clampedFifths = keySignatureFifths.clamp(-7, 7);
    final majorTonicPc = ((clampedFifths * 7) % 12 + 12) % 12;
    final tonicPc = isMinorMode ? (majorTonicPc + 9) % 12 : majorTonicPc;
    const majorIntervals = <int>[0, 2, 4, 5, 7, 9, 11];
    const minorIntervals = <int>[0, 2, 3, 5, 7, 8, 10];
    final scaleOffsets = isMinorMode ? minorIntervals : majorIntervals;
    final scalePcs = scaleOffsets.map((offset) => (tonicPc + offset) % 12).toList();

    final rootPc = ((rootMidi % 12) + 12) % 12;
    final degreeIdx = scalePcs.indexOf(rootPc);
    if (degreeIdx == -1) {
      // Nota cromática fuera de la armadura: respetar el modo general
      return isMinorMode ? (3, 7) : (4, 7);
    }

    final thirdPc = scalePcs[(degreeIdx + 2) % 7];
    final fifthPc = scalePcs[(degreeIdx + 4) % 7];
    final thirdInterval = ((thirdPc - rootPc) % 12 + 12) % 12;
    final fifthInterval = ((fifthPc - rootPc) % 12 + 12) % 12;
    return (thirdInterval, fifthInterval);
  }

  /// Infiere si la obra está en modo menor a partir de pistas en el título o de la
  /// coincidencia de la tónica inicial/final con la relativa menor de la armadura.
  static bool _inferMinorMode(String title, List<MeasureEntity> leadMeasures) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('menor') ||
        lowerTitle.contains('minor') ||
        lowerTitle.contains('greensleeves') ||
        lowerTitle.contains('elisa') ||
        lowerTitle.contains('elise') ||
        lowerTitle.contains('elegía') ||
        lowerTitle.contains('elegia')) {
      return true;
    }
    if (lowerTitle.contains('mayor') || lowerTitle.contains('major')) {
      return false;
    }

    final pitched = leadMeasures
        .expand((m) => m.notes)
        .where((n) => !n.isRest && n.noteName.isNotEmpty && n.noteName != '--')
        .toList();
    if (pitched.isEmpty || leadMeasures.isEmpty) return false;

    final fifths = leadMeasures.first.keySignatureFifths.clamp(-7, 7);
    final majorTonicPc = ((fifths * 7) % 12 + 12) % 12;
    final minorTonicPc = (majorTonicPc + 9) % 12;

    final firstFreq = NoteEntity.frequencyForNote(pitched.first.noteName);
    final lastFreq = NoteEntity.frequencyForNote(pitched.last.noteName);
    if (firstFreq <= 20.0 || lastFreq <= 20.0) return false;

    final firstPc = NoteEntity.fromFrequency(firstFreq).midiNumber % 12;
    final lastPc = NoteEntity.fromFrequency(lastFreq).midiNumber % 12;
    return (firstPc == minorTonicPc || lastPc == minorTonicPc) &&
        firstPc != majorTonicPc &&
        lastPc != majorTonicPc;
  }

  static List<MeasureEntity> _buildHarmonyMeasures(
    List<MeasureEntity> leadMeasures, {
    bool isMinorMode = false,
  }) {
    return leadMeasures.map((m) {
      final firstPitched = m.notes.where((n) => !n.isRest && n.noteName.isNotEmpty && n.noteName != '--').toList();
      if (firstPitched.isEmpty) {
        return MeasureEntity(
          index: m.index,
          timeSignature: m.timeSignature,
          keySignatureFifths: m.keySignatureFifths,
          notes: [HierarchicalNote.rest(startTick: 0, durationTicks: m.timeSignature.totalTicks)],
        );
      }
      final rootNote = firstPitched.first.noteName;
      final rootFreq = NoteEntity.frequencyForNote(rootNote);
      final rootMidi = rootFreq > 20.0 ? NoteEntity.fromFrequency(rootFreq).midiNumber : 60;
      final (thirdSemitones, fifthSemitones) = _resolveDiatonicTriadIntervals(
        rootMidi: rootMidi,
        keySignatureFifths: m.keySignatureFifths,
        isMinorMode: isMinorMode,
      );
      final thirdNote = _transposeNoteBySemitones(rootNote, thirdSemitones);
      final fifthNote = _transposeNoteBySemitones(rootNote, fifthSemitones);
      final totalTicks = m.timeSignature.totalTicks;
      return MeasureEntity(
        index: m.index,
        timeSignature: m.timeSignature,
        keySignatureFifths: m.keySignatureFifths,
        notes: [
          HierarchicalNote.note(startTick: 0, durationTicks: totalTicks, noteName: rootNote),
          HierarchicalNote.note(startTick: 0, durationTicks: totalTicks, noteName: thirdNote),
          HierarchicalNote.note(startTick: 0, durationTicks: totalTicks, noteName: fifthNote),
        ],
      );
    }).toList();
  }

  static List<MeasureEntity> _buildBassMeasures(List<MeasureEntity> leadMeasures) {
    return leadMeasures.map((m) {
      final firstPitched = m.notes.where((n) => !n.isRest && n.noteName.isNotEmpty && n.noteName != '--').toList();
      if (firstPitched.isEmpty) {
        return MeasureEntity(
          index: m.index,
          timeSignature: m.timeSignature,
          notes: [HierarchicalNote.rest(startTick: 0, durationTicks: m.timeSignature.totalTicks)],
        );
      }
      final bassRoot = _toBassRegister(firstPitched.first.noteName);
      final totalTicks = m.timeSignature.totalTicks;
      return MeasureEntity(
        index: m.index,
        timeSignature: m.timeSignature,
        notes: [
          HierarchicalNote.note(startTick: 0, durationTicks: totalTicks, noteName: bassRoot),
        ],
      );
    }).toList();
  }

  static List<MeasureEntity> _buildRhythmMeasures(List<MeasureEntity> leadMeasures) {
    return leadMeasures.map((m) {
      final totalTicks = m.timeSignature.totalTicks;
      final beatTicks = (16 ~/ m.timeSignature.denominator).clamp(1, totalTicks);
      final pulseNotes = <HierarchicalNote>[];
      for (int tick = 0; tick < totalTicks; tick += beatTicks) {
        final dur = math.min(beatTicks, totalTicks - tick);
        pulseNotes.add(
          HierarchicalNote.note(
            startTick: tick,
            durationTicks: dur,
            noteName: tick == 0 ? 'Do3' : 'Sol2',
          ),
        );
      }
      return MeasureEntity(
        index: m.index,
        timeSignature: m.timeSignature,
        notes: pulseNotes,
      );
    }).toList();
  }

  /// Descompone una partitura importada o creada por el usuario en un paquete completo de canción.
  static SongPackage decomposeCustomScore({
    required String title,
    required String composer,
    required int bpm,
    required TimeSignature timeSignature,
    required List<MeasureEntity> measures,
    List<AudioTrack>? customTracks,
    bool includeLead = true,
    bool includePiano = true,
    bool includeBass = true,
    bool includeRhythm = true,
    bool? isMinorMode,
  }) {
    final safeBpm = bpm.clamp(20, 300);
    final safeTitle = title.trim().isEmpty ? "Obra Personalizada" : title.trim();
    final resolvedMinorMode = isMinorMode ?? _inferMinorMode(safeTitle, measures);
    final stems = <AudioTrack>[];
    final stemScores = <String, HierarchicalScore>{};

    if (includeLead) {
      stems.add(const AudioTrack(
        id: "lead_stem",
        title: "Pista Melódica Solista",
        instrumentIcon: "music_note",
        volume: 0.90,
      ));
      stemScores["lead_stem"] = HierarchicalScore(
        title: "$safeTitle (Melodia)",
        baseBpm: safeBpm,
        measures: measures,
      );
    }
    if (includePiano) {
      stems.add(const AudioTrack(
        id: "harmony_stem",
        title: "Acompañamiento Armónico (Piano)",
        instrumentIcon: "piano",
        volume: 0.75,
      ));
      stemScores["harmony_stem"] = HierarchicalScore(
        title: "$safeTitle (Armonia)",
        baseBpm: safeBpm,
        measures: _buildHarmonyMeasures(measures, isMinorMode: resolvedMinorMode),
      );
    }
    if (includeBass) {
      stems.add(const AudioTrack(
        id: "bass_stem",
        title: "Línea de Bajo / Cello",
        instrumentIcon: "music_note",
        volume: 0.70,
      ));
      stemScores["bass_stem"] = HierarchicalScore(
        title: "$safeTitle (Bajo)",
        baseBpm: safeBpm,
        measures: _buildBassMeasures(measures),
      );
    }
    if (includeRhythm) {
      stems.add(const AudioTrack(
        id: "rhythm_stem",
        title: "Capa Rítmica & Percusión",
        instrumentIcon: "music_note",
        volume: 0.80,
      ));
      stemScores["rhythm_stem"] = HierarchicalScore(
        title: "$safeTitle (Ritmo)",
        baseBpm: safeBpm,
        measures: _buildRhythmMeasures(measures),
      );
    }

    final finalStems = customTracks ?? (stems.isNotEmpty ? stems : [
      const AudioTrack(id: "user_lead", title: "Melodía Principal", instrumentIcon: "music_note", volume: 0.9),
      const AudioTrack(id: "user_piano", title: "Acompañamiento", instrumentIcon: "piano", volume: 0.75),
    ]);

    return SongPackage(
      id: "custom_${DateTime.now().millisecondsSinceEpoch}",
      title: safeTitle,
      composer: composer.trim().isEmpty ? "Compositor Local" : composer.trim(),
      genre: MusicGenre.contemporary,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: safeBpm,
      tracks: finalStems,
      score: HierarchicalScore(
        title: safeTitle,
        baseBpm: safeBpm,
        measures: measures,
      ),
      stemScores: stemScores,
    );
  }

  /// Adapta un paquete de canción y su partitura a cualquier instrumento musical,
  /// reubicando las notas en la tesitura cómoda del instrumento, renombrando
  /// las pistas melódicas solistas y preservando `stemScores`.
  static SongPackage adaptSongPackageToInstrument(
    SongPackage package,
    InstrumentProfileEntity instrument,
  ) {
    // 1. Adaptar títulos de pistas solistas
    final adaptedTracks = package.tracks.map((track) {
      if (track.id == 'melody' || track.id == 'violins' || track.id == 'lead_vocal' || track.id == 'lead_stem') {
        return AudioTrack(
          id: track.id,
          title: "Melodía de ${instrument.name}",
          instrumentIcon: track.instrumentIcon,
          volume: track.volume,
        );
      }
      return track;
    }).toList();

    // 2. Adaptar la partitura principal a la tesitura del instrumento
    final adaptedScore = adaptScoreToInstrument(package.score, instrument);

    // 3. Preservar stemScores (adaptando los stems melódicos solistas a la tesitura objetivo)
    final adaptedStemScores = <String, HierarchicalScore>{};
    package.stemScores.forEach((stemId, stemScore) {
      final isLeadStem = stemId == 'melody' ||
          stemId == 'violins' ||
          stemId == 'lead_vocal' ||
          stemId == 'lead_stem';
      adaptedStemScores[stemId] = isLeadStem
          ? adaptScoreToInstrument(stemScore, instrument)
          : stemScore;
    });

    return SongPackage(
      id: "${package.id}_${instrument.id}",
      title: package.title,
      composer: package.composer,
      genre: package.genre,
      difficulty: package.difficulty,
      defaultBpm: package.defaultBpm,
      tracks: adaptedTracks,
      score: adaptedScore,
      stemScores: adaptedStemScores,
    );
  }

  /// Adapta una partitura jerárquica a la tesitura natural de un instrumento.
  static HierarchicalScore adaptScoreToInstrument(
    HierarchicalScore score,
    InstrumentProfileEntity instrument,
  ) {
    const adapter = InstrumentPedagogyAdapterEngine();

    final adaptedMeasures = score.measures.map((measure) {
      final adaptedNotes = measure.notes.map((note) {
        if (note.isRest || note.noteName.isEmpty) {
          return note;
        }

        final parsedMidi = adapter.noteNameToMidi(note.noteName);
        if (parsedMidi == null) return note;

        final shiftedMidi = adapter.shiftMidiToInstrumentRange(parsedMidi, instrument);
        final shiftedNoteName = adapter.midiToNoteName(shiftedMidi);

        return note.copyWith(noteName: shiftedNoteName);
      }).toList();

      return MeasureEntity(
        index: measure.index,
        timeSignature: measure.timeSignature,
        notes: adaptedNotes,
        keySignatureFifths: measure.keySignatureFifths,
      );
    }).toList();

    return HierarchicalScore(
      title: "${score.title} (${instrument.name})",
      baseBpm: score.baseBpm,
      measures: adaptedMeasures,
      staffCount: score.staffCount,
    );
  }

  /// Ejecuta [decomposeCustomScore] en un Isolate secundario para mantener la fluidez de la UI.
  static Future<SongPackage> decomposeCustomScoreAsync({
    required String title,
    required String composer,
    required int bpm,
    required TimeSignature timeSignature,
    required List<MeasureEntity> measures,
    List<AudioTrack>? customTracks,
    bool includeLead = true,
    bool includePiano = true,
    bool includeBass = true,
    bool includeRhythm = true,
  }) {
    return Isolate.run(
      () => SongDecomposerService.decomposeCustomScore(
        title: title,
        composer: composer,
        bpm: bpm,
        timeSignature: timeSignature,
        measures: measures,
        customTracks: customTracks,
        includeLead: includeLead,
        includePiano: includePiano,
        includeBass: includeBass,
        includeRhythm: includeRhythm,
      ),
    );
  }
}

/// Implementacion canónica basada en instancia de [ISongDecomposerService].
class DefaultSongDecomposerService implements ISongDecomposerService {
  const DefaultSongDecomposerService();

  @override
  List<SongPackage> getCuratedLibrary() => SongDecomposerService.getCuratedLibrary();

  @override
  List<SongDecompositionTemplate> getDecompositionTemplates() =>
      SongDecomposerService.getDecompositionTemplates();

  @override
  SongPackage decomposeCustomScore({
    required String title,
    required String composer,
    required int bpm,
    required TimeSignature timeSignature,
    required List<MeasureEntity> measures,
    List<AudioTrack>? customTracks,
    bool includeLead = true,
    bool includePiano = true,
    bool includeBass = true,
    bool includeRhythm = true,
  }) =>
      SongDecomposerService.decomposeCustomScore(
        title: title,
        composer: composer,
        bpm: bpm,
        timeSignature: timeSignature,
        measures: measures,
        customTracks: customTracks,
        includeLead: includeLead,
        includePiano: includePiano,
        includeBass: includeBass,
        includeRhythm: includeRhythm,
      );

  @override
  SongPackage adaptSongPackageToInstrument(
    SongPackage package,
    InstrumentProfileEntity instrument,
  ) =>
      SongDecomposerService.adaptSongPackageToInstrument(package, instrument);
}
