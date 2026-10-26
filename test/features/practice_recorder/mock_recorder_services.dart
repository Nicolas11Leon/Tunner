import 'dart:async';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';

class MockPracticeRecorderService implements IPracticeRecorderService {
  bool _isRecording = false;
  String? lastDestinationPath;
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  void emitAmplitude(double peak) {
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(peak);
    }
  }

  @override
  Future<void> startRecording({required String destinationPath}) async {
    lastDestinationPath = destinationPath;
    _isRecording = true;
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    return lastDestinationPath ?? "/mock/take.m4a";
  }

  @override
  Future<void> pauseRecording() async {
    _isRecording = false;
  }

  @override
  Future<void> resumeRecording() async {
    _isRecording = true;
  }

  @override
  void dispose() {
    _amplitudeController.close();
  }
}

class MockAudioPlaybackService implements IAudioPlaybackService {
  bool _isPlaying = false;
  String? currentFilePath;
  Duration currentPosition = Duration.zero;
  Duration currentDuration = const Duration(seconds: 30);
  double currentRate = 1.0;

  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<void> _completeController = StreamController<void>.broadcast();

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<void> play(String filePath) async {
    currentFilePath = filePath;
    _isPlaying = true;
    _durationController.add(currentDuration);
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    currentPosition = Duration.zero;
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    currentPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    currentRate = rate;
  }

  void emitPosition(Duration pos) {
    currentPosition = pos;
    _positionController.add(pos);
  }

  void emitComplete() {
    _isPlaying = false;
    _completeController.add(null);
  }

  @override
  void dispose() {
    _positionController.close();
    _durationController.close();
    _completeController.close();
  }
}
