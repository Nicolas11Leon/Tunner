import '../../mixer/domain/mixer_track_entity.dart';
import '../../sheet_music/domain/score_tree.dart';

/// Dificultad pedagógica de la obra musical.
enum SongDifficulty {
  beginner,
  intermediate,
  advanced,
  virtuoso,
}

/// Género musical para organización y filtrado en la biblioteca.
enum MusicGenre {
  classical,
  baroque,
  romantic,
  traditional,
  jazz,
  contemporary,
}

/// Paquete completo de canción descompuesta: combina partitura jerárquica y pistas de acompañamiento separadas (stems).
class SongPackage {
  final String id;
  final String title;
  final String composer;
  final MusicGenre genre;
  final SongDifficulty difficulty;
  final int defaultBpm;
  final HierarchicalScore score;
  final List<AudioTrack> tracks; // Stems de acompañamiento (ej: Piano, Voz, Guitarras, Bajo)

  const SongPackage({
    required this.id,
    required this.title,
    required this.composer,
    required this.genre,
    required this.difficulty,
    required this.defaultBpm,
    required this.score,
    required this.tracks,
  });

  int get totalMeasures => score.totalMeasures;
  TimeSignature get initialTimeSignature => score.measures.isNotEmpty ? score.measures.first.timeSignature : TimeSignature.commonTime44;

  SongPackage copyWith({
    String? id,
    String? title,
    String? composer,
    MusicGenre? genre,
    SongDifficulty? difficulty,
    int? defaultBpm,
    HierarchicalScore? score,
    List<AudioTrack>? tracks,
  }) {
    return SongPackage(
      id: id ?? this.id,
      title: title ?? this.title,
      composer: composer ?? this.composer,
      genre: genre ?? this.genre,
      difficulty: difficulty ?? this.difficulty,
      defaultBpm: defaultBpm ?? this.defaultBpm,
      score: score ?? this.score,
      tracks: tracks ?? this.tracks,
    );
  }
}
