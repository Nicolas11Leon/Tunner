import 'dart:typed_data';

import '../core/terminal/domain/i_terminal_feature_ports.dart';
import '../features/pedagogy/domain/ebbinghaus_spaced_repetition_engine.dart';
import '../features/pedagogy/domain/pedagogical_certificate_pdf_generator.dart';
import '../features/pedagogy/domain/vocal_stability_evaluator.dart';
import '../features/sheet_music/domain/score_playback_coordinator.dart';
import '../features/tuner_viewmodel.dart';

/// Adaptador de aplicación que conecta [ScorePlaybackCoordinator] al puerto puro [ITerminalScorePort].
class ScorePlaybackTerminalAdapter implements ITerminalScorePort {
  final ScorePlaybackCoordinator coordinator;

  const ScorePlaybackTerminalAdapter(this.coordinator);

  @override
  bool get isPlaying => coordinator.isPlaying;

  @override
  int get currentMeasureIndex => coordinator.currentMeasureIndex;

  @override
  int get currentSubTick => coordinator.currentSubTick;

  @override
  double get bpm => coordinator.bpm;

  @override
  set bpm(double value) => coordinator.bpm = value;

  @override
  bool get hasActiveScore => coordinator.activeScore != null;

  @override
  void startActiveScore() {
    final score = coordinator.activeScore;
    if (score != null) {
      coordinator.startPlayback(score: score);
    }
  }

  @override
  void pausePlayback() => coordinator.pausePlayback();

  @override
  void stopPlayback() => coordinator.stopPlayback();
}

/// Adaptador de aplicación que conecta [TunerViewModel] al puerto puro [ITerminalProjectPort].
class TunerProjectTerminalAdapter implements ITerminalProjectPort {
  final TunerViewModel viewModel;

  const TunerProjectTerminalAdapter(this.viewModel);

  @override
  String get activeTitle => viewModel.activePackage.title;

  @override
  String get activeComposer => viewModel.activePackage.composer;

  @override
  int get bpm => viewModel.bpm;

  @override
  void updateBpm(int bpm) => viewModel.updateBpm(bpm);

  @override
  Uint8List exportCurrentProjectToTunner({String? projectTitle}) {
    return viewModel.exportCurrentProjectToTunner(projectTitle: projectTitle);
  }
}

/// Adaptador de aplicación que conecta [EbbinghausSpacedRepetitionEngine] al puerto puro [ITerminalEarTrainingPort].
class EbbinghausTerminalAdapter implements ITerminalEarTrainingPort {
  final EbbinghausSpacedRepetitionEngine engine;

  EbbinghausTerminalAdapter({EbbinghausSpacedRepetitionEngine? engine})
      : engine = engine ?? EbbinghausSpacedRepetitionEngine();

  TerminalEarTrainingItemSnapshot _mapItem(EarTrainingItemEntity item, DateTime now) {
    return TerminalEarTrainingItemSnapshot(
      id: item.id,
      name: item.name,
      semitones: item.semitones,
      stabilityDays: item.stabilityDays,
      repetitions: item.repetitions,
      retentionPercent: item.retentionAt(now) * 100.0,
      nextReviewDate: item.nextReviewDate,
    );
  }

  @override
  List<TerminalEarTrainingItemSnapshot> getAllItems(DateTime now) {
    return engine.allItems.map((e) => _mapItem(e, now)).toList(growable: false);
  }

  @override
  List<TerminalEarTrainingItemSnapshot> getDueItems(DateTime now) {
    return engine.getDueItems(now: now).map((e) => _mapItem(e, now)).toList(growable: false);
  }

  @override
  TerminalEarTrainingItemSnapshot? getItem(String id, DateTime now) {
    final item = engine.getItem(id);
    return item != null ? _mapItem(item, now) : null;
  }

  @override
  double overallRetentionAverage(DateTime now) => engine.overallRetentionAverage(now);

  @override
  TerminalEarTrainingSubmitSnapshot submitAnswer(
    String itemId, {
    required bool isCorrect,
    required double centsError,
    required double responseTimeSeconds,
    required DateTime timestamp,
  }) {
    final result = engine.submitAnswer(
      itemId,
      isCorrect: isCorrect,
      centsError: centsError,
      responseTimeSeconds: responseTimeSeconds,
      timestamp: timestamp,
    );
    return TerminalEarTrainingSubmitSnapshot(
      updatedItem: _mapItem(result.updatedItem, timestamp),
      qualityGrade: result.qualityGrade,
      centsError: result.centsError,
      responseTimeSeconds: result.responseTimeSeconds,
      cognitiveFeedback: result.cognitiveFeedback,
    );
  }

  @override
  void reset() => engine.reset();
}

/// Adaptador de aplicación que conecta [VocalStabilityEvaluator] y [PedagogicalCertificatePdfGenerator] a [ITerminalVocalPedagogyPort].
class VocalPedagogyTerminalAdapter implements ITerminalVocalPedagogyPort {
  final VocalStabilityEvaluator evaluator;

  const VocalPedagogyTerminalAdapter({
    this.evaluator = const VocalStabilityEvaluator(),
  });

  @override
  TerminalVocalEvalSnapshot evaluate({
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
  }) {
    final eval = evaluator.evaluate(
      frequenciesHz: frequenciesHz,
      amplitudes: amplitudes,
      targetFrequencyHz: targetFrequencyHz,
    );
    return TerminalVocalEvalSnapshot(
      evaluationId: eval.evaluationId,
      targetFrequencyHz: eval.targetFrequencyHz,
      measuredMeanFrequencyHz: eval.measuredMeanFrequencyHz,
      centsDeviation: eval.centsDeviation,
      jitterPercent: eval.jitterPercent,
      shimmerPercent: eval.shimmerPercent,
      vibratoRateHz: eval.vibratoRateHz,
      vibratoDepthCents: eval.vibratoDepthCents,
      overallScore: eval.overallScore,
      classificationLabel: eval.classificationLabel,
      payloadHashSha256: eval.payloadHashSha256,
    );
  }

  @override
  Uint8List generateCertificatePdf({
    required String studentName,
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
  }) {
    final eval = evaluator.evaluate(
      frequenciesHz: frequenciesHz,
      amplitudes: amplitudes,
      targetFrequencyHz: targetFrequencyHz,
    );
    return PedagogicalCertificatePdfGenerator.generateCertificatePdf(
      studentName: studentName,
      evaluation: eval,
    );
  }
}
