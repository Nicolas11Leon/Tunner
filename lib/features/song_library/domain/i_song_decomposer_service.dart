import '../../mixer/domain/mixer_track_entity.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
import 'song_package_entity.dart';

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

/// Contrato abstracto de dominio para la biblioteca y adaptación de canciones.
abstract class ISongDecomposerService {
  List<SongPackage> getCuratedLibrary();
  List<SongDecompositionTemplate> getDecompositionTemplates();
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
  });
  SongPackage adaptSongPackageToInstrument(
    SongPackage package,
    InstrumentProfileEntity instrument,
  );
}
