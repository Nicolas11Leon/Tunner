import 'mixer_track_entity.dart';
import 'score_tree.dart';
import 'song_package_entity.dart';

/// Servicio de dominio puro para la gestión de la biblioteca de canciones y descomposición de pistas.
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

  /// Descompone una partitura importada o creada por el usuario en un paquete completo de canción.
  static SongPackage decomposeCustomScore({
    required String title,
    required String composer,
    required int bpm,
    required TimeSignature timeSignature,
    required List<MeasureEntity> measures,
    List<AudioTrack>? customTracks,
  }) {
    final stems = customTracks ?? [
      const AudioTrack(id: "user_lead", title: "Voz / Instrumento Principal", instrumentIcon: "music_note", volume: 0.9),
      const AudioTrack(id: "user_piano", title: "Piano Acompañante", instrumentIcon: "piano", volume: 0.75),
      const AudioTrack(id: "user_bass", title: "Bajo Armónico", instrumentIcon: "music_note", volume: 0.70),
    ];

    return SongPackage(
      id: "custom_${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      composer: composer,
      genre: MusicGenre.contemporary,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: bpm,
      tracks: stems,
      score: HierarchicalScore(
        title: title,
        baseBpm: bpm,
        measures: measures,
      ),
    );
  }
}
