import 'dart:async';
import 'dart:math' as math;

import '../../../core/file_system/domain/i_platform_file_gateway.dart';
import '../../../core/logging/domain/i_studio_logger.dart';
import '../../acoustic_lab/domain/harmonic_series_analyzer.dart';
import '../../persistence/domain/app_user_settings_entity.dart';
import '../../persistence/domain/i_local_persistence_service.dart';
import '../domain/i_audio_playback_service.dart';
import '../domain/i_practice_recorder_service.dart';
import '../domain/multitrack_session_entity.dart';
import '../domain/practice_recording_entity.dart';

/// Controlador cohesivo dedicado a la grabación de práctica, reproducción de tomas,
/// sesiones multipista (comparador espectral) y persistencia offline del estudio.
class PracticeRecorderController {
  static const int maxWaveformPeaks = 120;
  static const int _maxRawWaveformBuffer = 16384;
  static const HarmonicSeriesAnalyzer _harmonicAnalyzer = HarmonicSeriesAnalyzer(maxHarmonics: 8);

  final IPracticeRecorderService _recorderService;
  final IAudioPlaybackService _playbackService;
  final ILocalPersistenceService _persistenceService;
  final IPlatformFileGateway _platformFileGateway;
  final Future<String> Function()? _recordingPathProvider;
  final void Function() _onNotify;
  final void Function() _onAutoSave;
  final IStudioLogger _logger;

  bool _isAudioRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  final Stopwatch _recordingStopwatch = Stopwatch();
  final List<double> _rawWaveformPeaks = [];
  final List<double> _currentWaveformPeaks = [];
  bool _waveformPeaksDirty = false;
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
    required IPlatformFileGateway platformFileGateway,
    required String initialTitle,
    required int initialBpm,
    required void Function() onNotify,
    required void Function() onAutoSave,
    Future<String> Function()? recordingPathProvider,
    IStudioLogger logger = const NoOpStudioLogger(),
  })  : _recorderService = recorderService,
        _playbackService = playbackService,
        _persistenceService = persistenceService,
        _platformFileGateway = platformFileGateway,
        _recordingPathProvider = recordingPathProvider,
        _onNotify = onNotify,
        _onAutoSave = onAutoSave,
        _logger = logger {
    initDefaultMultiTrackSession(title: initialTitle, bpm: initialBpm);
  }

  bool get isAudioRecording => _isAudioRecording;
  Duration get recordingDuration => _recordingDuration;
  List<double> get currentWaveformPeaks {
    _refreshWaveformPeaksIfNeeded();
    return List.unmodifiable(_currentWaveformPeaks);
  }

  void _refreshWaveformPeaksIfNeeded() {
    if (!_waveformPeaksDirty) return;
    _currentWaveformPeaks
      ..clear()
      ..addAll(downsampleWaveformPeaks(_rawWaveformPeaks));
    _waveformPeaksDirty = false;
  }
  List<double> get rawWaveformPeaks => List.unmodifiable(_rawWaveformPeaks);
  List<TimedPitchSample> get currentPitchTrack => List.unmodifiable(_currentPitchTrack);
  List<TimedPitchSample> get rawCurrentPitchTrack => _currentPitchTrack;
  List<TimedSpectralSample> get currentSpectralTrack => List.unmodifiable(_currentSpectralTrack);
  PracticeRecordingEntity? get activeRecording => _activeRecording;
  List<PracticeRecordingEntity> get recordingHistory => List.unmodifiable(_recordingHistory);
  List<PracticeRecordingEntity> get rawRecordingHistory => _recordingHistory;
  MultiTrackSessionEntity get multiTrackSession => _multiTrackSession;
  bool get isPlayingAudio => _isPlayingAudio;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;
  double get playbackSpeed => _playbackSpeed;
  Future<void> get isInitialized => _initCompleter.future;

  /// Reduce proporcionalmente una serie de picos brutos mediante max-pooling por cubetas
  /// para cubrir el 100% de la duracion de la grabacion dentro de [maxPeaks] barras.
  static List<double> downsampleWaveformPeaks(
    List<double> rawPeaks, {
    int maxPeaks = maxWaveformPeaks,
  }) {
    if (rawPeaks.isEmpty || maxPeaks <= 0) return const [];
    if (rawPeaks.length <= maxPeaks) {
      return List<double>.from(rawPeaks);
    }
    final total = rawPeaks.length;
    final downsampled = <double>[];
    for (int bucket = 0; bucket < maxPeaks; bucket++) {
      final start = (bucket * total) ~/ maxPeaks;
      final rawEnd = ((bucket + 1) * total) ~/ maxPeaks;
      final end = rawEnd > start ? rawEnd : start + 1;
      double bucketMax = 0.0;
      for (int i = start; i < end && i < total; i++) {
        if (rawPeaks[i] > bucketMax) {
          bucketMax = rawPeaks[i];
        }
      }
      downsampled.add(bucketMax);
    }
    return downsampled;
  }

  static double _computeRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    return math.sqrt(sumSquares / samples.length).clamp(0.0, 1.0);
  }

  void addWaveformPeak(double peak) {
    final sanitizedPeak = peak.isFinite ? peak.clamp(0.0, 1.0) : 0.0;
    _rawWaveformPeaks.add(sanitizedPeak);
    if (_rawWaveformPeaks.length >= _maxRawWaveformBuffer) {
      final compacted = <double>[];
      for (int i = 0; i < _rawWaveformPeaks.length; i += 2) {
        final first = _rawWaveformPeaks[i];
        final second = (i + 1 < _rawWaveformPeaks.length) ? _rawWaveformPeaks[i + 1] : first;
        compacted.add(math.max(first, second));
      }
      _rawWaveformPeaks
        ..clear()
        ..addAll(compacted);
      _waveformPeaksDirty = true;
      return;
    }
    if (!_waveformPeaksDirty && _rawWaveformPeaks.length <= maxWaveformPeaks) {
      _currentWaveformPeaks.add(sanitizedPeak);
    } else {
      _waveformPeaksDirty = true;
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
    _rawWaveformPeaks.clear();
    _currentWaveformPeaks.clear();
    _waveformPeaksDirty = false;
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
    } catch (e, st) {
      _logger.warning(
        'PracticeRecorderController',
        'Fallback a directorio temporal para grabacion: $e',
        error: e,
        stackTrace: st,
      );
      try {
        final tempDir = await _platformFileGateway.getTemporaryDirectoryPath();
        return '$tempDir/tunner_take_${DateTime.now().millisecondsSinceEpoch}.wav';
      } catch (tempError, tempSt) {
        _logger.warning(
          'PracticeRecorderController',
          'Fallback a ruta relativa para grabacion: $tempError',
          error: tempError,
          stackTrace: tempSt,
        );
        return 'tunner_take_${DateTime.now().millisecondsSinceEpoch}.wav';
      }
    }
  }

  Future<void> startPracticeRecording() async {
    if (_isAudioRecording) return;
    if (_isPlayingAudio) {
      await stopActiveRecordingPlayback();
    }

    _rawWaveformPeaks.clear();
    _currentWaveformPeaks.clear();
    _waveformPeaksDirty = false;
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
    } catch (e, st) {
      _logger.warning(
        'PracticeRecorderController',
        'Error al iniciar grabacion de practica: $e',
        error: e,
        stackTrace: st,
      );
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
    final recordedDuration = _recordingStopwatch.elapsed > _recordingDuration
        ? _recordingStopwatch.elapsed
        : _recordingDuration;

    final filePath = await _recorderService.stopRecording();
    if (filePath != null && recordedDuration.inMilliseconds >= 500) {
      _refreshWaveformPeaksIfNeeded();
      _recordingDuration = recordedDuration;
      final recording = PracticeRecordingEntity(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        filePath: filePath,
        recordedAt: DateTime.now(),
        duration: recordedDuration,
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
        duration: recordedDuration,
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
  }) async {
    final toPlay = targetRecording ?? _activeRecording;
    if (toPlay == null) return;
    _activeRecording = toPlay;
    final path = toPlay.filePath.trim();
    if (path.isEmpty) {
      if (_isPlayingAudio) {
        await _playbackService.stop();
      }
      _isPlayingAudio = false;
      _playbackPosition = Duration.zero;
      _logger.warning(
        'PracticeRecorderController',
        'No existe archivo valido para reproducir la grabacion ${toPlay.id}.',
      );
      _onNotify();
      return;
    }

    try {
      await _playbackService.play(path);
      _isPlayingAudio = true;
    } catch (e, st) {
      _isPlayingAudio = false;
      _logger.warning(
        'PracticeRecorderController',
        'Error reproduciendo la grabacion ${toPlay.id}: $e',
        error: e,
        stackTrace: st,
      );
    }
    _onNotify();
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
    List<double>? audioSamples,
    double sampleRate = 44100.0,
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
    if (pitch > 20.0 && !isSilent) {
      final samples = audioSamples;
      final timbre = _harmonicAnalyzer.analyze(
        fundamentalHz: pitch,
        samples: samples,
        sampleRate: sampleRate,
      );
      if (samples != null && timbre.harmonics.isNotEmpty) {
        _currentSpectralTrack.add(
          TimedSpectralSample(
            timeMs: timeMs,
            spectralCentroidHz: timbre.spectralCentroidHz,
            thdPercent: timbre.totalHarmonicDistortionPercent,
            rmsEnergy: _computeRms(samples),
          ),
        );
      }
    }
  }

  void initDefaultMultiTrackSession({required String title, required int bpm}) {
    final now = DateTime.now();
    _multiTrackSession = MultiTrackSessionEntity(
      id: 'session_${now.millisecondsSinceEpoch}',
      title: title,
      createdAt: now,
      bpm: bpm,
      takes: <PracticeTakeEntity>[],
      selectedTakeAId: null,
      selectedTakeBId: null,
    );
  }

  void selectComparisonTakes({String? takeAId, String? takeBId}) {
    _multiTrackSession = _multiTrackSession.copyWith(
      selectedTakeAId: takeAId ?? _multiTrackSession.selectedTakeAId,
      selectedTakeBId: takeBId ?? _multiTrackSession.selectedTakeBId,
    );
    _onAutoSave();
    _onNotify();
  }

  void addPracticeTake(PracticeTakeEntity take) {
    _multiTrackSession = _multiTrackSession.copyWith(
      takes: [..._multiTrackSession.takes, take],
      selectedTakeAId: _multiTrackSession.takes.isNotEmpty ? _multiTrackSession.takes.last.id : take.id,
      selectedTakeBId: take.id,
    );
    _onAutoSave();
    _onNotify();
  }

  void setTakeMute(String takeId, bool isMuted) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(isMuted: isMuted) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    _onAutoSave();
    _onNotify();
  }

  void setTakeSolo(String takeId, bool isSolo) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(isSolo: isSolo) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    _onAutoSave();
    _onNotify();
  }

  void setTakeGain(String takeId, double gain) {
    final updated = _multiTrackSession.takes.map((t) {
      return t.id == takeId ? t.copyWith(gain: gain) : t;
    }).toList();
    _multiTrackSession = _multiTrackSession.copyWith(takes: updated);
    _onAutoSave();
    _onNotify();
  }

  Future<void> playTakeAudio(PracticeTakeEntity take) async {
    final path = take.filePath.trim();
    if (path.isEmpty) {
      if (_isPlayingAudio) {
        await _playbackService.stop();
      }
      _isPlayingAudio = false;
      _playbackPosition = Duration.zero;
      _logger.warning(
        'PracticeRecorderController',
        'No existe archivo valido para reproducir la toma ${take.id}.',
      );
      _onNotify();
      return;
    }

    try {
      await _playbackService.play(path);
      _isPlayingAudio = true;
    } catch (e, st) {
      _isPlayingAudio = false;
      _logger.warning(
        'PracticeRecorderController',
        'Error reproduciendo la toma ${take.id}: $e',
        error: e,
        stackTrace: st,
      );
    }
    _onNotify();
  }

  Future<void> loadSettingsInto(void Function(AppUserSettingsEntity settings) applySettings) async {
    try {
      final settings = await _persistenceService.loadSettings();
      if (settings.recordingHistory.isNotEmpty) {
        _recordingHistory.clear();
        _recordingHistory.addAll(settings.recordingHistory);
        _activeRecording = _recordingHistory.first;
      }
      if (settings.multiTrackSession != null) {
        _multiTrackSession = settings.multiTrackSession!;
      }
      applySettings(settings);
    } catch (e, st) {
      _logger.warning(
        'PracticeRecorderController',
        'Error cargando configuracion inicial de practica: $e',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  void seedDefaultRecordingsIfEmpty() {
    // No se siembran grabaciones ficticias por defecto: la grabadora inicia limpia hasta capturar audio real.
  }

  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    try {
      await _persistenceService.saveSettings(settings);
    } catch (e, st) {
      _logger.warning(
        'PracticeRecorderController',
        'Error persistiendo configuracion de practica: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recordingStopwatch.stop();
  }
}
