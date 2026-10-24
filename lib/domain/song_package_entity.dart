import 'mixer_track_entity.dart';
import 'score_tree.dart';

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
}
