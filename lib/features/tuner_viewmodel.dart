import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../core/file_system/data/platform_file_gateway.dart';
import '../core/file_system/domain/i_platform_file_gateway.dart';
import 'tuner/domain/tuning_preset_entity.dart';
import '../core/theme/tunner_theme.dart';
import 'tuner/domain/note_entity.dart';
import 'tuner/domain/i_pitch_detector_service.dart';
import 'tuner/data/pitch_detector_service.dart';
import 'metronome/domain/tempo_entity.dart';
import 'metronome/domain/i_metronome_service.dart';
import 'metronome/data/metronome_service.dart';
import 'sheet_music/domain/score_tree.dart';
import 'sheet_music/presentation/real_sheet_music_painter.dart';
import 'mixer/domain/mixer_track_entity.dart';
import 'song_library/domain/song_package_entity.dart';
import 'song_library/data/song_decomposer_service.dart';
import 'practice_evaluator/domain/i_practice_evaluator_service.dart';
import 'practice_evaluator/domain/note_evaluation_entity.dart';
import 'practice_evaluator/domain/practice_report_entity.dart';
import 'practice_evaluator/data/practice_evaluator_service.dart';
import 'instrument/domain/instrument_profile_entity.dart';
import 'instrument/domain/i_instrument_transposition_service.dart';
import 'instrument/data/instrument_transposition_service.dart';
import 'practice_recorder/domain/practice_recording_entity.dart';
import 'practice_recorder/domain/multitrack_session_entity.dart';
import 'practice_recorder/domain/i_practice_recorder_service.dart';
import 'practice_recorder/domain/i_audio_playback_service.dart';
import 'practice_recorder/data/practice_recorder_service.dart';
import 'practice_recorder/data/audio_playback_service.dart';
import 'persistence/domain/app_user_settings_entity.dart';
import 'persistence/domain/i_local_persistence_service.dart';
import 'persistence/data/json_local_persistence_service.dart';
import 'universal_importer/domain/i_score_parser_service.dart';
import 'universal_importer/domain/parsed_score_result_entity.dart';
import 'universal_importer/data/universal_score_importer_service.dart';
import 'audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'audio_synthesizer/data/audio_synthesizer_service.dart';
import 'audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'sheet_music/domain/score_playback_coordinator.dart';
import 'score_editor/domain/score_editor_domain.dart';
import 'universal_importer/domain/canonical_musicxml_exporter.dart';
import 'universal_importer/domain/canonical_midi_exporter.dart';
import 'universal_importer/domain/canonical_abc_exporter.dart';
import 'universal_importer/domain/canonical_pdf_exporter.dart';
import 'transcription/domain/live_transcription_engine.dart';
import 'transcription/domain/polyphonic_transcription_engine.dart';
import 'exercise_generator/domain/algorithmic_exercise_generator.dart';
import 'tuner/domain/temperament_engine.dart';
import 'tuner/domain/acoustic_echo_suppressor.dart';
import 'tuner/domain/microphone_calibration_models.dart';
import 'tuner/domain/instrument_acoustic_filter.dart';
import 'tuner/domain/acoustic_rigor_profile.dart';
import 'drone/domain/harmonic_drone_config.dart';
import 'drone/domain/harmonic_drone_synthesizer.dart';
import 'chord_analyzer/domain/chord_entity.dart';
import 'chord_analyzer/domain/chroma_vector_calculator.dart';
import 'chord_analyzer/domain/polyphonic_chord_recognizer.dart';
import 'chord_analyzer/domain/polyphonic_pitch_entity.dart';
import 'chord_analyzer/domain/polyphonic_multitone_detector.dart';
import 'metronome/domain/tap_tempo_engine.dart';
import 'metronome/domain/tap_tempo_result.dart';
import 'pedagogy_report/domain/pedagogical_report_models.dart';
import 'pedagogy_report/domain/pedagogical_report_pdf_generator.dart';
import 'audio_synthesizer/data/soundfont_synthesizer_service.dart';
import 'audio_synthesizer/domain/sf2/sf2_models.dart';
import 'pedagogy_profiles/domain/learner_profile_entity.dart';
import 'pedagogy_profiles/domain/adaptive_scaffolding_engine.dart';
import 'workspaces/domain/workspace_type.dart';
import 'audio_synthesizer/domain/stem_export_entity.dart';
import 'audio_synthesizer/domain/stem_audio_synthesizer.dart';
import 'audio_synthesizer/data/stem_export_persistence_service.dart';
import 'guided_lessons/domain/guided_lesson_entity.dart';
import 'guided_lessons/domain/curated_guided_lessons.dart';
import 'guided_lessons/domain/guided_lesson_evaluator.dart';
import 'guided_lessons/domain/instrument_pedagogy_adapter_engine.dart';
import 'vocal_autotune/domain/autotune_config_entity.dart';
import 'vocal_autotune/domain/scale_quantizer.dart';
import 'vocal_autotune/domain/vocal_autotune_processor.dart';
import 'vocal_autotune/domain/vocal_score_converter.dart';
import 'instrument/domain/smart_instrument_detector.dart';
import 'song_library/domain/minus_one_session_entity.dart';
import 'song_library/domain/minus_one_orchestrator.dart';
import 'modular_rack/domain/port_permission_broker.dart';
import 'tuner/domain/hardware_audio_endpoint.dart';
import 'audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import '../core/packaging/domain/i_tunner_package_codec.dart';
import '../core/packaging/domain/tunner_project_manifest_entity.dart';
import '../core/packaging/domain/tunner_project_package_entity.dart';
import '../core/packaging/infrastructure/tunner_package_codec_service.dart';
import '../core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../core/audio/domain/audio_device_matrix_entity.dart';

part 'tuner/presentation/parts/tuner_viewmodel_recorder_part.dart';
part 'tuner/presentation/parts/tuner_viewmodel_score_editor_part.dart';
part 'tuner/presentation/parts/tuner_viewmodel_vocal_and_pedagogy_part.dart';

/// ViewModel principal orquestador del estudio interactivo.
/// Diseñado bajo Clean Architecture con Inversión de Dependencias (DIP).
/// Recibe abstracciones de servicios en lugar de construirlos acopladamente.
class TunerViewModel extends ChangeNotifier {
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
  final Future<String> Function()? _recordingPathProvider;

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completeSubscription;

  // Estado de Grabación de Práctica & Auto-Escucha (Loopback)
  bool _isAudioRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  final List<double> _currentWaveformPeaks = [];
  PracticeRecordingEntity? _activeRecording;
  final List<PracticeRecordingEntity> _recordingHistory = [];

  // Estado de Grabación Multi-Pista y Comparador Espectral
  final List<TimedPitchSample> _currentPitchTrack = [];
  final List<TimedSpectralSample> _currentSpectralTrack = [];
  late MultiTrackSessionEntity _multiTrackSession;

  bool _isPlayingAudio = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  double _playbackSpeed = 1.0;

  double _frequency = 0.0;
  String _noteName = "--";
  double _cents = 0.0;
  bool _isRecording = false;

  Timer? _silenceTimer;
  bool _isDisposed = false;
  final Completer<void> _initCompleter = Completer<void>();
  final InstrumentPedagogyAdapterEngine _pedagogyAdapter = const InstrumentPedagogyAdapterEngine();

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

  // Editor de Partituras & Exportadores Canónicos
  final ScoreEditorOperations _editorOps = const ScoreEditorOperations();
  final ScoreUndoRedoHistory _scoreHistory = ScoreUndoRedoHistory();
  final CanonicalMusicXmlExporter _musicXmlExporter = const CanonicalMusicXmlExporter();
  final CanonicalMidiExporter _midiExporter = const CanonicalMidiExporter();
  final CanonicalAbcExporter _abcExporter = const CanonicalAbcExporter();
  final CanonicalPdfExporter _pdfExporter = const CanonicalPdfExporter();
  final LiveTranscriptionEngine _transcriptionEngine = LiveTranscriptionEngine();
  bool _isLiveTranscriptionActive = false;
  final PolyphonicTranscriptionEngine _polyphonicTranscriptionEngine = PolyphonicTranscriptionEngine();
  bool _isPolyphonicTranscriptionActive = false;
  final AlgorithmicExerciseGenerator _exerciseGenerator = const AlgorithmicExerciseGenerator();
  final TemperamentEngine _temperamentEngine = const TemperamentEngine();
  MusicalTemperament _selectedTemperament = TemperamentEngine.allTemperaments.first;
  int _temperamentRootKey = 0;
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
  final List<ChordEntity> _chordHistory = [];
  final TapTempoEngine _tapTempoEngine = TapTempoEngine();
  TapTempoResult? _lastTapTempoResult;
  final PedagogicalReportPdfGenerator _pedagogicalPdfGenerator = const PedagogicalReportPdfGenerator();
  LearnerProfileEntity _learnerProfile = LearnerProfileEntity.adult();
  final AdaptiveScaffoldingEngine _scaffoldingEngine = const AdaptiveScaffoldingEngine();
  int _consecutiveSuccesses = 0;
  int _consecutiveErrors = 0;
  PedagogicalDiagnosticResult? _lastPedagogicalDiagnostic;
  WorkspaceType _activeWorkspace = WorkspaceType.learning;

  // Motor de Exportación de Stems y MIDI
  final StemAudioSynthesizer _stemSynthesizer;
  final StemExportPersistenceService _exportPersistenceService;
  ExportBundleResult? _lastExportBundle;
  bool _isExportingStems = false;

  // Motor de Lecciones Guiadas Interactivas
  final GuidedLessonEvaluator _guidedLessonEvaluator;
  DateTime? _lastLessonFrameTime;

  // Motor de Vocal AutoTune en Tiempo Real y Post-Producción
  final VocalAutoTuneProcessor _autoTuneProcessor;
  ScaleQuantizationResult _lastAutoTuneResult = ScaleQuantizationResult.unvoiced(0.0);

  // Conversor Vocal a Pentagrama y Melodyne Mode (UC-60)
  final VocalScoreConverter _vocalScoreConverter = const VocalScoreConverter();
  SongPackage? _lastConvertedVocalPackage;
  VocalScoreConversionResult? _lastVocalConversionResult;

  // Motor de Síntesis SoundFont SF2 y Timbres Acústicos
  final SoundFontSynthesizerService _soundFontSynthesizer;

  // Motor de Síntesis Polifónica SMuFL y Coordinador de Partitura
  final PolyphonicVoicePool _polyphonicVoicePool;
  late final ScorePlaybackCoordinator _scorePlaybackCoordinator;
  int? _selectedScoreNoteIndex;

  // Empaquetador Canónico de Proyectos .tunner
  ITunnerPackageCodec packageCodec;
  final StudioAudioDeviceMatrixService? _audioDeviceMatrixService;

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

  // Ensamble Virtual Minus-One y Descomposición de Partituras (UC-61)
  final MinusOneOrchestrator _minusOneOrchestrator = const MinusOneOrchestrator();
  MinusOneSessionEntity? _activeMinusOneSession;

  // Arbitraje de Puertos de Hardware y Seguridad Acústica (UC-62)
  final PortPermissionBroker _portPermissionBroker = const PortPermissionBroker();
  bool _isHeadphonesConnected = false;
  List<HardwareAudioEndpoint> _hardwareAudioEndpoints = const [];

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
    StemExportPersistenceService? exportPersistenceService,
    PolyphonicMultiToneDetector? multiToneDetector,
    GuidedLessonEvaluator? guidedLessonEvaluator,
    VocalAutoTuneProcessor? autoTuneProcessor,
    SoundFontSynthesizerService? soundFontSynthesizer,
    PolyphonicVoicePool? polyphonicVoicePool,
    ScorePlaybackCoordinator? scorePlaybackCoordinator,
    ITunnerPackageCodec? packageCodec,
    StudioAudioDeviceMatrixService? audioDeviceMatrixService,
    IPlatformFileGateway? platformFileGateway,
    Future<String> Function()? documentsDirectoryProvider,
    Future<String> Function()? recordingPathProvider,
    bool seedDefaults = false,
  })  : _shouldSeedDefaults = seedDefaults,
        _pitchService = pitchService ?? PitchDetectorService(),
        _metronomeService = metronomeService ?? MetronomeService(),
        _evaluatorService = evaluatorService ?? const PracticeEvaluatorService(),
        _transpositionService = transpositionService ?? const InstrumentTranspositionService(),
        _recorderService = recorderService ?? PracticeRecorderService(),
        _playbackService = playbackService ?? AudioPlaybackService(),
        _persistenceService = persistenceService ??
            JsonLocalPersistenceService(documentsPathProvider: documentsDirectoryProvider ?? recordingPathProvider),
        _scoreImporterService = scoreImporterService ?? const UniversalScoreImporterService(),
        _audioSynthesizer = audioSynthesizerService ?? AudioSynthesizerService(),
        _echoSuppressor = echoSuppressor ?? AcousticEchoSuppressor(),
        _platformFileGateway = platformFileGateway ?? const PlatformFileGateway(),
        _stemSynthesizer = stemSynthesizer ?? const StemAudioSynthesizer(),
        _exportPersistenceService = exportPersistenceService ??
            StemExportPersistenceService(documentsPathProvider: documentsDirectoryProvider ?? recordingPathProvider),
        _multiToneDetector = multiToneDetector ?? PolyphonicMultiToneDetector(),
        _guidedLessonEvaluator = guidedLessonEvaluator ?? GuidedLessonEvaluator(),
        _autoTuneProcessor = autoTuneProcessor ?? VocalAutoTuneProcessor(),
        _soundFontSynthesizer = soundFontSynthesizer ?? SoundFontSynthesizerService(),
        _polyphonicVoicePool = polyphonicVoicePool ?? PolyphonicVoicePool(),
        packageCodec = packageCodec ?? const TunnerPackageCodecService(),
        _audioDeviceMatrixService = audioDeviceMatrixService,
        _recordingPathProvider = recordingPathProvider {
    _scorePlaybackCoordinator = scorePlaybackCoordinator ??
        ScorePlaybackCoordinator(
          voicePool: _polyphonicVoicePool,
          initialBpm: _bpm.toDouble(),
        );
    _activePackage = _curatedLibrary.first;
    _bpm = _activePackage.defaultBpm;
    _mixerConsole = MixerConsoleEntity(
      metronomeTrack: _mixerConsole.metronomeTrack,
      stems: _activePackage.tracks,
    );
    _initListeners();
    _syncInstrumentAcousticFilter();
    _initDefaultMultiTrackSession();
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
  SoundFontSynthesizerService get soundFontSynthesizer => _soundFontSynthesizer;
  int get activeSoundFontPatch => _soundFontSynthesizer.activePatch;
  List<Sf2Preset> get availableSoundFontPresets => _soundFontSynthesizer.availablePresets;

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
    return _soundFontSynthesizer.synthesizeNoteWav(
      midiPitch: midiPitch,
      durationSeconds: durationSeconds,
      velocity: velocity,
    );
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
    _triggerAutoSave();
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
    _triggerAutoSave();
  }

  MixerConsoleEntity get mixerConsole => _mixerConsole;
  List<SongPackage> get curatedLibrary => _curatedLibrary;
  List<SongPackage> get workspaceScores => List.unmodifiable(_workspaceScores);
  List<TuningPresetEntity> get customTuningPresets => List.unmodifiable(_tuningPresets);
  SongPackage get activePackage => _activePackage;
  InstrumentProfileEntity get activeInstrument => _activeInstrument;

  // --- Smart Instrument Recognition & Acoustic Adaptation (UC-59) ---
  bool get isSmartInstrumentTuningActive => _isSmartInstrumentTuningActive;
  bool get autoSwitchInstrumentEnabled => _autoSwitchInstrumentEnabled;
  SmartInstrumentMatch? get lastDetectedMatch => _lastDetectedMatch;

  // --- Vocal Suite & Melodyne Mode (UC-60) ---
  SongPackage? get lastConvertedVocalPackage => _lastConvertedVocalPackage;
  VocalScoreConversionResult? get lastVocalConversionResult => _lastVocalConversionResult;

  // --- Ensamble Virtual Minus-One (UC-61) ---
  MinusOneSessionEntity? get activeMinusOneSession => _activeMinusOneSession;
  bool get isMinusOneActive => _activeMinusOneSession?.isMinusOneActive ?? false;
  String? get minusOneUserTrackId => _activeMinusOneSession?.userTrackId;

  // --- Arbitraje de Puertos de Hardware y Seguridad Acústica (UC-62) ---
  PortPermissionBroker get portPermissionBroker => _portPermissionBroker;
  bool get isHeadphonesConnected => _isHeadphonesConnected;
  bool get canActivateLiveMonitoring =>
      _portPermissionBroker.canAuthorizeLiveMonitoring(
        isHeadphonesOrInterfaceConnected: _isHeadphonesConnected,
      );
  List<HardwareAudioEndpoint> get hardwareAudioEndpoints =>
      List.unmodifiable(_hardwareAudioEndpoints);

  // --- Getters de Grabación & Auto-Escucha (Loopback) ---
  bool get isAudioRecording => _isAudioRecording;
  Duration get recordingDuration => _recordingDuration;
  List<double> get currentWaveformPeaks => List.unmodifiable(_currentWaveformPeaks);
  PracticeRecordingEntity? get activeRecording => _activeRecording;
  List<PracticeRecordingEntity> get recordingHistory => List.unmodifiable(_recordingHistory);
  bool get isPlayingAudio => _isPlayingAudio;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;
  double get playbackSpeed => _playbackSpeed;
  MultiTrackSessionEntity get multiTrackSession => _multiTrackSession;

  double get frequency => _frequency;
  String get noteName => _noteName;
  bool get hasTransposition => _activeInstrument.isTransposing;
  String get writtenNoteName {
    if (_noteName == "--" || _noteName.isEmpty) return "--";
    if (!_activeInstrument.isTransposing) return _noteName;
    return _transpositionService.getWrittenNote(_noteName, _activeInstrument);
  }
  double get cents => _cents;
  double get referencePitch => _referencePitch;
  MusicalTemperament get selectedTemperament => _selectedTemperament;
  int get temperamentRootKey => _temperamentRootKey;
  List<MusicalTemperament> get availableTemperaments => TemperamentEngine.allTemperaments;
  TemperamentEngine get temperamentEngine => _temperamentEngine;
  HarmonicDroneConfig get droneConfig => _droneConfig;
  bool get isDronePlaying => _audioSynthesizer.isDroneLoopPlaying;
  ChordEntity get recognizedChord => _recognizedChord;
  PolyphonicMultiToneAnalysisResult get polyphonicAnalysisResult => _multiToneResult;
  bool get isChordRecognitionActive => _isChordRecognitionActive;
  List<double> get activeChromaVector => _activeChromaVector;
  List<double>? get latestAudioSamples => _latestAudioSamples;
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
      );
      _cents = _temperamentEngine.calculateCentsDeviation(
        detectedFrequency: _frequency,
        targetFrequency: targetFreq,
      );
    }
  }

  bool get isRecording => _isRecording;
  bool get isMetronomePlaying => _isMetronomePlaying;
  bool get isMetronomeActive => _isMetronomePlaying;
  bool get isScorePlaybackEnabled => _isScorePlaybackEnabled;
  bool get isLiveTranscriptionActive => _isLiveTranscriptionActive;
  bool get isPolyphonicTranscriptionActive => _isPolyphonicTranscriptionActive;
  PolyphonicTranscriptionEngine get polyphonicTranscriptionEngine => _polyphonicTranscriptionEngine;

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
  StudioAudioDeviceMatrixService? get audioDeviceMatrixService => _audioDeviceMatrixService;

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
      } catch (_) {}
    }

    notifyListeners();
    return pkg;
  }

  void _initListeners() {
    _pitchService.onRmsLevelChanged = (rms) {
      _currentMicRmsLevel = rms;
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

      if (_isLiveTranscriptionActive) {
        final updatedPkg = _transcriptionEngine.processPitchFrame(
          frequencyHz: pitch,
          clarity: pitch > 20.0 ? 0.95 : 0.0,
          noteName: noteEntity.name,
        );
        if (updatedPkg != null) {
          _scoreHistory.recordState(_activePackage);
          _activePackage = updatedPkg;
        }
      }

      if (_isChordRecognitionActive) {
        _updateChordFromPitch(pitch);
      }

      if (_isAudioRecording) {
        _recordSampleForMultiTrack(pitch, _cents, noteEntity.name);
      }

      if (_guidedLessonEvaluator.hasActiveLesson && pitch > 20.0) {
        final now = DateTime.now();
        final double deltaSeconds;
        if (_lastLessonFrameTime == null) {
          deltaSeconds = 0.05;
        } else {
          final diffMs = now.difference(_lastLessonFrameTime!).inMilliseconds;
          deltaSeconds = (diffMs / 1000.0).clamp(0.01, 0.25);
        }
        _lastLessonFrameTime = now;
        _guidedLessonEvaluator.evaluateSample(
          frequencyHz: pitch,
          cents: _cents,
          detectedNoteName: noteEntity.name,
          deltaSeconds: deltaSeconds,
        );
      }

      if (_autoTuneProcessor.config.isEnabled && pitch > 20.0) {
        _lastAutoTuneResult = _autoTuneProcessor.evaluatePitchFrame(
          detectedPitchHz: pitch,
          deltaSeconds: 0.05,
        );
      }

      if (_isSmartInstrumentTuningActive && pitch > 20.0) {
        _evaluateSmartInstrumentFromPitch(pitch);
      }

      _validatePerformance();
      notifyListeners();

      _silenceTimer = Timer(const Duration(milliseconds: 60), () {
        _frequency = 0.0;
        _noteName = "--";
        _cents = 0.0;
        _lastLessonFrameTime = null;
        if (_autoTuneProcessor.config.isEnabled) {
          _lastAutoTuneResult = ScaleQuantizationResult.unvoiced(0.0);
        }

        if (_isLiveTranscriptionActive) {
          final updatedPkg = _transcriptionEngine.processPitchFrame(
            frequencyHz: 0.0,
            clarity: 0.0,
            noteName: "--",
          );
          if (updatedPkg != null) {
            _scoreHistory.recordState(_activePackage);
            _activePackage = updatedPkg;
          }
        }

        if (_isChordRecognitionActive) {
          _recognizedChord = ChordEntity.none;
        }

        if (_isAudioRecording) {
          _recordSampleForMultiTrack(0.0, 0.0, "--", isSilent: true);
        }

        _validatePerformance();
        notifyListeners();
      });
    };

    _metronomeService.onSubTick = (subTick) {
      if (_isCountingIn) {
        if (subTick % 4 == 0) {
          final metroGain = _mixerConsole.getEffectiveGain(_mixerConsole.metronomeTrack.id);
          if (metroGain > 0.001) {
            _echoSuppressor.notifyClickEmitted();
            _audioSynthesizer.playMetronomeClick(
              isDownbeat: _countInBeat == 1,
              volume: metroGain,
            );
          }
          _countInBeat++;
          if (_countInBeat > 4) {
            _isCountingIn = false;
            _currentMeasureIndex = 0;
            _currentSubTick = 0;
            _measureHistory.clear();
            _updateExpectedNoteForTick(0);
          }
        }
      } else {
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

        // Disparo sonoro de la nota musical de la partitura
        if (_isScorePlaybackEnabled &&
            _expectedNote != null &&
            _expectedNote!.startTick == subTick) {
          final noteName = _expectedNote!.noteName;
          if (noteName != "--" && noteName.toLowerCase() != "rest") {
            final leadTrackId = _activePackage.tracks.isNotEmpty
                ? _activePackage.tracks.first.id
                : "voice";
            final voiceGain = _mixerConsole.getEffectiveGain(leadTrackId);
            if (voiceGain > 0.001) {
              final freq = NoteEntity.frequencyForNote(noteName, a4Ref: _referencePitch);
              if (freq > 20.0) {
                final msPerTick = 60000.0 / _bpm / 4.0;
                final durationMs = (_expectedNote!.durationTicks * msPerTick).round();
                _audioSynthesizer.playNoteTone(
                  frequency: freq,
                  duration: Duration(milliseconds: durationMs),
                  volume: voiceGain,
                );
              }
            }
          }
        }

        if (subTick % 4 == 0) {
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
      if (_isAudioRecording) {
        _currentWaveformPeaks.add(peak);
        notifyListeners();
      }
    });

    _positionSubscription = _playbackService.onPositionChanged.listen((pos) {
      _playbackPosition = pos;
      notifyListeners();
    });

    _durationSubscription = _playbackService.onDurationChanged.listen((dur) {
      _playbackDuration = dur;
      notifyListeners();
    });

    _completeSubscription = _playbackService.onPlayerComplete.listen((_) {
      _isPlayingAudio = false;
      _playbackPosition = Duration.zero;
      notifyListeners();
    });
  }

  void setInstrumentProfile(InstrumentProfileEntity instrument) {
    _activeInstrument = instrument;
    _syncInstrumentAcousticFilter();
    _validatePerformance();

    // Si hay una lección guiada activa, readaptarla a la tesitura del nuevo instrumento
    if (hasActiveGuidedLesson && _guidedLessonEvaluator.activeProgress != null) {
      final currentLesson = _guidedLessonEvaluator.activeProgress!.lesson;
      final original = CuratedGuidedLessons.all.firstWhere(
        (l) => currentLesson.id.startsWith(l.id),
        orElse: () => currentLesson,
      );
      final adapted = _pedagogyAdapter.adaptLesson(original, _activeInstrument);
      _guidedLessonEvaluator.startLesson(adapted, customToleranceCents: centsTolerance);
    }

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
        final noteEntity = NoteEntity.fromFrequency(_frequency, a4Ref: _referencePitch);
        _noteName = noteEntity.name;
        _cents = noteEntity.cents;
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

    if (_isPolyphonicTranscriptionActive) {
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

      final updatedPkg = _polyphonicTranscriptionEngine.processPolyphonicFrame(
        noteNames: effectiveNotes,
        energyRms: rms,
      );
      if (updatedPkg != null) {
        _scoreHistory.recordState(_activePackage);
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
      if (_activeMinusOneSession != null && _activeMinusOneSession!.isMinusOneActive) {
        _activeMinusOneSession = _minusOneOrchestrator.recordEvaluation(
          _activeMinusOneSession!,
          eval,
        );
      }
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

  void toggleRecording() async {
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
    notifyListeners();
  }

  void startSongWithCountIn() async {
    if (_isMetronomePlaying) {
      await _metronomeService.stop();
      _isMetronomePlaying = false;
      if (_isPracticeMode && _activeEvaluations.isNotEmpty) {
        _generatePracticeReport();
      }
      resetSongState();
    } else {
      _isCountingIn = true;
      _countInBeat = 0;
      _currentSubTick = -1;
      _measureHistory.clear();
      _lastEvaluatedNote = null;
      _activeEvaluations.clear();
      _isMetronomePlaying = true;
      final currentTicks = currentMeasureTimeSignature.totalTicks;
      await _metronomeService.start(_bpm, ticksPerMeasure: currentTicks);
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
      recording: _activeRecording,
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
    if (_isMetronomePlaying) {
      final currentTicks = currentMeasureTimeSignature.totalTicks;
      _metronomeService.stop().then((_) => _metronomeService.start(_bpm, ticksPerMeasure: currentTicks));
    }
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
      _triggerAutoSave();
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint("Error al importar partitura: $e");
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
      debugPrint("Error al seleccionar archivo en FilePicker: $e");
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
    _recordingHistory.removeWhere((r) => r.id == id);
    if (_activeRecording?.id == id) {
      _activeRecording = _recordingHistory.isNotEmpty ? _recordingHistory.first : null;
    }
    _triggerAutoSave();
    notifyListeners();
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

    if (_activeMinusOneSession != null && _activeMinusOneSession!.isMinusOneActive) {
      final userTrackId = _minusOneOrchestrator.detectUserTrack(package, _activeInstrument.id);
      _activeMinusOneSession = _minusOneOrchestrator.createSession(
        package: package,
        userTrackId: userTrackId,
        isMinusOneActive: true,
        isMutedUserTrack: _activeMinusOneSession!.guideTrackVolume <= 0.0,
        guideTrackVolume: _activeMinusOneSession!.guideTrackVolume,
      );
      _mixerConsole = _minusOneOrchestrator.configureMinusOneMixer(
        _mixerConsole,
        userTrackId,
        muteUserTrack: _activeMinusOneSession!.guideTrackVolume <= 0.0,
        guideVolume: _activeMinusOneSession!.guideTrackVolume,
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
    } catch (_) {
      return false;
    }
  }

  void setCustomTimeSignature(TimeSignature? signature) {
    _customTimeSignatureOverride = signature;
    if (_isMetronomePlaying) {
      _metronomeService.stop().then((_) => _metronomeService.start(_bpm, ticksPerMeasure: currentMeasureTimeSignature.totalTicks));
    }
    resetSongState();
    notifyListeners();
  }

  void setTrackVolume(String trackId, double volume) {
    _mixerConsole = _mixerConsole.copyWithTrackVolume(trackId, volume);
    notifyListeners();
  }

  void toggleTrackMute(String trackId) {
    _mixerConsole = _mixerConsole.toggleMute(trackId);
    notifyListeners();
  }

  void toggleTrackSolo(String trackId) {
    _mixerConsole = _mixerConsole.toggleSolo(trackId);
    notifyListeners();
  }

  void playReferenceTone([String noteName = "La4"]) {
    final double freq = NoteEntity.frequencyForNote(noteName);
    if (freq > 0) {
      _frequency = freq;
      _noteName = noteName;
      _cents = 0.0;
      _audioSynthesizer.startDiapasonTone(freq);
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _scorePlaybackCoordinator.dispose();
    _silenceTimer?.cancel();
    _pitchService.stopRecording();
    _metronomeService.stop();
    _audioSynthesizer.dispose();
    _amplitudeSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completeSubscription?.cancel();
    _recordingTimer?.cancel();
    _recorderService.dispose();
    _playbackService.dispose();
    super.dispose();
  }
}
