import '../../mixer/domain/mixer_track_entity.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../domain/song_package_entity.dart';

/// Plantilla preconfigurada para el descompositor musical.
class SongDecompositionTemplate {
  final String title;
  final String composer;
  final MusicGenre genre;
  final SongDifficulty difficulty;
  final int bpm;
  final TimeSignature timeSignature;
  final String melodyNotation;

  const SongDecompositionTemplate({
    required this.title,
    required this.composer,
    required this.genre,
    required this.difficulty,
    required this.bpm,
    required this.timeSignature,
    required this.melodyNotation,
  });
}

/// Servicio de datos / repositorio para la gestión de la biblioteca de canciones y descomposición de pistas.
class SongDecomposerService {
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
          AudioTrack(id: "melody", title: "Melodía de Flauta / Voz", instrumentIcon: "music_note", volume: 0.9),
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

    // Si no se pudo generar ningún compás, crear un compás vacío por defecto
    if (measures.isEmpty) {
      measures.add(
        MeasureEntity(
          index: 0,
          timeSignature: timeSignature,
          notes: [
            HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Do4"),
            HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "Mi4"),
            HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: "Sol4"),
            HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: "Do5"),
          ],
        ),
      );
    }

    return measures;
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
  }) {
    final stems = <AudioTrack>[];

    if (includeLead) {
      stems.add(const AudioTrack(
        id: "lead_stem",
        title: "Pista Melódica Solista",
        instrumentIcon: "music_note",
        volume: 0.90,
      ));
    }
    if (includePiano) {
      stems.add(const AudioTrack(
        id: "harmony_stem",
        title: "Acompañamiento Armónico (Piano)",
        instrumentIcon: "piano",
        volume: 0.75,
      ));
    }
    if (includeBass) {
      stems.add(const AudioTrack(
        id: "bass_stem",
        title: "Línea de Bajo / Cello",
        instrumentIcon: "music_note",
        volume: 0.70,
      ));
    }
    if (includeRhythm) {
      stems.add(const AudioTrack(
        id: "rhythm_stem",
        title: "Capa Rítmica & Percusión",
        instrumentIcon: "music_note",
        volume: 0.80,
      ));
    }

    final finalStems = customTracks ?? (stems.isNotEmpty ? stems : [
      const AudioTrack(id: "user_lead", title: "Melodía Principal", instrumentIcon: "music_note", volume: 0.9),
      const AudioTrack(id: "user_piano", title: "Acompañamiento", instrumentIcon: "piano", volume: 0.75),
    ]);

    return SongPackage(
      id: "custom_${DateTime.now().millisecondsSinceEpoch}",
      title: title.trim().isEmpty ? "Obra Personalizada" : title.trim(),
      composer: composer.trim().isEmpty ? "Compositor Local" : composer.trim(),
      genre: MusicGenre.contemporary,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: bpm,
      tracks: finalStems,
      score: HierarchicalScore(
        title: title,
        baseBpm: bpm,
        measures: measures,
      ),
    );
  }
}
