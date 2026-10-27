import 'dart:math' as math;
import '../../score_editor/domain/score_editor_domain.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';

/// Cuantizador rítmico determinista que mapea duraciones continuas en sub-ticks
/// a las figuras canónicas de notación musical en conservatorio.
class RhythmicQuantizer {
  /// Colección ordenada de duraciones canónicas soportadas en compases de 4/4 (en sub-ticks de semicorchea).
  static const List<int> canonicalDurations = [1, 2, 4, 8, 16];

  /// Cuantiza una duración acústica observada en sub-ticks a la figura canónica más apropiada.
  static int quantizeDuration(int observedTicks) {
    if (observedTicks <= 1) return 1;
    if (observedTicks == 2) return 2;
    if (observedTicks <= 5) return 4;
    if (observedTicks <= 11) return 8;
    return 16;
  }
}

/// Candidato acústico que acumula energía y estabilidad para un ataque de nota.
class TranscriptionCandidate {
  final String noteName;
  final double frequencyHz;
  final int startTick;
  final int measureIndex;
  int durationTicks;
  int consecutiveFrames;

  TranscriptionCandidate({
    required this.noteName,
    required this.frequencyHz,
    required this.startTick,
    required this.measureIndex,
    this.durationTicks = 1,
    this.consecutiveFrames = 1,
  });
}

/// Motor de dominio para transcripción de audio de micrófono a partitura en tiempo real.
class LiveTranscriptionEngine {
  final int minFramesForOnset;
  final double minClarityThreshold;
  final ScoreEditorOperations _operations;

  bool _isTranscribing = false;
  SongPackage? _activePackage;
  int _currentMeasureIndex = 0;
  int _currentTickInMeasure = 0;
  TranscriptionCandidate? _candidate;

  LiveTranscriptionEngine({
    this.minFramesForOnset = 2,
    this.minClarityThreshold = 0.80,
    ScoreEditorOperations? operations,
  }) : _operations = operations ?? const ScoreEditorOperations();

  bool get isTranscribing => _isTranscribing;
  SongPackage? get activePackage => _activePackage;
  HierarchicalScore? get activeScore => _activePackage?.score;
  int get currentMeasureIndex => _currentMeasureIndex;
  int get currentTickInMeasure => _currentTickInMeasure;

  /// Inicia una sesión de transcripción activa sobre una partitura o paquete base.
  void start({
    required SongPackage initialPackage,
    int startMeasureIndex = 0,
    int startTick = 0,
  }) {
    _activePackage = initialPackage;
    _currentMeasureIndex = math.max(0, math.min(startMeasureIndex, initialPackage.score.measures.length - 1));
    _currentTickInMeasure = math.max(0, math.min(startTick, 15));
    _candidate = null;
    _isTranscribing = true;
  }

  /// Procesa un frame de estimación de tono proveniente del detector acústico (MPM o YIN).
  /// Retorna una nueva instancia de [SongPackage] si se ha generado o cerrado una nota en la partitura.
  SongPackage? processPitchFrame({
    required double frequencyHz,
    required double clarity,
    required String noteName,
  }) {
    if (!_isTranscribing || _activePackage == null) return null;

    final isVoiced = clarity >= minClarityThreshold && frequencyHz > 20.0 && noteName != "--";

    if (!isVoiced) {
      // Silencio o ruido sin tono periódico definido
      if (_candidate != null) {
        if (_candidate!.consecutiveFrames >= minFramesForOnset) {
          final updatedPackage = _finalizeCandidate(_candidate!);
          _candidate = null;
          return updatedPackage;
        } else {
          // Descartar por ruido transitorio breve
          _candidate = null;
        }
      }
      return null;
    }

    // Tono periódico estable detectado
    if (_candidate == null) {
      _candidate = TranscriptionCandidate(
        noteName: noteName,
        frequencyHz: frequencyHz,
        startTick: _currentTickInMeasure,
        measureIndex: _currentMeasureIndex,
        durationTicks: 1,
        consecutiveFrames: 1,
      );
      return null;
    }

    if (_candidate!.noteName == noteName) {
      // Misma nota sostenida
      _candidate!.durationTicks++;
      _candidate!.consecutiveFrames++;
      return null;
    } else {
      // Cambio de nota
      SongPackage? packageUpdate;
      if (_candidate!.consecutiveFrames >= minFramesForOnset) {
        packageUpdate = _finalizeCandidate(_candidate!);
      }
      _candidate = TranscriptionCandidate(
        noteName: noteName,
        frequencyHz: frequencyHz,
        startTick: _currentTickInMeasure,
        measureIndex: _currentMeasureIndex,
        durationTicks: 1,
        consecutiveFrames: 1,
      );
      return packageUpdate;
    }
  }

  /// Finaliza la sesión de transcripción y asegura que cualquier nota pendiente sea transcrita.
  SongPackage? stop() {
    if (!_isTranscribing) return _activePackage;
    _isTranscribing = false;

    if (_candidate != null && _candidate!.consecutiveFrames >= minFramesForOnset) {
      final updatedPackage = _finalizeCandidate(_candidate!);
      _candidate = null;
      return updatedPackage;
    }
    _candidate = null;
    return _activePackage;
  }

  SongPackage _finalizeCandidate(TranscriptionCandidate candidate) {
    var package = _activePackage!;
    final quantizedDuration = RhythmicQuantizer.quantizeDuration(candidate.durationTicks);

    // Asegurar que el compás objetivo existe
    while (_currentMeasureIndex >= package.score.measures.length) {
      package = _operations.addMeasure(package: package);
    }

    // Limitar al espacio restante en el compás actual si es necesario
    final targetMeasure = package.score.measures[_currentMeasureIndex];
    final maxTicksInMeasure = targetMeasure.timeSignature.totalTicks;
    final safeDuration = math.min(quantizedDuration, maxTicksInMeasure - _currentTickInMeasure);
    final effectiveDuration = safeDuration > 0 ? safeDuration : 1;

    package = _operations.insertOrUpdateNote(
      package: package,
      measureIndex: _currentMeasureIndex,
      startTick: _currentTickInMeasure,
      durationTicks: effectiveDuration,
      noteName: candidate.noteName,
    );

    // Avanzar tick métrico
    _currentTickInMeasure += effectiveDuration;
    if (_currentTickInMeasure >= maxTicksInMeasure) {
      _currentMeasureIndex++;
      _currentTickInMeasure = 0;
      // Añadir compás si no existe
      if (_currentMeasureIndex >= package.score.measures.length) {
        package = _operations.addMeasure(package: package);
      }
    }

    _activePackage = package;
    return package;
  }
}
