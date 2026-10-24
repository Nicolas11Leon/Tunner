import 'dart:async';
import 'package:flutter/material.dart';
import '../data/pitch_detector_service.dart';
import '../data/metronome_service.dart';
import '../domain/note_entity.dart';
import '../domain/score_entity.dart';
import '../domain/score_tree.dart';
import '../domain/tempo_entity.dart';
import '../domain/mixer_track_entity.dart';
import 'theme/tunner_theme.dart';

class PlayedRecord {
  final String noteName;
  final double cents;
  final bool isCorrect;
  final bool isRest;
  PlayedRecord(this.noteName, this.cents, this.isCorrect, {this.isRest = false});
}

class TunerViewModel extends ChangeNotifier {
  final PitchDetectorService _pitchService = PitchDetectorService();
  final MetronomeService _metronomeService = MetronomeService();
  
  double _frequency = 0.0;
  String _noteName = "--";
  double _cents = 0.0;
  bool _isRecording = false;

  Timer? _silenceTimer; // Temporizador para limpiar nota

  bool _isMetronomePlaying = false;
  int _currentSubTick = -1;
  int _currentMeasureIndex = 0;
  int _bpm = 75; 
  
  bool _isCountingIn = false;
  int _countInBeat = 0;
  
  final List<SongEntity> _playlist = SongEntity.getMockSongs();
  int _selectedSongIndex = 0;
  
  SongNote? _expectedNote;
  bool _isNoteCorrect = false;
  final Map<int, PlayedRecord> _measureHistory = {};

  // Personalización Estética y de Compás Pro
  TunnerThemeMode _themeMode = TunnerThemeMode.obsidianStudio;
  TimeSignature? _customTimeSignatureOverride;

  // Consola Mezcladora Multicanal (Stems y Metrónomo Independiente)
  MixerConsoleEntity _mixerConsole = MixerConsoleEntity.defaultSetup();

  TunnerThemeMode get themeMode => _themeMode;
  TunnerThemePalette get currentPalette => TunnerThemePalette.fromMode(_themeMode);
  MixerConsoleEntity get mixerConsole => _mixerConsole;

  double get frequency => _frequency;
  String get noteName => _noteName;
  double get cents => _cents;
  bool get isRecording => _isRecording;
  bool get isMetronomePlaying => _isMetronomePlaying;
  int get currentSubTick => _currentSubTick;
  int get currentMeasureIndex => _currentMeasureIndex;
  int get totalMeasures => _playlist[_selectedSongIndex].totalMeasures;
  int get bpm => _bpm;
  TempoMark get currentTempoMark => TempoMark.fromBpm(_bpm);
  bool get isCountingIn => _isCountingIn;
  int get countInBeat => _countInBeat;
  List<SongEntity> get playlist => _playlist;
  int get selectedSongIndex => _selectedSongIndex;
  SongNote? get expectedNote => _expectedNote;
  bool get isNoteCorrect => _isNoteCorrect;
  Map<int, PlayedRecord> get measureHistory => _measureHistory;

  List<SongNote> get currentMeasureNotes => _playlist[_selectedSongIndex].notesForMeasure(_currentMeasureIndex);
  TimeSignature get currentMeasureTimeSignature => _customTimeSignatureOverride ?? _playlist[_selectedSongIndex].timeSignatureForMeasure(_currentMeasureIndex);

  void setThemeMode(TunnerThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setCustomTimeSignature(TimeSignature? signature) {
    _customTimeSignatureOverride = signature;
    if (_isMetronomePlaying) {
      _metronomeService.stop().then((_) => _metronomeService.start(_bpm, ticksPerMeasure: currentMeasureTimeSignature.totalTicks));
    }
    resetSongState();
    notifyListeners();
  }

  // --- Controles de la Consola Mezcladora ---
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

  TunerViewModel() {
    _pitchService.onPitchDetected = (pitch) {
      _silenceTimer?.cancel();

      _frequency = pitch;
      final noteEntity = NoteEntity.fromFrequency(pitch);
      _noteName = noteEntity.name;
      _cents = noteEntity.cents;
      _validatePerformance();
      notifyListeners();

      // Respuesta ultrasónica para notas rápidas (solos de violín/guitarra):
      // 60ms en lugar de 250ms para que notas sucesivas ultra-cortas no queden retenidas
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
        // Un beat ocurre cada 4 subdivisiones de semicorchea
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
        // Detección de avance de compás cuando el tick se reinicia a 0
        if (_currentSubTick != -1 && subTick == 0) {
          final maxMeasures = _playlist[_selectedSongIndex].totalMeasures;
          _currentMeasureIndex = (_currentMeasureIndex + 1) % maxMeasures;
          _measureHistory.clear();
        }
        
        _currentSubTick = subTick;
        _updateExpectedNoteForTick(subTick);
      }
      
      _validatePerformance();
      notifyListeners();
    };
  }

  void _updateExpectedNoteForTick(int tick) {
    final notes = currentMeasureNotes;
    _expectedNote = notes.firstWhere(
      (n) => tick >= n.startTick && tick < (n.startTick + n.durationTicks),
      orElse: () => SongNote(startTick: tick, durationTicks: 1, noteName: "--"),
    );
  }

  void _validatePerformance() {
    if (_isCountingIn || _expectedNote == null || _currentSubTick == -1) {
      _isNoteCorrect = false;
      return;
    }

    if (_expectedNote!.isRest) {
      // Silencio correcto si no hay sonido o el Hz es ruido ambiental bajo
      _isNoteCorrect = _noteName == "--" || _frequency < 50;
      _measureHistory[_currentSubTick] = PlayedRecord("", 0, _isNoteCorrect, isRest: true);
    } else {
      if (_noteName == "--") {
        _isNoteCorrect = false;
      } else {
        _isNoteCorrect = _noteName.toLowerCase() == _expectedNote!.noteName.toLowerCase();
      }
      
      // Guardar registro para pintar en el pentagrama
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
      resetSongState();
    } else {
      _isCountingIn = true;
      _countInBeat = 0;
      _currentSubTick = -1;
      _measureHistory.clear();
      _isMetronomePlaying = true;
      final currentTicks = _playlist[_selectedSongIndex].timeSignature.totalTicks;
      await _metronomeService.start(_bpm, ticksPerMeasure: currentTicks);
    }
    notifyListeners();
  }

  void updateBpm(int newBpm) {
    _bpm = newBpm.clamp(20, 300);
    if (_isMetronomePlaying) {
      final currentTicks = _playlist[_selectedSongIndex].timeSignature.totalTicks;
      _metronomeService.stop().then((_) => _metronomeService.start(_bpm, ticksPerMeasure: currentTicks));
    }
    notifyListeners();
  }

  void incrementBpm([int step = 1]) {
    updateBpm(_bpm + step);
  }

  void decrementBpm([int step = 1]) {
    updateBpm(_bpm - step);
  }

  void selectSong(int index) {
    _selectedSongIndex = index;
    resetSongState();
    notifyListeners();
  }

  void resetSongState() {
    _isCountingIn = false;
    _countInBeat = 0;
    _currentSubTick = -1;
    _currentMeasureIndex = 0;
    _measureHistory.clear();
  }

  void selectMeasure(int measureIndex) {
    final maxMeasures = _playlist[_selectedSongIndex].totalMeasures;
    if (measureIndex >= 0 && measureIndex < maxMeasures) {
      _currentMeasureIndex = measureIndex;
      _currentSubTick = -1;
      _measureHistory.clear();
      notifyListeners();
    }
  }

  void nextMeasure() {
    final maxMeasures = _playlist[_selectedSongIndex].totalMeasures;
    selectMeasure((_currentMeasureIndex + 1) % maxMeasures);
  }

  void previousMeasure() {
    final maxMeasures = _playlist[_selectedSongIndex].totalMeasures;
    selectMeasure((_currentMeasureIndex - 1 + maxMeasures) % maxMeasures);
  }

  /// Sintetiza y activa la referencia sonora de afinación (Ear Training)
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