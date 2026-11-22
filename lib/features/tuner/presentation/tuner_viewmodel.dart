import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../../../core/file_system/domain/i_platform_file_gateway.dart';
import '../domain/tuning_preset_entity.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/note_entity.dart';
import '../domain/i_pitch_detector_service.dart';
import '../../metronome/domain/tempo_entity.dart';
import '../../metronome/domain/i_metronome_service.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../sheet_music/presentation/real_sheet_music_painter.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../song_library/domain/song_decomposer_service.dart';
import '../../practice_evaluator/domain/i_practice_evaluator_service.dart';
import '../../practice_evaluator/domain/note_evaluation_entity.dart';
import '../../practice_evaluator/domain/practice_evaluator_service.dart';
import '../../practice_evaluator/domain/practice_report_entity.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
import '../../instrument/domain/i_instrument_transposition_service.dart';
import '../../instrument/domain/instrument_transposition_service.dart';
import '../../practice_recorder/domain/practice_recording_entity.dart';
import '../../practice_recorder/domain/multitrack_session_entity.dart';
import '../../practice_recorder/domain/i_practice_recorder_service.dart';
import '../../practice_recorder/domain/i_audio_playback_service.dart';
import '../../persistence/domain/app_user_settings_entity.dart';
import '../../persistence/domain/i_local_persistence_service.dart';
import '../../universal_importer/domain/i_score_parser_service.dart';
import '../../universal_importer/domain/parsed_score_result_entity.dart';
import '../../audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import '../../audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import '../../sheet_music/domain/score_playback_coordinator.dart';
import '../../transcription/domain/polyphonic_transcription_engine.dart';
import '../../exercise_generator/domain/algorithmic_exercise_generator.dart';
import '../domain/temperament_engine.dart';
import '../domain/acoustic_echo_suppressor.dart';
import '../domain/microphone_calibration_models.dart';
import '../domain/instrument_acoustic_filter.dart';
import '../domain/acoustic_rigor_profile.dart';
import '../../drone/domain/harmonic_drone_config.dart';
import '../../drone/domain/harmonic_drone_synthesizer.dart';
import '../../chord_analyzer/domain/chord_entity.dart';
import '../../chord_analyzer/domain/chroma_vector_calculator.dart';
import '../../chord_analyzer/domain/polyphonic_chord_recognizer.dart';
import '../../chord_analyzer/domain/polyphonic_pitch_entity.dart';
import '../../chord_analyzer/domain/polyphonic_multitone_detector.dart';
import '../../metronome/domain/tap_tempo_engine.dart';
import '../../metronome/domain/tap_tempo_result.dart';
import '../../pedagogy_report/domain/pedagogical_report_models.dart';
import '../../audio_synthesizer/domain/sf2/i_soundfont_synthesizer_service.dart';
import '../../audio_synthesizer/domain/sf2/sf2_models.dart';
import '../../pedagogy_profiles/domain/learner_profile_entity.dart';
import '../../pedagogy_profiles/domain/adaptive_scaffolding_engine.dart';
import '../../workspaces/domain/workspace_type.dart';
import '../../audio_synthesizer/domain/i_stem_export_persistence_service.dart';
import '../../audio_synthesizer/domain/stem_export_entity.dart';
import '../../audio_synthesizer/domain/stem_audio_synthesizer.dart';
import '../../guided_lessons/domain/guided_lesson_entity.dart';
import '../../guided_lessons/domain/guided_lesson_evaluator.dart';
import '../../vocal_autotune/domain/autotune_config_entity.dart';
import '../../vocal_autotune/domain/i_vocal_take_file_gateway.dart';
import '../../vocal_autotune/domain/scale_quantizer.dart';
import '../../vocal_autotune/domain/vocal_autotune_processor.dart';
import '../../vocal_autotune/domain/vocal_score_converter.dart';
import '../../instrument/domain/smart_instrument_detector.dart';
import '../../song_library/domain/minus_one_session_entity.dart';
import '../../modular_rack/domain/port_permission_broker.dart';
import '../domain/hardware_audio_endpoint.dart';
import '../../audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import '../../../core/packaging/domain/i_tunner_package_codec.dart';
import '../../../core/packaging/domain/tunner_project_manifest_entity.dart';
import '../../../core/packaging/domain/tunner_project_package_entity.dart';
import '../../../core/audio/domain/i_studio_audio_device_matrix_port.dart';
import '../../../core/audio/domain/audio_device_matrix_entity.dart';
import '../domain/tuner_session_ports.dart';
import 'tuner_acoustic_telemetry.dart';
import '../../practice_recorder/presentation/practice_recorder_controller.dart';
import '../../score_editor/presentation/score_editor_controller.dart';
import '../../vocal_autotune/presentation/vocal_pedagogy_controller.dart';

/// ViewModel principal orquestador del estudio interactivo.
/// Diseñado bajo Clean Architecture con Inversión de Dependencias (DIP) y composición modular
/// de controladores cohesivos ([PracticeRecorderController], [ScoreEditorController], [VocalPedagogyController]).
class TunerViewModel extends ChangeNotifier
    implements IGuidedLessonSessionPort, IChordAnalyzerSessionPort, IScoreEditorSessionPort {
  final IPitchDetectorService _pitchService;
  final IMetronomeService _metronomeService;
  final IPracticeEvaluatorService _evaluatorService;
  final IInstrumentTranspositionService _transpositionService;
  final IPracticeRecorderService _recorderService;
  final IAudioPlaybackService _playbackService;
  final ILocalPersistenceService _persistenceService;
  final IScoreParserService _scoreImporterService;
  final IAudioSynthesizerService _audioSynthesizer;
  final AcousticEchoSuppressor _echoSuppressor;
  final IPlatformFileGateway _platformFileGateway;
  late final PracticeRecorderController _recorderController;
  late final ScoreEditorController _scoreEditorController;
  late final VocalPedagogyController _vocalPedagogyController;

  final ValueNotifier<TunerAcousticTelemetry> _telemetryNotifier =
      ValueNotifier<TunerAcousticTelemetry>(const TunerAcousticTelemetry());

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completeSubscription;

  double _frequency = 0.0;
  String _noteName = "--";
  double _cents = 0.0;
  bool _isRecording = false;

  Timer? _silenceTimer;
  bool _isDisposed = false;

  bool _isMetronomePlaying = false;
  int _currentSubTick = -1;
  int _currentMeasureIndex = 0;
  int _bpm = 75;
  bool _isScorePlaybackEnabled = true;

  bool _isCountingIn = false;
  int _countInBeat = 0;

  // Catálogo de canciones descompuestas canónicas
  final List<SongPackage> _curatedLibrary = SongDecomposerService.getCuratedLibrary();
  late SongPackage _activePackage;

  // Documentos de trabajo de partituras (inicia vacío por defecto)
  final List<SongPackage> _workspaceScores = [];

  // Presets de afinación acústica personalizados (inicia vacío por defecto)
  final List<TuningPresetEntity> _tuningPresets = [];

  HierarchicalNote? _expectedNote;
  HierarchicalNote? _lastEvaluatedNote;
  bool _isNoteCorrect = false;
  final Map<int, PlayedRecord> _measureHistory = {};

  // Perfil de Instrumento y Transposición
  InstrumentProfileEntity _activeInstrument = InstrumentProfileEntity.flute;

  // Modo de Práctica Evaluada & Analítica Pedagógica
  bool _isPracticeMode = false;
  bool _isSmartWaitEnabled = false;
  final List<NoteEvaluationEntity> _activeEvaluations = [];
  PracticeReportEntity? _lastReport;
  final List<PracticeReportEntity> _sessionHistory = [];

  // Personalización Estética y de Compás Pro
  TunnerThemeMode _themeMode = TunnerThemeMode.obsidianStudio;
  TunnerThemePalette _currentPalette = TunnerThemePalette.obsidianStudio;
  final List<TunnerThemePalette> _customPalettes = [];
  TimeSignature? _customTimeSignatureOverride;
  AppDisplayMode _displayMode = AppDisplayMode.conservatoryPro;

  // Consola Mezcladora Multicanal
  MixerConsoleEntity _mixerConsole = MixerConsoleEntity.defaultSetup();

  // Calibración de Concierto A4 (415 Hz - 466 Hz)
  double _referencePitch = 440.0;

  // Temperamentos, Dron, Acordes, Tap Tempo y Scaffolding
  final TemperamentEngine _temperamentEngine = const TemperamentEngine();
  MusicalTemperament _selectedTemperament = TemperamentEngine.allTemperaments.first;
  int _temperamentRootKey = 0;
  bool _anchorA4 = false;
  final HarmonicDroneSynthesizer _droneSynthesizer = const HarmonicDroneSynthesizer();
  HarmonicDroneConfig _droneConfig = const HarmonicDroneConfig();
  final PolyphonicChordRecognizer _chordRecognizer = PolyphonicChordRecognizer();
  final ChromaVectorCalculator _chromaCalculator = const ChromaVectorCalculator();
  late final PolyphonicMultiToneDetector _multiToneDetector;
  ChordEntity _recognizedChord = ChordEntity.none;
  PolyphonicMultiToneAnalysisResult _multiToneResult = PolyphonicMultiToneAnalysisResult.empty;
  bool _isChordRecognitionActive = false;
  List<double> _activeChromaVector = List<double>.filled(12, 0.0);
  List<double>? _latestAudioSamples;
  double _lastClarity = 0.0;
  final List<ChordEntity> _chordHistory = [];
  final TapTempoEngine _tapTempoEngine = TapTempoEngine();
  TapTempoResult? _lastTapTempoResult;
  LearnerProfileEntity _learnerProfile = LearnerProfileEntity.adult();
  final AdaptiveScaffoldingEngine _scaffoldingEngine = const AdaptiveScaffoldingEngine();
  int _consecutiveSuccesses = 0;
  int _consecutiveErrors = 0;
  PedagogicalDiagnosticResult? _lastPedagogicalDiagnostic;
  WorkspaceType _activeWorkspace = WorkspaceType.learning;

  // Motor de Síntesis SoundFont SF2 y Timbres Acústicos
  final ISoundFontSynthesizerService _soundFontSynthesizer;

  // Motor de Síntesis Polifónica SMuFL y Coordinador de Partitura
  final PolyphonicVoicePool _polyphonicVoicePool;
  late final ScorePlaybackCoordinator _scorePlaybackCoordinator;
  int? _selectedScoreNoteIndex;

  // Empaquetador Canónico de Proyectos .tunner
  ITunnerPackageCodec packageCodec;
  final IStudioAudioDeviceMatrixPort? _audioDeviceMatrixService;
  final IStudioLogger _logger;

  // Calibración y Adaptación Acústica del Micrófono (UC-41)
  MicrophoneCalibrationProfile _micProfile = const MicrophoneCalibrationProfile();
  double _currentMicRmsLevel = 0.0;
  bool _isCalibratingNoiseFloor = false;
  List<String> _availableAudioDevices = [];
  NoiseProfileReport? _lastNoiseReport;

  // Aislamiento Acústico de Instrumento y Rechazo de Voz (UC-43)
  bool _isInstrumentIsolationActive = true;

  // Presets de Rigurosidad Acústica y Controles de Micrófono (UC-44)
  AcousticRigorProfile _acousticRigorProfile = const AcousticRigorProfile();

  // Reconocimiento Acústico Inteligente de Instrumentos y Adaptación Tímbrica (UC-59)
  final SmartInstrumentDetector _smartInstrumentDetector = SmartInstrumentDetector();
  bool _isSmartInstrumentTuningActive = false;
  bool _autoSwitchInstrumentEnabled = false;
  SmartInstrumentMatch? _lastDetectedMatch;

  // Inyección de dependencias en el constructor
  TunerViewModel({
    IPitchDetectorService? pitchService,
    IMetronomeService? metronomeService,
    IPracticeEvaluatorService? evaluatorService,
    IInstrumentTranspositionService? transpositionService,
    IPracticeRecorderService? recorderService,
    IAudioPlaybackService? playbackService,
    ILocalPersistenceService? persistenceService,
    IScoreParserService? scoreImporterService,
    IAudioSynthesizerService? audioSynthesizerService,
    AcousticEchoSuppressor? echoSuppressor,
    StemAudioSynthesizer? stemSynthesizer,
    IStemExportPersistenceService? exportPersistenceService,
    PolyphonicMultiToneDetector? multiToneDetector,
    GuidedLessonEvaluator? guidedLessonEvaluator,
    VocalAutoTuneProcessor? autoTuneProcessor,
    IVocalTakeFileGateway? vocalTakeFileGateway,
    ISoundFontSynthesizerService? soundFontSynthesizer,
    PolyphonicVoicePool? polyphonicVoicePool,
    ScorePlaybackCoordinator? scorePlaybackCoordinator,
    ITunnerPackageCodec? packageCodec,
    IStudioAudioDeviceMatrixPort? audioDeviceMatrixService,
    IPlatformFileGateway? platformFileGateway,
    IStudioLogger? logger,
    Future<String> Function()? documentsDirectoryProvider,
    Future<String> Function()? recordingPathProvider,
    bool seedDefaults = false,
  })  : _shouldSeedDefaults = seedDefaults,
        _pitchService = pitchService ?? NoOpPitchDetectorService(),
        _metronomeService = metronomeService ?? NoOpMetronomeService(),
        _evaluatorService = evaluatorService ?? const PracticeEvaluatorService(),
        _transpositionService = transpositionService ?? const InstrumentTranspositionService(),
        _recorderService = recorderService ?? const NoOpPracticeRecorderService(),
        _playbackService = playbackService ?? const NoOpAudioPlaybackService(),
        _persistenceService = persistenceService ?? InMemoryLocalPersistenceService(),
        _scoreImporterService = scoreImporterService ?? const NoOpScoreParserService(),
        _audioSynthesizer = audioSynthesizerService ?? const NoOpAudioSynthesizerService(),
        _echoSuppressor = echoSuppressor ?? AcousticEchoSuppressor(),
        _platformFileGateway = platformFileGateway ?? const NoOpPlatformFileGateway(),
        _multiToneDetector = multiToneDetector ?? PolyphonicMultiToneDetector(),
        _soundFontSynthesizer = soundFontSynthesizer ?? const NoOpSoundFontSynthesizerService(),
        _polyphonicVoicePool = polyphonicVoicePool ?? PolyphonicVoicePool(),
        packageCodec = packageCodec ?? const NoOpTunnerPackageCodec(),
        _audioDeviceMatrixService = audioDeviceMatrixService,
        _logger = logger ?? const NoOpStudioLogger() {
    _activePackage = _curatedLibrary.first;
    _bpm = _activePackage.defaultBpm;
    _recorderController = PracticeRecorderController(
      recorderService: _recorderService,
      playbackService: _playbackService,
      persistenceService: _persistenceService,
      audioSynthesizer: _audioSynthesizer,
      platformFileGateway: _platformFileGateway,
      initialTitle: _activePackage.title,
      initialBpm: _bpm,
      onNotify: notifyListeners,
      onAutoSave: _triggerAutoSave,
      recordingPathProvider: recordingPathProvider,
    );
    _scoreEditorController = ScoreEditorController(
      audioSynthesizer: _audioSynthesizer,
      scoreImporterService: _scoreImporterService,
      stemSynthesizer: stemSynthesizer ?? const StemAudioSynthesizer(),
      exportPersistenceService: exportPersistenceService ?? const NoOpStemExportPersistenceService(),
      logger: _logger,
      onNotify: notifyListeners,
    );
    _vocalPedagogyController = VocalPedagogyController(
      guidedLessonEvaluator: guidedLessonEvaluator ?? GuidedLessonEvaluator(),
      autoTuneProcessor: autoTuneProcessor ?? VocalAutoTuneProcessor(),
      vocalTakeFileGateway: vocalTakeFileGateway ?? const NoOpVocalTakeFileGateway(),
      logger: _logger,
      onNotify: notifyListeners,
      onAutoSave: _triggerAutoSave,
    );
    _scorePlaybackCoordinator = scorePlaybackCoordinator ??
        ScorePlaybackCoordinator(
          voicePool: _polyphonicVoicePool,
          initialBpm: _bpm.toDouble(),
        );
    _mixerConsole = MixerConsoleEntity(
      metronomeTrack: _mixerConsole.metronomeTrack,
      stems: _activePackage.tracks,
    );
    _initListeners();
    _syncInstrumentAcousticFilter();
    if (_shouldSeedDefaults) {
      _seedDefaultWorkspaceIfEmpty();
    }
    loadPersistedState();
  }

  final bool _shouldSeedDefaults;

  // --- Getters del Estado ---
  AcousticRigorProfile get acousticRigorProfile => _acousticRigorProfile;
  bool get isInstrumentIsolationActive => _isInstrumentIsolationActive;
  TunnerThemeMode get themeMode => _themeMode;
  TunnerThemePalette get currentPalette => _currentPalette;
  List<TunnerThemePalette> get availablePalettes => [...TunnerThemePalette.allPresets, ..._customPalettes];
  List<TunnerThemePalette> get customPalettes => List.unmodifiable(_customPalettes);
  AppDisplayMode get displayMode => _displayMode;
  bool get isEssentialMode => _displayMode == AppDisplayMode.essential;
  ISoundFontSynthesizerService get soundFontSynthesizer => _soundFontSynthesizer;
  IPlatformFileGateway get platformFileGateway => _platformFileGateway;
  int get activeSoundFontPatch => _soundFontSynthesizer.activePatch;
  List<Sf2Preset> get availableSoundFontPresets => _soundFontSynthesizer.availablePresets;

  /// Acceso controlado al sintetizador de audio para modales interactivos.
  IAudioSynthesizerService get audioSynthesizer => _audioSynthesizer;

  /// Selecciona el instrumento acústico SoundFont activo.
  void selectSoundFontPatch(int patch) {
    _soundFontSynthesizer.selectPatch(patch);
    notifyListeners();
  }

  /// Sintetiza y reproduce una nota con el timbre SoundFont activo.
  Uint8List synthesizeSoundFontNote({
    required int midiPitch,
    double durationSeconds = 1.0,
    int velocity = 100,
  }) {
    final wavBytes = _soundFontSynthesizer.synthesizeNoteWav(
      midiPitch: midiPitch,
      durationSeconds: durationSeconds,
      velocity: velocity,
    );
    if (wavBytes.isNotEmpty) {
      _audioSynthesizer.playPcmWav(wavBytes);
    }
    return wavBytes;
  }

  /// Cambia el modo de visualización de interfaz (Esencial vs. Conservatorio Pro).
  void setDisplayMode(AppDisplayMode mode) {
    if (_displayMode != mode) {
      _displayMode = mode;
      notifyListeners();
      _triggerAutoSave();
    }
  }

  /// Alterna entre el Modo Esencial minimalista y el Modo Conservatorio Pro completo.
  void toggleDisplayMode() {
    _displayMode = _displayMode == AppDisplayMode.essential
        ? AppDisplayMode.conservatoryPro
        : AppDisplayMode.essential;
    notifyListeners();
    _triggerAutoSave();
  }
  // Getters de Calibración de Micrófono
  MicrophoneCalibrationProfile get micProfile => _micProfile;
  double get currentMicRmsLevel => _currentMicRmsLevel;
  bool get isCalibratingNoiseFloor => _isCalibratingNoiseFloor;
  List<String> get availableAudioDevices => List.unmodifiable(_availableAudioDevices);
  NoiseProfileReport? get lastNoiseReport => _lastNoiseReport;

  /// Actualiza la ganancia de entrada digital del micrófono.
  void setMicrophoneGain(double gain) {
    _micProfile = _micProfile.copyWith(digitalGain: gain.clamp(0.2, 5.0));
    _pitchService.updateCalibrationProfile(_micProfile);
    notifyListeners();
    _triggerAutoSave();
  }

  /// Actualiza el umbral de corte del Noise Gate.
  void setNoiseGateThreshold(double threshold) {
    _micProfile = _micProfile.copyWith(noiseGateThreshold: threshold.clamp(0.001, 0.100));
    _pitchService.updateCalibrationProfile(_micProfile);
    notifyListeners();
    _triggerAutoSave();
  }

  /// Activa o desactiva el filtro eliminador de offset DC (DC-Blocker).
  void toggleDcBlocker(bool enabled) {
    _micProfile = _micProfile.copyWith(enableDcBlocker: enabled);
    _pitchService.updateCalibrationProfile(_micProfile);
    notifyListeners();
    _triggerAutoSave();
  }

  /// Actualiza la lista de dispositivos físicos de captura disponibles.
  Future<void> refreshAudioDevices() async {
    _availableAudioDevices = await _pitchService.listInputDevices();
    notifyListeners();
  }

  /// Selecciona el dispositivo físico de entrada.
  Future<void> selectAudioDevice(String deviceId) async {
    await _pitchService.setInputDevice(deviceId);
    _micProfile = _micProfile.copyWith(deviceId: deviceId);
    notifyListeners();
    await _triggerAutoSave();
  }

  /// Inicia el proceso de perfilado del piso de ruido ambiental (1.5 segundos).
  Future<void> calibrateAmbientNoiseFloor() async {
    if (_isCalibratingNoiseFloor) return;
    _isCalibratingNoiseFloor = true;
    notifyListeners();

    final capturedRmsSamples = <double>[];
    void listener(double rms) {
      capturedRmsSamples.add(rms);
    }

    final prevRmsCallback = _pitchService.onRmsLevelChanged;
    _pitchService.onRmsLevelChanged = (rms) {
      listener(rms);
      prevRmsCallback?.call(rms);
    };

    // Asegurar que el micrófono esté capturando
    final wasRecording = _isRecording;
    if (!wasRecording) {
      await _pitchService.startRecording();
    }

    await Future.delayed(const Duration(milliseconds: 1600));

    // Analizar muestras recolectadas
    double sumRms = 0.0;
    double maxRms = 0.0;
    for (final rms in capturedRmsSamples) {
      sumRms += rms;
      if (rms > maxRms) maxRms = rms;
    }

    final meanRms = capturedRmsSamples.isNotEmpty
        ? (sumRms / capturedRmsSamples.length)
        : 0.002;

    final recommendedGate = (meanRms * 1.8).clamp(0.003, 0.080);

    _lastNoiseReport = NoiseProfileReport(
      meanRms: meanRms,
      peakRms: maxRms,
      recommendedNoiseGate: recommendedGate,
      detectedDcOffset: 0.0,
      totalFramesAnalyzed: capturedRmsSamples.length,
    );

    _micProfile = _micProfile.copyWith(
      noiseGateThreshold: recommendedGate,
      measuredNoiseFloorRms: meanRms,
    );

    _pitchService.updateCalibrationProfile(_micProfile);

    if (!wasRecording) {
      await _pitchService.stopRecording();
    }

    _pitchService.onRmsLevelChanged = prevRmsCallback;
    _isCalibratingNoiseFloor = false;
    notifyListeners();
    await _triggerAutoSave();
  }

  MixerConsoleEntity get mixerConsole => _mixerConsole;
  List<SongPackage> get curatedLibrary => _curatedLibrary;
  List<SongPackage> get workspaceScores => List.unmodifiable(_workspaceScores);
  List<TuningPresetEntity> get customTuningPresets => List.unmodifiable(_tuningPresets);
  SongPackage get activePackage => _activePackage;
  @override
  InstrumentProfileEntity get activeInstrument => _activeInstrument;

  // --- Smart Instrument Recognition & Acoustic Adaptation (UC-59) ---
  bool get isSmartInstrumentTuningActive => _isSmartInstrumentTuningActive;
  bool get autoSwitchInstrumentEnabled => _autoSwitchInstrumentEnabled;
  SmartInstrumentMatch? get lastDetectedMatch => _lastDetectedMatch;

  // --- Vocal Suite & Melodyne Mode (UC-60) ---
  SongPackage? get lastConvertedVocalPackage => _vocalPedagogyController.lastConvertedVocalPackage;
  VocalScoreConversionResult? get lastVocalConversionResult =>
      _vocalPedagogyController.lastVocalConversionResult;

  // --- Ensamble Virtual Minus-One (UC-61) ---
  MinusOneSessionEntity? get activeMinusOneSession => _vocalPedagogyController.activeMinusOneSession;
  bool get isMinusOneActive => _vocalPedagogyController.isMinusOneActive;
  String? get minusOneUserTrackId => _vocalPedagogyController.activeMinusOneSession?.userTrackId;

  // --- Arbitraje de Puertos de Hardware y Seguridad Acústica (UC-62) ---
  PortPermissionBroker get portPermissionBroker => _vocalPedagogyController.portPermissionBroker;
  bool get isHeadphonesConnected => _vocalPedagogyController.isHeadphonesConnected;
  bool get canActivateLiveMonitoring =>
      _vocalPedagogyController.portPermissionBroker.canAuthorizeLiveMonitoring(
        isHeadphonesOrInterfaceConnected: _vocalPedagogyController.isHeadphonesConnected,
      );
  List<HardwareAudioEndpoint> get hardwareAudioEndpoints =>
      _vocalPedagogyController.hardwareAudioEndpoints;

  // --- Getters de Grabación & Auto-Escucha (Loopback) ---
  bool get isAudioRecording => _recorderController.isAudioRecording;
  Duration get recordingDuration => _recorderController.recordingDuration;
  List<double> get currentWaveformPeaks => _recorderController.currentWaveformPeaks;
  PracticeRecordingEntity? get activeRecording => _recorderController.activeRecording;
  List<PracticeRecordingEntity> get recordingHistory => _recorderController.recordingHistory;
  bool get isPlayingAudio => _recorderController.isPlayingAudio;
  Duration get playbackPosition => _recorderController.playbackPosition;
  Duration get playbackDuration => _recorderController.playbackDuration;
  double get playbackSpeed => _recorderController.playbackSpeed;
  MultiTrackSessionEntity get multiTrackSession => _recorderController.multiTrackSession;
  Future<void> get isInitialized => _recorderController.isInitialized;
  ValueListenable<TunerAcousticTelemetry> get telemetryListenable => _telemetryNotifier;

  @override
  double get frequency => _frequency;
  @override
  String get noteName => _noteName;
  bool get hasTransposition => _activeInstrument.isTransposing;
  String get writtenNoteName {
    if (_noteName == "--" || _noteName.isEmpty) return "--";
    if (!_activeInstrument.isTransposing) return _noteName;
    return _transpositionService.getWrittenNote(_noteName, _activeInstrument);
  }
  @override
  double get cents => _cents;
  double get referencePitch => _referencePitch;
  MusicalTemperament get selectedTemperament => _selectedTemperament;
  int get temperamentRootKey => _temperamentRootKey;
  List<MusicalTemperament> get availableTemperaments => TemperamentEngine.allTemperaments;
  TemperamentEngine get temperamentEngine => _temperamentEngine;
  HarmonicDroneConfig get droneConfig => _droneConfig;
  bool get isDronePlaying => _audioSynthesizer.isDroneLoopPlaying;
  @override
  ChordEntity get recognizedChord => _recognizedChord;
  @override
  PolyphonicMultiToneAnalysisResult get polyphonicAnalysisResult => _multiToneResult;
  @override
  bool get isChordRecognitionActive => _isChordRecognitionActive;
  @override
  List<double> get activeChromaVector => _activeChromaVector;
  List<double>? get latestAudioSamples => _latestAudioSamples;
  double get lastClarity => _lastClarity;
  List<ChordEntity> get chordHistory => List.unmodifiable(_chordHistory);
  TapTempoResult? get lastTapTempoResult => _lastTapTempoResult;
  LearnerProfileEntity get learnerProfile => _learnerProfile;
  AdaptiveScaffoldingEngine get scaffoldingEngine => _scaffoldingEngine;
  double get centsTolerance => _scaffoldingEngine.computeEffectiveTolerance(
        profile: _learnerProfile,
        consecutiveSuccesses: _consecutiveSuccesses,
      );
  PedagogicalDiagnosticResult? get lastPedagogicalDiagnostic => _lastPedagogicalDiagnostic;
  AcousticEchoSuppressor get echoSuppressor => _echoSuppressor;
  WorkspaceType get activeWorkspace => _activeWorkspace;

  /// Cambia el espacio de trabajo activo (Aprender, Componer, Producir).
  void setWorkspace(WorkspaceType workspace) {
    if (_activeWorkspace != workspace) {
      _activeWorkspace = workspace;
      notifyListeners();
      _triggerAutoSave();
    }
  }

  /// Modifica el temperamento histórico activo (ej. Werckmeister III, Mesotónico, Justo).
  void setTemperament(String temperamentId) {
    final target = TemperamentEngine.getById(temperamentId);
    if (_selectedTemperament.id != target.id) {
      _selectedTemperament = target;
      if (_frequency > 0) {
        _recalculatePitchForActiveTemperament();
      }
      if (_audioSynthesizer.isDroneLoopPlaying) {
        _refreshDronePlayback();
      }
      notifyListeners();
      _triggerAutoSave();
    }
  }

  /// Modifica la tónica o nota raíz del temperamento (0 = Do, 1 = Do#, ..., 11 = Si).
  void setTemperamentRoot(int rootKey) {
    final normalized = (rootKey % 12 + 12) % 12;
    if (_temperamentRootKey != normalized) {
      _temperamentRootKey = normalized;
      if (_frequency > 0) {
        _recalculatePitchForActiveTemperament();
      }
      if (_audioSynthesizer.isDroneLoopPlaying) {
        _refreshDronePlayback();
      }
      notifyListeners();
      _triggerAutoSave();
    }
  }

  bool get anchorA4 => _anchorA4;

  /// Configura si la afinación con temperamentos históricos se ancla a A4=440Hz o a la tónica raíz.
  void setAnchorA4(bool value) {
    if (_anchorA4 == value) return;
    _anchorA4 = value;
    if (_frequency > 0) {
      _recalculatePitchForActiveTemperament();
    }
    notifyListeners();
  }

  void _recalculatePitchForActiveTemperament() {
    final noteEntity = NoteEntity.fromFrequency(_frequency, a4Ref: _referencePitch);
    _noteName = noteEntity.name;
    if (_selectedTemperament.id == 'equal') {
      _cents = noteEntity.cents;
    } else {
      final targetFreq = _temperamentEngine.getTargetFrequency(
        midiNumber: noteEntity.midiNumber,
        temperament: _selectedTemperament,
        a4Ref: _referencePitch,
        rootKey: _temperamentRootKey,
        anchorA4: _anchorA4,
      );
      _cents = _temperamentEngine.calculateCentsDeviation(
        detectedFrequency: _frequency,
        targetFrequency: targetFreq,
      );
    }
  }

  @override
  bool get isRecording => _isRecording;
  bool get isMetronomePlaying => _isMetronomePlaying;
  bool get isMetronomeActive => _isMetronomePlaying;
  bool get isScorePlaybackEnabled => _isScorePlaybackEnabled;
  bool get isLiveTranscriptionActive => _scoreEditorController.isLiveTranscriptionActive;
  bool get isPolyphonicTranscriptionActive => _scoreEditorController.isPolyphonicTranscriptionActive;
  PolyphonicTranscriptionEngine get polyphonicTranscriptionEngine =>
      _scoreEditorController.polyphonicTranscriptionEngine;

  /// Alterna el metrónomo de práctica.
  void toggleMetronome() => startSongWithCountIn();

  /// Detiene la reproducción de la partitura si está activa.
  void stopSong() {
    if (_isMetronomePlaying) {
      startSongWithCountIn();
    }
  }

  /// Alterna la reproducción acústica de las notas de la partitura durante el metrónomo.
  void toggleScorePlayback() {
    _isScorePlaybackEnabled = !_isScorePlaybackEnabled;
    notifyListeners();
  }

  int get currentSubTick => _currentSubTick;
  @override
  int get currentMeasureIndex => _currentMeasureIndex;
  int get totalMeasures => _activePackage.totalMeasures;
  int get bpm => _bpm;
  TempoMark get currentTempoMark => TempoMark.fromBpm(_bpm);
  bool get isCountingIn => _isCountingIn;
  int get countInBeat => _countInBeat;
  HierarchicalNote? get expectedNote => _expectedNote;
  bool get isNoteCorrect => _isNoteCorrect;
  Map<int, PlayedRecord> get measureHistory => _measureHistory;

  bool get isPracticeMode => _isPracticeMode;
  bool get isSmartWaitEnabled => _isSmartWaitEnabled;
  PracticeReportEntity? get lastReport => _lastReport;
  List<PracticeReportEntity> get sessionHistory => _sessionHistory;
  int get practiceEvaluationsCount => _activeEvaluations.length;

  @override
  List<HierarchicalNote> get currentMeasureNotes =>
      _activePackage.score.measures[_currentMeasureIndex].notes;

  TimeSignature get currentMeasureTimeSignature =>
      _customTimeSignatureOverride ??
      _activePackage.score.measures[_currentMeasureIndex].timeSignature;

  // Acceso al Motor de Síntesis Polifónica SMuFL y Reproductor de Partitura
  PolyphonicVoicePool get polyphonicVoicePool => _polyphonicVoicePool;
  ScorePlaybackCoordinator get scorePlaybackCoordinator => _scorePlaybackCoordinator;
  int? get selectedScoreNoteIndex => _selectedScoreNoteIndex;

  /// Selecciona una nota en el pentagrama y reproduce su sonido acústico de inmediato (Tap-to-Listen).
  void selectAndPreviewScoreNote(int noteIndex) {
    if (noteIndex < 0 || noteIndex >= currentMeasureNotes.length) return;
    _selectedScoreNoteIndex = noteIndex;
    final note = currentMeasureNotes[noteIndex];
    _scorePlaybackCoordinator.previewNote(note);
    notifyListeners();
  }

  /// Limpia la selección de la nota en el pentagrama.
  void clearSelectedScoreNote() {
    _selectedScoreNoteIndex = null;
    notifyListeners();
  }

  // Acceso a servicios de hardware y empaquetado canónico
  IStudioAudioDeviceMatrixPort? get audioDeviceMatrixService => _audioDeviceMatrixService;

  /// Exporta el estado completo de la sesión actual a un paquete canónico binario `.tunner`.
  Uint8List exportCurrentProjectToTunner({
    String? projectTitle,
    String? author,
  }) {
    final now = DateTime.now();
    final manifest = TunnerProjectManifestEntity(
      id: 'tunner_proj_${now.millisecondsSinceEpoch}',
      title: projectTitle ?? _activePackage.title,
      author: author ?? _activePackage.composer,
      createdAt: now,
      modifiedAt: now,
      bpm: _bpm.toDouble(),
      timeSignature: _activePackage.initialTimeSignature.toString(),
    );

    final synthPresetJson = <String, dynamic>{
      'waveform': _polyphonicVoicePool.waveform.name,
      'attack': _polyphonicVoicePool.attackSeconds,
      'decay': _polyphonicVoicePool.decaySeconds,
      'sustain': _polyphonicVoicePool.sustainLevel,
      'release': _polyphonicVoicePool.releaseSeconds,
      'pulseWidth': _polyphonicVoicePool.pulseWidth,
      'masterGain': _polyphonicVoicePool.masterGain,
    };

    final scoreJson = <String, dynamic>{
      'title': _activePackage.title,
      'composer': _activePackage.composer,
      'bpm': _bpm,
      'songPackage': _activePackage.toMap(),
    };

    Map<String, dynamic>? routingMatrixJson;
    if (_audioDeviceMatrixService != null) {
      routingMatrixJson = _audioDeviceMatrixService.matrix.toJson();
    }

    final pkg = TunnerProjectPackageEntity(
      manifest: manifest,
      routingMatrixJson: routingMatrixJson,
      scoreJson: scoreJson,
      synthPresetJson: synthPresetJson,
    );

    return packageCodec.encodePackage(pkg);
  }

  /// Importa un proyecto desde un flujo de bytes `.tunner` y restaura
  /// de forma reactiva el tempo, matriz de hardware y presets del sintetizador.
  TunnerProjectPackageEntity importProjectFromTunnerBytes(
    Uint8List bytes, {
    bool verifyHashes = true,
  }) {
    final pkg = packageCodec.decodePackage(bytes, verifyHashes: verifyHashes);

    if (pkg.manifest.bpm > 0) {
      updateBpm(pkg.manifest.bpm.round());
    }

    if (pkg.synthPresetJson != null) {
      final waveStr = pkg.synthPresetJson!['waveform'] as String?;
      if (waveStr != null) {
        for (final w in SynthWaveform.values) {
          if (w.name == waveStr) {
            _polyphonicVoicePool.waveform = w;
            break;
          }
        }
      }
      final attack = (pkg.synthPresetJson!['attack'] as num?)?.toDouble();
      if (attack != null) _polyphonicVoicePool.attackSeconds = attack;
      final decay = (pkg.synthPresetJson!['decay'] as num?)?.toDouble();
      if (decay != null) _polyphonicVoicePool.decaySeconds = decay;
      final sustain = (pkg.synthPresetJson!['sustain'] as num?)?.toDouble();
      if (sustain != null) _polyphonicVoicePool.sustainLevel = sustain;
      final release = (pkg.synthPresetJson!['release'] as num?)?.toDouble();
      if (release != null) _polyphonicVoicePool.releaseSeconds = release;
      final pw = (pkg.synthPresetJson!['pulseWidth'] as num?)?.toDouble();
      if (pw != null) _polyphonicVoicePool.pulseWidth = pw;
      final gain = (pkg.synthPresetJson!['masterGain'] as num?)?.toDouble();
      if (gain != null) _polyphonicVoicePool.masterGain = gain;
    }

    if (pkg.routingMatrixJson != null && _audioDeviceMatrixService != null) {
      final restoredMatrix = AudioDeviceMatrixEntity.fromJson(pkg.routingMatrixJson!);
      _audioDeviceMatrixService.restoreMatrix(restoredMatrix);
    }

    if (pkg.scoreJson != null && pkg.scoreJson!['songPackage'] is Map<String, dynamic>) {
      try {
        final pkgMap = pkg.scoreJson!['songPackage'] as Map<String, dynamic>;
        _activePackage = SongPackage.fromMap(pkgMap);
      } catch (e) {
        _logger.warning('TunerViewModel', 'Error deserializando songPackage en proyecto: $e');
      }
    }

    notifyListeners();
    return pkg;
  }

  void _initListeners() {
    _pitchService.onRmsLevelChanged = (rms) {
      _currentMicRmsLevel = rms;
      _updateTelemetry();
      notifyListeners();
    };

    _pitchService.onClarityDetected = (clarity) {
      _lastClarity = clarity;
      notifyListeners();
    };

    _pitchService.onAudioWindowCaptured = (window) {
      _latestAudioSamples = window;
      if (_isChordRecognitionActive) {
        processChordSamples(window);
      }
      notifyListeners();
    };

    _pitchService.onPitchDetected = (pitch) {
      if (_echoSuppressor.shouldSuppressPitch(pitch)) {
        return;
      }

      _silenceTimer?.cancel();
      _frequency = pitch;
      final noteEntity = NoteEntity.fromFrequency(pitch, a4Ref: _referencePitch);
      _noteName = noteEntity.name;
      if (_selectedTemperament.id == 'equal') {
        _cents = noteEntity.cents;
      } else {
        final targetFreq = _temperamentEngine.getTargetFrequency(
          midiNumber: noteEntity.midiNumber,
          temperament: _selectedTemperament,
          a4Ref: _referencePitch,
          rootKey: _temperamentRootKey,
          anchorA4: _anchorA4,
        );
        _cents = _temperamentEngine.calculateCentsDeviation(
          detectedFrequency: pitch,
          targetFrequency: targetFreq,
        );
      }

      // Evaluación pedagógica adaptativa
      final diagnostic = _scaffoldingEngine.evaluateNote(
        centsDeviation: _cents,
        profile: _learnerProfile,
        consecutiveSuccesses: _consecutiveSuccesses,
        consecutiveErrors: _consecutiveErrors,
      );
      _lastPedagogicalDiagnostic = diagnostic;
      if (diagnostic.isInTune) {
        _consecutiveSuccesses++;
        _consecutiveErrors = 0;
      } else {
        _consecutiveErrors++;
        _consecutiveSuccesses = 0;
      }

      final transcribedPkg = _scoreEditorController.processLiveTranscriptionFrame(
        activePackage: _activePackage,
        pitchHz: pitch,
        clarity: _lastClarity > 0.0 ? _lastClarity : (pitch > 20.0 ? 0.95 : 0.0),
        noteName: noteEntity.name,
      );
      if (transcribedPkg != null) {
        _activePackage = transcribedPkg;
      }

      if (_isChordRecognitionActive) {
        _updateChordFromPitch(pitch);
      }

      if (_recorderController.isAudioRecording) {
        _recorderController.recordSampleForMultiTrack(
          pitch: pitch,
          cents: _cents,
          noteName: noteEntity.name,
          isAutoTuneEnabled: _vocalPedagogyController.isAutoTuneActive,
          autoTuneTargetHz: _vocalPedagogyController.lastAutoTuneResult.targetFrequencyHz,
          autoTuneCentsDev: _vocalPedagogyController.lastAutoTuneResult.centsDeviation,
          autoTuneTargetNote: _vocalPedagogyController.lastAutoTuneResult.targetNoteName,
          expectedNoteName: _expectedNote?.noteName,
        );
      }

      _vocalPedagogyController.processPitchFrame(
        pitchHz: pitch,
        cents: _cents,
        noteName: noteEntity.name,
      );

      if (_isSmartInstrumentTuningActive && pitch > 20.0) {
        _evaluateSmartInstrumentFromPitch(pitch);
      }

      _validatePerformance();
      _updateTelemetry();
      notifyListeners();

      _silenceTimer = Timer(const Duration(milliseconds: 350), () {
        _frequency = 0.0;
        _noteName = "--";
        _cents = 0.0;
        _lastClarity = 0.0;
        _vocalPedagogyController.resetOnSilence();

        final silentPkg = _scoreEditorController.processLiveTranscriptionFrame(
          activePackage: _activePackage,
          pitchHz: 0.0,
          clarity: 0.0,
          noteName: "--",
        );
        if (silentPkg != null) {
          _activePackage = silentPkg;
        }

        if (_isChordRecognitionActive) {
          _recognizedChord = ChordEntity.none;
        }

        if (_recorderController.isAudioRecording) {
          _recorderController.recordSampleForMultiTrack(
            pitch: 0.0,
            cents: 0.0,
            noteName: "--",
            isAutoTuneEnabled: _vocalPedagogyController.isAutoTuneActive,
            autoTuneTargetHz: _vocalPedagogyController.lastAutoTuneResult.targetFrequencyHz,
            autoTuneCentsDev: _vocalPedagogyController.lastAutoTuneResult.centsDeviation,
            autoTuneTargetNote: _vocalPedagogyController.lastAutoTuneResult.targetNoteName,
            expectedNoteName: _expectedNote?.noteName,
            isSilent: true,
          );
        }

        _validatePerformance();
        _updateTelemetry();
        notifyListeners();
      });
    };

    _metronomeService.onSubTick = (subTick) {
      final ts = currentMeasureTimeSignature;
      final int beatTicks = (ts.denominator == 8 && ts.numerator >= 6 && ts.numerator % 3 == 0)
          ? 6
          : (ts.denominator == 8 ? 2 : (ts.denominator == 2 ? 8 : 4));
      final int countInBeats = (ts.totalTicks / beatTicks).round().clamp(1, 16);

      if (_isCountingIn) {
        if (subTick % beatTicks == 0) {
          final metroGain = _mixerConsole.getEffectiveGain(_mixerConsole.metronomeTrack.id);
          if (metroGain > 0.001) {
            _echoSuppressor.notifyClickEmitted();
            _audioSynthesizer.playMetronomeClick(
              isDownbeat: _countInBeat == 1,
              volume: metroGain,
            );
          }
          _countInBeat++;
          if (_countInBeat > countInBeats) {
            _isCountingIn = false;
            _currentMeasureIndex = 0;
            _currentSubTick = -1;
            _measureHistory.clear();
            _updateExpectedNoteForTick(0);
          }
        }
      } else {
        if (_isSmartWaitEnabled &&
            _isPracticeMode &&
            _expectedNote != null &&
            !_expectedNote!.isRest &&
            _expectedNote!.noteName != "--" &&
            !_isNoteCorrect) {
          // Smart Wait: retener el avance de compás/tick hasta que el alumno toque la nota esperada
          notifyListeners();
          return;
        }

        if (_currentSubTick != -1 && subTick == 0) {
          final maxMeasures = _activePackage.totalMeasures;
          final nextIndex = (_currentMeasureIndex + 1) % maxMeasures;

          // Si completamos todas las medidas en modo práctica, generamos reporte
          if (_isPracticeMode && nextIndex == 0 && _activeEvaluations.isNotEmpty) {
            _generatePracticeReport();
          }

          _currentMeasureIndex = nextIndex;
          _measureHistory.clear();
        }

        _currentSubTick = subTick;
        _updateExpectedNoteForTick(subTick);

        // Disparo sonoro polifónico de las notas musicales de la partitura
        if (_isScorePlaybackEnabled) {
          final msPerTick = 60000.0 / _bpm / 4.0;
          final activeNotes = currentMeasureNotes.where((n) => !n.isRest && n.startTick == subTick);
          final leadTrackId = _activePackage.tracks.isNotEmpty
              ? _activePackage.tracks.first.id
              : "voice";
          final voiceGain = _mixerConsole.getEffectiveGain(leadTrackId);

          if (voiceGain > 0.001) {
            for (final note in activeNotes) {
              final noteName = note.noteName;
              if (noteName != "--" && noteName.toLowerCase() != "rest" && noteName.isNotEmpty) {
                final freq = NoteEntity.frequencyForNote(noteName, a4Ref: _referencePitch);
                if (freq > 20.0) {
                  final durationMs = (note.durationTicks * msPerTick).round();
                  _audioSynthesizer.playNoteTone(
                    frequency: freq,
                    duration: Duration(milliseconds: durationMs),
                    volume: voiceGain,
                  );
                }
              }
            }
          }
        }

        if (subTick % beatTicks == 0) {
          final metroGain = _mixerConsole.getEffectiveGain(_mixerConsole.metronomeTrack.id);
          if (metroGain > 0.001) {
            _echoSuppressor.notifyClickEmitted();
            _audioSynthesizer.playMetronomeClick(
              isDownbeat: subTick == 0,
              volume: metroGain,
            );
          }
        }
      }

      _validatePerformance();
      notifyListeners();
    };

    _amplitudeSubscription = _recorderService.amplitudeStream.listen((peak) {
      if (_recorderController.isAudioRecording) {
        _recorderController.addWaveformPeak(peak);
        notifyListeners();
      }
    });

    _positionSubscription = _playbackService.onPositionChanged.listen((pos) {
      _recorderController.updatePlaybackPosition(pos);
      notifyListeners();
    });

    _durationSubscription = _playbackService.onDurationChanged.listen((dur) {
      _recorderController.updatePlaybackDuration(dur);
      notifyListeners();
    });

    _completeSubscription = _playbackService.onPlayerComplete.listen((_) {
      _recorderController.markPlaybackComplete();
      notifyListeners();
    });
  }

  void setInstrumentProfile(InstrumentProfileEntity instrument) {
    _activeInstrument = instrument;
    _syncInstrumentAcousticFilter();
    _validatePerformance();

    _vocalPedagogyController.adaptActiveLessonToInstrument(
      _activeInstrument,
      toleranceCents: centsTolerance,
    );

    notifyListeners();
    _triggerAutoSave();
  }

  /// Alterna el modo de reconocimiento acústico inteligente de instrumentos (UC-59).
  void toggleSmartInstrumentTuning() {
    _isSmartInstrumentTuningActive = !_isSmartInstrumentTuningActive;
    if (!_isSmartInstrumentTuningActive) {
      _lastDetectedMatch = null;
    }
    notifyListeners();
  }

  /// Alterna la auto-adaptación directa vs sugerencia interactiva.
  void toggleAutoSwitchInstrument() {
    _autoSwitchInstrumentEnabled = !_autoSwitchInstrumentEnabled;
    notifyListeners();
  }

  /// Aplica la adaptación al instrumento reconocido: actualiza perfil, filtro acústico y patch SoundFont.
  void applyDetectedInstrumentMatch(SmartInstrumentMatch match) {
    setInstrumentProfile(match.instrument);
    selectSoundFontPatch(match.soundFontPatch);
    _lastDetectedMatch = match;
    notifyListeners();
  }

  /// Descarta o limpia la sugerencia de reconocimiento acústico activa.
  void dismissSmartInstrumentMatch() {
    _lastDetectedMatch = null;
    notifyListeners();
  }

  /// Evalúa la firma acústica espectral y reconoce el instrumento candidato.
  SmartInstrumentMatch? evaluateSmartInstrumentAcoustics({
    required double freqHz,
    required List<double> overtones,
    required double clarity,
    required double centroidHz,
    double minimumConfidence = 0.75,
  }) {
    if (freqHz <= 0 || clarity < 0.60) return null;

    final signature = AcousticSignature(
      fundamentalFrequencyHz: freqHz,
      clarity: clarity,
      overtoneAmplitudes: overtones,
      spectralCentroidHz: centroidHz,
    );

    final match = _smartInstrumentDetector.bestMatch(
      signature,
      minimumConfidence: minimumConfidence,
    );

    if (match != null) {
      _lastDetectedMatch = match;
      if (_autoSwitchInstrumentEnabled && match.instrument.id != _activeInstrument.id) {
        applyDetectedInstrumentMatch(match);
      } else {
        notifyListeners();
      }
    }

    return match;
  }

  void _evaluateSmartInstrumentFromPitch(double pitch) {
    if (pitch <= 20.0) return;
    evaluateSmartInstrumentAcoustics(
      freqHz: pitch,
      overtones: const [1.0, 0.5, 0.25, 0.12, 0.06, 0.03, 0.01, 0.0],
      clarity: 0.90,
      centroidHz: pitch * 2.0,
      minimumConfidence: 0.65,
    );
  }

  /// Alterna el modo de aislamiento acústico por tesitura instrumental y rechazo de habla/ruidos.
  void toggleInstrumentIsolation() {
    _isInstrumentIsolationActive = !_isInstrumentIsolationActive;
    _acousticRigorProfile = _acousticRigorProfile.copyWith(
      enableInstrumentIsolation: _isInstrumentIsolationActive,
    );
    _syncInstrumentAcousticFilter();
    notifyListeners();
    _triggerAutoSave();
  }

  /// Establece el modo de aislamiento acústico por tesitura instrumental.
  void setInstrumentIsolation(bool active) {
    if (_isInstrumentIsolationActive != active) {
      _isInstrumentIsolationActive = active;
      _acousticRigorProfile = _acousticRigorProfile.copyWith(
        enableInstrumentIsolation: active,
      );
      _syncInstrumentAcousticFilter();
      notifyListeners();
      _triggerAutoSave();
    }
  }

  /// Selecciona un preset acústico de contexto (Fácil, Ensayo, Grabación, Escenario, Conservatorio).
  void setAcousticRigorPreset(AcousticRigorPreset preset) {
    final baseGate = _micProfile.measuredNoiseFloorRms > 0.0001
        ? _micProfile.measuredNoiseFloorRms * 2.2
        : _micProfile.noiseGateThreshold;
    _acousticRigorProfile = AcousticRigorProfile.fromPreset(
      preset,
      isAdvancedMode: _acousticRigorProfile.isAdvancedMode,
      baseNoiseGate: baseGate,
      baseGain: _micProfile.digitalGain,
    );
    _micProfile = _micProfile.copyWith(
      noiseGateThreshold: _acousticRigorProfile.noiseGateThreshold,
      digitalGain: _acousticRigorProfile.digitalGain,
      enableDcBlocker: _acousticRigorProfile.enableDcBlocker,
    );
    _isInstrumentIsolationActive = _acousticRigorProfile.enableInstrumentIsolation;
    _pitchService.updateCalibrationProfile(_micProfile);
    _syncInstrumentAcousticFilter();
    notifyListeners();
    _triggerAutoSave();
  }

  /// Permite ajustar parámetros granulares en modo avanzado (para ingenieros y productores).
  void setAcousticRigorAdvancedParameters({
    double? minClarity,
    int? minConsecutiveFrames,
    double? maxCentsDeviation,
    double? noiseGateThreshold,
    double? digitalGain,
    bool? enableDcBlocker,
    bool? enableInstrumentIsolation,
  }) {
    _acousticRigorProfile = _acousticRigorProfile.copyWith(
      preset: AcousticRigorPreset.custom,
      minClarity: minClarity,
      minConsecutiveFrames: minConsecutiveFrames,
      maxCentsDeviation: maxCentsDeviation,
      noiseGateThreshold: noiseGateThreshold,
      digitalGain: digitalGain,
      enableDcBlocker: enableDcBlocker,
      enableInstrumentIsolation: enableInstrumentIsolation,
    );
    _micProfile = _micProfile.copyWith(
      noiseGateThreshold: _acousticRigorProfile.noiseGateThreshold,
      digitalGain: _acousticRigorProfile.digitalGain,
      enableDcBlocker: _acousticRigorProfile.enableDcBlocker,
    );
    if (enableInstrumentIsolation != null) {
      _isInstrumentIsolationActive = enableInstrumentIsolation;
    }
    _pitchService.updateCalibrationProfile(_micProfile);
    _syncInstrumentAcousticFilter();
    notifyListeners();
    _triggerAutoSave();
  }

  /// Conmuta entre la vista de presets sencillos y la vista avanzada en el modal de calibración.
  void toggleAcousticRigorAdvancedView() {
    _acousticRigorProfile = _acousticRigorProfile.copyWith(
      isAdvancedMode: !_acousticRigorProfile.isAdvancedMode,
    );
    notifyListeners();
    _triggerAutoSave();
  }

  /// Sincroniza la configuración de filtro acústico e histéresis temporal con el detector MPM.
  void _syncInstrumentAcousticFilter() {
    final isolationActive = _isInstrumentIsolationActive && _acousticRigorProfile.enableInstrumentIsolation;
    if (!isolationActive || _activeInstrument.id == 'voice') {
      _pitchService.setInstrumentAcousticFilter(
        InstrumentAcousticFilterConfig.universal(
          enabled: isolationActive,
        ).copyWith(
          minClarity: _acousticRigorProfile.minClarity,
          minConsecutiveFrames: _acousticRigorProfile.minConsecutiveFrames,
          maxCentsDeviation: _acousticRigorProfile.maxCentsDeviation,
        ),
      );
    } else {
      _pitchService.setInstrumentAcousticFilter(
        InstrumentAcousticFilterConfig.forInstrument(
          minFrequencyHz: _activeInstrument.minFrequencyHz,
          maxFrequencyHz: _activeInstrument.maxFrequencyHz,
          enabled: true,
          minClarity: _acousticRigorProfile.minClarity,
        ).copyWith(
          minConsecutiveFrames: _acousticRigorProfile.minConsecutiveFrames,
          maxCentsDeviation: _acousticRigorProfile.maxCentsDeviation,
        ),
      );
    }
  }

  /// Calibra la afinación de concierto del tono A4 (rango 415.0 Hz a 466.0 Hz).
  /// Presets típicos: 432 Hz (Filosófico/Verdi), 440 Hz (Estándar ISO), 442 Hz (Sinfónico), 444 Hz (Brillante).
  void setReferencePitch(double pitch) {
    final clamped = pitch.clamp(415.0, 466.0);
    if ((_referencePitch - clamped).abs() > 0.01) {
      _referencePitch = clamped;
      if (_frequency > 0) {
        _recalculatePitchForActiveTemperament();
      }
      if (_audioSynthesizer.isDiapasonPlaying) {
        _audioSynthesizer.startDiapasonTone(_referencePitch);
      }
      if (_audioSynthesizer.isDroneLoopPlaying) {
        _refreshDronePlayback();
      }
      _validatePerformance();
      notifyListeners();
      _triggerAutoSave();
    }
  }

  /// Indica si el diapasón acústico de concierto está sonando actualmente.
  bool get isDiapasonPlaying => _audioSynthesizer.isDiapasonPlaying;

  /// Alterna (inicia / detiene) la emisión del tono continuo de diapasón A4 calibrado.
  Future<void> toggleDiapasonTone() async {
    if (_audioSynthesizer.isDiapasonPlaying) {
      await _audioSynthesizer.stopDiapasonTone();
    } else {
      await _audioSynthesizer.startDiapasonTone(_referencePitch);
    }
    notifyListeners();
  }

  /// Detiene la emisión del diapasón de concierto.
  Future<void> stopDiapasonTone() async {
    if (_audioSynthesizer.isDiapasonPlaying) {
      await _audioSynthesizer.stopDiapasonTone();
      notifyListeners();
    }
  }

  /// Sintetiza y reproduce una frecuencia acústica de referencia (Hz) con duración y envolvente.
  Future<void> playSyntheticTone(
    double frequencyHz, {
    Duration duration = const Duration(milliseconds: 600),
  }) async {
    await _audioSynthesizer.playNoteTone(frequency: frequencyHz, duration: duration);
  }

  /// Inicia la emisión de un tono continuo de diapasón a la frecuencia especificada en [frequencyHz].
  Future<void> startReferencePitchTone(double frequencyHz) async {
    await _audioSynthesizer.startDiapasonTone(frequencyHz);
    notifyListeners();
  }

  /// Detiene la emisión de tonos sintéticos o diapasón.
  Future<void> stopReferenceTone() async {
    await stopDiapasonTone();
  }

  /// Actualiza la configuración acústica del dron pedal (nota, octava, armónicos, timbre, volumen).
  Future<void> setDroneConfig(HarmonicDroneConfig config) async {
    _droneConfig = config;
    if (_audioSynthesizer.isDroneLoopPlaying) {
      await _refreshDronePlayback();
    }
    notifyListeners();
  }

  /// Alterna (inicia / detiene) la emisión del bucle continuo del dron armónico.
  Future<void> toggleDrone() async {
    if (_audioSynthesizer.isDroneLoopPlaying) {
      await _audioSynthesizer.stopDroneLoop();
    } else {
      await _refreshDronePlayback();
    }
    notifyListeners();
  }

  /// Detiene la reproducción del dron armónico si está activo.
  Future<void> stopDrone() async {
    if (_audioSynthesizer.isDroneLoopPlaying) {
      await _audioSynthesizer.stopDroneLoop();
      notifyListeners();
    }
  }

  Future<void> _refreshDronePlayback() async {
    final buffer = _droneSynthesizer.generateDroneWavBuffer(
      config: _droneConfig,
      a4Ref: _referencePitch,
      temperament: _selectedTemperament,
      temperamentRootKey: _temperamentRootKey,
    );
    await _audioSynthesizer.startDroneLoop(buffer, volume: _droneConfig.volume);
  }

  /// Selecciona el perfil pedagógico de aprendizaje (Infantil, Adulto, Conservatorio).
  void setLearnerProfileType(LearnerProfileType type) {
    switch (type) {
      case LearnerProfileType.childPlayful:
        _learnerProfile = LearnerProfileEntity.child();
        _isSmartWaitEnabled = true;
        break;
      case LearnerProfileType.adultDeliberate:
        _learnerProfile = LearnerProfileEntity.adult();
        _isSmartWaitEnabled = true;
        break;
      case LearnerProfileType.conservatoryMastery:
        _learnerProfile = LearnerProfileEntity.conservatory();
        _isSmartWaitEnabled = false;
        break;
      case LearnerProfileType.custom:
        _learnerProfile = _learnerProfile.copyWith(type: LearnerProfileType.custom);
        break;
    }
    _consecutiveSuccesses = 0;
    _consecutiveErrors = 0;
    _triggerAutoSave();
    notifyListeners();
  }

  /// Actualiza la configuración detallada del perfil pedagógico.
  void updateLearnerProfile(LearnerProfileEntity profile) {
    _learnerProfile = profile;
    _isSmartWaitEnabled = profile.enableSmartWait;
    _consecutiveSuccesses = 0;
    _consecutiveErrors = 0;
    _triggerAutoSave();
    notifyListeners();
  }

  /// Alterna el estado activo del reconocedor polifónico de acordes.
  @override
  void toggleChordRecognition() {
    _isChordRecognitionActive = !_isChordRecognitionActive;
    if (!_isChordRecognitionActive) {
      _recognizedChord = ChordEntity.none;
      _multiToneResult = PolyphonicMultiToneAnalysisResult.empty;
      _chordRecognizer.reset();
      _activeChromaVector = List<double>.filled(12, 0.0);
    }
    notifyListeners();
  }

  /// Establece explícitamente el estado del reconocedor de acordes.
  void setChordRecognitionActive(bool active) {
    if (_isChordRecognitionActive != active) {
      toggleChordRecognition();
    }
  }

  /// Procesa muestras PCM normalizadas [-1.0, 1.0] para análisis armónico polifónico multitonal.
  void processChordSamples(List<double> samples) {
    _latestAudioSamples = samples;
    if (!_isChordRecognitionActive) return;

    final multiResult = _multiToneDetector.detectFromSamples(
      samples: samples,
      sampleRate: 44100.0,
      a4Ref: _referencePitch,
    );
    _multiToneResult = multiResult;

    final chroma = _chromaCalculator.calculateFromSamples(
      samples: samples,
      a4Ref: _referencePitch,
    );
    _activeChromaVector = chroma;

    final detected = multiResult.chord.isRecognized
        ? multiResult.chord
        : _chordRecognizer.identifyFromChroma(chroma);

    if (detected.isRecognized) {
      if (_chordHistory.isEmpty || _chordHistory.last != detected) {
        _chordHistory.add(detected);
        if (_chordHistory.length > 20) {
          _chordHistory.removeAt(0);
        }
      }
    }
    _recognizedChord = detected;

    if (_scoreEditorController.isPolyphonicTranscriptionActive) {
      final noteNames = multiResult.voices.map((v) => v.fullNoteName).toList();
      final effectiveNotes = noteNames.isNotEmpty
          ? noteNames
          : (detected.isRecognized ? detected.notes : <String>[]);

      final double rms;
      if (samples.isNotEmpty) {
        double sumSquares = 0.0;
        for (final s in samples) {
          sumSquares += s * s;
        }
        rms = math.sqrt(sumSquares / samples.length);
      } else {
        rms = _currentMicRmsLevel;
      }

      final updatedPkg = _scoreEditorController.processPolyphonicTranscriptionFrame(
        activePackage: _activePackage,
        noteNames: effectiveNotes,
        energyRms: rms,
      );
      if (updatedPkg != null) {
        _activePackage = updatedPkg;
      }
    }

    notifyListeners();
  }

  void _updateChordFromPitch(double pitchHz) {
    if (pitchHz > 20.0) {
      final chroma = _chromaCalculator.calculateFromFrequencies(
        frequencyAmplitudes: {pitchHz: 1.0},
        a4Ref: _referencePitch,
      );
      _activeChromaVector = chroma;
      final detected = _chordRecognizer.identifyFromChroma(chroma);
      if (detected.isRecognized) {
        if (_chordHistory.isEmpty || _chordHistory.last != detected) {
          _chordHistory.add(detected);
          if (_chordHistory.length > 20) {
            _chordHistory.removeAt(0);
          }
        }
      }
      _recognizedChord = detected;
    } else {
      _recognizedChord = ChordEntity.none;
    }
  }

  /// Limpia la progresión armónica registrada en el historial.
  void clearChordHistory() {
    _chordHistory.clear();
    notifyListeners();
  }

  void _updateExpectedNoteForTick(int tick) {
    final notes = currentMeasureNotes;
    _expectedNote = notes.firstWhere(
      (n) => tick >= n.startTick && tick < (n.startTick + n.durationTicks),
      orElse: () => HierarchicalNote(startTick: tick, durationTicks: 1, noteName: "--"),
    );

    // Registro atómico de evaluación pedagógica si cambió la nota
    if (_isPracticeMode &&
        _expectedNote != null &&
        _expectedNote != _lastEvaluatedNote &&
        !_isCountingIn) {
      _lastEvaluatedNote = _expectedNote;
      final soundingExpected = _transpositionService.getSoundingNote(
        _expectedNote!.noteName,
        _activeInstrument,
      );
      final eval = _evaluatorService.evaluateNote(
        expectedNote: _expectedNote!,
        soundingExpectedNoteName: soundingExpected,
        detectedNoteName: _noteName,
        detectedFrequency: _frequency,
        detectedCents: _cents,
        timingDeltaMs: 0,
        sustainRatio: 1.0,
      );
      _activeEvaluations.add(eval);
      _vocalPedagogyController.recordMinusOneEvaluation(eval);
    }
  }

  void _validatePerformance() {
    if (_isCountingIn || _expectedNote == null || _currentSubTick == -1) {
      _isNoteCorrect = false;
      return;
    }

    if (_expectedNote!.isRest) {
      _isNoteCorrect = _noteName == "--" || _frequency < 50;
      _measureHistory[_currentSubTick] = PlayedRecord("", 0, _isNoteCorrect, isRest: true);
    } else {
      final targetSoundingNote = _transpositionService.getSoundingNote(
        _expectedNote!.noteName,
        _activeInstrument,
      );

      if (_noteName == "--") {
        _isNoteCorrect = false;
      } else {
        _isNoteCorrect = _noteName.toLowerCase() == targetSoundingNote.toLowerCase();
      }

      if (_isNoteCorrect) {
        _measureHistory[_currentSubTick] = PlayedRecord(_noteName, _cents, true);
      } else if (_noteName != "--") {
        _measureHistory[_currentSubTick] = PlayedRecord(_noteName, _cents, false);
      }
    }
  }

  @override
  Future<void> toggleRecording() async {
    if (_isRecording) {
      await _pitchService.stopRecording();
      _silenceTimer?.cancel();
      _isRecording = false;
      _frequency = 0.0;
      _noteName = "--";
    } else {
      await _pitchService.startRecording();
      _isRecording = true;
    }
    _updateTelemetry();
    notifyListeners();
  }

  Future<void> startSongWithCountIn() async {
    if (_isMetronomePlaying) {
      await _metronomeService.stop();
      _isMetronomePlaying = false;
      if (_isPracticeMode && _activeEvaluations.isNotEmpty) {
        _generatePracticeReport();
      }
      resetSongState();
    } else {
      _isCountingIn = true;
      _countInBeat = 1;
      _currentSubTick = -1;
      _measureHistory.clear();
      _lastEvaluatedNote = null;
      _activeEvaluations.clear();
      _isMetronomePlaying = true;
      final ts = currentMeasureTimeSignature;
      final metro = _metronomeService;
      if (metro is IMeteredMetronomeService) {
        await metro.startWithMeter(
          _bpm,
          ticksPerMeasure: ts.totalTicks,
          meterDenominator: ts.denominator,
        );
      } else {
        await metro.start(_bpm, ticksPerMeasure: ts.totalTicks);
      }
    }
    notifyListeners();
  }

  void togglePracticeMode() {
    _isPracticeMode = !_isPracticeMode;
    if (_isPracticeMode) {
      _activeEvaluations.clear();
      _lastEvaluatedNote = null;
    }
    notifyListeners();
  }

  void toggleSmartWait() {
    _isSmartWaitEnabled = !_isSmartWaitEnabled;
    notifyListeners();
    _triggerAutoSave();
  }

  void _generatePracticeReport() {
    if (_activeEvaluations.isEmpty) return;

    final prev = _sessionHistory.isNotEmpty ? _sessionHistory.last : null;
    final report = _evaluatorService.generateReport(
      songTitle: _activePackage.title,
      instrumentName: _activeInstrument.name,
      evaluations: List.unmodifiable(_activeEvaluations),
      previousSession: prev,
      recording: _recorderController.activeRecording,
    );
    _lastReport = report;
    _sessionHistory.add(report);
    _triggerAutoSave();
  }

  void completeManualPracticeSession() {
    if (_activeEvaluations.isNotEmpty) {
      _generatePracticeReport();
      notifyListeners();
    }
  }

  void updateBpm(int newBpm) {
    _bpm = newBpm.clamp(20, 300);
    _scorePlaybackCoordinator.bpm = _bpm.toDouble();
    if (_isMetronomePlaying) {
      final ts = currentMeasureTimeSignature;
      _metronomeService.stop().then((_) {
        if (_isMetronomePlaying && !_isDisposed) {
          final metro = _metronomeService;
          if (metro is IMeteredMetronomeService) {
            metro.startWithMeter(
              _bpm,
              ticksPerMeasure: ts.totalTicks,
              meterDenominator: ts.denominator,
            );
          } else {
            metro.start(_bpm, ticksPerMeasure: ts.totalTicks);
          }
        }
      });
    }
    _triggerAutoSave();
    notifyListeners();
  }

  void incrementBpm([int step = 1]) => updateBpm(_bpm + step);
  void decrementBpm([int step = 1]) => updateBpm(_bpm - step);

  /// Registra una pulsación manual en el motor de Tap Tempo y calibra automáticamente el metrónomo.
  void recordTapTempo([int? timestampMs]) {
    final result = _tapTempoEngine.recordTap(timestampMs);
    _lastTapTempoResult = result;
    if (result.isCalibrated) {
      updateBpm(result.bpm);
    } else {
      notifyListeners();
    }
  }

  /// Limpia la sesión actual del motor de Tap Tempo.
  void resetTapTempo() {
    _tapTempoEngine.reset();
    _lastTapTempoResult = null;
    notifyListeners();
  }

  IScoreParserService get scoreImporterService => _scoreImporterService;

  /// Importa una partitura externa en formato MusicXML o MIDI a partir de su contenido en bytes.
  Future<ParsedScoreResult?> importScoreFromBytes(Uint8List bytes, String fileName) async {
    try {
      final result = await _scoreImporterService.parseScoreData(
        bytes: bytes,
        fileName: fileName,
      );
      addSongPackage(result.package);
      _workspaceScores.removeWhere((p) => p.id == result.package.id);
      _workspaceScores.insert(0, result.package);
      await _triggerAutoSave();
      notifyListeners();
      return result;
    } catch (e) {
      _logger.warning('TunerViewModel', "Error al importar partitura: $e");
      return null;
    }
  }

  /// Crea una nueva partitura en blanco de conservatorio y la agrega al espacio de trabajo.
  SongPackage createWorkspaceScore({
    required String title,
    required int bpm,
    required TimeSignature timeSignature,
    int initialMeasures = 4,
  }) {
    final validMeasures = List.generate(
      math.max(1, initialMeasures),
      (idx) => MeasureEntity(
        index: idx,
        timeSignature: timeSignature,
        notes: [
          HierarchicalNote.rest(
            startTick: 0,
            durationTicks: timeSignature.totalTicks,
          ),
        ],
      ),
    );

    final score = HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: validMeasures,
    );

    final pkg = SongPackage(
      id: 'pkg_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      composer: 'Compositor Tunner',
      genre: MusicGenre.classical,
      difficulty: SongDifficulty.beginner,
      defaultBpm: bpm,
      score: score,
      tracks: const [],
    );

    _workspaceScores.removeWhere((s) => s.id == pkg.id);
    _workspaceScores.insert(0, pkg);
    addSongPackage(pkg);
    _triggerAutoSave();
    notifyListeners();
    return pkg;
  }

  /// Importa una obra maestra canónica directamente al espacio de trabajo activo.
  SongPackage importPresetToWorkspace(SongPackage preset) {
    final cloned = preset.copyWith(
      id: 'score_${DateTime.now().microsecondsSinceEpoch}',
    );
    _workspaceScores.removeWhere((s) => s.id == cloned.id);
    _workspaceScores.insert(0, cloned);
    addSongPackage(cloned);
    _triggerAutoSave();
    notifyListeners();
    return cloned;
  }

  /// Elimina una partitura del espacio de trabajo del usuario.
  void deleteWorkspaceScore(String id) {
    _workspaceScores.removeWhere((s) => s.id == id);
    _triggerAutoSave();
    notifyListeners();
  }

  /// Abre el selector nativo del sistema de archivos para importar partituras MusicXML, MIDI, etc.
  Future<ParsedScoreResult?> importScoreFromFilePicker() async {
    try {
      final picked = await _platformFileGateway.pickFile(
        allowedExtensions: ['musicxml', 'xml', 'mxl', 'mid', 'midi', 'abc', 'pdf', 'wav'],
      );

      if (picked == null || picked.bytes == null || picked.bytes!.isEmpty) {
        return null;
      }

      final parsed = await importScoreFromBytes(picked.bytes!, picked.name);
      return parsed;
    } catch (e) {
      _logger.warning('TunerViewModel', "Error al seleccionar archivo en FilePicker: $e");
      return null;
    }
  }

  /// Guarda un nuevo preset de afinación acústica y lo persiste offline.
  void saveCustomTuningPreset(TuningPresetEntity preset) {
    _tuningPresets.removeWhere((p) => p.id == preset.id);
    _tuningPresets.insert(0, preset);
    _triggerAutoSave();
    notifyListeners();
  }

  /// Elimina un preset de afinación del usuario.
  void deleteCustomTuningPreset(String id) {
    _tuningPresets.removeWhere((p) => p.id == id);
    _triggerAutoSave();
    notifyListeners();
  }

  /// Aplica de forma inmediata la calibración y temperamento de un preset.
  void applyTuningPreset(TuningPresetEntity preset) {
    setReferencePitch(preset.referencePitchHz);
    if (preset.temperamentId.isNotEmpty) {
      setTemperament(preset.temperamentId);
    }
    setTemperamentRoot(preset.rootKey);
  }

  /// Elimina una grabación de práctica y actualiza la persistencia offline.
  void deletePracticeRecording(String id) {
    _recorderController.deletePracticeRecordingById(id);
  }

  void addSongPackage(SongPackage package) {
    _curatedLibrary.removeWhere((p) => p.id == package.id);
    _curatedLibrary.insert(0, package);
    loadSongPackage(package);
  }

  void loadSongPackage(SongPackage package) {
    _activePackage = package;
    _bpm = package.defaultBpm;
    _customTimeSignatureOverride = null;

    _mixerConsole = MixerConsoleEntity(
      metronomeTrack: _mixerConsole.metronomeTrack,
      stems: package.tracks,
    );

    if (_vocalPedagogyController.isMinusOneActive) {
      _mixerConsole = _vocalPedagogyController.setMinusOneUserTrack(
        activePackage: package,
        mixerConsole: _mixerConsole,
        trackId: _vocalPedagogyController.activeMinusOneSession!.userTrackId,
      );
    }

    resetSongState();
    notifyListeners();
  }

  void resetSongState() {
    _isCountingIn = false;
    _countInBeat = 0;
    _currentSubTick = -1;
    _currentMeasureIndex = 0;
    _measureHistory.clear();
    _lastEvaluatedNote = null;
    _activeEvaluations.clear();
  }

  void selectMeasure(int measureIndex) {
    final maxMeasures = _activePackage.totalMeasures;
    if (measureIndex >= 0 && measureIndex < maxMeasures) {
      _currentMeasureIndex = measureIndex;
      _currentSubTick = -1;
      _measureHistory.clear();
      _lastEvaluatedNote = null;
      notifyListeners();
    }
  }

  void nextMeasure() {
    final maxMeasures = _activePackage.totalMeasures;
    selectMeasure((_currentMeasureIndex + 1) % maxMeasures);
  }

  void previousMeasure() {
    final maxMeasures = _activePackage.totalMeasures;
    selectMeasure((_currentMeasureIndex - 1 + maxMeasures) % maxMeasures);
  }

  void setPalette(TunnerThemePalette palette) {
    _currentPalette = palette;
    _themeMode = palette.mode;
    notifyListeners();
    _triggerAutoSave();
  }

  void setThemeMode(TunnerThemeMode mode) {
    _themeMode = mode;
    _currentPalette = TunnerThemePalette.fromMode(mode);
    notifyListeners();
    _triggerAutoSave();
  }

  /// Activa una paleta cromática de la aplicación a partir de su ID o nombre descriptivo.
  void setPaletteById(String paletteId) {
    final query = paletteId.toLowerCase();
    for (final palette in TunnerThemePalette.allPresets) {
      if (palette.id.toLowerCase() == query ||
          palette.displayName.toLowerCase().contains(query)) {
        setPalette(palette);
        return;
      }
    }
  }

  void addCustomPalette(TunnerThemePalette palette) {
    _customPalettes.removeWhere((p) => p.id == palette.id);
    _customPalettes.add(palette);
    _currentPalette = palette;
    _themeMode = palette.mode;
    notifyListeners();
    _triggerAutoSave();
  }

  void updateCustomPalette(TunnerThemePalette palette) {
    final index = _customPalettes.indexWhere((p) => p.id == palette.id);
    if (index != -1) {
      _customPalettes[index] = palette;
    } else {
      _customPalettes.add(palette);
    }
    if (_currentPalette.id == palette.id) {
      _currentPalette = palette;
    }
    notifyListeners();
    _triggerAutoSave();
  }

  void deleteCustomPalette(String paletteId) {
    _customPalettes.removeWhere((p) => p.id == paletteId);
    if (_currentPalette.id == paletteId) {
      _currentPalette = TunnerThemePalette.obsidianStudio;
      _themeMode = TunnerThemeMode.obsidianStudio;
    }
    notifyListeners();
    _triggerAutoSave();
  }

  bool importPaletteFromJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        final imported = TunnerThemePalette.fromJson(decoded);
        addCustomPalette(imported);
        return true;
      }
      return false;
    } catch (e, st) {
      _logger.warning('TunerViewModel', 'Error al importar paleta JSON: $e', error: e, stackTrace: st);
      return false;
    }
  }

  void setCustomTimeSignature(TimeSignature? signature) {
    _customTimeSignatureOverride = signature;
    final wasPlaying = _isMetronomePlaying;
    resetSongState();
    if (wasPlaying) {
      _isMetronomePlaying = true;
      final ts = currentMeasureTimeSignature;
      _metronomeService.stop().then((_) {
        if (_isMetronomePlaying && !_isDisposed) {
          final metro = _metronomeService;
          if (metro is IMeteredMetronomeService) {
            metro.startWithMeter(
              _bpm,
              ticksPerMeasure: ts.totalTicks,
              meterDenominator: ts.denominator,
            );
          } else {
            metro.start(_bpm, ticksPerMeasure: ts.totalTicks);
          }
        }
      });
    }
    notifyListeners();
  }

  void setTrackVolume(String trackId, double volume) {
    _mixerConsole = _mixerConsole.copyWithTrackVolume(trackId, volume);
    notifyListeners();
    unawaited(_triggerAutoSave());
  }

  void toggleTrackMute(String trackId) {
    _mixerConsole = _mixerConsole.toggleMute(trackId);
    notifyListeners();
    unawaited(_triggerAutoSave());
  }

  void toggleTrackSolo(String trackId) {
    _mixerConsole = _mixerConsole.toggleSolo(trackId);
    notifyListeners();
    unawaited(_triggerAutoSave());
  }

  @override
  void playReferenceTone([String noteName = "La4"]) {
    if (_audioSynthesizer.isDiapasonPlaying) {
      _audioSynthesizer.stopDiapasonTone();
      notifyListeners();
      return;
    }
    final double freq = NoteEntity.frequencyForNote(noteName, a4Ref: _referencePitch);
    if (freq > 0) {
      _audioSynthesizer.startDiapasonTone(freq);
      notifyListeners();
    }
  }

  Timer? _bpmRampTimer;
  bool _isBpmRampActive = false;
  bool get isBpmRampActive => _isBpmRampActive;

  bool _isWarmupActive = false;
  bool get isWarmupActive => _isWarmupActive;

  /// Inicia una rampa progresiva de tempo que incrementa [stepBpm] periódicamente cada [measuresInterval] compases.
  void startProgressiveBpmRamp({int stepBpm = 2, int measuresInterval = 4}) {
    stopProgressiveBpmRamp();
    _isBpmRampActive = true;
    if (!isMetronomeActive) {
      toggleMetronome();
    }
    void scheduleNextRamp() {
      if (!_isBpmRampActive) return;
      final secondsPerMeasure = (60.0 / math.max(30.0, _bpm.toDouble())) * 4.0;
      final duration = Duration(milliseconds: (secondsPerMeasure * measuresInterval * 1000).toInt());
      _bpmRampTimer?.cancel();
      _bpmRampTimer = Timer(duration, () {
        if (!_isBpmRampActive) return;
        incrementBpm(stepBpm);
        scheduleNextRamp();
      });
    }
    scheduleNextRamp();
    notifyListeners();
  }

  /// Detiene la rampa progresiva de tempo.
  void stopProgressiveBpmRamp() {
    _bpmRampTimer?.cancel();
    _bpmRampTimer = null;
    _isBpmRampActive = false;
    notifyListeners();
  }

  /// Inicia una rutina guiada de calentamiento combinando afinación con dron armónico.
  void startGuidedWarmupRoutine() {
    _isWarmupActive = true;
    if (!_isRecording) {
      unawaited(toggleRecording());
    }
    if (!isDronePlaying) {
      toggleDrone();
    }
    notifyListeners();
  }

  /// Detiene la rutina guiada de calentamiento.
  void stopGuidedWarmupRoutine() {
    _isWarmupActive = false;
    if (isDronePlaying) {
      toggleDrone();
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _updateTelemetry() {
    if (_isDisposed) return;
    _telemetryNotifier.value = TunerAcousticTelemetry(
      frequency: _frequency,
      cents: _cents,
      noteName: _noteName,
      micRmsLevel: _currentMicRmsLevel,
      isRecording: _isRecording,
    );
  }

  // --- Delegación hacia PracticeRecorderController ---
  Future<void> startPracticeRecording() => _recorderController.startPracticeRecording();

  Future<void> stopPracticeRecording() => _recorderController.stopPracticeRecording(
        songTitle: _activePackage.title,
        bpm: _bpm,
      );

  Future<void> togglePracticeRecording() => _recorderController.togglePracticeRecording(
        songTitle: _activePackage.title,
        bpm: _bpm,
      );

  Future<void> playActiveRecording([PracticeRecordingEntity? targetRecording]) =>
      _recorderController.playActiveRecording(
        targetRecording: targetRecording,
        referencePitch: _referencePitch,
      );

  Future<void> pauseActiveRecording() => _recorderController.pauseActiveRecording();

  Future<void> stopActiveRecordingPlayback() => _recorderController.stopActiveRecordingPlayback();

  Future<void> seekPlayback(Duration position) => _recorderController.seekPlayback(position);

  Future<void> setPlaybackSpeed(double speed) => _recorderController.setPlaybackSpeed(speed);

  void discardActiveRecording() => _recorderController.discardActiveRecording();

  void selectComparisonTakes({String? takeAId, String? takeBId}) =>
      _recorderController.selectComparisonTakes(takeAId: takeAId, takeBId: takeBId);

  void addPracticeTake(PracticeTakeEntity take) => _recorderController.addPracticeTake(take);

  void setTakeMute(String takeId, bool isMuted) => _recorderController.setTakeMute(takeId, isMuted);

  void setTakeSolo(String takeId, bool isSolo) => _recorderController.setTakeSolo(takeId, isSolo);

  void setTakeGain(String takeId, double gain) => _recorderController.setTakeGain(takeId, gain);

  Future<void> playTakeAudio(PracticeTakeEntity take) => _recorderController.playTakeAudio(take);

  Future<void> loadPersistedState() async {
    await _recorderController.loadSettingsInto((settings) {
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

      if (settings.tuningPresets.isNotEmpty) {
        _tuningPresets.clear();
        _tuningPresets.addAll(settings.tuningPresets);
      }

      if (settings.workspaceScores.isNotEmpty) {
        _workspaceScores.clear();
        _workspaceScores.addAll(settings.workspaceScores);

        SongPackage? restoredActive;
        if (settings.activeScoreId != null) {
          restoredActive = _workspaceScores
              .where((s) => s.id == settings.activeScoreId)
              .firstOrNull;
        }
        restoredActive ??= _workspaceScores
            .where((s) => s.id == _activePackage.id)
            .firstOrNull;
        restoredActive ??= _workspaceScores.first;
        _activePackage = restoredActive;
      }

      if (_shouldSeedDefaults) {
        _seedDefaultWorkspaceIfEmpty();
      }

      if (settings.mixerConsole != null) {
        _mixerConsole = settings.mixerConsole!;
      } else if (settings.workspaceScores.isNotEmpty) {
        _mixerConsole = MixerConsoleEntity(
          metronomeTrack: _mixerConsole.metronomeTrack,
          stems: _activePackage.tracks,
        );
      }

      _micProfile = settings.micCalibrationProfile;
      _acousticRigorProfile = settings.acousticRigorProfile;
      _isInstrumentIsolationActive = _acousticRigorProfile.enableInstrumentIsolation;
      _pitchService.updateCalibrationProfile(_micProfile);
      _syncInstrumentAcousticFilter();

      notifyListeners();
    });
  }

  void _seedDefaultWorkspaceIfEmpty() {
    if (_workspaceScores.isEmpty && _curatedLibrary.isNotEmpty) {
      _workspaceScores.addAll(_curatedLibrary.take(3));
    }
    _recorderController.seedDefaultRecordingsIfEmpty();
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

  Future<void> savePersistedState() => _triggerAutoSave();

  Future<void> _triggerAutoSave() {
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
      recordingHistory: _recorderController.rawRecordingHistory,
      tuningPresets: _tuningPresets,
      workspaceScores: _workspaceScores,
      learnerProfile: _learnerProfile,
      activeWorkspace: _activeWorkspace,
      micCalibrationProfile: _micProfile,
      acousticRigorProfile: _acousticRigorProfile,
      mixerConsole: _mixerConsole,
      activeScoreId: _activePackage.id,
    );
    return _recorderController.saveSettings(settings);
  }

  void _commitActiveScoreMutation() {
    final workspaceIdx = _workspaceScores.indexWhere((s) => s.id == _activePackage.id);
    if (workspaceIdx >= 0) {
      _workspaceScores[workspaceIdx] = _activePackage;
    } else {
      _workspaceScores.insert(0, _activePackage);
    }
    final curatedIdx = _curatedLibrary.indexWhere((s) => s.id == _activePackage.id);
    if (curatedIdx >= 0) {
      _curatedLibrary[curatedIdx] = _activePackage;
    }
    unawaited(_triggerAutoSave());
  }

  // --- Delegación hacia ScoreEditorController ---
  @override
  bool get canUndoScoreEdit => _scoreEditorController.canUndoScoreEdit;
  @override
  bool get canRedoScoreEdit => _scoreEditorController.canRedoScoreEdit;
  int get scoreUndoCount => _scoreEditorController.scoreUndoCount;
  int get scoreRedoCount => _scoreEditorController.scoreRedoCount;
  ExportBundleResult? get lastExportBundle => _scoreEditorController.lastExportBundle;
  bool get isExportingStems => _scoreEditorController.isExportingStems;

  @override
  void insertOrUpdateScoreNote({
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required String noteName,
    bool playAudibleFeedback = true,
  }) {
    _activePackage = _scoreEditorController.insertOrUpdateScoreNote(
      activePackage: _activePackage,
      measureIndex: measureIndex,
      startTick: startTick,
      durationTicks: durationTicks,
      noteName: noteName,
      referencePitch: _referencePitch,
      bpm: _bpm,
      playAudibleFeedback: playAudibleFeedback,
    );
    _validatePerformance();
    _commitActiveScoreMutation();
    notifyListeners();
  }

  @override
  void insertScoreChordNotes({
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required List<String> noteNames,
    bool playAudibleFeedback = true,
  }) {
    _activePackage = _scoreEditorController.insertScoreChordNotes(
      activePackage: _activePackage,
      measureIndex: measureIndex,
      startTick: startTick,
      durationTicks: durationTicks,
      noteNames: noteNames,
      referencePitch: _referencePitch,
      bpm: _bpm,
      playAudibleFeedback: playAudibleFeedback,
    );
    _validatePerformance();
    _commitActiveScoreMutation();
    notifyListeners();
  }

  @override
  void deleteScoreNote({
    required int measureIndex,
    required int startTick,
  }) {
    _activePackage = _scoreEditorController.deleteScoreNote(
      activePackage: _activePackage,
      measureIndex: measureIndex,
      startTick: startTick,
    );
    _commitActiveScoreMutation();
    notifyListeners();
  }

  @override
  void undoScoreEdit() {
    final prev = _scoreEditorController.undoScoreEdit(_activePackage);
    if (prev != null) {
      _activePackage = prev;
      _commitActiveScoreMutation();
      notifyListeners();
    }
  }

  @override
  void redoScoreEdit() {
    final next = _scoreEditorController.redoScoreEdit(_activePackage);
    if (next != null) {
      _activePackage = next;
      _commitActiveScoreMutation();
      notifyListeners();
    }
  }

  @override
  void addScoreMeasure() {
    _activePackage = _scoreEditorController.addScoreMeasure(_activePackage);
    _commitActiveScoreMutation();
    notifyListeners();
  }

  @override
  void removeScoreMeasure(int measureIndex) {
    _activePackage = _scoreEditorController.removeScoreMeasure(_activePackage, measureIndex);
    if (_currentMeasureIndex >= _activePackage.totalMeasures) {
      _currentMeasureIndex = _activePackage.totalMeasures - 1;
    }
    _commitActiveScoreMutation();
    notifyListeners();
  }

  void transposeActiveScore(int semitones) {
    final transposed = _scoreEditorController.transposeActiveScore(_activePackage, semitones);
    if (transposed != null) {
      _activePackage = transposed;
      _commitActiveScoreMutation();
      notifyListeners();
    }
  }

  void transposeActiveScoreForInstrument(InstrumentProfileEntity targetInstrument) {
    final transposed = _scoreEditorController.transposeActiveScoreForInstrument(
      _activePackage,
      targetInstrument,
    );
    if (transposed != null) {
      _activePackage = transposed;
      _commitActiveScoreMutation();
      notifyListeners();
    }
  }

  @override
  String exportActiveScoreToMusicXml() =>
      _scoreEditorController.exportActiveScoreToMusicXml(_activePackage);

  Uint8List exportActiveScoreToMidi() =>
      _scoreEditorController.exportActiveScoreToMidi(_activePackage);

  @override
  String exportActiveScoreToAbc() =>
      _scoreEditorController.exportActiveScoreToAbc(_activePackage);

  Uint8List exportActiveScoreToPdf() =>
      _scoreEditorController.exportActiveScoreToPdf(_activePackage);

  PedagogicalSessionData get currentPedagogicalSessionData =>
      _scoreEditorController.buildPedagogicalSessionData(
        activePackage: _activePackage,
        sessionHistory: _sessionHistory,
        multiTrackSession: _recorderController.multiTrackSession,
        cents: _cents,
        bpm: _bpm,
        lastTapTempoResult: _lastTapTempoResult,
      );

  Uint8List exportPedagogicalReportPdf(PedagogicalReportConfig config) =>
      _scoreEditorController.exportPedagogicalReportPdf(
        sessionData: currentPedagogicalSessionData,
        config: config,
      );

  Future<ParsedScoreResult?> transcribeAudioFileToScore(
    Uint8List audioBytes,
    String fileName,
  ) async {
    final result = await _scoreEditorController.transcribeAudioFileToScore(audioBytes, fileName);
    if (result != null) {
      addSongPackage(result.package);
      notifyListeners();
    }
    return result;
  }

  void toggleLiveTranscription() {
    final finalPkg = _scoreEditorController.toggleLiveTranscription(
      activePackage: _activePackage,
      currentMeasureIndex: _currentMeasureIndex,
      currentSubTick: _currentSubTick,
      bpm: _bpm,
    );
    if (finalPkg != null) {
      _activePackage = finalPkg;
    }
    notifyListeners();
  }

  void togglePolyphonicLiveTranscription() {
    final finalPkg = _scoreEditorController.togglePolyphonicLiveTranscription(
      activePackage: _activePackage,
      currentMeasureIndex: _currentMeasureIndex,
      currentSubTick: _currentSubTick,
      bpm: _bpm,
      ensureChordRecognitionActive: () {
        if (!_isChordRecognitionActive) {
          _isChordRecognitionActive = true;
        }
      },
    );
    if (finalPkg != null) {
      _activePackage = finalPkg;
    }
    notifyListeners();
  }

  void processPolyphonicTranscriptionFrame({
    required List<String> noteNames,
    double energyRms = 0.1,
  }) {
    final updatedPkg = _scoreEditorController.processPolyphonicTranscriptionFrame(
      activePackage: _activePackage,
      noteNames: noteNames,
      energyRms: energyRms,
    );
    if (updatedPkg != null) {
      _activePackage = updatedPkg;
      notifyListeners();
    }
  }

  void generateAndLoadExercise({
    required String rootNote,
    required ExerciseType type,
    ExerciseRhythm rhythm = ExerciseRhythm.quarter,
    int bpm = 80,
  }) {
    _activePackage = _scoreEditorController.generateExercise(
      activePackage: _activePackage,
      rootNote: rootNote,
      type: type,
      rhythm: rhythm,
      bpm: bpm,
    );
    _bpm = bpm;
    _currentMeasureIndex = 0;
    _currentSubTick = -1;
    _measureHistory.clear();
    _mixerConsole = MixerConsoleEntity(
      metronomeTrack: _mixerConsole.metronomeTrack,
      stems: _activePackage.tracks,
    );
    notifyListeners();
  }

  Future<ExportBundleResult> exportStemsAndMidi({
    StemExportConfig config = const StemExportConfig(),
  }) {
    return _scoreEditorController.exportStemsAndMidi(
      activePackage: _activePackage,
      mixerConsole: _mixerConsole,
      bpm: _bpm,
      recordedTake: _recorderController.activeRecording,
      config: config,
    );
  }

  // --- Delegación hacia VocalPedagogyController ---
  @override
  GuidedLessonProgressEntity? get activeLessonProgress => _vocalPedagogyController.activeLessonProgress;
  @override
  bool get hasActiveGuidedLesson => _vocalPedagogyController.hasActiveGuidedLesson;
  List<GuidedLessonEntity> get availableGuidedLessons =>
      _vocalPedagogyController.availableGuidedLessons(_activeInstrument);

  @override
  void startGuidedLesson(GuidedLessonEntity lesson) =>
      _vocalPedagogyController.startGuidedLesson(lesson, toleranceCents: centsTolerance);

  @override
  void cancelGuidedLesson() => _vocalPedagogyController.cancelGuidedLesson();

  @override
  void jumpToLessonStep(int stepIndex) => _vocalPedagogyController.jumpToLessonStep(stepIndex);

  SongPackage adaptSongPackageToActiveInstrument(SongPackage package) =>
      _vocalPedagogyController.adaptSongPackageToActiveInstrument(package, _activeInstrument);

  VocalAutoTuneProcessor get autoTuneProcessor => _vocalPedagogyController.autoTuneProcessor;
  AutoTuneConfigEntity get autoTuneConfig => _vocalPedagogyController.autoTuneConfig;
  bool get isAutoTuneActive => _vocalPedagogyController.isAutoTuneActive;
  ScaleQuantizationResult get lastAutoTuneResult => _vocalPedagogyController.lastAutoTuneResult;

  void toggleAutoTune() => _vocalPedagogyController.toggleAutoTune();

  void updateAutoTuneConfig(AutoTuneConfigEntity config) =>
      _vocalPedagogyController.updateAutoTuneConfig(config);

  Future<PracticeTakeEntity?> applyAutoTuneToRecordingTake(String takeId) async {
    final res = await _vocalPedagogyController.applyAutoTuneToRecordingTake(
      session: _recorderController.multiTrackSession,
      takeId: takeId,
    );
    if (res == null) return null;
    _recorderController.setMultiTrackSession(res.session);
    notifyListeners();
    await _triggerAutoSave();
    return res.tunedTake;
  }

  VocalScoreConversionResult? convertActiveRecordingToScorePackage({
    String? takeId,
    bool preferCorrectedPitch = true,
    bool autoLoadAsActivePackage = true,
  }) {
    final result = _vocalPedagogyController.convertActiveRecordingToScorePackage(
      session: _recorderController.multiTrackSession,
      currentPitchTrack: _recorderController.rawCurrentPitchTrack,
      bpm: _bpm,
      timeSignature: currentMeasureTimeSignature,
      takeId: takeId,
      preferCorrectedPitch: preferCorrectedPitch,
    );
    if (result == null) return null;

    if (autoLoadAsActivePackage) {
      _scoreEditorController.recordUndoSnapshot(_activePackage);
      _activePackage = result.package;
      _currentMeasureIndex = 0;
      _currentSubTick = -1;
      _measureHistory.clear();
    }

    notifyListeners();
    return result;
  }

  void snapActiveScoreToScale({
    int? rootKey,
    VocalScaleType? scaleType,
  }) {
    _scoreEditorController.recordUndoSnapshot(_activePackage);
    _activePackage = _vocalPedagogyController.snapActiveScoreToScale(
      activePackage: _activePackage,
      rootKey: rootKey,
      scaleType: scaleType,
    );
    notifyListeners();
    _triggerAutoSave();
  }

  void toggleMinusOneMode({String? targetTrackId}) {
    _mixerConsole = _vocalPedagogyController.toggleMinusOneMode(
      activePackage: _activePackage,
      activeInstrument: _activeInstrument,
      mixerConsole: _mixerConsole,
      targetTrackId: targetTrackId,
    );
    notifyListeners();
  }

  void setMinusOneUserTrack(String trackId) {
    _mixerConsole = _vocalPedagogyController.setMinusOneUserTrack(
      activePackage: _activePackage,
      mixerConsole: _mixerConsole,
      trackId: trackId,
    );
    notifyListeners();
  }

  void setMinusOneGuideVolume(double volume) {
    final nextMixer = _vocalPedagogyController.setMinusOneGuideVolume(
      mixerConsole: _mixerConsole,
      volume: volume,
    );
    if (nextMixer != null) {
      _mixerConsole = nextMixer;
      notifyListeners();
    }
  }

  void recordMinusOneEvaluation(NoteEvaluationEntity evaluation) =>
      _vocalPedagogyController.recordMinusOneEvaluation(evaluation);

  void resetMinusOneEvaluations() => _vocalPedagogyController.resetMinusOneEvaluations();

  void setHeadphonesConnected(bool connected) =>
      _vocalPedagogyController.setHeadphonesConnected(connected);

  void updateHardwareEndpoints(List<HardwareAudioEndpoint> endpoints) =>
      _vocalPedagogyController.updateHardwareEndpoints(endpoints);

  String getLiveMonitoringSafetyWarning() =>
      _vocalPedagogyController.getLiveMonitoringSafetyWarning();

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _scorePlaybackCoordinator.dispose();
    _bpmRampTimer?.cancel();
    _silenceTimer?.cancel();
    _pitchService.stopRecording();
    _metronomeService.stop();
    _audioSynthesizer.dispose();
    _amplitudeSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completeSubscription?.cancel();
    _recorderController.dispose();
    _telemetryNotifier.dispose();
    _recorderService.dispose();
    _playbackService.dispose();
    super.dispose();
  }
}
