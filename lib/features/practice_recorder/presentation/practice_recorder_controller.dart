import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/file_system/domain/i_platform_file_gateway.dart';
import '../../audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import '../../persistence/domain/app_user_settings_entity.dart';
import '../../persistence/domain/i_local_persistence_service.dart';
import '../domain/i_audio_playback_service.dart';
import '../domain/i_practice_recorder_service.dart';
import '../domain/multitrack_session_entity.dart';
import '../domain/practice_recording_entity.dart';

/// Controlador cohesivo dedicado a la grabación de práctica, reproducción de tomas,
/// sesiones multipista (comparador espectral) y persistencia offline del estudio.
class PracticeRecorderController {
  final IPracticeRecorderService _recorderService;
  final IAudioPlaybackService _playbackService;
  final ILocalPersistenceService _persistenceService;
  final IAudioSynthesizerService _audioSynthesizer;
  final IPlatformFileGateway _platformFileGateway;
  final Future<String> Function()? _recordingPathProvider;
  final VoidCallback _onNotify;
  final VoidCallback _onAutoSave;

  bool _isAudioRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  final Stopwatch _recordingStopwatch = Stopwatch();
  final List<double> _currentWaveformPeaks = [];
  final List<TimedPitchSample> _currentPitchTrack = [];
  final List<TimedSpectralSample> _currentSpectralTrack = [];

  PracticeRecordingEntity? _activeRecording;
  final List<PracticeRecordingEntity> _recordingHistory = [];
  late MultiTrackSessionEntity _multiTrackSession;

  bool _isPlayingAudio = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  double _playbackSpeed = 1.0;

  final Completer<void> _initCompleter = Completer<void>();

  PracticeRecorderController({
    required IPracticeRecorderService recorderService,
    required IAudioPlaybackService playbackService,
    required ILocalPersistenceService persistenceService,
    required IAudioSynthesizerService audioSynthesizer,
    required IPlatformFileGateway platformFileGateway,
    required String initialTitle,
    required int initialBpm,
    required VoidCallback onNotify,
    required VoidCallback onAutoSave,
    Future<String> Function()? recordingPathProvider,
  })  : _recorderService = recorderService,
        _playbackService = playbackService,
        _persistenceService = persistenceService,
        _audioSynthesizer = audioSynthesizer,
        _platformFileGateway = platformFileGateway,
        _recordingPathProvider = recordingPathProvider,
        _onNotify = onNotify,
        _onAutoSave = onAutoSave {
    initDefaultMultiTrackSession(title: initialTitle, bpm: initialBpm);
  }

  bool get isAudioRecording => _isAudioRecording;
  Duration get recordingDuration => _recordingDuration;
  List<double> get currentWaveformPeaks => List.unmodifiable(_currentWaveformPeaks);
  List<TimedPitchSample> get currentPitchTrack => List.unmodifiable(_currentPitchTrack);
  List<TimedPitchSample> get rawCurrentPitchTrack => _currentPitchTrack;
  PracticeRecordingEntity? get activeRecording => _activeRecording;
  List<PracticeRecordingEntity> get recordingHistory => List.unmodifiable(_recordingHistory);
  List<PracticeRecordingEntity> get rawRecordingHistory => _recordingHistory;
  MultiTrackSessionEntity get multiTrackSession => _multiTrackSession;
  bool get isPlayingAudio => _isPlayingAudio;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;
  double get playbackSpeed => _playbackSpeed;
  Future<void> get isInitialized => _initCompleter.future;

  void addWaveformPeak(double peak) {
    _currentWaveformPeaks.add(peak);
    if (_currentWaveformPeaks.length > 60) {
      _currentWaveformPeaks.removeAt(0);
    }
  }

  void updatePlaybackPosition(Duration pos) {
    _playbackPosition = pos;
  }

  void updatePlaybackDuration(Duration dur) {
    _playbackDuration = dur;
  }

  void markPlaybackComplete() {
    _isPlayingAudio = false;
    _playbackPosition = Duration.zero;
  }

  void setMultiTrackSession(MultiTrackSessionEntity session) {
    _multiTrackSession = session;
  }

  void clearMultiTrackTracks() {
    _currentWaveformPeaks.clear();
    _currentPitchTrack.clear();
    _currentSpectralTrack.clear();
  }

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
        _onNotify();
      });
      _onNotify();
    } catch (_) {
      _isAudioRecording = false;
      _onNotify();
    }
  }

  Future<void> stopPracticeRecording({
    required String songTitle,
    required int bpm,
  }) async {
    if (!_isAudioRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStopwatch.stop();
    _isAudioRecording = false;

    final filePath = await _recorderService.stopRecording();
    if (filePath != null && _recordingDuration.inMilliseconds >= 500) {
      final recording = PracticeRecordingEntity(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        filePath: filePath,
        recordedAt: DateTime.now(),
        duration: _recordingDuration,
        songTitle: songTitle,
        bpm: bpm,
        waveformPeaks: List.unmodifiable(_currentWaveformPeaks),
      );
      _activeRecording = recording;
      _recordingHistory.insert(0, recording);

      final take = PracticeTakeEntity(
        id: 'take_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Toma ${_multiTrackSession.takes.length + 1}',
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
      _onAutoSave();
    }
    _onNotify();
  }

  Future<void> togglePracticeRecording({
    required String songTitle,
    required int bpm,
  }) async {
    if (_isAudioRecording) {
      await stopPracticeRecording(songTitle: songTitle, bpm: bpm);
    } else {
      await startPracticeRecording();
    }
  }

  Future<void> playActiveRecording({
    PracticeRecordingEntity? targetRecording,
    required double referencePitch,
  }) async {
    final toPlay = targetRecording ?? _activeRecording;
    if (toPlay == null) return;
    _activeRecording = toPlay;
    if (toPlay.filePath.isNotEmpty) {
      await _playbackService.play(toPlay.filePath);
      _isPlayingAudio = true;
      _onNotify();
    } else {
      _isPlayingAudio = true;
      _onNotify();
      await _audioSynthesizer.playNoteTone(
        frequency: referencePitch,
        duration: const Duration(seconds: 4),
        volume: 0.8,
      );
      _isPlayingAudio = false;
      _onNotify();
    }
  }

  Future<void> pauseActiveRecording() async {
    await _playbackService.pause();
    _isPlayingAudio = false;
    _onNotify();
  }

  Future<void> stopActiveRecordingPlayback() async {
    await _playbackService.stop();
    _isPlayingAudio = false;
    _playbackPosition = Duration.zero;
    _onNotify();
  }

  Future<void> seekPlayback(Duration position) async {
    await _playbackService.seek(position);
    _playbackPosition = position;
    _onNotify();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _playbackService.setPlaybackRate(speed);
    _onNotify();
  }

  void discardActiveRecording() {
    if (_isPlayingAudio) {
      stopActiveRecordingPlayback();
    }
    if (_activeRecording != null) {
      _recordingHistory.removeWhere((r) => r.id == _activeRecording!.id);
      _onAutoSave();
    }
    _activeRecording = null;
    _onNotify();
  }

  void deletePracticeRecordingById(String id) {
    _recordingHistory.removeWhere((r) => r.id == id);
    if (_activeRecording?.id == id) {
      _activeRecording = _recordingHistory.isNotEmpty ? _recordingHistory.first : null;
    }
    _onAutoSave();
    _onNotify();
  }

  void recordSampleForMultiTrack({
    required double pitch,
    required double cents,
    required String noteName,
    required bool isAutoTuneEnabled,
    required double autoTuneTargetHz,
    required double autoTuneCentsDev,
    required String autoTuneTargetNote,
    required String? expectedNoteName,
    bool isSilent = false,
  }) {
    final timeMs = _recordingStopwatch.isRunning
        ? _recordingStopwatch.elapsedMilliseconds
        : _recordingDuration.inMilliseconds;
    if (_currentPitchTrack.isNotEmpty && (timeMs - _currentPitchTrack.last.timeMs).abs() < 20) {
      return;
    }

    final isAutoTuned = isAutoTuneEnabled && autoTuneTargetHz > 20.0;
    final correctedPitch = isAutoTuned ? autoTuneTargetHz : null;
    final effectiveCents = isAutoTuned ? autoTuneCentsDev : cents;
    final effectiveNoteName = isAutoTuned ? autoTuneTargetNote : noteName;

    _currentPitchTrack.add(
      TimedPitchSample(
        timeMs: timeMs,
        frequencyHz: pitch,
        centsDeviation: effectiveCents,
        targetNoteName: expectedNoteName ?? effectiveNoteName,
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
          rmsEnergy: _currentWaveformPeaks.isNotEmpty ? _currentWaveformPeaks.last : 0.25,
        ),
      );
    }
  }

  void initDefaultMultiTrackSession({required String title, required int bpm}) {
    final now = DateTime.now();
    _multiTrackSession = MultiTrackSessionEntity(
      id: 'session_${now.millisecondsSinceEpoch}',
      title: title,
      createdAt: now,
      bpm: bpm,
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
    _onNotify();
  }

  void addPracticeTake(PracticeTakeEntity take) {
    _multiTrackSession = _multiTrackSession.copyWith(
      takes: [..._multiTrackSession.takes, take],
      selectedTakeAId: _multiTrackSession.takes.isNotEmpty ? _multiTrackSession.takes.last.id : take.id,
      selectedTakeBId: take.id,
    );
    _onNotify();
  }

  void setTakeMute(String takeId, bool isMuted) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(isMuted: isMuted) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    _onNotify();
  }

  void setTakeSolo(String takeId, bool isSolo) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(isSolo: isSolo) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    _onNotify();
  }

  void setTakeGain(String takeId, double gain) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(gain: gain) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    _onNotify();
  }

  Future<void> playTakeAudio(PracticeTakeEntity take) async {
    if (take.filePath.isNotEmpty) {
      await _playbackService.play(take.filePath);
      _isPlayingAudio = true;
      _onNotify();
    } else {
      _isPlayingAudio = true;
      _onNotify();
      final freq = take.pitchTrack.isNotEmpty ? take.pitchTrack.first.frequencyHz : 440.0;
      await _audioSynthesizer.playNoteTone(
        frequency: freq,
        duration: const Duration(seconds: 2),
        volume: 0.75,
      );
      _isPlayingAudio = false;
      _onNotify();
    }
  }

  Future<void> loadSettingsInto(void Function(AppUserSettingsEntity settings) applySettings) async {
    try {
      final settings = await _persistenceService.loadSettings();
      if (settings.recordingHistory.isNotEmpty) {
        _recordingHistory.clear();
        _recordingHistory.addAll(settings.recordingHistory);
        _activeRecording = _recordingHistory.first;
      }
      applySettings(settings);
    } catch (_) {
      // Ignorar fallas de carga silenciosamente
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  void seedDefaultRecordingsIfEmpty() {
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
  }

  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    try {
      await _persistenceService.saveSettings(settings);
    } catch (_) {
      // Ignorar fallas de guardado secundarias
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recordingStopwatch.stop();
  }
}
