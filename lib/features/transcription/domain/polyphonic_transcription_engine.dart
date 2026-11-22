import 'dart:math' as math;
import '../../score_editor/domain/score_editor_domain.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import 'live_transcription_engine.dart';

/// Candidato acustico que acumula estabilidad, duracion real en ms y energia para un acorde o cluster polifonico.
class PolyphonicChordCandidate {
  final List<String> activeNoteNames;
  final int startTick;
  final int measureIndex;
  int durationTicks;
  int consecutiveFrames;
  double accumulatedMs;

  PolyphonicChordCandidate({
    required List<String> activeNoteNames,
    required this.startTick,
    required this.measureIndex,
    this.durationTicks = 1,
    this.consecutiveFrames = 1,
    this.accumulatedMs = 0.0,
  }) : activeNoteNames = List.unmodifiable(
          activeNoteNames.where((n) => n.isNotEmpty && n != '--').toSet().toList()..sort(),
        );

  /// Verifica si otro conjunto de notas coincide con el cluster armonico del candidato.
  bool matchesNoteNames(List<String> otherNotes) {
    final filteredOther =
        otherNotes.where((n) => n.isNotEmpty && n != '--').toSet();
    if (activeNoteNames.length != filteredOther.length) return false;
    return activeNoteNames.every(filteredOther.contains);
  }
}

/// Motor de dominio para transcripcion polifonica en tiempo real de microfono a partitura.
/// Transforma conjuntos de notas armonicas simultaneas detectadas en acordes ritmicamente
/// cuantizados sobre el arbol de partituras ScoreTree.
/// Pure Dart: Cero dependencias de Flutter UI.
class PolyphonicTranscriptionEngine {
  final int minFramesForOnset;
  final double defaultFrameDurationMs;
  final int Function()? clockMsProvider;
  final ScoreEditorOperations _operations;

  bool _isTranscribing = false;
  SongPackage? _activePackage;
  int? _activeBpm;
  int _currentMeasureIndex = 0;
  int _currentTickInMeasure = 0;
  PolyphonicChordCandidate? _candidate;
  double _silenceAccumulatedMs = 0.0;
  double? _lastFrameTimestampMs;

  PolyphonicTranscriptionEngine({
    this.minFramesForOnset = 2,
    this.defaultFrameDurationMs = 20.0,
    this.clockMsProvider,
    ScoreEditorOperations? operations,
  }) : _operations = operations ?? const ScoreEditorOperations();

  bool get isTranscribing => _isTranscribing;
  SongPackage? get activePackage => _activePackage;
  HierarchicalScore? get activeScore => _activePackage?.score;
  int get currentMeasureIndex => _currentMeasureIndex;
  int get currentTickInMeasure => _currentTickInMeasure;
  PolyphonicChordCandidate? get activeCandidate => _candidate;

  /// Inicia una sesion de transcripcion polifonica activa.
  void start({
    required SongPackage initialPackage,
    int startMeasureIndex = 0,
    int startTick = 0,
    int? bpm,
  }) {
    _activePackage = initialPackage;
    _activeBpm = bpm;
    _currentMeasureIndex = initialPackage.score.measures.isEmpty
        ? 0
        : startMeasureIndex.clamp(0, initialPackage.score.measures.length - 1);
    final maxTicks = initialPackage.score.measures.isNotEmpty
        ? initialPackage.score.measures[_currentMeasureIndex].timeSignature.totalTicks
        : 16;
    _currentTickInMeasure = startTick.clamp(0, math.max(0, maxTicks - 1));
    _candidate = null;
    _silenceAccumulatedMs = 0.0;
    _lastFrameTimestampMs = clockMsProvider?.call().toDouble();
    _isTranscribing = true;
  }

  /// Procesa un frame polifonico con la lista de nombres de notas simultaneas activas.
  /// Convierte la duracion acumulada en milisegundos a sub-ticks segun el BPM activo.
  SongPackage? processPolyphonicFrame({
    required List<String> noteNames,
    double energyRms = 0.1,
    double? frameDurationMs,
    double? timestampMs,
  }) {
    if (!_isTranscribing || _activePackage == null) return null;

    double dtMs;
    if (frameDurationMs != null) {
      dtMs = math.max(1.0, frameDurationMs);
    } else {
      final effectiveTs = timestampMs ?? clockMsProvider?.call().toDouble();
      if (effectiveTs != null && _lastFrameTimestampMs != null) {
        dtMs = (effectiveTs - _lastFrameTimestampMs!).clamp(1.0, 2000.0);
      } else {
        dtMs = defaultFrameDurationMs;
      }
      if (effectiveTs != null) {
        _lastFrameTimestampMs = effectiveTs;
      }
    }
    final bpm = math.max(20, _activeBpm ?? _activePackage!.defaultBpm);
    final msPerTick = 15000.0 / bpm;

    final validNotes =
        noteNames.where((n) => n.isNotEmpty && n != '--').toList();
    final isVoiced = validNotes.isNotEmpty && energyRms > 0.005;

    if (!isVoiced) {
      SongPackage? updated;
      if (_candidate != null) {
        if (_candidate!.consecutiveFrames >= minFramesForOnset) {
          updated = _finalizeSpan(
            durationMs: _candidate!.accumulatedMs,
            isRest: false,
            noteNames: _candidate!.activeNoteNames,
          );
        }
        _candidate = null;
      }
      _silenceAccumulatedMs += dtMs;
      return updated;
    }

    SongPackage? packageUpdate;
    if (_silenceAccumulatedMs >= msPerTick * 0.5 && _candidate == null) {
      packageUpdate = _finalizeSpan(
        durationMs: _silenceAccumulatedMs,
        isRest: true,
        noteNames: const [],
      );
      _silenceAccumulatedMs = 0.0;
    } else if (_candidate == null) {
      _silenceAccumulatedMs = 0.0;
    }

    if (_candidate == null) {
      final initialTicks = math.max(1, (dtMs / msPerTick).round());
      _candidate = PolyphonicChordCandidate(
        activeNoteNames: validNotes,
        startTick: _currentTickInMeasure,
        measureIndex: _currentMeasureIndex,
        durationTicks: initialTicks,
        consecutiveFrames: 1,
        accumulatedMs: dtMs,
      );
      return packageUpdate;
    }

    if (_candidate!.matchesNoteNames(validNotes)) {
      _candidate!.accumulatedMs += dtMs;
      _candidate!.consecutiveFrames++;
      _candidate!.durationTicks = math.max(1, (_candidate!.accumulatedMs / msPerTick).round());
      return packageUpdate;
    } else {
      if (_candidate!.consecutiveFrames >= minFramesForOnset) {
        packageUpdate = _finalizeSpan(
          durationMs: _candidate!.accumulatedMs,
          isRest: false,
          noteNames: _candidate!.activeNoteNames,
        );
      }
      _silenceAccumulatedMs = 0.0;
      final initialTicks = math.max(1, (dtMs / msPerTick).round());
      _candidate = PolyphonicChordCandidate(
        activeNoteNames: validNotes,
        startTick: _currentTickInMeasure,
        measureIndex: _currentMeasureIndex,
        durationTicks: initialTicks,
        consecutiveFrames: 1,
        accumulatedMs: dtMs,
      );
      return packageUpdate;
    }
  }

  /// Detiene la transcripcion polifonica y consolida cualquier acorde o silencio residual.
  SongPackage? stop() {
    if (!_isTranscribing) return _activePackage;
    _isTranscribing = false;

    SongPackage? updated = _activePackage;
    if (_candidate != null &&
        _candidate!.consecutiveFrames >= minFramesForOnset) {
      updated = _finalizeSpan(
        durationMs: _candidate!.accumulatedMs,
        isRest: false,
        noteNames: _candidate!.activeNoteNames,
      );
    } else if (_activePackage != null) {
      final bpm = math.max(20, _activePackage!.defaultBpm);
      final msPerTick = 15000.0 / bpm;
      if (_silenceAccumulatedMs >= msPerTick * 0.5) {
        updated = _finalizeSpan(
          durationMs: _silenceAccumulatedMs,
          isRest: true,
          noteNames: const [],
        );
      }
    }
    _candidate = null;
    _silenceAccumulatedMs = 0.0;
    return updated;
  }

  SongPackage _finalizeSpan({
    required double durationMs,
    required bool isRest,
    required List<String> noteNames,
  }) {
    var package = _activePackage!;
    final bpm = math.max(20, package.defaultBpm);
    final msPerTick = 15000.0 / bpm;
    final rawTicks = math.max(1, (durationMs / msPerTick).round());
    int remainingTicks = RhythmicQuantizer.quantizeDuration(rawTicks);

    while (remainingTicks > 0) {
      while (_currentMeasureIndex >= package.score.measures.length) {
        package = _operations.addMeasure(package: package);
      }

      final targetMeasure = package.score.measures[_currentMeasureIndex];
      final maxTicksInMeasure = targetMeasure.timeSignature.totalTicks;
      final spaceInMeasure = math.max(1, maxTicksInMeasure - _currentTickInMeasure);
      final ticksToFit = math.min(remainingTicks, spaceInMeasure);

      if (isRest || noteNames.isEmpty) {
        package = _operations.insertOrUpdateNote(
          package: package,
          measureIndex: _currentMeasureIndex,
          startTick: _currentTickInMeasure,
          durationTicks: ticksToFit,
          noteName: '--',
        );
      } else {
        package = _operations.insertChordNotes(
          package: package,
          measureIndex: _currentMeasureIndex,
          startTick: _currentTickInMeasure,
          durationTicks: ticksToFit,
          noteNames: noteNames,
        );
      }

      _currentTickInMeasure += ticksToFit;
      remainingTicks -= ticksToFit;

      if (_currentTickInMeasure >= maxTicksInMeasure) {
        _currentMeasureIndex++;
        _currentTickInMeasure = 0;
        if (_currentMeasureIndex >= package.score.measures.length) {
          package = _operations.addMeasure(package: package);
        }
      }
    }

    _activePackage = package;
    return package;
  }
}
