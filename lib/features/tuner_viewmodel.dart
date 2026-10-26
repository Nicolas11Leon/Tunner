import 'dart:async';
import 'dart:convert';
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

  // Inyección de dependencias en el constructor
  TunerViewModel({
    IPitchDetectorService? pitchService,
    IMetronomeService? metronomeService,
    IPracticeEvaluatorService? evaluatorService,
    IInstrumentTranspositionService? transpositionService,
    IPracticeRecorderService? recorderService,
    IAudioPlaybackService? playbackService,
    Future<String> Function()? recordingPathProvider,
  })  : _pitchService = pitchService ?? PitchDetectorService(),
        _metronomeService = metronomeService ?? MetronomeService(),
        _evaluatorService = evaluatorService ?? const PracticeEvaluatorService(),
        _transpositionService = transpositionService ?? const InstrumentTranspositionService(),
        _recorderService = recorderService ?? PracticeRecorderService(),
        _playbackService = playbackService ?? AudioPlaybackService(),
        _recordingPathProvider = recordingPathProvider {
    _activePackage = _curatedLibrary.first;
    _bpm = _activePackage.defaultBpm;
    _mixerConsole = MixerConsoleEntity(
      metronomeTrack: _mixerConsole.metronomeTrack,
      stems: _activePackage.tracks,
    );
    _initListeners();
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
  bool get isRecording => _isRecording;
  bool get isMetronomePlaying => _isMetronomePlaying;
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
      final noteEntity = NoteEntity.fromFrequency(pitch);
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
  }

  void setThemeMode(TunnerThemeMode mode) {
    _themeMode = mode;
    _currentPalette = TunnerThemePalette.fromMode(mode);
    notifyListeners();
  }

  void addCustomPalette(TunnerThemePalette palette) {
    _customPalettes.removeWhere((p) => p.id == palette.id);
    _customPalettes.add(palette);
    _currentPalette = palette;
    _themeMode = palette.mode;
    notifyListeners();
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
  }

  void deleteCustomPalette(String paletteId) {
    _customPalettes.removeWhere((p) => p.id == paletteId);
    if (_currentPalette.id == paletteId) {
      _currentPalette = TunnerThemePalette.obsidianStudio;
      _themeMode = TunnerThemeMode.obsidianStudio;
    }
    notifyListeners();
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
    }
    _activeRecording = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pitchService.stopRecording();
    _metronomeService.stop();
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
