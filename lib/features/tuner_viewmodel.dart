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

/// ViewModel principal orquestador del estudio interactivo.
/// Diseñado bajo Clean Architecture con Inversión de Dependencias (DIP).
/// Recibe abstracciones de servicios en lugar de construirlos acopladamente.
class TunerViewModel extends ChangeNotifier {
  final IPitchDetectorService _pitchService;
  final IMetronomeService _metronomeService;
  final IPracticeEvaluatorService _evaluatorService;
  final IInstrumentTranspositionService _transpositionService;

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
  })  : _pitchService = pitchService ?? PitchDetectorService(),
        _metronomeService = metronomeService ?? MetronomeService(),
        _evaluatorService = evaluatorService ?? const PracticeEvaluatorService(),
        _transpositionService = transpositionService ?? const InstrumentTranspositionService() {
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

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pitchService.stopRecording();
    _metronomeService.stop();
    super.dispose();
  }
}
