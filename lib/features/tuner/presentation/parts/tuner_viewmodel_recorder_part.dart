part of '../../../tuner_viewmodel.dart';

extension TunerViewModelRecorderPart on TunerViewModel {
  // --- Métodos de Grabación de Práctica & Auto-Escucha (Loopback) ---

  Future<String> _getRecordingPath() async {
    if (_recordingPathProvider != null) {
      return _recordingPathProvider();
    }
    try {
      final dirPath = await _platformFileGateway.getDocumentsDirectoryPath();
      return '$dirPath/take_${DateTime.now().millisecondsSinceEpoch}.wav';
    } catch (_) {
      try {
        final tempDir = await _platformFileGateway.getTemporaryDirectoryPath();
        return '$tempDir/tunner_take_${DateTime.now().millisecondsSinceEpoch}.wav';
      } catch (_) {
        return 'tunner_take_${DateTime.now().millisecondsSinceEpoch}.wav';
      }
    }
  }

  /// Inicia la grabación acústica de la interpretación en segundo plano.
  Future<void> startPracticeRecording() async {
    if (_isAudioRecording) return;
    if (_isPlayingAudio) {
      await stopActiveRecordingPlayback();
    }

    _currentWaveformPeaks.clear();
    _currentPitchTrack.clear();
    _currentSpectralTrack.clear();
    _recordingDuration = Duration.zero;
    final path = await _getRecordingPath();

    try {
      await _recorderService.startRecording(destinationPath: path);
      _isAudioRecording = true;
      _recordingStopwatch
        ..reset()
        ..start();
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingDuration += const Duration(seconds: 1);
        notifyListeners();
      });
      notifyListeners();
    } catch (_) {
      _isAudioRecording = false;
      notifyListeners();
    }
  }

  /// Detiene la grabación activa y consolida la toma como [PracticeRecordingEntity] y [PracticeTakeEntity].
  Future<void> stopPracticeRecording() async {
    if (!_isAudioRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStopwatch.stop();
    _isAudioRecording = false;

    final filePath = await _recorderService.stopRecording();
    if (filePath != null && _recordingDuration.inMilliseconds >= 500) {
      final recording = PracticeRecordingEntity(
        id: "rec_${DateTime.now().millisecondsSinceEpoch}",
        filePath: filePath,
        recordedAt: DateTime.now(),
        duration: _recordingDuration,
        songTitle: _activePackage.title,
        bpm: _bpm,
        waveformPeaks: List.unmodifiable(_currentWaveformPeaks),
      );
      _activeRecording = recording;
      _recordingHistory.insert(0, recording);

      final take = PracticeTakeEntity(
        id: "take_${DateTime.now().millisecondsSinceEpoch}",
        name: "Toma ${_multiTrackSession.takes.length + 1}",
        timestamp: DateTime.now(),
        duration: _recordingDuration,
        filePath: filePath,
        waveformPeaks: List.unmodifiable(_currentWaveformPeaks),
        pitchTrack: List.unmodifiable(_currentPitchTrack),
        spectralTrack: List.unmodifiable(_currentSpectralTrack),
      );
      _multiTrackSession = _multiTrackSession.copyWith(
        takes: [..._multiTrackSession.takes, take],
        selectedTakeAId: _multiTrackSession.takes.isNotEmpty ? _multiTrackSession.takes.last.id : take.id,
        selectedTakeBId: take.id,
      );
      _triggerAutoSave();
    }
    notifyListeners();
  }

  /// Alterna entre iniciar y detener la grabación de práctica con un solo toque.
  Future<void> togglePracticeRecording() async {
    if (_isAudioRecording) {
      await stopPracticeRecording();
    } else {
      await startPracticeRecording();
    }
  }

  /// Reproduce la toma de práctica activa o la toma especificada en [targetRecording].
  Future<void> playActiveRecording([PracticeRecordingEntity? targetRecording]) async {
    final toPlay = targetRecording ?? _activeRecording;
    if (toPlay == null) return;
    _activeRecording = toPlay;
    if (toPlay.filePath.isNotEmpty) {
      await _playbackService.play(toPlay.filePath);
      _isPlayingAudio = true;
      notifyListeners();
    } else {
      // Síntesis acústica procedimental de la toma demo
      _isPlayingAudio = true;
      notifyListeners();
      await _audioSynthesizer.playNoteTone(
        frequency: _referencePitch,
        duration: const Duration(seconds: 4),
        volume: 0.8,
      );
      _isPlayingAudio = false;
      notifyListeners();
    }
  }

  /// Pausa la auto-escucha de la toma activa.
  Future<void> pauseActiveRecording() async {
    await _playbackService.pause();
    _isPlayingAudio = false;
    notifyListeners();
  }

  /// Detiene la reproducción y regresa al inicio de la toma.
  Future<void> stopActiveRecordingPlayback() async {
    await _playbackService.stop();
    _isPlayingAudio = false;
    _playbackPosition = Duration.zero;
    notifyListeners();
  }

  /// Salta a una posición temporal específica dentro de la toma de audio.
  Future<void> seekPlayback(Duration position) async {
    await _playbackService.seek(position);
    _playbackPosition = position;
    notifyListeners();
  }

  /// Ajusta la velocidad de reproducción de auto-escucha (ej. 0.75x, 1.0x, 1.25x).
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _playbackService.setPlaybackRate(speed);
    notifyListeners();
  }

  /// Descarta la toma activa actual.
  void discardActiveRecording() {
    if (_isPlayingAudio) {
      stopActiveRecordingPlayback();
    }
    if (_activeRecording != null) {
      _recordingHistory.removeWhere((r) => r.id == _activeRecording!.id);
      _triggerAutoSave();
    }
    _activeRecording = null;
    notifyListeners();
  }

  // --- Métodos de Gestión Multi-Pista y Comparador Espectral ---

  void _recordSampleForMultiTrack(double pitch, double cents, String noteName, {bool isSilent = false}) {
    final timeMs = _recordingStopwatch.isRunning
        ? _recordingStopwatch.elapsedMilliseconds
        : _recordingDuration.inMilliseconds;
    if (_currentPitchTrack.isNotEmpty && (timeMs - _currentPitchTrack.last.timeMs).abs() < 20) {
      return;
    }

    final isAutoTuned = _autoTuneProcessor.config.isEnabled && _lastAutoTuneResult.targetFrequencyHz > 20.0;
    final correctedPitch = isAutoTuned ? _lastAutoTuneResult.targetFrequencyHz : null;
    final effectiveCents = isAutoTuned ? _lastAutoTuneResult.centsDeviation : cents;
    final effectiveNoteName = isAutoTuned ? _lastAutoTuneResult.targetNoteName : noteName;

    _currentPitchTrack.add(
      TimedPitchSample(
        timeMs: timeMs,
        frequencyHz: pitch,
        centsDeviation: effectiveCents,
        targetNoteName: _expectedNote?.noteName ?? effectiveNoteName,
        isSilent: isSilent || pitch <= 20.0,
        correctedPitchHz: correctedPitch,
        isAutoTuned: isAutoTuned,
      ),
    );
    if (pitch > 20.0) {
      _currentSpectralTrack.add(
        TimedSpectralSample(
          timeMs: timeMs,
          spectralCentroidHz: pitch * 2.6,
          thdPercent: 3.2,
          rmsEnergy: (_currentWaveformPeaks.isNotEmpty ? _currentWaveformPeaks.last : 0.25),
        ),
      );
    }
  }

  void _initDefaultMultiTrackSession() {
    final now = DateTime.now();
    _multiTrackSession = MultiTrackSessionEntity(
      id: "session_${now.millisecondsSinceEpoch}",
      title: _activePackage.title,
      createdAt: now,
      bpm: _bpm,
      takes: [
        PracticeTakeEntity(
          id: 'take_1',
          name: 'Toma 1 (Afinación Base)',
          timestamp: now.subtract(const Duration(minutes: 5)),
          duration: const Duration(seconds: 4),
          filePath: '',
          waveformPeaks: const [0.2, 0.4, 0.7, 0.5, 0.3],
          pitchTrack: const [
            TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 12.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 200, frequencyHz: 440.0, centsDeviation: -15.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 400, frequencyHz: 440.0, centsDeviation: 14.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 600, frequencyHz: 440.0, centsDeviation: -10.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 800, frequencyHz: 440.0, centsDeviation: 8.0, targetNoteName: 'La4'),
          ],
          spectralTrack: const [
            TimedSpectralSample(timeMs: 0, spectralCentroidHz: 1100.0, thdPercent: 4.2, rmsEnergy: 0.2),
            TimedSpectralSample(timeMs: 400, spectralCentroidHz: 1150.0, thdPercent: 4.5, rmsEnergy: 0.25),
            TimedSpectralSample(timeMs: 800, spectralCentroidHz: 1120.0, thdPercent: 4.0, rmsEnergy: 0.22),
          ],
        ),
        PracticeTakeEntity(
          id: 'take_2',
          name: 'Toma 2 (Enfoque Precisión)',
          timestamp: now,
          duration: const Duration(seconds: 4),
          filePath: '',
          waveformPeaks: const [0.25, 0.5, 0.8, 0.6, 0.35],
          pitchTrack: const [
            TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 2.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 200, frequencyHz: 440.0, centsDeviation: -1.5, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 400, frequencyHz: 440.0, centsDeviation: 3.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 600, frequencyHz: 440.0, centsDeviation: -2.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 800, frequencyHz: 440.0, centsDeviation: 1.0, targetNoteName: 'La4'),
          ],
          spectralTrack: const [
            TimedSpectralSample(timeMs: 0, spectralCentroidHz: 1350.0, thdPercent: 2.5, rmsEnergy: 0.28),
            TimedSpectralSample(timeMs: 400, spectralCentroidHz: 1380.0, thdPercent: 2.4, rmsEnergy: 0.3),
            TimedSpectralSample(timeMs: 800, spectralCentroidHz: 1360.0, thdPercent: 2.6, rmsEnergy: 0.27),
          ],
        ),
      ],
      selectedTakeAId: 'take_1',
      selectedTakeBId: 'take_2',
    );
  }

  void selectComparisonTakes({String? takeAId, String? takeBId}) {
    _multiTrackSession = _multiTrackSession.copyWith(
      selectedTakeAId: takeAId ?? _multiTrackSession.selectedTakeAId,
      selectedTakeBId: takeBId ?? _multiTrackSession.selectedTakeBId,
    );
    notifyListeners();
  }

  void addPracticeTake(PracticeTakeEntity take) {
    _multiTrackSession = _multiTrackSession.copyWith(
      takes: [..._multiTrackSession.takes, take],
      selectedTakeAId: _multiTrackSession.takes.isNotEmpty ? _multiTrackSession.takes.last.id : take.id,
      selectedTakeBId: take.id,
    );
    notifyListeners();
  }

  void setTakeMute(String takeId, bool isMuted) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(isMuted: isMuted) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    notifyListeners();
  }

  void setTakeSolo(String takeId, bool isSolo) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(isSolo: isSolo) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    notifyListeners();
  }

  void setTakeGain(String takeId, double gain) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(gain: gain) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    notifyListeners();
  }

  Future<void> playTakeAudio(PracticeTakeEntity take) async {
    if (take.filePath.isNotEmpty) {
      await _playbackService.play(take.filePath);
      _isPlayingAudio = true;
      notifyListeners();
    } else {
      _isPlayingAudio = true;
      notifyListeners();
      final freq = take.pitchTrack.isNotEmpty ? take.pitchTrack.first.frequencyHz : 440.0;
      await _audioSynthesizer.playNoteTone(
        frequency: freq,
        duration: const Duration(seconds: 2),
        volume: 0.75,
      );
      _isPlayingAudio = false;
      notifyListeners();
    }
  }

  Future<void> get isInitialized => _initCompleter.future;

  /// Carga asíncronamente las preferencias y estado persistido desde almacenamiento offline.
  Future<void> loadPersistedState() async {
    try {
      final settings = await _persistenceService.loadSettings();
      _referencePitch = settings.referencePitch.clamp(415.0, 466.0);
      _isSmartWaitEnabled = settings.isSmartWaitEnabled;
      if (settings.bpm >= 20 && settings.bpm <= 300) {
        _bpm = settings.bpm;
        _scorePlaybackCoordinator.bpm = _bpm.toDouble();
      }

      if (settings.customPalettes.isNotEmpty) {
        _customPalettes.clear();
        _customPalettes.addAll(settings.customPalettes);
      }

      final targetPalette = availablePalettes.firstWhere(
        (p) => p.id == settings.selectedThemeId,
        orElse: () => TunnerThemePalette.obsidianStudio,
      );
      _currentPalette = targetPalette;
      _themeMode = targetPalette.mode;

      final targetInstrument = InstrumentProfileEntity.standardInstruments.firstWhere(
        (inst) => inst.id == settings.selectedInstrumentId,
        orElse: () => InstrumentProfileEntity.flute,
      );
      _activeInstrument = targetInstrument;
      _displayMode = settings.displayMode;
      _selectedTemperament = TemperamentEngine.getById(settings.selectedTemperamentId);
      _temperamentRootKey = settings.temperamentRootKey;
      _learnerProfile = settings.learnerProfile;
      _activeWorkspace = settings.activeWorkspace;

      if (settings.sessionHistory.isNotEmpty) {
        _sessionHistory.clear();
        _sessionHistory.addAll(settings.sessionHistory);
        _lastReport = _sessionHistory.last;
      }

      if (settings.recordingHistory.isNotEmpty) {
        _recordingHistory.clear();
        _recordingHistory.addAll(settings.recordingHistory);
        _activeRecording = _recordingHistory.first;
      }

      if (settings.tuningPresets.isNotEmpty) {
        _tuningPresets.clear();
        _tuningPresets.addAll(settings.tuningPresets);
      }

      if (settings.workspaceScores.isNotEmpty) {
        _workspaceScores.clear();
        _workspaceScores.addAll(settings.workspaceScores);
      }

      if (_shouldSeedDefaults) {
        _seedDefaultWorkspaceIfEmpty();
      }

      _micProfile = settings.micCalibrationProfile;
      _acousticRigorProfile = settings.acousticRigorProfile;
      _isInstrumentIsolationActive = _acousticRigorProfile.enableInstrumentIsolation;
      _pitchService.updateCalibrationProfile(_micProfile);
      _syncInstrumentAcousticFilter();

      notifyListeners();
    } catch (_) {
      // Ignorar fallas de carga silenciosamente
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Inicializa semillas por defecto en el espacio de trabajo local para garantizar
  /// que la interfaz de usuario no muestre contadores vacíos al arrancar el estudio.
  void _seedDefaultWorkspaceIfEmpty() {
    if (_workspaceScores.isEmpty && _curatedLibrary.isNotEmpty) {
      _workspaceScores.addAll(_curatedLibrary.take(3));
    }
    if (_recordingHistory.isEmpty) {
      _recordingHistory.addAll([
        PracticeRecordingEntity(
          id: 'rec_acoustic_demo_a440',
          filePath: 'Toma_Acustica_440Hz.wav',
          recordedAt: DateTime.now().subtract(const Duration(minutes: 45)),
          duration: const Duration(seconds: 4),
          songTitle: 'Toma Acústica de Calibración A4 (440 Hz)',
          bpm: 120,
          waveformPeaks: const [0.1, 0.4, 0.8, 0.95, 0.85, 0.7, 0.5, 0.3, 0.1],
        ),
        PracticeRecordingEntity(
          id: 'rec_club_groove_124bpm',
          filePath: 'Loop_Club_Groove_124BPM.wav',
          recordedAt: DateTime.now().subtract(const Duration(hours: 2)),
          duration: const Duration(seconds: 8),
          songTitle: 'Loop Club Groove Master (124 BPM)',
          bpm: 124,
          waveformPeaks: const [0.9, 0.7, 0.85, 0.95, 0.6, 0.8, 0.9, 0.75, 0.6],
        ),
      ]);
      _activeRecording = _recordingHistory.first;
    }
    if (_tuningPresets.isEmpty) {
      _tuningPresets.addAll([
        TuningPresetEntity(
          id: 'preset_philharmonic_442',
          name: 'Afinación Filarmónica',
          referencePitchHz: 442.0,
          temperamentId: 'equal',
          rootKey: 0,
          description: 'Estándar orquestal europeo moderno (442 Hz)',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        TuningPresetEntity(
          id: 'preset_baroque_415',
          name: 'Afinación Barroca',
          referencePitchHz: 415.0,
          temperamentId: 'werckmeister_iii',
          rootKey: 0,
          description: 'Afinación historicista barroca a 415 Hz en Werckmeister III',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ]);
    }
  }

  /// Método público para forzar y esperar la persistencia de estado atómica en disco.
  Future<void> savePersistedState() => _triggerAutoSave();

  /// Persiste el estado consolidado de la aplicación en disco local atómicamente.
  Future<void> _triggerAutoSave() async {
    try {
      final settings = AppUserSettingsEntity(
        referencePitch: _referencePitch,
        selectedThemeId: _currentPalette.id,
        selectedInstrumentId: _activeInstrument.id,
        bpm: _bpm,
        isSmartWaitEnabled: _isSmartWaitEnabled,
        displayMode: _displayMode,
        selectedTemperamentId: _selectedTemperament.id,
        temperamentRootKey: _temperamentRootKey,
        customPalettes: _customPalettes,
        sessionHistory: _sessionHistory,
        recordingHistory: _recordingHistory,
        tuningPresets: _tuningPresets,
        workspaceScores: _workspaceScores,
        learnerProfile: _learnerProfile,
        activeWorkspace: _activeWorkspace,
        micCalibrationProfile: _micProfile,
        acousticRigorProfile: _acousticRigorProfile,
      );
      await _persistenceService.saveSettings(settings);
    } catch (_) {
      // Ignorar fallas de guardado secundarias
    }
  }

}
