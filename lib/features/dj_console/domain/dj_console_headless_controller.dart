import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/audio/domain/offline_wav_decoder.dart';
import 'bpm_beat_tracker_engine.dart';
import 'dj_action.dart';
import 'dj_audio_processor.dart';
import 'dj_channel_fx_entity.dart';
import 'dj_crossfader_entity.dart';
import 'dj_deck_entity.dart';
import 'dj_harmonic_camelot_engine.dart';
import 'dj_performance_orchestrator.dart';
import 'dj_smart_automix_engine.dart';
import 'dj_stem_isolation_entity.dart';
import 'dj_transition_sfx_synthesizer.dart';
import 'dj_mix_wav_encoder.dart';

/// Immutable acoustic analysis summary for a track loaded into the headless DJ controller.
class DjTrackAnalysisResult {
  final String deckId;
  final String title;
  final String artist;
  final double bpm;
  final CamelotKey camelotKey;
  final int durationMs;
  final int sampleRate;
  final int channels;
  final List<SpectralWaveformBucket> spectralSummary;

  const DjTrackAnalysisResult({
    required this.deckId,
    required this.title,
    required this.artist,
    required this.bpm,
    required this.camelotKey,
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
    required this.spectralSummary,
  });

  Map<String, dynamic> toJson() => {
        'deckId': deckId,
        'title': title,
        'artist': artist,
        'bpm': bpm,
        'camelotKey': camelotKey.code,
        'musicalKey': camelotKey.musicalName,
        'durationMs': durationMs,
        'sampleRate': sampleRate,
        'channels': channels,
        'spectralSummaryBuckets': spectralSummary.length,
      };
}

/// Immutable result of an offline Automix transition WAV render.
class DjAutomixRenderResult {
  final Uint8List wavBytes;
  final int durationMs;
  final int sampleRate;
  final double referenceBpm;
  final int durationBars;
  final AutomixDirection direction;
  final bool bassSwapEnabled;

  const DjAutomixRenderResult({
    required this.wavBytes,
    required this.durationMs,
    required this.sampleRate,
    required this.referenceBpm,
    required this.durationBars,
    required this.direction,
    required this.bassSwapEnabled,
  });

  Map<String, dynamic> toJson() => {
        'bytesWritten': wavBytes.length,
        'durationMs': durationMs,
        'sampleRate': sampleRate,
        'referenceBpm': referenceBpm,
        'durationBars': durationBars,
        'direction': direction.name,
        'bassSwapEnabled': bassSwapEnabled,
      };
}

/// Pure Dart headless controller for the Virtual DJ Console.
///
/// Decouples PCM WAV decoding, BPM/Camelot analysis, deck/mixer DSP control,
/// and offline Smart Automix WAV rendering from Flutter UI and ChangeNotifier.
class DjConsoleHeadlessController {
  final DjPerformanceOrchestrator _orchestrator;
  final DjAudioProcessor _audioProcessor;

  Float32List _deckSamplesA = Float32List(0);
  Float32List _deckSamplesB = Float32List(0);
  int _deckSampleRateA = 44100;
  int _deckSampleRateB = 44100;
  List<SpectralWaveformBucket> _waveformA = const [];
  List<SpectralWaveformBucket> _waveformB = const [];

  DjConsoleHeadlessController({
    DjPerformanceOrchestrator? orchestrator,
    DjAudioProcessor? audioProcessor,
    int defaultSampleRate = 44100,
  })  : _orchestrator = orchestrator ?? DjPerformanceOrchestrator(),
        _audioProcessor = audioProcessor ?? DjAudioProcessor(sampleRate: defaultSampleRate);

  DjPerformanceOrchestrator get orchestrator => _orchestrator;
  DjAudioProcessor get audioProcessor => _audioProcessor;

  DjDeckEntity get deckA => _orchestrator.deckA;
  DjDeckEntity get deckB => _orchestrator.deckB;
  DjCrossfaderEntity get crossfader => _orchestrator.crossfader;
  DjChannelFxEntity get fxA => _orchestrator.fxA;
  DjChannelFxEntity get fxB => _orchestrator.fxB;
  DjSmartAutomixEngine get automix => _orchestrator.automix;
  double get masterVolume => _orchestrator.masterVolume;
  CamelotCompatibility get harmonicCompatibility => _orchestrator.harmonicCompatibility;

  Float32List getDeckSamples(String deckId) =>
      _normalizeDeckId(deckId) == 'A' ? _deckSamplesA : _deckSamplesB;

  int getDeckSampleRate(String deckId) =>
      _normalizeDeckId(deckId) == 'A' ? _deckSampleRateA : _deckSampleRateB;

  List<SpectralWaveformBucket> getDeckWaveform(String deckId) =>
      _normalizeDeckId(deckId) == 'A' ? _waveformA : _waveformB;

  /// Decodes raw WAV bytes using [OfflineWavDecoder], runs BPM and Camelot
  /// analysis when [autoAnalyze] is true, and loads the track into [deckId].
  DjTrackAnalysisResult loadWavBytes(
    String deckId,
    Uint8List wavBytes, {
    String? title,
    String? artist,
    String? audioPath,
    bool autoAnalyze = true,
    int waveformBuckets = 96,
  }) {
    final decoded = OfflineWavDecoder.decode(wavBytes);
    final float32Samples = _toFloat32List(decoded.samples);

    return loadPcmSamples(
      deckId,
      float32Samples,
      sampleRate: decoded.sampleRate,
      channels: decoded.channels,
      title: title ?? 'Deck ${_normalizeDeckId(deckId)} Track',
      artist: artist ?? 'Unknown',
      audioPath: audioPath,
      autoAnalyze: autoAnalyze,
      waveformBuckets: waveformBuckets,
    );
  }

  /// Loads raw mono PCM samples into [deckId] and optionally analyzes BPM & Camelot key.
  DjTrackAnalysisResult loadPcmSamples(
    String deckId,
    Float32List samples, {
    int sampleRate = 44100,
    int channels = 1,
    String title = 'Untitled Track',
    String artist = 'Unknown',
    String? audioPath,
    bool autoAnalyze = true,
    int waveformBuckets = 96,
  }) {
    final normalizedId = _normalizeDeckId(deckId);
    final safeSampleRate = sampleRate > 0 ? sampleRate : 44100;
    final durationMs =
        samples.isEmpty ? 0 : ((samples.length / safeSampleRate) * 1000.0).round();

    final double bpm = autoAnalyze
        ? BpmBeatTrackerEngine.estimateBpm(samples: samples, sampleRate: safeSampleRate)
        : 120.0;
    final CamelotKey camelot = autoAnalyze
        ? DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples(
            samples,
            sampleRate: safeSampleRate,
          )
        : DjHarmonicCamelotEngine.findByCode('8A');
    final waveform = DjTransitionSfxSynthesizer.computeSpectralWaveformSummary(
      samples,
      buckets: waveformBuckets,
      sampleRate: safeSampleRate,
    );

    if (normalizedId == 'A') {
      _deckSamplesA = Float32List.fromList(samples);
      _deckSampleRateA = safeSampleRate;
      _waveformA = waveform;
    } else {
      _deckSamplesB = Float32List.fromList(samples);
      _deckSampleRateB = safeSampleRate;
      _waveformB = waveform;
    }

    _orchestrator.loadTrack(
      normalizedId,
      title: title,
      artist: artist,
      bpm: bpm,
      durationMs: durationMs,
      audioPath: audioPath,
      camelotKey: camelot.code,
    );

    return DjTrackAnalysisResult(
      deckId: normalizedId,
      title: title,
      artist: artist,
      bpm: bpm,
      camelotKey: camelot,
      durationMs: durationMs,
      sampleRate: safeSampleRate,
      channels: channels,
      spectralSummary: waveform,
    );
  }

  /// Statelessly analyzes WAV bytes without modifying either deck's loaded state.
  DjTrackAnalysisResult analyzeWavBytes(
    Uint8List wavBytes, {
    String deckId = 'A',
    String title = 'Analyzed Track',
    String artist = 'Unknown',
    int waveformBuckets = 96,
  }) {
    final decoded = OfflineWavDecoder.decode(wavBytes);
    final float32Samples = _toFloat32List(decoded.samples);
    final bpm = BpmBeatTrackerEngine.estimateBpm(
      samples: float32Samples,
      sampleRate: decoded.sampleRate,
    );
    final camelot = DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples(
      float32Samples,
      sampleRate: decoded.sampleRate,
    );
    final waveform = DjTransitionSfxSynthesizer.computeSpectralWaveformSummary(
      float32Samples,
      buckets: waveformBuckets,
      sampleRate: decoded.sampleRate,
    );
    return DjTrackAnalysisResult(
      deckId: _normalizeDeckId(deckId),
      title: title,
      artist: artist,
      bpm: bpm,
      camelotKey: camelot,
      durationMs: (decoded.durationSeconds * 1000.0).round(),
      sampleRate: decoded.sampleRate,
      channels: decoded.channels,
      spectralSummary: waveform,
    );
  }

  // --- Mixing, EQ, Trim, FX, Stems, Loops, Sync Controls ---

  void setCrossfaderPosition(double position) =>
      _orchestrator.setCrossfaderPosition(position);

  void setCrossfaderCurve(CrossfaderCurve curve) =>
      _orchestrator.setCrossfaderCurve(curve);

  void setMasterVolume(double volume) => _orchestrator.setMasterVolume(volume);

  void setDeckVolume(String deckId, double volume) =>
      _orchestrator.setDeckVolume(_normalizeDeckId(deckId), volume);

  void setTrim(String deckId, double trim) =>
      _orchestrator.setTrim(_normalizeDeckId(deckId), trim);

  void setEqGains(String deckId, {double? low, double? mid, double? high}) =>
      _orchestrator.setEqGains(
        _normalizeDeckId(deckId),
        low: low,
        mid: mid,
        high: high,
      );

  void toggleEqKill(String deckId, String band) =>
      _orchestrator.toggleEqKill(_normalizeDeckId(deckId), band);

  void setChannelFilter(String deckId, double position) =>
      _orchestrator.setChannelFilter(_normalizeDeckId(deckId), position);

  void toggleChannelDelay(String deckId) =>
      _orchestrator.toggleChannelDelay(_normalizeDeckId(deckId));

  void setChannelDelayDivision(String deckId, DjDelayDivision division) =>
      _orchestrator.setChannelDelayDivision(_normalizeDeckId(deckId), division);

  void setChannelDelayParams(String deckId, {double? feedback, double? dryWet}) =>
      _orchestrator.setChannelDelayParams(
        _normalizeDeckId(deckId),
        feedback: feedback,
        dryWet: dryWet,
      );

  void toggleStem(String deckId, DjStemType type) =>
      _orchestrator.toggleStem(_normalizeDeckId(deckId), type);

  void applyStemPreset(String deckId, String preset) =>
      _orchestrator.applyStemPreset(_normalizeDeckId(deckId), preset);

  void engageAutoLoop(String deckId, double beats) =>
      _orchestrator.engageAutoLoop(_normalizeDeckId(deckId), beats);

  void toggleLoop(String deckId) =>
      _orchestrator.toggleLoop(_normalizeDeckId(deckId));

  void exitLoop(String deckId) => _orchestrator.exitLoop(_normalizeDeckId(deckId));

  void halveLoop(String deckId) => _orchestrator.halveLoop(_normalizeDeckId(deckId));

  void doubleLoop(String deckId) =>
      _orchestrator.doubleLoop(_normalizeDeckId(deckId));

  void beatJump(String deckId, double beatDelta) =>
      _orchestrator.beatJump(_normalizeDeckId(deckId), beatDelta);

  void toggleSlipMode(String deckId) =>
      _orchestrator.toggleSlipMode(_normalizeDeckId(deckId));

  void syncBpm(String targetDeckId) =>
      _orchestrator.syncBpm(_normalizeDeckId(targetDeckId));

  void syncKey(String targetDeckId) =>
      _orchestrator.syncKey(_normalizeDeckId(targetDeckId));

  void togglePlay(String deckId) =>
      _orchestrator.togglePlay(_normalizeDeckId(deckId));

  void triggerCue(String deckId) =>
      _orchestrator.triggerCue(_normalizeDeckId(deckId));

  void seekDeckPlayback(String deckId, int targetPositionMs) =>
      _orchestrator.seekDeckPlayback(_normalizeDeckId(deckId), targetPositionMs);

  void triggerHotCue(String deckId, int cueIndex) =>
      _orchestrator.triggerHotCue(_normalizeDeckId(deckId), cueIndex);

  void clearHotCue(String deckId, int cueIndex) =>
      _orchestrator.clearHotCue(_normalizeDeckId(deckId), cueIndex);

  void executeAction(DjAction action) => _orchestrator.executeAction(action);

  /// Renders a deterministic offline Smart Automix transition between Deck A and Deck B
  /// into a RIFF/WAVE 16-bit PCM stereo buffer.
  ///
  /// Uses the currently loaded deck PCM buffers unless [deckAWavBytes] / [deckBWavBytes]
  /// are explicitly supplied. Applies crossfader curve gains, optional Bass-Swap EQ
  /// automation, active deck EQ/stems/FX, trim, volume, master volume, and soft limiting.
  Uint8List renderAutomixTransitionWav({
    AutomixDirection direction = AutomixDirection.deckAToDeckB,
    int durationBars = 8,
    bool enableBassSwap = true,
    CrossfaderCurve? crossfaderCurve,
    double? referenceBpm,
    int sampleRate = 44100,
    int blockSize = 1024,
    Uint8List? deckAWavBytes,
    Uint8List? deckBWavBytes,
  }) {
    return renderAutomixTransition(
      direction: direction,
      durationBars: durationBars,
      enableBassSwap: enableBassSwap,
      crossfaderCurve: crossfaderCurve,
      referenceBpm: referenceBpm,
      sampleRate: sampleRate,
      blockSize: blockSize,
      deckAWavBytes: deckAWavBytes,
      deckBWavBytes: deckBWavBytes,
    ).wavBytes;
  }

  /// Renders an offline Smart Automix transition and returns both WAV bytes and metadata.
  DjAutomixRenderResult renderAutomixTransition({
    AutomixDirection direction = AutomixDirection.deckAToDeckB,
    int durationBars = 8,
    bool enableBassSwap = true,
    CrossfaderCurve? crossfaderCurve,
    double? referenceBpm,
    int sampleRate = 44100,
    int blockSize = 1024,
    Uint8List? deckAWavBytes,
    Uint8List? deckBWavBytes,
  }) {
    final int safeSampleRate = sampleRate > 0 ? sampleRate : 44100;
    final int safeBars = durationBars.clamp(1, 64);
    final int safeBlockSize = blockSize.clamp(128, 8192);

    Float32List samplesA = _deckSamplesA;
    int rateA = _deckSampleRateA;
    if (deckAWavBytes != null) {
      final decodedA = OfflineWavDecoder.decode(deckAWavBytes);
      samplesA = _toFloat32List(decodedA.samples);
      rateA = decodedA.sampleRate;
    }

    Float32List samplesB = _deckSamplesB;
    int rateB = _deckSampleRateB;
    if (deckBWavBytes != null) {
      final decodedB = OfflineWavDecoder.decode(deckBWavBytes);
      samplesB = _toFloat32List(decodedB.samples);
      rateB = decodedB.sampleRate;
    }

    if (samplesA.isEmpty && samplesB.isEmpty) {
      throw StateError(
        'Cannot render Automix transition: both Deck A and Deck B audio buffers are empty.',
      );
    }

    final double effectiveBpm = (referenceBpm ??
            (direction == AutomixDirection.deckAToDeckB
                ? _orchestrator.deckA.effectiveBpm
                : _orchestrator.deckB.effectiveBpm))
        .clamp(40.0, 240.0);

    // 1 bar in 4/4 = 4 beats -> durationSeconds = bars * 4 * (60 / bpm)
    final double totalDurationSeconds = safeBars * 4.0 * (60.0 / effectiveBpm);
    final int totalFrames = math.max(1, (totalDurationSeconds * safeSampleRate).round());
    final int durationMs = (totalDurationSeconds * 1000.0).round();

    final curve = crossfaderCurve ?? _orchestrator.crossfader.curve;
    final processor = DjAudioProcessor(sampleRate: safeSampleRate);

    // Prepare playback rate ratios accounting for source sample rate and deck pitch multiplier
    final double stepA =
        (rateA / safeSampleRate) * _orchestrator.deckA.pitchMultiplier.clamp(0.5, 2.0);
    final double stepB =
        (rateB / safeSampleRate) * _orchestrator.deckB.pitchMultiplier.clamp(0.5, 2.0);

    final int delaySamplesA = _computeDelaySamples(
      safeSampleRate,
      _orchestrator.deckA.effectiveBpm,
      _orchestrator.fxA.delayDivision,
    );
    final int delaySamplesB = _computeDelaySamples(
      safeSampleRate,
      _orchestrator.deckB.effectiveBpm,
      _orchestrator.fxB.delayDivision,
    );

    var automixState = const DjSmartAutomixEngine().start(
      direction: direction,
      durationBars: safeBars,
      enableBassSwap: enableBassSwap,
    );

    final monoMixed = Float32List(totalFrames);
    double cursorA = 0.0;
    double cursorB = 0.0;

    for (int offset = 0; offset < totalFrames; offset += safeBlockSize) {
      final int currentLen = math.min(safeBlockSize, totalFrames - offset);
      final blockA = Float32List(currentLen);
      final blockB = Float32List(currentLen);

      for (int i = 0; i < currentLen; i++) {
        blockA[i] = _sampleLinear(samplesA, cursorA);
        blockB[i] = _sampleLinear(samplesB, cursorB);
        cursorA += stepA;
        cursorB += stepB;
      }

      final xfaderGains = DjCrossfaderEntity(
        position: automixState.crossfaderPosition,
        curve: curve,
      ).calculateGains();

      final double gainA = (_orchestrator.deckA.volume *
              _orchestrator.deckA.trim *
              xfaderGains.gainA *
              _orchestrator.masterVolume)
          .clamp(0.0, 2.0);
      final double gainB = (_orchestrator.deckB.volume *
              _orchestrator.deckB.trim *
              xfaderGains.gainB *
              _orchestrator.masterVolume)
          .clamp(0.0, 2.0);

      final double eqLowA =
          _orchestrator.deckA.effectiveGainLow * automixState.bassSwapGainLowA;
      final double eqLowB =
          _orchestrator.deckB.effectiveGainLow * automixState.bassSwapGainLowB;

      final mixedBlock = processor.mixBuffers(
        bufferA: blockA,
        bufferB: blockB,
        gainA: gainA,
        gainB: gainB,
        eqLowA: eqLowA,
        eqMidA: _orchestrator.deckA.effectiveGainMid,
        eqHighA: _orchestrator.deckA.effectiveGainHigh,
        eqLowB: eqLowB,
        eqMidB: _orchestrator.deckB.effectiveGainMid,
        eqHighB: _orchestrator.deckB.effectiveGainHigh,
        stemsA: _orchestrator.deckA.stems,
        stemsB: _orchestrator.deckB.stems,
        filterA: _orchestrator.fxA.filterPosition,
        filterB: _orchestrator.fxB.filterPosition,
        delayActiveA: _orchestrator.fxA.isDelayActive,
        delaySamplesA: delaySamplesA,
        delayFeedbackA: _orchestrator.fxA.delayFeedback,
        delayDryWetA: _orchestrator.fxA.delayDryWet,
        delayActiveB: _orchestrator.fxB.isDelayActive,
        delaySamplesB: delaySamplesB,
        delayFeedbackB: _orchestrator.fxB.delayFeedback,
        delayDryWetB: _orchestrator.fxB.delayDryWet,
      );

      for (int i = 0; i < currentLen; i++) {
        monoMixed[offset + i] = mixedBlock[i];
      }

      final int elapsedMs = ((currentLen / safeSampleRate) * 1000.0).round();
      automixState = automixState.advance(
        elapsedMs: elapsedMs,
        referenceBpm: effectiveBpm,
      );
    }

    // Interleave to 2-channel stereo PCM 16-bit WAV
    final stereoInterleaved = Float32List(totalFrames * 2);
    for (int i = 0; i < totalFrames; i++) {
      final s = monoMixed[i];
      stereoInterleaved[i * 2] = s;
      stereoInterleaved[i * 2 + 1] = s;
    }

    final wavBytes = DjMixWavEncoder.encode(
      samples: stereoInterleaved,
      sampleRate: safeSampleRate,
      numChannels: 2,
    );

    return DjAutomixRenderResult(
      wavBytes: wavBytes,
      durationMs: durationMs,
      sampleRate: safeSampleRate,
      referenceBpm: effectiveBpm,
      durationBars: safeBars,
      direction: direction,
      bassSwapEnabled: enableBassSwap,
    );
  }

  /// Returns a complete JSON-serializable snapshot of the DJ console state.
  Map<String, dynamic> toJson() => {
        'masterVolume': _orchestrator.masterVolume,
        'crossfader': {
          'position': _orchestrator.crossfader.position,
          'curve': _orchestrator.crossfader.curve.name,
        },
        'harmonicCompatibility': _orchestrator.harmonicCompatibility.label,
        'deckA': _deckToJson(_orchestrator.deckA, _orchestrator.fxA, _deckSamplesA.length),
        'deckB': _deckToJson(_orchestrator.deckB, _orchestrator.fxB, _deckSamplesB.length),
        'automix': {
          'isActive': _orchestrator.automix.isActive,
          'direction': _orchestrator.automix.direction.name,
          'durationBars': _orchestrator.automix.durationBars,
          'progress': _orchestrator.automix.progress,
          'enableBassSwap': _orchestrator.automix.enableBassSwap,
        },
      };

  Map<String, dynamic> _deckToJson(
    DjDeckEntity deck,
    DjChannelFxEntity fx,
    int loadedSamplesCount,
  ) {
    return {
      'deckId': deck.deckId,
      'title': deck.trackTitle,
      'artist': deck.artist,
      'audioPath': deck.audioPath,
      'bpm': deck.bpm,
      'effectiveBpm': deck.effectiveBpm,
      'camelotKey': deck.camelotKey,
      'effectiveCamelotKey': deck.effectiveCamelotKey.code,
      'durationMs': deck.durationMs,
      'currentPositionMs': deck.currentPositionMs,
      'isPlaying': deck.isPlaying,
      'volume': deck.volume,
      'trim': deck.trim,
      'pitchMultiplier': deck.pitchMultiplier,
      'pitchSemitonesShift': deck.pitchSemitonesShift,
      'isKeyLockEnabled': deck.isKeyLockEnabled,
      'isSyncActive': deck.isSyncActive,
      'eq': {
        'low': deck.gainLow,
        'mid': deck.gainMid,
        'high': deck.gainHigh,
        'kills': [deck.isKillLow, deck.isKillMid, deck.isKillHigh],
      },
      'stems': {
        'vocals': deck.stems.effectiveVocalGain,
        'drums': deck.stems.effectiveDrumsGain,
        'bass': deck.stems.effectiveBassGain,
        'melody': deck.stems.effectiveMelodyGain,
      },
      'fx': {
        'filterPosition': fx.filterPosition,
        'isDelayActive': fx.isDelayActive,
        'delayDivision': fx.delayDivision.name,
        'delayFeedback': fx.delayFeedback,
        'delayDryWet': fx.delayDryWet,
      },
      'hotCues': deck.hotCues.map((k, v) => MapEntry(k.toString(), v)),
      'loop': {
        'isActive': deck.isLoopActive,
        'startMs': deck.loopStartMs,
        'endMs': deck.loopEndMs,
        'beats': deck.loopBeats,
        'isSlipModeActive': deck.isSlipModeActive,
      },
      'loadedSamplesCount': loadedSamplesCount,
    };
  }

  static String _normalizeDeckId(String deckId) {
    final upper = deckId.trim().toUpperCase();
    return upper == 'B' ? 'B' : 'A';
  }

  static Float32List _toFloat32List(Float64List source) {
    final result = Float32List(source.length);
    for (int i = 0; i < source.length; i++) {
      result[i] = source[i];
    }
    return result;
  }

  static double _sampleLinear(Float32List buffer, double index) {
    if (buffer.isEmpty || index < 0.0) return 0.0;
    final int idx0 = index.floor();
    if (idx0 >= buffer.length) return 0.0;
    final int idx1 = idx0 + 1;
    if (idx1 >= buffer.length) return buffer[idx0];
    final double frac = index - idx0;
    return buffer[idx0] + (buffer[idx1] - buffer[idx0]) * frac;
  }

  static int _computeDelaySamples(
    int sampleRate,
    double bpm,
    DjDelayDivision division,
  ) {
    final double safeBpm = bpm > 0 ? bpm : 120.0;
    final double beatSeconds = 60.0 / safeBpm;
    return (sampleRate * beatSeconds * division.factor)
        .round()
        .clamp(1, sampleRate * 2 - 1);
  }
}
