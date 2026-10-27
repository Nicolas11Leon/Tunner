import 'dart:async';
import 'dart:convert';
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

  // Consola Mezcladora Multicanal
  MixerConsoleEntity _mixerConsole = MixerConsoleEntity.defaultSetup();

  // Calibración de Concierto A4 (415 Hz - 466 Hz)
  double _referencePitch = 440.0;

  // Editor de Partituras & Exportadores Canónicos
  final ScoreEditorOperations _editorOps = const ScoreEditorOperations();
  final ScoreUndoRedoHistory _scoreHistory = ScoreUndoRedoHistory();
  final CanonicalMusicXmlExporter _musicXmlExporter = const CanonicalMusicXmlExporter();
  final CanonicalMidiExporter _midiExporter = const CanonicalMidiExporter();

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
        _recordingPathProvider = recordingPathProvider {
    _activePackage = _curatedLibrary.first;
    _bpm = _activePackage.defaultBpm;
    _mixerConsole = MixerConsoleEntity(
      metronomeTrack: _mixerConsole.metronomeTrack,
      stems: _activePackage.tracks,
    );
    _initListeners();
    loadPersistedState();
  }

  // --- Getters del Estado ---
  TunnerThemeMode get themeMode => _themeMode;
  TunnerThemePalette get currentPalette => _currentPalette;
  List<TunnerThemePalette> get availablePalettes => [...TunnerThemePalette.allPresets, ..._customPalettes];
  List<TunnerThemePalette> get customPalettes => List.unmodifiable(_customPalettes);
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

  double get frequency => _frequency;
  String get noteName => _noteName;
  double get cents => _cents;
  double get referencePitch => _referencePitch;
  bool get isRecording => _isRecording;
  bool get isMetronomePlaying => _isMetronomePlaying;
  bool get isScorePlaybackEnabled => _isScorePlaybackEnabled;

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
    _pitchService.onPitchDetected = (pitch) {
      _silenceTimer?.cancel();
      _frequency = pitch;
      final noteEntity = NoteEntity.fromFrequency(pitch, a4Ref: _referencePitch);
      _noteName = noteEntity.name;
      _cents = noteEntity.cents;
      _validatePerformance();
      notifyListeners();

      _silenceTimer = Timer(const Duration(milliseconds: 60), () {
        _frequency = 0.0;
        _noteName = "--";
        _cents = 0.0;
        _validatePerformance();
        notifyListeners();
      });
    };

    _metronomeService.onSubTick = (subTick) {
      if (_isCountingIn) {
        if (subTick % 4 == 0) {
          final metroGain = _mixerConsole.getEffectiveGain(_mixerConsole.metronomeTrack.id);
          if (metroGain > 0.001) {
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
    _validatePerformance();
    notifyListeners();
    _triggerAutoSave();
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

  /// Detiene la grabación activa y consolida la toma como [PracticeRecordingEntity].
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
        customPalettes: _customPalettes,
        sessionHistory: _sessionHistory,
        recordingHistory: _recordingHistory,
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

  /// Exporta la partitura activa al estándar internacional MusicXML.
  String exportActiveScoreToMusicXml() {
    return _musicXmlExporter.exportToMusicXml(_activePackage);
  }

  /// Exporta la partitura activa al estándar binario Standard MIDI File (SMF Tipo 0).
  Uint8List exportActiveScoreToMidi() {
    return _midiExporter.exportToMidi(_activePackage);
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
