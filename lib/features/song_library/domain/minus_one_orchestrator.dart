import '../../mixer/domain/mixer_track_entity.dart';
import '../../practice_evaluator/domain/note_evaluation_entity.dart';
import 'minus_one_session_entity.dart';
import 'song_package_entity.dart';

/// Orquestador y logica de negocio pura para el modo de practica con ensamble virtual "Minus-One".
class MinusOneOrchestrator {
  const MinusOneOrchestrator();

  /// Identifica de forma heuristica la pista que corresponde al instrumento activo del estudiante.
  /// Si ninguna pista coincide por identificador o icono, selecciona la primera pista (voz principal/melodia).
  String detectUserTrack(SongPackage package, String activeInstrumentId) {
    if (package.tracks.isEmpty) return '';

    final normalizedInstrument = activeInstrumentId.toLowerCase().trim();

    // 1. Coincidencia exacta por ID de pista
    for (final track in package.tracks) {
      if (track.id.toLowerCase().trim() == normalizedInstrument) {
        return track.id;
      }
    }

    // 2. Coincidencia por icono de instrumento o palabras clave
    for (final track in package.tracks) {
      final icon = track.instrumentIcon.toLowerCase().trim();
      final title = track.title.toLowerCase().trim();
      if (icon == normalizedInstrument ||
          title.contains(normalizedInstrument) ||
          normalizedInstrument.contains(icon)) {
        return track.id;
      }
    }

    // 3. Fallback: primera pista de la obra
    return package.tracks.first.id;
  }

  /// Retorna las pistas constitutivas de acompanamiento excluyendo la pista del usuario.
  List<AudioTrack> getAccompanimentStems(SongPackage package, String userTrackId) {
    return package.tracks.where((t) => t.id != userTrackId).toList();
  }

  /// Determina si la obra tiene una unica pista melodica sin acompanamiento adicional.
  bool isSingleTrackWork(SongPackage package) {
    return package.tracks.length <= 1;
  }

  /// Configura la consola de mezcla adaptada al modo Minus-One:
  /// - Silencia la pista del estudiante (`userTrackId`).
  /// - Opcionalmente le asigna un volumen guia (`guideVolume`).
  /// - Mantiene audibles las pistas de acompanamiento y el metronomo.
  MixerConsoleEntity configureMinusOneMixer(
    MixerConsoleEntity console,
    String userTrackId, {
    bool muteUserTrack = true,
    double guideVolume = 0.0,
  }) {
    // Si la pista del usuario es silenciada, actualizamos su mute y volumen guia
    var updated = console.setTrackMute(userTrackId, muteUserTrack);
    if (guideVolume > 0.0) {
      updated = updated.copyWithTrackVolume(userTrackId, guideVolume);
    }
    return updated;
  }

  /// Restaura la consola de mezcla al modo normal con todas las pistas activas.
  MixerConsoleEntity restoreFullEnsembleMixer(
    MixerConsoleEntity console,
    String userTrackId, {
    double standardVolume = 0.85,
  }) {
    var updated = console.setTrackMute(userTrackId, false);
    updated = updated.copyWithTrackVolume(userTrackId, standardVolume);
    return updated;
  }

  /// Inicializa una nueva entidad de sesion Minus-One para una obra dada.
  MinusOneSessionEntity createSession({
    required SongPackage package,
    required String userTrackId,
    bool isMinusOneActive = true,
    bool isMutedUserTrack = true,
    double guideTrackVolume = 0.0,
  }) {
    return MinusOneSessionEntity(
      songId: package.id,
      userTrackId: userTrackId,
      isMinusOneActive: isMinusOneActive,
      isMutedUserTrack: isMutedUserTrack,
      guideTrackVolume: guideTrackVolume,
      evaluations: const [],
    );
  }

  /// Agrega una evaluacion acustica en tiempo real a la sesion activa.
  MinusOneSessionEntity recordEvaluation(
    MinusOneSessionEntity session,
    NoteEvaluationEntity evaluation,
  ) {
    final updatedList = List<NoteEvaluationEntity>.from(session.evaluations)..add(evaluation);
    return session.copyWith(evaluations: updatedList);
  }

  /// Calcula la calificacion pedagogica formal de la sesion (S, A, B, C, D).
  String calculateSessionGrade(MinusOneSessionEntity session) => session.sessionGrade;
}
