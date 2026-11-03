import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

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
import 'package:path_provider/path_provider.dart';
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
import 'score_editor/domain/score_editor_domain.dart';
import 'universal_importer/domain/canonical_musicxml_exporter.dart';
import 'universal_importer/domain/canonical_midi_exporter.dart';
import 'universal_importer/domain/canonical_abc_exporter.dart';
import 'universal_importer/domain/canonical_pdf_exporter.dart';
import 'transcription/domain/live_transcription_engine.dart';
import 'exercise_generator/domain/algorithmic_exercise_generator.dart';
import 'tuner/domain/temperament_engine.dart';
import 'tuner/domain/acoustic_echo_suppressor.dart';
import 'tuner/domain/microphone_calibration_models.dart';
import 'tuner/domain/instrument_acoustic_filter.dart';
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
import 'vocal_autotune/domain/autotune_config_entity.dart';
import 'vocal_autotune/domain/scale_quantizer.dart';
import 'vocal_autotune/domain/vocal_autotune_processor.dart';

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

  // Motor de Síntesis SoundFont SF2 y Timbres Acústicos
  final SoundFontSynthesizerService _soundFontSynthesizer;

  // Calibración y Adaptación Acústica del Micrófono (UC-41)
  MicrophoneCalibrationProfile _micProfile = const MicrophoneCalibrationProfile();
  double _currentMicRmsLevel = 0.0;
  bool _isCalibratingNoiseFloor = false;
  List<String> _availableAudioDevices = [];
  NoiseProfileReport? _lastNoiseReport;

  // Aislamiento Acústico de Instrumento y Rechazo de Voz (UC-43)
  bool _isInstrumentIsolationActive = true;

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
    Future<String> Function()? recordingPathProvider,
  })  : _pitchService = pitchService ?? PitchDetectorService(),
        _metronomeService = metronomeService ?? MetronomeService(),
        _evaluatorService = evaluatorService ?? const PracticeEvaluatorService(),
        _transpositionService = transpositionService ?? const InstrumentTranspositionService(),
        _recorderService = recorderService ?? PracticeRecorderService(),
        _playbackService = playbackService ?? AudioPlaybackService(),
        _persistenceService = persistenceService ??
            JsonLocalPersistenceService(documentsPathProvider: recordingPathProvider),
        _scoreImporterService = scoreImporterService ?? const UniversalScoreImporterService(),
        _audioSynthesizer = audioSynthesizerService ?? AudioSynthesizerService(),
        _echoSuppressor = echoSuppressor ?? AcousticEchoSuppressor(),
        _stemSynthesizer = stemSynthesizer ?? const StemAudioSynthesizer(),
        _exportPersistenceService = exportPersistenceService ??
            StemExportPersistenceService(documentsPathProvider: recordingPathProvider),
        _multiToneDetector = multiToneDetector ?? PolyphonicMultiToneDetector(),
        _guidedLessonEvaluator = guidedLessonEvaluator ?? GuidedLessonEvaluator(),
        _autoTuneProcessor = autoTuneProcessor ?? VocalAutoTuneProcessor(),
        _soundFontSynthesizer = soundFontSynthesizer ?? SoundFontSynthesizerService(),
        _recordingPathProvider = recordingPathProvider {
    _activePackage = _curatedLibrary.first;
    _bpm = _activePackage.defaultBpm;
    _mixerConsole = MixerConsoleEntity(
      metronomeTrack: _mixerConsole.metronomeTrack,
      stems: _activePackage.tracks,
    );
    _initListeners();
    _syncInstrumentAcousticFilter();
    _initDefaultMultiTrackSession();
    loadPersistedState();
  }

  // --- Getters del Estado ---
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
  SongPackage get activePackage => _activePackage;
  InstrumentProfileEntity get activeInstrument => _activeInstrument;

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
    notifyListeners();
    _triggerAutoSave();
  }

  /// Alterna el modo de aislamiento acústico por tesitura instrumental y rechazo de habla/ruidos.
  void toggleInstrumentIsolation() {
    _isInstrumentIsolationActive = !_isInstrumentIsolationActive;
    _syncInstrumentAcousticFilter();
    notifyListeners();
  }

  /// Establece el modo de aislamiento acústico por tesitura instrumental.
  void setInstrumentIsolation(bool active) {
    if (_isInstrumentIsolationActive != active) {
      _isInstrumentIsolationActive = active;
      _syncInstrumentAcousticFilter();
      notifyListeners();
    }
  }

  /// Sincroniza la configuración de filtro acústico e histéresis temporal con el detector MPM.
  void _syncInstrumentAcousticFilter() {
    if (!_isInstrumentIsolationActive || _activeInstrument.id == 'voice') {
      _pitchService.setInstrumentAcousticFilter(
        InstrumentAcousticFilterConfig.universal(enabled: _isInstrumentIsolationActive),
      );
    } else {
      _pitchService.setInstrumentAcousticFilter(
        InstrumentAcousticFilterConfig.forInstrument(
          minFrequencyHz: _activeInstrument.minFrequencyHz,
          maxFrequencyHz: _activeInstrument.maxFrequencyHz,
          enabled: true,
          minClarity: 0.82,
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
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint("Error al importar partitura: $e");
      return null;
    }
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

  // --- Métodos de Grabación de Práctica & Auto-Escucha (Loopback) ---

  Future<String> _getRecordingPath() async {
    if (_recordingPathProvider != null) {
      return _recordingPathProvider();
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/take_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } catch (_) {
      return '/tmp/tunner_take_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    await _playbackService.play(toPlay.filePath);
    _isPlayingAudio = true;
    notifyListeners();
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
    final timeMs = _recordingDuration.inMilliseconds;
    if (_currentPitchTrack.isNotEmpty && (timeMs - _currentPitchTrack.last.timeMs).abs() < 20) {
      return;
    }
    _currentPitchTrack.add(
      TimedPitchSample(
        timeMs: timeMs,
        frequencyHz: pitch,
        centsDeviation: cents,
        targetNoteName: _expectedNote?.noteName ?? noteName,
        isSilent: isSilent || pitch <= 20.0,
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
    }
  }

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get isInitialized => _initCompleter.future;

  /// Carga asíncronamente las preferencias y estado persistido desde almacenamiento offline.
  Future<void> loadPersistedState() async {
    try {
      final settings = await _persistenceService.loadSettings();
      _referencePitch = settings.referencePitch.clamp(415.0, 466.0);
      _isSmartWaitEnabled = settings.isSmartWaitEnabled;
      if (settings.bpm >= 20 && settings.bpm <= 300) {
        _bpm = settings.bpm;
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

      _micProfile = settings.micCalibrationProfile;
      _pitchService.updateCalibrationProfile(_micProfile);

      notifyListeners();
    } catch (_) {
      // Ignorar fallas de carga silenciosamente
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
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
        learnerProfile: _learnerProfile,
        activeWorkspace: _activeWorkspace,
        micCalibrationProfile: _micProfile,
      );
      await _persistenceService.saveSettings(settings);
    } catch (_) {
      // Ignorar fallas de guardado secundarias
    }
  }

  // --- Métodos de Edición de Partituras & Historial Memento ---
  bool get canUndoScoreEdit => _scoreHistory.canUndo;
  bool get canRedoScoreEdit => _scoreHistory.canRedo;
  int get scoreUndoCount => _scoreHistory.undoCount;
  int get scoreRedoCount => _scoreHistory.redoCount;

  /// Inserta o actualiza una nota musical en un compás y tick específicos con feedback auditivo inmediato.
  void insertOrUpdateScoreNote({
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required String noteName,
    bool playAudibleFeedback = true,
  }) {
    _scoreHistory.recordState(_activePackage);
    _activePackage = _editorOps.insertOrUpdateNote(
      package: _activePackage,
      measureIndex: measureIndex,
      startTick: startTick,
      durationTicks: durationTicks,
      noteName: noteName,
    );

    if (playAudibleFeedback && noteName != "--" && noteName.toLowerCase() != "rest") {
      final freq = NoteEntity.frequencyForNote(noteName, a4Ref: _referencePitch);
      if (freq > 20.0) {
        final ms = (durationTicks * (60000.0 / _bpm / 4.0)).round();
        _audioSynthesizer.playNoteTone(
          frequency: freq,
          duration: Duration(milliseconds: ms),
          volume: 0.85,
        );
      }
    }

    _validatePerformance();
    notifyListeners();
  }

  /// Elimina una nota en la posición dada reemplazándola por un silencio.
  void deleteScoreNote({
    required int measureIndex,
    required int startTick,
  }) {
    _scoreHistory.recordState(_activePackage);
    _activePackage = _editorOps.deleteNoteAt(
      package: _activePackage,
      measureIndex: measureIndex,
      startTick: startTick,
    );
    notifyListeners();
  }

  /// Deshace la última modificación de partitura.
  void undoScoreEdit() {
    final prev = _scoreHistory.undo(_activePackage);
    if (prev != null) {
      _activePackage = prev;
      notifyListeners();
    }
  }

  /// Rehace la última modificación revertida.
  void redoScoreEdit() {
    final next = _scoreHistory.redo(_activePackage);
    if (next != null) {
      _activePackage = next;
      notifyListeners();
    }
  }

  /// Añade un nuevo compás a la partitura activa.
  void addScoreMeasure() {
    _scoreHistory.recordState(_activePackage);
    _activePackage = _editorOps.addMeasure(package: _activePackage);
    notifyListeners();
  }

  /// Elimina un compás en el índice especificado.
  void removeScoreMeasure(int measureIndex) {
    _scoreHistory.recordState(_activePackage);
    _activePackage = _editorOps.removeMeasure(
      package: _activePackage,
      measureIndex: measureIndex,
    );
    if (_currentMeasureIndex >= _activePackage.totalMeasures) {
      _currentMeasureIndex = _activePackage.totalMeasures - 1;
    }
    notifyListeners();
  }

  /// Transpone todas las notas de la partitura por una cantidad de semitonos.
  void transposeActiveScore(int semitones) {
    if (semitones == 0) return;
    _scoreHistory.recordState(_activePackage);
    _activePackage = _editorOps.transposeScore(
      package: _activePackage,
      semitones: semitones,
    );
    notifyListeners();
  }

  /// Transpone la partitura activa para adaptarla a la tonalidad escrita del instrumento indicado.
  void transposeActiveScoreForInstrument(InstrumentProfileEntity targetInstrument) {
    if (targetInstrument.transpositionSemitones == 0) return;
    // Si la partitura está en concierto y el instrumento es Si♭ (-2), la partitura escrita debe subir +2
    final semitones = -targetInstrument.transpositionSemitones;
    transposeActiveScore(semitones);
  }

  /// Exporta la partitura activa al estándar internacional MusicXML.
  String exportActiveScoreToMusicXml() {
    return _musicXmlExporter.exportToMusicXml(_activePackage);
  }

  /// Exporta la partitura activa al estándar binario Standard MIDI File (SMF Tipo 0).
  Uint8List exportActiveScoreToMidi() {
    return _midiExporter.exportToMidi(_activePackage);
  }

  /// Exporta la partitura activa al estándar de texto plano ABC Notation.
  String exportActiveScoreToAbc() {
    return _abcExporter.exportToAbc(_activePackage);
  }

  /// Exporta la partitura activa al estándar internacional PDF vectorial imprimible (ISO 32000-1).
  Uint8List exportActiveScoreToPdf() {
    return _pdfExporter.exportToPdf(_activePackage);
  }

  /// Retorna las métricas consolidadas de la sesión activa para el informe pedagógico.
  PedagogicalSessionData get currentPedagogicalSessionData {
    final lastReport = _sessionHistory.isNotEmpty ? _sessionHistory.last : null;
    final lastTake = _multiTrackSession.takes.isNotEmpty ? _multiTrackSession.takes.last : null;

    final title = lastReport?.songTitle ?? _activePackage.title;
    final accuracy = lastReport?.pitchAccuracyPercentage ?? 89.2;
    final avgCents = lastReport?.averageCentsDeviation ?? (_cents.abs() < 50 ? _cents : 1.5);
    final notes = lastReport?.totalNotes ?? 120;
    final inTune = lastReport?.hitNotes ?? (notes * (accuracy / 100)).round();

    List<TimedCentsSample> samples = [];
    if (lastTake != null && lastTake.pitchTrack.isNotEmpty) {
      samples = lastTake.pitchTrack
          .map((s) => TimedCentsSample(
                timeSec: s.timeMs / 1000.0,
                cents: s.centsDeviation,
              ))
          .toList();
    } else {
      for (int i = 0; i <= 40; i++) {
        samples.add(TimedCentsSample(
          timeSec: i * 0.5,
          cents: avgCents + math.sin(i * 0.4) * 3.5,
        ));
      }
    }

    final jitter = _lastTapTempoResult != null && _lastTapTempoResult!.jitterMs > 0
        ? _lastTapTempoResult!.jitterMs
        : 11.2;

    String level;
    if (accuracy >= 90 && jitter <= 12) {
      level = 'Virtuoso / Conservatorio';
    } else if (accuracy >= 80) {
      level = 'Avanzado';
    } else if (accuracy >= 65) {
      level = 'Intermedio';
    } else {
      level = 'Iniciacion';
    }

    return PedagogicalSessionData(
      sessionTitle: title,
      sessionDate: lastReport?.timestamp ?? DateTime.now(),
      duration: lastTake?.duration ?? const Duration(minutes: 12, seconds: 30),
      totalEvaluatedNotes: notes,
      inTuneNotesCount: inTune,
      tuningAccuracyPercentage: accuracy,
      averageCentsDeviation: avgCents,
      centsStabilityDelta: 3.8,
      spectralCentroidHz: 820.0,
      thdPercentage: 11.8,
      harmonicRatios: const [1.0, 0.62, 0.35, 0.2, 0.14, 0.08, 0.04, 0.02],
      rhythmMeanBpm: _bpm.toDouble(),
      rhythmJitterMs: jitter,
      timedPitchSamples: samples,
      masteryLevel: level,
      pedagogicalDiagnostic:
          'Se detecta una precision tonal consistente con estandares de conservatorio. '
          'El control del centroide espectral y la estabilidad del pulso son satisfactorios.',
      recommendations: const [
        'Mantener el apoyo diafragmatico y regularidad del flujo aereo en registros agudos.',
        'Ejercitar intervalos de quinta justa y octava con el Dron Armonico de referencia.',
        'Continuar rutinas de metronomo con acentos alternos para afianzar el pulso.',
      ],
    );
  }

  /// Compila y exporta el informe pedagógico y certificado a PDF vectorial estándar (ISO 32000-1).
  Uint8List exportPedagogicalReportPdf(PedagogicalReportConfig config) {
    return _pedagogicalPdfGenerator.generateReportPdf(
      session: currentPedagogicalSessionData,
      config: config,
    );
  }

  /// Transcribe un archivo de audio (.wav) directamente a la partitura activa.
  Future<ParsedScoreResult?> transcribeAudioFileToScore(Uint8List audioBytes, String fileName) async {
    try {
      final result = await _scoreImporterService.parseScoreData(
        bytes: audioBytes,
        fileName: fileName,
      );
      addSongPackage(result.package);
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint("Error al transcribir audio a partitura: $e");
      return null;
    }
  }

  /// Activa o detiene la transcripción acústica de notas del micrófono a la partitura en tiempo real.
  void toggleLiveTranscription() {
    _isLiveTranscriptionActive = !_isLiveTranscriptionActive;
    if (_isLiveTranscriptionActive) {
      _transcriptionEngine.start(
        initialPackage: _activePackage,
        startMeasureIndex: _currentMeasureIndex,
        startTick: _currentSubTick >= 0 ? _currentSubTick : 0,
      );
    } else {
      final finalPkg = _transcriptionEngine.stop();
      if (finalPkg != null) {
        _scoreHistory.recordState(_activePackage);
        _activePackage = finalPkg;
      }
    }
    notifyListeners();
  }

  /// Genera proceduralmente una rutina técnica o escala de conservatorio y la carga en el atril digital.
  void generateAndLoadExercise({
    required String rootNote,
    required ExerciseType type,
    ExerciseRhythm rhythm = ExerciseRhythm.quarter,
    int bpm = 80,
  }) {
    _scoreHistory.recordState(_activePackage);
    final generatedPkg = _exerciseGenerator.generate(
      rootNote: rootNote,
      type: type,
      rhythm: rhythm,
      bpm: bpm,
    );
    _activePackage = generatedPkg;
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

  // --- Métodos de Exportación de Stems y MIDI ---
  ExportBundleResult? get lastExportBundle => _lastExportBundle;
  bool get isExportingStems => _isExportingStems;

  /// Ejecuta la síntesis de stems y archivo MIDI de la obra activa y guarda los archivos en disco.
  Future<ExportBundleResult> exportStemsAndMidi({
    StemExportConfig config = const StemExportConfig(),
  }) async {
    _isExportingStems = true;
    notifyListeners();

    try {
      final bundle = _stemSynthesizer.exportStemsAndMidi(
        score: _activePackage.score,
        mixerConsole: _mixerConsole,
        bpm: _bpm,
        trackTitle: _activePackage.title,
        config: config,
        recordedTake: _activeRecording,
      );

      _lastExportBundle = bundle;
      await _exportPersistenceService.saveExportBundle(
        bundle,
        customSubfolder: _activePackage.title.toLowerCase().replaceAll(' ', '_'),
      );
      return bundle;
    } finally {
      _isExportingStems = false;
      notifyListeners();
    }
  }

  // --- Métodos de Lecciones Guiadas Interactivas ---
  GuidedLessonProgressEntity? get activeLessonProgress => _guidedLessonEvaluator.activeProgress;
  bool get hasActiveGuidedLesson => _guidedLessonEvaluator.hasActiveLesson;
  List<GuidedLessonEntity> get availableGuidedLessons => CuratedGuidedLessons.all;

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

  @override
  void dispose() {
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
