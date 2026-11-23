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
  final Map<String, HierarchicalScore> stemScores;

  const SongPackage({
    required this.id,
    required this.title,
    required this.composer,
    required this.genre,
    required this.difficulty,
    required this.defaultBpm,
    required this.score,
    required this.tracks,
    this.stemScores = const {},
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
    Map<String, HierarchicalScore>? stemScores,
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
      stemScores: stemScores ?? this.stemScores,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'composer': composer,
      'genre': genre.name,
      'difficulty': difficulty.name,
      'defaultBpm': defaultBpm,
      'score': score.toMap(),
      'tracks': tracks.map((t) => t.toMap()).toList(),
      if (stemScores.isNotEmpty)
        'stemScores': stemScores.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  factory SongPackage.fromMap(Map<String, dynamic> map) {
    final rawTracks = map['tracks'] as List<dynamic>? ?? [];
    final tracksList = rawTracks
        .whereType<Map<String, dynamic>>()
        .map((t) => AudioTrack.fromMap(t))
        .toList();

    final rawStemScores = map['stemScores'] as Map<String, dynamic>? ?? {};
    final parsedStemScores = <String, HierarchicalScore>{};
    rawStemScores.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsedStemScores[key] = HierarchicalScore.fromMap(value);
      }
    });

    return SongPackage(
      id: map['id'] as String? ?? 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Partitura sin título',
      composer: map['composer'] as String? ?? 'Compositor Tunner',
      genre: MusicGenre.values.firstWhere(
        (g) => g.name == map['genre'],
        orElse: () => MusicGenre.classical,
      ),
      difficulty: SongDifficulty.values.firstWhere(
        (d) => d.name == map['difficulty'],
        orElse: () => SongDifficulty.beginner,
      ),
      defaultBpm: (map['defaultBpm'] as num?)?.toInt() ?? 120,
      score: HierarchicalScore.fromMap(map['score'] as Map<String, dynamic>? ?? {}),
      tracks: tracksList,
      stemScores: parsedStemScores,
    );
  }
}
