import 'dart:async';
import 'package:flutter/material.dart';
import '../data/pitch_detector_service.dart';
import '../data/metronome_service.dart';
import '../domain/note_entity.dart';
import '../domain/score_entity.dart';

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
  int _bpm = 75; 
  
  bool _isCountingIn = false;
  int _countInBeat = 0;
  
  final List<SongEntity> _playlist = SongEntity.getMockSongs();
  int _selectedSongIndex = 0;
  
  SongNote? _expectedNote;
  bool _isNoteCorrect = false;
  final Map<int, PlayedRecord> _measureHistory = {};

  double get frequency => _frequency;
  String get noteName => _noteName;
  double get cents => _cents;
  bool get isRecording => _isRecording;
  bool get isMetronomePlaying => _isMetronomePlaying;
  int get currentSubTick => _currentSubTick;
  int get bpm => _bpm;
  bool get isCountingIn => _isCountingIn;
  int get countInBeat => _countInBeat;
  List<SongEntity> get playlist => _playlist;
  int get selectedSongIndex => _selectedSongIndex;
  SongNote? get expectedNote => _expectedNote;
  bool get isNoteCorrect => _isNoteCorrect;
  Map<int, PlayedRecord> get measureHistory => _measureHistory;

  TunerViewModel() {
    _pitchService.onPitchDetected = (pitch) {
      _silenceTimer?.cancel();

      _frequency = pitch;
      final noteEntity = NoteEntity.fromFrequency(pitch);
      _noteName = noteEntity.name;
      _cents = noteEntity.cents;
      _validatePerformance();
      notifyListeners();

      _silenceTimer = Timer(const Duration(milliseconds: 250), () {
        _frequency = 0.0;
        _noteName = "--";
        _cents = 0.0;
        _validatePerformance();
        notifyListeners();
      });
    };

    _metronomeService.onSubTick = (subTick) {
      if (_isCountingIn) {
        // Como hay 16 ticks por compás, un "beat" entero ocurre cada 4 ticks (0, 4, 8, 12)
        if (subTick % 4 == 0) {
          _countInBeat++;
          if (_countInBeat > 4) {
            _isCountingIn = false;
            _currentSubTick = 0;
            _measureHistory.clear();
            _updateExpectedNoteForTick(0);
          }
        }
      } else {
        _currentSubTick = subTick;
        if (subTick == 0) _measureHistory.clear();
        _updateExpectedNoteForTick(subTick);
      }
      
      _validatePerformance();
      notifyListeners();
    };
  }

  void _updateExpectedNoteForTick(int tick) {
    final notes = _playlist[_selectedSongIndex].notes;
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
      await _metronomeService.start(_bpm);
    }
    notifyListeners();
  }

  void updateBpm(int newBpm) {
    _bpm = newBpm.clamp(40, 200);
    if (_isMetronomePlaying) {
      _metronomeService.stop().then((_) => _metronomeService.start(_bpm));
    }
    notifyListeners();
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
    _measureHistory.clear();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pitchService.stopRecording();
    _metronomeService.stop();
    super.dispose();
  }
}