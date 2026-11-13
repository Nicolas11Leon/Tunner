import 'dart:math' as math;
import '../../score_editor/domain/score_editor_domain.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import 'live_transcription_engine.dart';

/// Candidato acústico que acumula estabilidad y energía para un acorde o cluster polifónico.
class PolyphonicChordCandidate {
  final List<String> activeNoteNames;
  final int startTick;
  final int measureIndex;
  int durationTicks;
  int consecutiveFrames;

  PolyphonicChordCandidate({
    required List<String> activeNoteNames,
    required this.startTick,
    required this.measureIndex,
    this.durationTicks = 1,
    this.consecutiveFrames = 1,
  }) : activeNoteNames = List.unmodifiable(
          activeNoteNames.where((n) => n.isNotEmpty && n != '--').toSet().toList()..sort(),
        );

  /// Verifica si otro conjunto de notas coincide con el cluster armónico del candidato.
  bool matchesNoteNames(List<String> otherNotes) {
    final filteredOther =
        otherNotes.where((n) => n.isNotEmpty && n != '--').toSet();
    if (activeNoteNames.length != filteredOther.length) return false;
    return activeNoteNames.every(filteredOther.contains);
  }
}

/// Motor de dominio para transcripción polifónica en tiempo real de micrófono a partitura.
/// Transforma conjuntos de notas armónicas simultáneas detectadas en acordes rítmicamente
/// cuantizados sobre el árbol de partituras ScoreTree.
/// Pure Dart: Cero dependencias de Flutter UI.
class PolyphonicTranscriptionEngine {
  final int minFramesForOnset;
  final ScoreEditorOperations _operations;

  bool _isTranscribing = false;
  SongPackage? _activePackage;
  int _currentMeasureIndex = 0;
  int _currentTickInMeasure = 0;
  PolyphonicChordCandidate? _candidate;

  PolyphonicTranscriptionEngine({
    this.minFramesForOnset = 2,
    ScoreEditorOperations? operations,
  }) : _operations = operations ?? const ScoreEditorOperations();

  bool get isTranscribing => _isTranscribing;
  SongPackage? get activePackage => _activePackage;
  HierarchicalScore? get activeScore => _activePackage?.score;
  int get currentMeasureIndex => _currentMeasureIndex;
  int get currentTickInMeasure => _currentTickInMeasure;
  PolyphonicChordCandidate? get activeCandidate => _candidate;

  /// Inicia una sesión de transcripción polifónica activa.
  void start({
    required SongPackage initialPackage,
    int startMeasureIndex = 0,
    int startTick = 0,
  }) {
    _activePackage = initialPackage;
    _currentMeasureIndex = math.max(
      0,
      math.min(startMeasureIndex, initialPackage.score.measures.length - 1),
    );
    _currentTickInMeasure = math.max(0, math.min(startTick, 15));
    _candidate = null;
    _isTranscribing = true;
  }

  /// Procesa un frame polifónico con la lista de nombres de notas simultáneas activas.
  /// Retorna un [SongPackage] actualizado si se ha insertado o consolidado un acorde.
  SongPackage? processPolyphonicFrame({
    required List<String> noteNames,
    double energyRms = 0.1,
  }) {
    if (!_isTranscribing || _activePackage == null) return null;

    final validNotes =
        noteNames.where((n) => n.isNotEmpty && n != '--').toList();
    final isVoiced = validNotes.isNotEmpty && energyRms > 0.005;

    if (!isVoiced) {
      // Silencio o decaimiento acústico
      if (_candidate != null) {
        if (_candidate!.consecutiveFrames >= minFramesForOnset) {
          final updatedPackage = _finalizeCandidate(_candidate!);
          _candidate = null;
          return updatedPackage;
        } else {
          _candidate = null;
        }
      }
      return null;
    }

    // Ataque inicial de notas
    if (_candidate == null) {
      _candidate = PolyphonicChordCandidate(
        activeNoteNames: validNotes,
        startTick: _currentTickInMeasure,
        measureIndex: _currentMeasureIndex,
        durationTicks: 1,
        consecutiveFrames: 1,
      );
      return null;
    }

    if (_candidate!.matchesNoteNames(validNotes)) {
      // Mismo acorde o nota sostenida
      _candidate!.durationTicks++;
      _candidate!.consecutiveFrames++;
      return null;
    } else {
      // Cambio de acorde o movimiento de voces
      SongPackage? packageUpdate;
      if (_candidate!.consecutiveFrames >= minFramesForOnset) {
        packageUpdate = _finalizeCandidate(_candidate!);
      }
      _candidate = PolyphonicChordCandidate(
        activeNoteNames: validNotes,
        startTick: _currentTickInMeasure,
        measureIndex: _currentMeasureIndex,
        durationTicks: 1,
        consecutiveFrames: 1,
      );
      return packageUpdate;
    }
  }

  /// Detiene la transcripción polifónica y consolida cualquier acorde residual.
  SongPackage? stop() {
    if (!_isTranscribing) return _activePackage;
    _isTranscribing = false;

    if (_candidate != null &&
        _candidate!.consecutiveFrames >= minFramesForOnset) {
      final updatedPackage = _finalizeCandidate(_candidate!);
      _candidate = null;
      return updatedPackage;
    }
    _candidate = null;
    return _activePackage;
  }

  SongPackage _finalizeCandidate(PolyphonicChordCandidate candidate) {
    var package = _activePackage!;
    final quantizedDuration =
        RhythmicQuantizer.quantizeDuration(candidate.durationTicks);

    // Asegurar que el compás objetivo existe
    while (_currentMeasureIndex >= package.score.measures.length) {
      package = _operations.addMeasure(package: package);
    }

    final targetMeasure = package.score.measures[_currentMeasureIndex];
    final maxTicksInMeasure = targetMeasure.timeSignature.totalTicks;
    final safeDuration =
        math.min(quantizedDuration, maxTicksInMeasure - _currentTickInMeasure);
    final effectiveDuration = safeDuration > 0 ? safeDuration : 1;

    package = _operations.insertChordNotes(
      package: package,
      measureIndex: _currentMeasureIndex,
      startTick: _currentTickInMeasure,
      durationTicks: effectiveDuration,
      noteNames: candidate.activeNoteNames,
    );

    // Avanzar posición temporal métrica
    _currentTickInMeasure += effectiveDuration;
    if (_currentTickInMeasure >= maxTicksInMeasure) {
      _currentMeasureIndex++;
      _currentTickInMeasure = 0;
      if (_currentMeasureIndex >= package.score.measures.length) {
        package = _operations.addMeasure(package: package);
      }
    }

    _activePackage = package;
    return package;
  }
}
