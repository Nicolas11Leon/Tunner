import 'package:flutter/foundation.dart';

import '../../guided_lessons/domain/curated_guided_lessons.dart';
import '../../guided_lessons/domain/guided_lesson_entity.dart';
import '../../guided_lessons/domain/guided_lesson_evaluator.dart';
import '../../guided_lessons/domain/instrument_pedagogy_adapter_engine.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../modular_rack/domain/port_permission_broker.dart';
import '../../practice_evaluator/domain/note_evaluation_entity.dart';
import '../../practice_recorder/domain/multitrack_session_entity.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/minus_one_orchestrator.dart';
import '../../song_library/domain/minus_one_session_entity.dart';
import '../../song_library/domain/song_decomposer_service.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../tuner/domain/hardware_audio_endpoint.dart';
import '../domain/autotune_config_entity.dart';
import '../domain/scale_quantizer.dart';
import '../domain/vocal_autotune_processor.dart';
import '../domain/vocal_score_converter.dart';

/// Controlador cohesivo para lecciones guiadas, Vocal Auto-Tune (TD-PSOLA),
/// conversión vocal a partitura, sesiones Minus-One y arbitraje de seguridad auditiva.
class VocalPedagogyController {
  final GuidedLessonEvaluator _guidedLessonEvaluator;
  final InstrumentPedagogyAdapterEngine _pedagogyAdapter;
  final VocalAutoTuneProcessor _autoTuneProcessor;
  final VocalScoreConverter _vocalScoreConverter;
  final MinusOneOrchestrator _minusOneOrchestrator;
  final PortPermissionBroker _portPermissionBroker;
  final VoidCallback _onNotify;
  final VoidCallback _onAutoSave;

  DateTime? _lastLessonFrameTime;
  ScaleQuantizationResult _lastAutoTuneResult = ScaleQuantizationResult.unvoiced(0.0);
  SongPackage? _lastConvertedVocalPackage;
  VocalScoreConversionResult? _lastVocalConversionResult;
  MinusOneSessionEntity? _activeMinusOneSession;
  bool _isHeadphonesConnected = false;
  List<HardwareAudioEndpoint> _hardwareAudioEndpoints = const [];

  VocalPedagogyController({
    required GuidedLessonEvaluator guidedLessonEvaluator,
    required VocalAutoTuneProcessor autoTuneProcessor,
    required VoidCallback onNotify,
    required VoidCallback onAutoSave,
    InstrumentPedagogyAdapterEngine pedagogyAdapter = const InstrumentPedagogyAdapterEngine(),
    VocalScoreConverter vocalScoreConverter = const VocalScoreConverter(),
    MinusOneOrchestrator minusOneOrchestrator = const MinusOneOrchestrator(),
    PortPermissionBroker portPermissionBroker = const PortPermissionBroker(),
  })  : _guidedLessonEvaluator = guidedLessonEvaluator,
        _autoTuneProcessor = autoTuneProcessor,
        _pedagogyAdapter = pedagogyAdapter,
        _vocalScoreConverter = vocalScoreConverter,
        _minusOneOrchestrator = minusOneOrchestrator,
        _portPermissionBroker = portPermissionBroker,
        _onNotify = onNotify,
        _onAutoSave = onAutoSave;

  GuidedLessonProgressEntity? get activeLessonProgress => _guidedLessonEvaluator.activeProgress;
  bool get hasActiveGuidedLesson => _guidedLessonEvaluator.hasActiveLesson;
  VocalAutoTuneProcessor get autoTuneProcessor => _autoTuneProcessor;
  AutoTuneConfigEntity get autoTuneConfig => _autoTuneProcessor.config;
  bool get isAutoTuneActive => _autoTuneProcessor.config.isEnabled;
  ScaleQuantizationResult get lastAutoTuneResult => _lastAutoTuneResult;
  SongPackage? get lastConvertedVocalPackage => _lastConvertedVocalPackage;
  VocalScoreConversionResult? get lastVocalConversionResult => _lastVocalConversionResult;
  MinusOneSessionEntity? get activeMinusOneSession => _activeMinusOneSession;
  bool get isMinusOneActive => _activeMinusOneSession?.isMinusOneActive ?? false;
  bool get isHeadphonesConnected => _isHeadphonesConnected;
  List<HardwareAudioEndpoint> get hardwareAudioEndpoints => _hardwareAudioEndpoints;

  PortPermissionBroker get portPermissionBroker => _portPermissionBroker;

  List<GuidedLessonEntity> availableGuidedLessons(InstrumentProfileEntity activeInstrument) =>
      _pedagogyAdapter.adaptLessons(CuratedGuidedLessons.all, activeInstrument);

  void processPitchFrame({
    required double pitchHz,
    required double cents,
    required String noteName,
  }) {
    if (_autoTuneProcessor.config.isEnabled && pitchHz > 20.0) {
      _lastAutoTuneResult = _autoTuneProcessor.evaluatePitchFrame(
        detectedPitchHz: pitchHz,
        deltaSeconds: 0.05,
      );
    }
    if (_guidedLessonEvaluator.hasActiveLesson && pitchHz > 20.0) {
      final now = DateTime.now();
      final deltaSec = _lastLessonFrameTime == null
          ? 0.05
          : (now.difference(_lastLessonFrameTime!).inMilliseconds / 1000.0).clamp(0.01, 0.25);
      _lastLessonFrameTime = now;
      _guidedLessonEvaluator.evaluateSample(
        frequencyHz: pitchHz,
        cents: cents,
        detectedNoteName: noteName,
        deltaSeconds: deltaSec,
      );
    }
  }

  void resetOnSilence() {
    _lastLessonFrameTime = null;
    if (_autoTuneProcessor.config.isEnabled) {
      _lastAutoTuneResult = ScaleQuantizationResult.unvoiced(0.0);
    }
  }

  void adaptActiveLessonToInstrument(
    InstrumentProfileEntity activeInstrument, {
    required double toleranceCents,
  }) {
    if (hasActiveGuidedLesson && _guidedLessonEvaluator.activeProgress != null) {
      final currentLesson = _guidedLessonEvaluator.activeProgress!.lesson;
      final original = CuratedGuidedLessons.all.firstWhere(
        (l) => currentLesson.id.startsWith(l.id),
        orElse: () => currentLesson,
      );
      final adapted = _pedagogyAdapter.adaptLesson(original, activeInstrument);
      _guidedLessonEvaluator.startLesson(adapted, customToleranceCents: toleranceCents);
    }
  }

  void startGuidedLesson(GuidedLessonEntity lesson, {required double toleranceCents}) {
    _lastLessonFrameTime = null;
    _guidedLessonEvaluator.startLesson(
      lesson,
      customToleranceCents: toleranceCents,
    );
    _onNotify();
  }

  void cancelGuidedLesson() {
    _lastLessonFrameTime = null;
    _guidedLessonEvaluator.cancelLesson();
    _onNotify();
  }

  void jumpToLessonStep(int stepIndex) {
    _lastLessonFrameTime = null;
    _guidedLessonEvaluator.jumpToStep(stepIndex);
    _onNotify();
  }

  SongPackage adaptSongPackageToActiveInstrument(
    SongPackage package,
    InstrumentProfileEntity activeInstrument,
  ) {
    return SongDecomposerService.adaptSongPackageToInstrument(package, activeInstrument);
  }

  void toggleAutoTune() {
    final newConfig = _autoTuneProcessor.config.copyWith(
      isEnabled: !_autoTuneProcessor.config.isEnabled,
    );
    _autoTuneProcessor.updateConfig(newConfig);
    _onNotify();
    _onAutoSave();
  }

  void updateAutoTuneConfig(AutoTuneConfigEntity config) {
    _autoTuneProcessor.updateConfig(config);
    _onNotify();
    _onAutoSave();
  }

  ({MultiTrackSessionEntity session, PracticeTakeEntity tunedTake})? applyAutoTuneToRecordingTake({
    required MultiTrackSessionEntity session,
    required String takeId,
  }) {
    final takeIndex = session.takes.indexWhere((t) => t.id == takeId);
    if (takeIndex == -1) return null;

    final originalTake = session.takes[takeIndex];
    final tunedTake = _autoTuneProcessor.processPracticeTake(take: originalTake);
    final updatedTakes = List<PracticeTakeEntity>.from(session.takes)..add(tunedTake);
    return (
      session: session.copyWith(takes: updatedTakes),
      tunedTake: tunedTake,
    );
  }

  VocalScoreConversionResult? convertActiveRecordingToScorePackage({
    required MultiTrackSessionEntity session,
    required List<TimedPitchSample> currentPitchTrack,
    required int bpm,
    required TimeSignature timeSignature,
    String? takeId,
    bool preferCorrectedPitch = true,
  }) {
    List<TimedPitchSample>? samples;
    String title = 'Toma Vocal en Vivo';

    if (takeId != null) {
      final index = session.takes.indexWhere((t) => t.id == takeId);
      if (index != -1) {
        final take = session.takes[index];
        samples = take.pitchTrack;
        title = 'Toma Afinada: ${take.name}';
      }
    }

    if (samples == null || samples.isEmpty) {
      if (currentPitchTrack.isNotEmpty) {
        samples = List<TimedPitchSample>.from(currentPitchTrack);
      } else if (session.takes.isNotEmpty) {
        final lastTake = session.takes.last;
        samples = lastTake.pitchTrack;
        title = 'Toma Afinada: ${lastTake.name}';
      }
    }

    if (samples == null || samples.isEmpty) return null;

    final result = _vocalScoreConverter.convertTrackToScore(
      pitchTrack: samples,
      title: title,
      bpm: bpm,
      timeSignature: timeSignature,
      preferCorrectedPitch: preferCorrectedPitch,
    );

    _lastVocalConversionResult = result;
    _lastConvertedVocalPackage = result.package;
    return result;
  }

  SongPackage snapActiveScoreToScale({
    required SongPackage activePackage,
    int? rootKey,
    VocalScaleType? scaleType,
  }) {
    final effectiveRoot = rootKey ?? _autoTuneProcessor.config.scaleRoot;
    final effectiveScale = scaleType ?? _autoTuneProcessor.config.scaleType;

    return _vocalScoreConverter.snapToScale(
      package: activePackage,
      rootKey: effectiveRoot,
      scaleType: effectiveScale,
    );
  }

  MixerConsoleEntity toggleMinusOneMode({
    required SongPackage activePackage,
    required InstrumentProfileEntity activeInstrument,
    required MixerConsoleEntity mixerConsole,
    String? targetTrackId,
  }) {
    MixerConsoleEntity nextMixer;
    if (_activeMinusOneSession != null && _activeMinusOneSession!.isMinusOneActive) {
      final userTrack = _activeMinusOneSession!.userTrackId;
      nextMixer = _minusOneOrchestrator.restoreFullEnsembleMixer(mixerConsole, userTrack);
      _activeMinusOneSession = _activeMinusOneSession!.copyWith(
        isMinusOneActive: false,
        isMutedUserTrack: false,
      );
    } else {
      final trackId = targetTrackId ??
          _minusOneOrchestrator.detectUserTrack(activePackage, activeInstrument.id);
      _activeMinusOneSession = _minusOneOrchestrator.createSession(
        package: activePackage,
        userTrackId: trackId,
        isMinusOneActive: true,
        isMutedUserTrack: true,
      );
      nextMixer = _minusOneOrchestrator.configureMinusOneMixer(
        mixerConsole,
        trackId,
        muteUserTrack: true,
      );
    }
    return nextMixer;
  }

  MixerConsoleEntity setMinusOneUserTrack({
    required SongPackage activePackage,
    required MixerConsoleEntity mixerConsole,
    required String trackId,
  }) {
    var workingMixer = mixerConsole;
    if (_activeMinusOneSession != null && _activeMinusOneSession!.userTrackId != trackId) {
      workingMixer = _minusOneOrchestrator.restoreFullEnsembleMixer(
        workingMixer,
        _activeMinusOneSession!.userTrackId,
      );
    }
    final guideVol = _activeMinusOneSession?.guideTrackVolume ?? 0.0;
    _activeMinusOneSession = _minusOneOrchestrator.createSession(
      package: activePackage,
      userTrackId: trackId,
      isMinusOneActive: true,
      isMutedUserTrack: guideVol <= 0.0,
      guideTrackVolume: guideVol,
    );
    return _minusOneOrchestrator.configureMinusOneMixer(
      workingMixer,
      trackId,
      muteUserTrack: guideVol <= 0.0,
      guideVolume: guideVol,
    );
  }

  MixerConsoleEntity? setMinusOneGuideVolume({
    required MixerConsoleEntity mixerConsole,
    required double volume,
  }) {
    if (_activeMinusOneSession == null) return null;
    _activeMinusOneSession = _activeMinusOneSession!.copyWith(
      guideTrackVolume: volume,
      isMutedUserTrack: volume <= 0.0,
    );
    return _minusOneOrchestrator.configureMinusOneMixer(
      mixerConsole,
      _activeMinusOneSession!.userTrackId,
      muteUserTrack: volume <= 0.0,
      guideVolume: volume,
    );
  }

  void recordMinusOneEvaluation(NoteEvaluationEntity evaluation) {
    if (_activeMinusOneSession == null || !_activeMinusOneSession!.isMinusOneActive) return;
    _activeMinusOneSession = _minusOneOrchestrator.recordEvaluation(
      _activeMinusOneSession!,
      evaluation,
    );
    _onNotify();
  }

  void resetMinusOneEvaluations() {
    if (_activeMinusOneSession != null) {
      _activeMinusOneSession = _activeMinusOneSession!.copyWith(evaluations: const []);
      _onNotify();
    }
  }

  void setHeadphonesConnected(bool connected) {
    if (_isHeadphonesConnected == connected) return;
    _isHeadphonesConnected = connected;
    _onNotify();
  }

  void updateHardwareEndpoints(List<HardwareAudioEndpoint> endpoints) {
    _hardwareAudioEndpoints = List.unmodifiable(endpoints);
    final hasSafeOutput = endpoints.any((e) => e.isOutput && e.isFeedbackSafe);
    if (hasSafeOutput != _isHeadphonesConnected) {
      _isHeadphonesConnected = hasSafeOutput;
    }
    _onNotify();
  }

  String getLiveMonitoringSafetyWarning() {
    return _portPermissionBroker.getSafetyWarningReason(
      isHeadphonesConnected: _isHeadphonesConnected,
      isLiveMonitoringRequested: true,
    );
  }
}
