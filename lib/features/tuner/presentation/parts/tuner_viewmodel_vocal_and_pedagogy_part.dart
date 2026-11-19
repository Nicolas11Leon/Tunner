part of '../../../tuner_viewmodel.dart';

extension TunerViewModelVocalAndPedagogyPart on TunerViewModel {
  // --- Métodos de Lecciones Guiadas Interactivas ---

  GuidedLessonProgressEntity? get activeLessonProgress => _guidedLessonEvaluator.activeProgress;
  bool get hasActiveGuidedLesson => _guidedLessonEvaluator.hasActiveLesson;
  List<GuidedLessonEntity> get availableGuidedLessons =>
      _pedagogyAdapter.adaptLessons(CuratedGuidedLessons.all, _activeInstrument);

  /// Inicia una nueva sesión de práctica guiada para la lección seleccionada.
  void startGuidedLesson(GuidedLessonEntity lesson) {
    _lastLessonFrameTime = null;
    _guidedLessonEvaluator.startLesson(
      lesson,
      customToleranceCents: centsTolerance,
    );
    notifyListeners();
  }

  /// Cancela o cierra la lección guiada activa.
  void cancelGuidedLesson() {
    _lastLessonFrameTime = null;
    _guidedLessonEvaluator.cancelLesson();
    notifyListeners();
  }

  /// Salta manualmente a un paso específico dentro de la lección activa.
  void jumpToLessonStep(int stepIndex) {
    _lastLessonFrameTime = null;
    _guidedLessonEvaluator.jumpToStep(stepIndex);
    notifyListeners();
  }

  /// Adapta cualquier paquete de canción a la tesitura ergonómica del instrumento activo.
  SongPackage adaptSongPackageToActiveInstrument(SongPackage package) {
    return SongDecomposerService.adaptSongPackageToInstrument(package, _activeInstrument);
  }

  // --- Getters y Métodos de Vocal AutoTune ---
  VocalAutoTuneProcessor get autoTuneProcessor => _autoTuneProcessor;
  AutoTuneConfigEntity get autoTuneConfig => _autoTuneProcessor.config;
  bool get isAutoTuneActive => _autoTuneProcessor.config.isEnabled;
  ScaleQuantizationResult get lastAutoTuneResult => _lastAutoTuneResult;

  /// Alterna el estado activo de corrección vocal en tiempo real.
  void toggleAutoTune() {
    final newConfig = _autoTuneProcessor.config.copyWith(
      isEnabled: !_autoTuneProcessor.config.isEnabled,
    );
    _autoTuneProcessor.updateConfig(newConfig);
    notifyListeners();
    _triggerAutoSave();
  }

  /// Actualiza la configuración de afinación vocal (escala, tónica, retune speed, mezcla).
  void updateAutoTuneConfig(AutoTuneConfigEntity config) {
    _autoTuneProcessor.updateConfig(config);
    notifyListeners();
    _triggerAutoSave();
  }

  /// Aplica AutoTune en post-producción a una toma grabada en la consola multitrack.
  PracticeTakeEntity? applyAutoTuneToRecordingTake(String takeId) {
    final takeIndex = _multiTrackSession.takes.indexWhere((t) => t.id == takeId);
    if (takeIndex == -1) return null;

    final originalTake = _multiTrackSession.takes[takeIndex];
    final tunedTake = _autoTuneProcessor.processPracticeTake(take: originalTake);

    final updatedTakes = List<PracticeTakeEntity>.from(_multiTrackSession.takes)..add(tunedTake);
    _multiTrackSession = _multiTrackSession.copyWith(takes: updatedTakes);
    notifyListeners();
    _triggerAutoSave();
    return tunedTake;
  }

  /// Convierte la toma de grabación activa a un SongPackage editable en el ScoreEditor (UC-60).
  VocalScoreConversionResult? convertActiveRecordingToScorePackage({
    String? takeId,
    bool preferCorrectedPitch = true,
    bool autoLoadAsActivePackage = true,
  }) {
    List<TimedPitchSample>? samples;
    String title = 'Toma Vocal en Vivo';

    if (takeId != null) {
      final index = _multiTrackSession.takes.indexWhere((t) => t.id == takeId);
      if (index != -1) {
        final take = _multiTrackSession.takes[index];
        samples = take.pitchTrack;
        title = 'Toma Afinada: ${take.name}';
      }
    }

    if (samples == null || samples.isEmpty) {
      if (_currentPitchTrack.isNotEmpty) {
        samples = List<TimedPitchSample>.from(_currentPitchTrack);
      } else if (_multiTrackSession.takes.isNotEmpty) {
        final lastTake = _multiTrackSession.takes.last;
        samples = lastTake.pitchTrack;
        title = 'Toma Afinada: ${lastTake.name}';
      }
    }

    if (samples == null || samples.isEmpty) return null;

    final result = _vocalScoreConverter.convertTrackToScore(
      pitchTrack: samples,
      title: title,
      bpm: _bpm,
      timeSignature: currentMeasureTimeSignature,
      preferCorrectedPitch: preferCorrectedPitch,
    );

    _lastVocalConversionResult = result;
    _lastConvertedVocalPackage = result.package;

    if (autoLoadAsActivePackage) {
      _scoreHistory.recordState(_activePackage);
      _activePackage = result.package;
      _currentMeasureIndex = 0;
      _currentSubTick = -1;
      _measureHistory.clear();
    }

    notifyListeners();
    return result;
  }

  /// Cuantiza todas las notas de la partitura activa a la escala musical actual (Melodyne 1-Tap Snap).
  void snapActiveScoreToScale({
    int? rootKey,
    VocalScaleType? scaleType,
  }) {
    final effectiveRoot = rootKey ?? _autoTuneProcessor.config.scaleRoot;
    final effectiveScale = scaleType ?? _autoTuneProcessor.config.scaleType;

    _scoreHistory.recordState(_activePackage);
    final snapped = _vocalScoreConverter.snapToScale(
      package: _activePackage,
      rootKey: effectiveRoot,
      scaleType: effectiveScale,
    );

    _activePackage = snapped;
    notifyListeners();
    _triggerAutoSave();
  }

  // =========================================================================
  // Ensamble Virtual Minus-One y Descomposición de Partituras (UC-61)
  // =========================================================================

  /// Conmuta la activación del modo de práctica Minus-One para la obra activa.
  void toggleMinusOneMode({String? targetTrackId}) {
    if (_activeMinusOneSession != null && _activeMinusOneSession!.isMinusOneActive) {
      final userTrack = _activeMinusOneSession!.userTrackId;
      _mixerConsole = _minusOneOrchestrator.restoreFullEnsembleMixer(_mixerConsole, userTrack);
      _activeMinusOneSession = _activeMinusOneSession!.copyWith(
        isMinusOneActive: false,
        isMutedUserTrack: false,
      );
    } else {
      final trackId = targetTrackId ??
          _minusOneOrchestrator.detectUserTrack(_activePackage, _activeInstrument.id);
      _activeMinusOneSession = _minusOneOrchestrator.createSession(
        package: _activePackage,
        userTrackId: trackId,
        isMinusOneActive: true,
        isMutedUserTrack: true,
      );
      _mixerConsole = _minusOneOrchestrator.configureMinusOneMixer(
        _mixerConsole,
        trackId,
        muteUserTrack: true,
      );
    }
    notifyListeners();
  }

  /// Asigna qué pista de la partitura corresponde al instrumento del usuario.
  void setMinusOneUserTrack(String trackId) {
    if (_activeMinusOneSession != null && _activeMinusOneSession!.userTrackId != trackId) {
      _mixerConsole = _minusOneOrchestrator.restoreFullEnsembleMixer(
        _mixerConsole,
        _activeMinusOneSession!.userTrackId,
      );
    }
    final guideVol = _activeMinusOneSession?.guideTrackVolume ?? 0.0;
    _activeMinusOneSession = _minusOneOrchestrator.createSession(
      package: _activePackage,
      userTrackId: trackId,
      isMinusOneActive: true,
      isMutedUserTrack: guideVol <= 0.0,
      guideTrackVolume: guideVol,
    );
    _mixerConsole = _minusOneOrchestrator.configureMinusOneMixer(
      _mixerConsole,
      trackId,
      muteUserTrack: guideVol <= 0.0,
      guideVolume: guideVol,
    );
    notifyListeners();
  }

  /// Ajusta el volumen de la pista guía del usuario durante el modo Minus-One (0.0 = silencio total).
  void setMinusOneGuideVolume(double volume) {
    if (_activeMinusOneSession == null) return;
    _activeMinusOneSession = _activeMinusOneSession!.copyWith(
      guideTrackVolume: volume,
      isMutedUserTrack: volume <= 0.0,
    );
    _mixerConsole = _minusOneOrchestrator.configureMinusOneMixer(
      _mixerConsole,
      _activeMinusOneSession!.userTrackId,
      muteUserTrack: volume <= 0.0,
      guideVolume: volume,
    );
    notifyListeners();
  }

  /// Registra una evaluación acústica en tiempo real en la sesión Minus-One activa.
  void recordMinusOneEvaluation(NoteEvaluationEntity evaluation) {
    if (_activeMinusOneSession == null || !_activeMinusOneSession!.isMinusOneActive) return;
    _activeMinusOneSession = _minusOneOrchestrator.recordEvaluation(
      _activeMinusOneSession!,
      evaluation,
    );
    notifyListeners();
  }

  /// Reinicia las evaluaciones acumuladas en la sesión Minus-One activa.
  void resetMinusOneEvaluations() {
    if (_activeMinusOneSession != null) {
      _activeMinusOneSession = _activeMinusOneSession!.copyWith(evaluations: const []);
      notifyListeners();
    }
  }

  // =========================================================================
  // Arbitraje de Puertos de Hardware y Seguridad Acústica (UC-62)
  // =========================================================================

  /// Actualiza el estado de conexión de auriculares o monitores externos desacoplados.
  void setHeadphonesConnected(bool connected) {
    if (_isHeadphonesConnected == connected) return;
    _isHeadphonesConnected = connected;
    notifyListeners();
  }

  /// Actualiza la lista de transductores y puertos de audio físicos detectados.
  void updateHardwareEndpoints(List<HardwareAudioEndpoint> endpoints) {
    _hardwareAudioEndpoints = List.unmodifiable(endpoints);
    final hasSafeOutput = endpoints.any((e) => e.isOutput && e.isFeedbackSafe);
    if (hasSafeOutput != _isHeadphonesConnected) {
      _isHeadphonesConnected = hasSafeOutput;
    }
    notifyListeners();
  }

  /// Retorna un mensaje de advertencia si se intenta activar monitoreo en vivo sin auriculares.
  String getLiveMonitoringSafetyWarning() {
    return _portPermissionBroker.getSafetyWarningReason(
      isHeadphonesConnected: _isHeadphonesConnected,
      isLiveMonitoringRequested: true,
    );
  }

}
