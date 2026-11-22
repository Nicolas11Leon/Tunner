import 'dart:math' as math;
import '../../score_editor/domain/score_editor_domain.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';

/// Cuantizador ritmico determinista que mapea duraciones continuas en sub-ticks
/// a las figuras canonicas de notacion musical en conservatorio.
class RhythmicQuantizer {
  /// Coleccion ordenada de duraciones canonicas soportadas en compases de 4/4 (en sub-ticks de semicorchea).
  static const List<int> canonicalDurations = [1, 2, 4, 8, 16];

  /// Cuantiza una duracion acustica observada en sub-ticks a la figura canonica mas apropiada.
  static int quantizeDuration(int observedTicks) {
    if (observedTicks <= 1) return 1;
    if (observedTicks == 2) return 2;
    if (observedTicks <= 5) return 4;
    if (observedTicks <= 11) return 8;
    return 16;
  }
}

/// Candidato acustico que acumula energia, duracion temporal real en ms y estabilidad para un ataque de nota.
class TranscriptionCandidate {
  final String noteName;
  final double frequencyHz;
  final int startTick;
  final int measureIndex;
  int durationTicks;
  int consecutiveFrames;
  double accumulatedMs;

  TranscriptionCandidate({
    required this.noteName,
    required this.frequencyHz,
    required this.startTick,
    required this.measureIndex,
    this.durationTicks = 1,
    this.consecutiveFrames = 1,
    this.accumulatedMs = 0.0,
  });
}

/// Motor de dominio para transcripcion de audio de microfono a partitura en tiempo real.
class LiveTranscriptionEngine {
  final int minFramesForOnset;
  final double minClarityThreshold;
  final double defaultFrameDurationMs;
  final int Function()? clockMsProvider;
  final ScoreEditorOperations _operations;

  bool _isTranscribing = false;
  SongPackage? _activePackage;
  int? _activeBpm;
  int _currentMeasureIndex = 0;
  int _currentTickInMeasure = 0;
  TranscriptionCandidate? _candidate;
  double _silenceAccumulatedMs = 0.0;
  double? _lastFrameTimestampMs;

  LiveTranscriptionEngine({
    this.minFramesForOnset = 2,
    this.minClarityThreshold = 0.80,
    this.defaultFrameDurationMs = 20.0,
    this.clockMsProvider,
    ScoreEditorOperations? operations,
  }) : _operations = operations ?? const ScoreEditorOperations();

  bool get isTranscribing => _isTranscribing;
  SongPackage? get activePackage => _activePackage;
  HierarchicalScore? get activeScore => _activePackage?.score;
  int get currentMeasureIndex => _currentMeasureIndex;
  int get currentTickInMeasure => _currentTickInMeasure;

  /// Inicia una sesion de transcripcion activa sobre una partitura o paquete base.
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

  /// Procesa un frame de estimacion de tono proveniente del detector acustico (MPM o YIN).
  /// Convierte la duracion acumulada real en milisegundos a sub-ticks segun el BPM activo.
  SongPackage? processPitchFrame({
    required double frequencyHz,
    required double clarity,
    required String noteName,
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

    final isVoiced = clarity >= minClarityThreshold && frequencyHz > 20.0 && noteName != "--";

    if (!isVoiced) {
      SongPackage? updated;
      if (_candidate != null) {
        if (_candidate!.consecutiveFrames >= minFramesForOnset) {
          updated = _finalizeSpan(
            durationMs: _candidate!.accumulatedMs,
            isRest: false,
            noteName: _candidate!.noteName,
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
      );
      _silenceAccumulatedMs = 0.0;
    } else if (_candidate == null) {
      _silenceAccumulatedMs = 0.0;
    }

    if (_candidate == null) {
      final initialTicks = math.max(1, (dtMs / msPerTick).round());
      _candidate = TranscriptionCandidate(
        noteName: noteName,
        frequencyHz: frequencyHz,
        startTick: _currentTickInMeasure,
        measureIndex: _currentMeasureIndex,
        durationTicks: initialTicks,
        consecutiveFrames: 1,
        accumulatedMs: dtMs,
      );
      return packageUpdate;
    }

    if (_candidate!.noteName == noteName) {
      _candidate!.accumulatedMs += dtMs;
      _candidate!.consecutiveFrames++;
      _candidate!.durationTicks = math.max(1, (_candidate!.accumulatedMs / msPerTick).round());
      return packageUpdate;
    } else {
      if (_candidate!.consecutiveFrames >= minFramesForOnset) {
        packageUpdate = _finalizeSpan(
          durationMs: _candidate!.accumulatedMs,
          isRest: false,
          noteName: _candidate!.noteName,
        );
      }
      _silenceAccumulatedMs = 0.0;
      final initialTicks = math.max(1, (dtMs / msPerTick).round());
      _candidate = TranscriptionCandidate(
        noteName: noteName,
        frequencyHz: frequencyHz,
        startTick: _currentTickInMeasure,
        measureIndex: _currentMeasureIndex,
        durationTicks: initialTicks,
        consecutiveFrames: 1,
        accumulatedMs: dtMs,
      );
      return packageUpdate;
    }
  }

  /// Finaliza la sesion de transcripcion y asegura que cualquier nota o silencio pendiente sea transcrita.
  SongPackage? stop() {
    if (!_isTranscribing) return _activePackage;
    _isTranscribing = false;

    SongPackage? updated = _activePackage;
    if (_candidate != null && _candidate!.consecutiveFrames >= minFramesForOnset) {
      updated = _finalizeSpan(
        durationMs: _candidate!.accumulatedMs,
        isRest: false,
        noteName: _candidate!.noteName,
      );
    } else if (_activePackage != null) {
      final bpm = math.max(20, _activeBpm ?? _activePackage!.defaultBpm);
      final msPerTick = 15000.0 / bpm;
      if (_silenceAccumulatedMs >= msPerTick * 0.5) {
        updated = _finalizeSpan(
          durationMs: _silenceAccumulatedMs,
          isRest: true,
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
    String noteName = '',
  }) {
    var package = _activePackage!;
    final bpm = math.max(20, _activeBpm ?? package.defaultBpm);
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

      package = _operations.insertOrUpdateNote(
        package: package,
        measureIndex: _currentMeasureIndex,
        startTick: _currentTickInMeasure,
        durationTicks: ticksToFit,
        noteName: isRest ? '--' : noteName,
      );

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
