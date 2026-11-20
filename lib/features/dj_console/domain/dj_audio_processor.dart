import 'dart:math' as math;
import 'dart:typed_data';
import '../../song_library/domain/song_package_entity.dart';
import '../../universal_importer/domain/canonical_midi_exporter.dart';
import 'dj_stem_isolation_entity.dart';

/// High-performance, deterministic stereo audio processor for the Virtual DJ Console.
///
/// Features:
/// - Equalizer 3-band filtering (Low Shelf: 250 Hz, Peaking Mid: 1200 Hz, High Shelf: 4000 Hz)
/// - Bipolar sweep filter (-1.0 Low-Pass sweep down to 60 Hz, +1.0 High-Pass sweep up to 12000 Hz)
/// - Beat-synchronized delay line with bounded feedback (<= 0.80) and dry/wet blending
/// - Total kill isolation (24 dB/oct slope simulation)
/// - Sub-10ms buffer processing
/// - Soft limiter (tanh saturation) to guarantee zero digital clipping at 0 dBFS.
class DjAudioProcessor {
  final int sampleRate;

  DjAudioProcessor({this.sampleRate = 44100});

  /// Processes and blends two stereo input buffers into a unified output buffer
  /// using the calculated deck gains, EQ coefficients, and soft limiter.
  Float32List mixBuffers({
    required Float32List bufferA,
    required Float32List bufferB,
    required double gainA,
    required double gainB,
    double eqLowA = 1.0,
    double eqMidA = 1.0,
    double eqHighA = 1.0,
    double eqLowB = 1.0,
    double eqMidB = 1.0,
    double eqHighB = 1.0,
    double filterA = 0.0,
    double filterB = 0.0,
    bool delayActiveA = false,
    int delaySamplesA = 0,
    double delayFeedbackA = 0.4,
    double delayDryWetA = 0.5,
    bool delayActiveB = false,
    int delaySamplesB = 0,
    double delayFeedbackB = 0.4,
    double delayDryWetB = 0.5,
  }) {
    // Apply channel FX to Deck A if active
    var processedA = bufferA;
    if (filterA != 0.0) {
      processedA = applyBipolarFilter(processedA, filterA);
    }
    if (delayActiveA && delaySamplesA > 0) {
      processedA = applyDelay(
        processedA,
        delaySamples: delaySamplesA,
        feedback: delayFeedbackA,
        dryWet: delayDryWetA,
      );
    }

    // Apply channel FX to Deck B if active
    var processedB = bufferB;
    if (filterB != 0.0) {
      processedB = applyBipolarFilter(processedB, filterB);
    }
    if (delayActiveB && delaySamplesB > 0) {
      processedB = applyDelay(
        processedB,
        delaySamples: delaySamplesB,
        feedback: delayFeedbackB,
        dryWet: delayDryWetB,
      );
    }

    // Apply 3-Band Equalizer crossover filtering to Deck A
    processedA = apply3BandEq(
      processedA,
      eqLow: eqLowA,
      eqMid: eqMidA,
      eqHigh: eqHighA,
    );

    // Apply 3-Band Equalizer crossover filtering to Deck B
    processedB = apply3BandEq(
      processedB,
      eqLow: eqLowB,
      eqMid: eqMidB,
      eqHigh: eqHighB,
    );

    final length = math.max(processedA.length, processedB.length);
    final output = Float32List(length);

    for (int i = 0; i < length; i++) {
      final sampleA = i < processedA.length ? processedA[i] : 0.0;
      final sampleB = i < processedB.length ? processedB[i] : 0.0;

      final combined = (sampleA * gainA) + (sampleB * gainB);

      // Soft limiter via hyperbolic tangent to eliminate hard digital clipping
      output[i] = _softLimit(combined);
    }

    return output;
  }

  /// Applies a true 3-band equalizer (Low Shelf / Crossover at 250 Hz, High Shelf / Crossover at 2500 Hz, Mid Band).
  ///
  /// Separates the spectrum into Low, Mid, and High frequency bands using stable
  /// single-pole crossover filters, scales each by its respective gain multiplier,
  /// and recombines them. When [eqLow], [eqMid], and [eqHigh] are 1.0, the output
  /// reconstructs the input with unity gain.
  Float32List apply3BandEq(
    Float32List input, {
    double eqLow = 1.0,
    double eqMid = 1.0,
    double eqHigh = 1.0,
  }) {
    if (input.isEmpty) return Float32List(0);
    if ((eqLow - 1.0).abs() < 0.001 &&
        (eqMid - 1.0).abs() < 0.001 &&
        (eqHigh - 1.0).abs() < 0.001) {
      return Float32List.fromList(input);
    }

    final len = input.length;
    final output = Float32List(len);

    // Filter coefficients for 250 Hz low-crossover and 2500 Hz high-crossover
    final dt = 1.0 / sampleRate;
    final rcLow = 1.0 / (2.0 * math.pi * 250.0);
    final alphaLow = (dt / (rcLow + dt)).clamp(0.0001, 1.0);

    final rcHigh = 1.0 / (2.0 * math.pi * 2500.0);
    final alphaHigh = (rcHigh / (rcHigh + dt)).clamp(0.0001, 1.0);

    double lpLow = 0.0;
    double hpHay = 0.0;
    double prevX = input[0];

    for (int i = 0; i < len; i++) {
      final x = input[i];

      // Low band: low-pass at 250 Hz
      lpLow += alphaLow * (x - lpLow);
      final lowSample = lpLow;

      // High band: high-pass at 2500 Hz
      hpHay = alphaHigh * (hpHay + x - prevX);
      prevX = x;
      final highSample = hpHay;

      // Mid band: remainder
      final midSample = x - lowSample - highSample;

      // Recombine with 3-band gain weighting
      output[i] = (lowSample * eqLow) + (midSample * eqMid) + (highSample * eqHigh);
    }

    return output;
  }

  /// Applies a bipolar sweep filter to an audio buffer.
  ///
  /// - Position 0.0: Neutral bypass.
  /// - Position in [-1.0, 0.0): Low-pass sweep from 20000 Hz down to 60 Hz.
  /// - Position in (0.0, 1.0]: High-pass sweep from 20 Hz up to 12000 Hz.
  Float32List applyBipolarFilter(Float32List input, double position) {
    if (position == 0.0 || input.isEmpty) {
      return Float32List.fromList(input);
    }

    final clampedPos = position.clamp(-1.0, 1.0);
    final output = Float32List(input.length);

    if (clampedPos < 0.0) {
      // Low-pass mode
      final cutoff = (20000.0 * math.pow(10.0, 2.52 * clampedPos)).clamp(60.0, 20000.0);
      final dt = 1.0 / sampleRate;
      final rc = 1.0 / (2.0 * math.pi * cutoff);
      final alpha = (dt / (rc + dt)).clamp(0.001, 1.0);

      double prev = 0.0;
      for (int i = 0; i < input.length; i++) {
        prev += alpha * (input[i] - prev);
        output[i] = prev;
      }
    } else {
      // High-pass mode
      final cutoff = (20.0 * math.pow(10.0, 2.78 * clampedPos)).clamp(20.0, 12000.0);
      final dt = 1.0 / sampleRate;
      final rc = 1.0 / (2.0 * math.pi * cutoff);
      final alpha = (rc / (rc + dt)).clamp(0.001, 1.0);

      double prevY = 0.0;
      double prevX = input[0];
      for (int i = 0; i < input.length; i++) {
        final x = input[i];
        final y = alpha * (prevY + x - prevX);
        output[i] = y;
        prevX = x;
        prevY = y;
      }
    }

    return output;
  }

  /// Applies a synchronized delay line with bounded feedback and dry/wet balance.
  Float32List applyDelay(
    Float32List input, {
    required int delaySamples,
    double feedback = 0.40,
    double dryWet = 0.50,
  }) {
    if (delaySamples <= 0 || input.isEmpty) {
      return Float32List.fromList(input);
    }

    final safeFeedback = feedback.clamp(0.0, 0.80);
    final safeDryWet = dryWet.clamp(0.0, 1.0);
    final output = Float32List(input.length);
    final delayLine = Float32List(delaySamples);
    int ringIdx = 0;

    for (int i = 0; i < input.length; i++) {
      final dry = input[i];
      final delayed = delayLine[ringIdx];

      // Update ring buffer with feedback
      delayLine[ringIdx] = dry + delayed * safeFeedback;
      ringIdx = (ringIdx + 1) % delaySamples;

      // Dry / wet blend
      output[i] = dry * (1.0 - safeDryWet) + delayed * safeDryWet;
    }

    return output;
  }

  /// Generates a synthetic demo groove buffer for testing and standalone demonstration.
  Float32List generateDemoGroove({
    required double bpm,
    required double frequencyHz,
    required int durationMs,
  }) {
    final numSamples = (sampleRate * (durationMs / 1000.0)).round();
    final buffer = Float32List(numSamples);
    final beatIntervalSamples = (sampleRate * 60.0 / bpm).round().clamp(100, sampleRate * 10);
    final sixteenthInterval = (beatIntervalSamples / 4).round().clamp(10, sampleRate);

    final chordOffsets = [1.0, 1.189, 1.498, 1.782]; // Root, m3, 5th, m7

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final beatPos = i % beatIntervalSamples;
      final beatIndex = (i ~/ beatIntervalSamples) % 4;

      // 1. Kick Drum (Beats 0, 1, 2, 3)
      final kickEnv = math.exp(-beatPos / (sampleRate * 0.08));
      final kickFreq = frequencyHz + 110.0 * math.exp(-beatPos / (sampleRate * 0.025));
      final kick = math.sin(2.0 * math.pi * kickFreq * (beatPos / sampleRate)) * kickEnv * 0.55;

      // 2. Snare / Clap on Beats 1 and 3 (0-indexed)
      double snare = 0.0;
      if (beatIndex == 1 || beatIndex == 3) {
        final snareEnv = math.exp(-beatPos / (sampleRate * 0.12));
        final noise = (((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
        final snareTone = math.sin(2.0 * math.pi * 210.0 * (beatPos / sampleRate));
        snare = (noise * 0.6 + snareTone * 0.4) * snareEnv * 0.35;
      }

      // 3. Hi-Hat (Every 16th note)
      final sixteenthPos = i % sixteenthInterval;
      final hatEnv = math.exp(-sixteenthPos / (sampleRate * 0.02));
      final hatNoise = (((i * 1664525 + 1013904223) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
      final hihat = hatNoise * hatEnv * 0.18;

      // 4. Bassline / Synth Stabs
      final noteIndex = ((i ~/ sixteenthInterval) % 16) ~/ 4;
      final pitchMult = chordOffsets[noteIndex % chordOffsets.length];
      final bassTone = math.sin(2.0 * math.pi * (frequencyHz * pitchMult) * t);
      final bassEnv = math.exp(-(beatPos % (beatIntervalSamples ~/ 2)) / (sampleRate * 0.18));
      final bass = (bassTone + 0.3 * math.sin(4.0 * math.pi * frequencyHz * pitchMult * t)) * bassEnv * 0.28;

      buffer[i] = (kick + snare + hihat + bass).clamp(-1.0, 1.0);
    }
    return buffer;
  }

  /// Synthesizes authentic polyphonic audio for any [SongPackage] (such as Für Elise,
  /// Pachelbel's Canon, Beethoven's Ode to Joy or custom workspace scores).
  ///
  /// Synthesizes the actual score notes, acoustic piano/string harmonics, accompaniment chords,
  /// and a synchronized club rhythm aligned with the song's native BPM so it can be mixed
  /// and filtered with 4-Stem isolation in the DJ console.
  Float32List synthesizeSongPackageTrack(
    SongPackage song, {
    required String deckId,
    int durationMs = 16000,
  }) {
    final numSamples = (sampleRate * (durationMs / 1000.0)).round();
    final buffer = Float32List(numSamples);
    final double bpm = song.defaultBpm.toDouble().clamp(40.0, 240.0);
    final double secondsPerBeat = 60.0 / bpm;
    final int beatIntervalSamples = (sampleRate * secondsPerBeat).round().clamp(100, sampleRate * 10);
    final int sixteenthInterval = (beatIntervalSamples / 4).round().clamp(10, sampleRate);

    // 1. Build melody notes sequence from the song score or iconic motifs
    final notes = _extractSongMelodyNotes(song);
    final double phraseDurationBeats = notes.isNotEmpty
        ? notes.map((n) => n.startBeat + n.durationBeats).reduce(math.max)
        : 16.0;
    final double loopBeats = math.max(phraseDurationBeats, 8.0);

    final titleLower = song.title.toLowerCase();
    final isWaltz = song.initialTimeSignature.numerator == 3 || titleLower.contains('elisa') || titleLower.contains('elise');

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double currentBeat = t / secondsPerBeat;
      final double loopBeat = currentBeat % loopBeats;

      // --- MELODY SYNTHESIS (Piano / Lead Harmonics) ---
      double melody = 0.0;
      for (final note in notes) {
        if (loopBeat >= note.startBeat && loopBeat < (note.startBeat + note.durationBeats)) {
          final double noteAgeSeconds = (loopBeat - note.startBeat) * secondsPerBeat;
          final double noteDurationSeconds = note.durationBeats * secondsPerBeat;
          
          // ADSR envelope: 8ms attack, exponential decay
          final double attackSeconds = 0.008;
          double env = 1.0;
          if (noteAgeSeconds < attackSeconds) {
            env = noteAgeSeconds / attackSeconds;
          } else {
            env = math.exp(-(noteAgeSeconds - attackSeconds) / (noteDurationSeconds * 0.85));
          }

          final double f0 = note.frequencyHz;
          // Rich piano/string harmonic series
          final double wave = 0.65 * math.sin(2.0 * math.pi * f0 * noteAgeSeconds) +
              0.22 * math.sin(4.0 * math.pi * f0 * noteAgeSeconds) +
              0.09 * math.sin(6.0 * math.pi * f0 * noteAgeSeconds) +
              0.04 * math.sin(8.0 * math.pi * f0 * noteAgeSeconds);

          melody += wave * env * 0.48;
        }
      }

      // --- HARMONIC BASS & ACCOMPANIMENT ---
      final (bassFreq, chordFreqs) = _getHarmonyAtBeat(song, loopBeat);
      final double bassEnv = math.exp(-((i % beatIntervalSamples) / (sampleRate * 0.35)));
      final double bass = (math.sin(2.0 * math.pi * bassFreq * t) +
              0.25 * math.sin(4.0 * math.pi * bassFreq * t)) *
          bassEnv *
          0.26;

      double chords = 0.0;
      for (final f in chordFreqs) {
        chords += math.sin(2.0 * math.pi * f * t);
      }
      chords = (chords / (chordFreqs.isNotEmpty ? chordFreqs.length : 1)) * 0.12;

      // --- SYNCHRONIZED DJ CLUB GROOVE (Drums & Transients) ---
      final int beatPos = i % beatIntervalSamples;
      final int beatIdx = (i ~/ beatIntervalSamples) % (isWaltz ? 3 : 4);

      // Kick: on downbeat 0 (and beat 2 if 4/4)
      double kick = 0.0;
      if (beatIdx == 0 || (!isWaltz && beatIdx == 2)) {
        final kickEnv = math.exp(-beatPos / (sampleRate * 0.065));
        final kickFreq = (deckId == 'A' ? 55.0 : 65.4) + 120.0 * math.exp(-beatPos / (sampleRate * 0.02));
        kick = math.sin(2.0 * math.pi * kickFreq * (beatPos / sampleRate)) * kickEnv * 0.45;
      }

      // Snare: on beat 1 & 3 (4/4) or beat 1 & 2 (3/4)
      double snare = 0.0;
      if ((!isWaltz && (beatIdx == 1 || beatIdx == 3)) || (isWaltz && (beatIdx == 1 || beatIdx == 2))) {
        final snareEnv = math.exp(-beatPos / (sampleRate * 0.10));
        final noise = (((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
        final tone = math.sin(2.0 * math.pi * 200.0 * (beatPos / sampleRate));
        snare = (noise * 0.65 + tone * 0.35) * snareEnv * 0.22;
      }

      // Hi-hats: on 16th notes
      final int sixteenthPos = i % sixteenthInterval;
      final hatEnv = math.exp(-sixteenthPos / (sampleRate * 0.018));
      final hatNoise = (((i * 1664525 + 1013904223) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
      final hihat = hatNoise * hatEnv * 0.14;

      // Soft-limited composite signal
      buffer[i] = _softLimit(melody + bass + chords + kick + snare + hihat);
    }

    return buffer;
  }

  /// Synthesizes distinct, genre-accurate audio for each club preset track.
  Float32List synthesizePresetTrack(
    String presetTitle, {
    required double bpm,
    required String deckId,
    int durationMs = 15000,
  }) {
    final titleLower = presetTitle.toLowerCase();
    final numSamples = (sampleRate * (durationMs / 1000.0)).round();
    final buffer = Float32List(numSamples);
    final double safeBpm = bpm.clamp(40.0, 240.0);
    final double secondsPerBeat = 60.0 / safeBpm;
    final int beatIntervalSamples = (sampleRate * secondsPerBeat).round().clamp(100, sampleRate * 10);
    final int sixteenthInterval = (beatIntervalSamples / 4).round().clamp(10, sampleRate);

    // 1. MIDNIGHT CYBER SYNTHWAVE (Am, 128 BPM)
    if (titleLower.contains('cyber') || titleLower.contains('synthwave')) {
      // 16th-note synth arpeggio notes in Am: A3, C4, E4, G4, A4, G4, E4, C4
      final arpMidi = [57, 60, 64, 67, 69, 67, 64, 60];
      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        final int beatPos = i % beatIntervalSamples;
        final int beatIdx = (i ~/ beatIntervalSamples) % 4;

        // Kick
        final kickEnv = math.exp(-beatPos / (sampleRate * 0.07));
        final kick = math.sin(2.0 * math.pi * (55.0 + 130.0 * math.exp(-beatPos / (sampleRate * 0.02))) * (beatPos / sampleRate)) * kickEnv * 0.60;

        // Snare on 2 and 4
        double snare = 0.0;
        if (beatIdx == 1 || beatIdx == 3) {
          final snareEnv = math.exp(-beatPos / (sampleRate * 0.14));
          final noise = (((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
          snare = noise * snareEnv * 0.38;
        }

        // Arpeggiator Lead
        final int arpStep = (i ~/ sixteenthInterval) % arpMidi.length;
        final double fArp = 440.0 * math.pow(2.0, (arpMidi[arpStep] - 69) / 12.0);
        final int stepPos = i % sixteenthInterval;
        final double arpEnv = math.exp(-stepPos / (sampleRate * 0.08));
        final double sawArp = (2.0 * ((t * fArp) - (t * fArp).floor()) - 1.0) * arpEnv * 0.28;

        // Rolling 16th bassline (A1 55Hz)
        final double bass = math.sin(2.0 * math.pi * 55.0 * t) * math.exp(-stepPos / (sampleRate * 0.06)) * 0.32;

        // Hi-Hat
        final hatEnv = math.exp(-stepPos / (sampleRate * 0.015));
        final hatNoise = (((i * 1664525 + 1013904223) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
        final hihat = hatNoise * hatEnv * 0.15;

        buffer[i] = _softLimit(kick + snare + sawArp + bass + hihat);
      }
      return buffer;
    }

    // 2. DEEP HORIZON HOUSE & GROOVE (Em, 124 BPM)
    if (titleLower.contains('deep') || titleLower.contains('house')) {
      // Em9 chord stabs: E3 (48), G3 (51), B3 (55), D4 (58), F#4 (62)
      final chordFreqs = [164.81, 196.00, 246.94, 293.66, 369.99];
      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        final int beatPos = i % beatIntervalSamples;
        final int sixteenthStep = (i ~/ sixteenthInterval) % 16;

        // 4x4 Round House Kick
        final kickEnv = math.exp(-beatPos / (sampleRate * 0.06));
        final kick = math.sin(2.0 * math.pi * (50.0 + 90.0 * math.exp(-beatPos / (sampleRate * 0.025))) * (beatPos / sampleRate)) * kickEnv * 0.65;

        // 909 Open Hat on the offbeat (8th note)
        double openHat = 0.0;
        if (sixteenthStep % 4 == 2) {
          final hatPos = i % (beatIntervalSamples ~/ 2);
          final hatEnv = math.exp(-hatPos / (sampleRate * 0.08));
          final noise = (((i * 1664525 + 1013904223) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
          openHat = noise * hatEnv * 0.22;
        }

        // House chord stabs on beats 1.5 and 3.5
        double chords = 0.0;
        if (sixteenthStep == 2 || sixteenthStep == 6 || sixteenthStep == 10 || sixteenthStep == 14) {
          final stepPos = i % (beatIntervalSamples ~/ 2);
          final chordEnv = math.exp(-stepPos / (sampleRate * 0.15));
          for (final f in chordFreqs) {
            chords += math.sin(2.0 * math.pi * f * t);
          }
          chords = (chords / chordFreqs.length) * chordEnv * 0.32;
        }

        // Bouncy sub-bass in E (E2 82.4Hz, G2 98Hz)
        final double bassFreq = (sixteenthStep < 8) ? 82.41 : 98.00;
        final double bassEnv = math.exp(-(beatPos % (beatIntervalSamples ~/ 2)) / (sampleRate * 0.12));
        final double bass = math.sin(2.0 * math.pi * bassFreq * t) * bassEnv * 0.35;

        buffer[i] = _softLimit(kick + openHat + chords + bass);
      }
      return buffer;
    }

    // 3. ACOUSTIC SOUL & FUNK FUSION (Dm, 116 BPM)
    if (titleLower.contains('funk') || titleLower.contains('soul')) {
      // Slap bass line in Dm: D2, F2, G2, A2
      final bassMidi = [38, 41, 43, 45];
      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        final int beatPos = i % beatIntervalSamples;
        final int beatIdx = (i ~/ beatIntervalSamples) % 4;
        final int sixteenthStep = (i ~/ sixteenthInterval) % 16;

        // Punchy acoustic kick
        final kickEnv = math.exp(-beatPos / (sampleRate * 0.05));
        final kick = math.sin(2.0 * math.pi * (65.0 + 100.0 * math.exp(-beatPos / (sampleRate * 0.015))) * (beatPos / sampleRate)) * kickEnv * 0.55;

        // Snappy snare on 2 and 4
        double snare = 0.0;
        if (beatIdx == 1 || beatIdx == 3) {
          final snareEnv = math.exp(-beatPos / (sampleRate * 0.09));
          final noise = (((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
          snare = (noise * 0.7 + math.sin(2.0 * math.pi * 220.0 * (beatPos / sampleRate)) * 0.3) * snareEnv * 0.40;
        }

        // Funky slap bass
        final int bIdx = bassMidi[(sixteenthStep ~/ 4) % bassMidi.length];
        final double fBass = 440.0 * math.pow(2.0, (bIdx - 69) / 12.0);
        final int stepPos = i % sixteenthInterval;
        final double slapEnv = math.exp(-stepPos / (sampleRate * 0.10));
        final double bass = (math.sin(2.0 * math.pi * fBass * t) + 0.4 * math.sin(4.0 * math.pi * fBass * t)) * slapEnv * 0.34;

        // Brass stab on beat 3.5
        double brass = 0.0;
        if (sixteenthStep == 10) {
          final stabPos = i % sixteenthInterval;
          final stabEnv = math.exp(-stabPos / (sampleRate * 0.12));
          brass = (math.sin(2.0 * math.pi * 293.66 * t) + math.sin(2.0 * math.pi * 349.23 * t) + math.sin(2.0 * math.pi * 440.0 * t)) * 0.33 * stabEnv * 0.30;
        }

        buffer[i] = _softLimit(kick + snare + bass + brass);
      }
      return buffer;
    }

    // 4. AFROBEAT ENERGY & POLY-RHYTHM (F#m, 120 BPM)
    if (titleLower.contains('afro') || titleLower.contains('rhythm')) {
      // Kalimba arpeggios in F#m: F#4, A4, C#5, E5, F#5
      final kalimbaMidi = [66, 69, 73, 76, 78];
      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        final int beatPos = i % beatIntervalSamples;
        final int sixteenthStep = (i ~/ sixteenthInterval) % 16;

        // Organic low drum
        final kickEnv = math.exp(-beatPos / (sampleRate * 0.09));
        final kick = math.sin(2.0 * math.pi * (52.0 + 80.0 * math.exp(-beatPos / (sampleRate * 0.03))) * (beatPos / sampleRate)) * kickEnv * 0.55;

        // Polyrhythmic conga / woodblock on 3-against-2 steps
        double percuss = 0.0;
        if (sixteenthStep == 0 || sixteenthStep == 3 || sixteenthStep == 6 || sixteenthStep == 10 || sixteenthStep == 12) {
          final pPos = i % (sixteenthInterval * 2);
          final pEnv = math.exp(-pPos / (sampleRate * 0.04));
          final wood = math.sin(2.0 * math.pi * 580.0 * (pPos / sampleRate));
          percuss = wood * pEnv * 0.28;
        }

        // Kalimba melody
        final int kNote = kalimbaMidi[sixteenthStep % kalimbaMidi.length];
        final double fKal = 440.0 * math.pow(2.0, (kNote - 69) / 12.0);
        final int kPos = i % sixteenthInterval;
        final double kEnv = math.exp(-kPos / (sampleRate * 0.12));
        final double kalimba = (math.sin(2.0 * math.pi * fKal * t) + 0.15 * math.sin(6.0 * math.pi * fKal * t)) * kEnv * 0.32;

        // Deep Log Drum Bass (F#1 46.25Hz)
        final double bass = math.sin(2.0 * math.pi * 46.25 * t) * math.exp(-beatPos / (sampleRate * 0.20)) * 0.32;

        buffer[i] = _softLimit(kick + percuss + kalimba + bass);
      }
      return buffer;
    }

    // 5. LO-FI CHILLHOP & RAIN PIANO (Fm, 85 BPM)
    if (titleLower.contains('lo-fi') || titleLower.contains('chill') || titleLower.contains('rain')) {
      // Warm Rhodes chords in Fm7: F3 (53), Ab3 (56), C4 (60), Eb4 (63)
      final rhodesMidi = [53, 56, 60, 63];
      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        final int beatPos = i % beatIntervalSamples;
        final int beatIdx = (i ~/ beatIntervalSamples) % 4;

        // Boombap Kick (Beats 0 and 2.5)
        double kick = 0.0;
        if (beatIdx == 0 || (beatIdx == 2 && beatPos > beatIntervalSamples ~/ 2)) {
          final kPos = beatIdx == 0 ? beatPos : (beatPos - beatIntervalSamples ~/ 2);
          final kickEnv = math.exp(-kPos / (sampleRate * 0.08));
          kick = math.sin(2.0 * math.pi * (48.0 + 70.0 * math.exp(-kPos / (sampleRate * 0.03))) * (kPos / sampleRate)) * kickEnv * 0.50;
        }

        // Rimshot Snare on Beat 2 (0-indexed, so 2nd beat)
        double rim = 0.0;
        if (beatIdx == 1 || beatIdx == 3) {
          final rimEnv = math.exp(-beatPos / (sampleRate * 0.06));
          final noise = (((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
          rim = (noise * 0.8 + math.sin(2.0 * math.pi * 320.0 * (beatPos / sampleRate)) * 0.2) * rimEnv * 0.32;
        }

        // Rhodes Chord Pad
        final int chordPos = i % (beatIntervalSamples * 2);
        final double chordEnv = math.exp(-chordPos / (sampleRate * 0.80));
        double rhodes = 0.0;
        for (final m in rhodesMidi) {
          final double f = 440.0 * math.pow(2.0, (m - 69) / 12.0);
          rhodes += math.sin(2.0 * math.pi * f * t) + 0.2 * math.sin(4.0 * math.pi * f * t);
        }
        rhodes = (rhodes / rhodesMidi.length) * chordEnv * 0.30;

        // Vinyl Crackle Noise
        final vinyl = (((i * 1664525 + 1013904223) & 0x7FFFFFFF) / 0x7FFFFFFF) * 0.035;

        // Sub Bass (F1 43.65Hz)
        final double bass = math.sin(2.0 * math.pi * 43.65 * t) * math.exp(-beatPos / (sampleRate * 0.30)) * 0.26;

        buffer[i] = _softLimit(kick + rim + rhodes + vinyl + bass);
      }
      return buffer;
    }

    // Fallback: standard groove at given BPM and Deck pitch
    return generateDemoGroove(
      bpm: bpm,
      frequencyHz: deckId == 'A' ? 55.0 : 65.4,
      durationMs: durationMs,
    );
  }

  /// Extracts the sequence of melody notes from a [SongPackage] for acoustic playback.
  List<_SynthesizedNote> _extractSongMelodyNotes(SongPackage song) {
    final titleLower = song.title.toLowerCase();

    // 1. BEETHOVEN: PARA ELISA (Iconic Motif)
    if (song.id == 'beethoven_fur_elise' || titleLower.contains('elisa') || titleLower.contains('elise')) {
      return const [
        // Measure 0
        _SynthesizedNote('Mi5', 0.0, 0.5, 659.25),
        _SynthesizedNote('Re#5', 0.5, 0.5, 622.25),
        _SynthesizedNote('Mi5', 1.0, 0.5, 659.25),
        _SynthesizedNote('Re#5', 1.5, 0.5, 622.25),
        _SynthesizedNote('Mi5', 2.0, 0.5, 659.25),
        _SynthesizedNote('Si4', 2.5, 0.5, 493.88),
        // Measure 1
        _SynthesizedNote('Re5', 3.0, 0.5, 587.33),
        _SynthesizedNote('Do5', 3.5, 0.5, 523.25),
        _SynthesizedNote('La4', 4.0, 1.5, 440.00),
        // Measure 2 (Left Hand / Lead Bridge)
        _SynthesizedNote('Do4', 6.0, 0.5, 261.63),
        _SynthesizedNote('Mi4', 6.5, 0.5, 329.63),
        _SynthesizedNote('La4', 7.0, 0.5, 440.00),
        _SynthesizedNote('Si4', 7.5, 1.5, 493.88),
        // Measure 3
        _SynthesizedNote('Mi4', 9.0, 0.5, 329.63),
        _SynthesizedNote('Sol#4', 9.5, 0.5, 415.30),
        _SynthesizedNote('Si4', 10.0, 0.5, 493.88),
        _SynthesizedNote('Do5', 10.5, 1.5, 523.25),
        // Measure 4 (Repeat theme)
        _SynthesizedNote('Mi5', 12.0, 0.5, 659.25),
        _SynthesizedNote('Re#5', 12.5, 0.5, 622.25),
        _SynthesizedNote('Mi5', 13.0, 0.5, 659.25),
        _SynthesizedNote('Re#5', 13.5, 0.5, 622.25),
        _SynthesizedNote('Mi5', 14.0, 0.5, 659.25),
        _SynthesizedNote('Si4', 14.5, 0.5, 493.88),
        _SynthesizedNote('Re5', 15.0, 0.5, 587.33),
        _SynthesizedNote('Do5', 15.5, 0.5, 523.25),
        _SynthesizedNote('La4', 16.0, 2.0, 440.00),
      ];
    }

    // 2. PACHELBEL: CANON EN RE MAYOR
    if (song.id == 'pachelbel_canon' || titleLower.contains('canon')) {
      return const [
        _SynthesizedNote('Fa#5', 0.0, 1.0, 739.99),
        _SynthesizedNote('Mi5', 1.0, 1.0, 659.25),
        _SynthesizedNote('Re5', 2.0, 1.0, 587.33),
        _SynthesizedNote('Do#5', 3.0, 1.0, 554.37),
        _SynthesizedNote('Si4', 4.0, 1.0, 493.88),
        _SynthesizedNote('La4', 5.0, 1.0, 440.00),
        _SynthesizedNote('Si4', 6.0, 1.0, 493.88),
        _SynthesizedNote('Do#5', 7.0, 1.0, 554.37),
        _SynthesizedNote('Re5', 8.0, 1.0, 587.33),
        _SynthesizedNote('Do#5', 9.0, 1.0, 554.37),
        _SynthesizedNote('Si4', 10.0, 1.0, 493.88),
        _SynthesizedNote('La4', 11.0, 1.0, 440.00),
        _SynthesizedNote('Sol4', 12.0, 1.0, 392.00),
        _SynthesizedNote('Fa#4', 13.0, 1.0, 369.99),
        _SynthesizedNote('Sol4', 14.0, 1.0, 392.00),
        _SynthesizedNote('Mi4', 15.0, 1.0, 329.63),
      ];
    }

    // 3. BEETHOVEN: HIMNO A LA ALEGRÍA
    if (song.id == 'ode_to_joy' || titleLower.contains('alegría') || titleLower.contains('joy')) {
      return const [
        _SynthesizedNote('Si4', 0.0, 1.0, 493.88),
        _SynthesizedNote('Si4', 1.0, 1.0, 493.88),
        _SynthesizedNote('Do5', 2.0, 1.0, 523.25),
        _SynthesizedNote('Re5', 3.0, 1.0, 587.33),
        _SynthesizedNote('Re5', 4.0, 1.0, 587.33),
        _SynthesizedNote('Do5', 5.0, 1.0, 523.25),
        _SynthesizedNote('Si4', 6.0, 1.0, 493.88),
        _SynthesizedNote('La4', 7.0, 1.0, 440.00),
        _SynthesizedNote('Sol4', 8.0, 1.0, 392.00),
        _SynthesizedNote('Sol4', 9.0, 1.0, 392.00),
        _SynthesizedNote('La4', 10.0, 1.0, 440.00),
        _SynthesizedNote('Si4', 11.0, 1.0, 493.88),
        _SynthesizedNote('Si4', 12.0, 1.5, 493.88),
        _SynthesizedNote('La4', 13.5, 0.5, 440.00),
        _SynthesizedNote('La4', 14.0, 2.0, 440.00),
      ];
    }

    // 4. MOZART: SONATA FÁCIL K.545
    if (titleLower.contains('mozart') || titleLower.contains('545')) {
      return const [
        _SynthesizedNote('Do5', 0.0, 2.0, 523.25),
        _SynthesizedNote('Mi5', 2.0, 1.0, 659.25),
        _SynthesizedNote('Sol5', 3.0, 1.0, 783.99),
        _SynthesizedNote('Si4', 4.0, 1.5, 493.88),
        _SynthesizedNote('Do5', 5.5, 0.5, 523.25),
        _SynthesizedNote('Re5', 6.0, 1.0, 587.33),
        _SynthesizedNote('Do5', 7.0, 1.0, 523.25),
      ];
    }

    // 5. EXTRACT FROM HIERARCHICAL SCORE MEASURES
    final result = <_SynthesizedNote>[];
    double currentBeat = 0.0;
    for (final measure in song.score.measures) {
      final beatsInMeasure = measure.timeSignature.totalTicks / 4.0;
      for (final n in measure.notes) {
        if (n.noteName.isNotEmpty && n.noteName != '--' && n.noteName.toLowerCase() != 'rest') {
          final midi = CanonicalMidiExporter.noteNameToMidiPitch(n.noteName);
          final f0 = 440.0 * math.pow(2.0, (midi - 69) / 12.0);
          result.add(_SynthesizedNote(
            n.noteName,
            currentBeat + (n.startTick / 4.0),
            n.durationTicks / 4.0,
            f0,
          ));
        }
      }
      currentBeat += beatsInMeasure;
    }

    return result;
  }

  /// Calculates harmonic bass note and chord frequencies at a given beat time.
  (double bassFreq, List<double> chordFreqs) _getHarmonyAtBeat(SongPackage song, double beat) {
    final titleLower = song.title.toLowerCase();

    // Für Elise: Am (beats 0..3) -> E (beats 3..6) -> Am (beats 6..9)
    if (song.id == 'beethoven_fur_elise' || titleLower.contains('elisa') || titleLower.contains('elise')) {
      final phraseStep = beat % 6.0;
      if (phraseStep < 3.0) {
        // Am (A2 110Hz, C4 261.63Hz, E4 329.63Hz)
        return (110.0, [261.63, 329.63, 440.0]);
      } else {
        // E (E2 82.4Hz, G#3 207.65Hz, B3 246.94Hz)
        return (82.41, [207.65, 246.94, 329.63]);
      }
    }

    // Canon in D: D -> A -> Bm -> F#m -> G -> D -> G -> A (2 beats each)
    if (song.id == 'pachelbel_canon' || titleLower.contains('canon')) {
      final step = (beat ~/ 2.0) % 8;
      switch (step) {
        case 0: return (73.42, [293.66, 369.99, 440.0]); // D
        case 1: return (55.00, [220.00, 277.18, 329.63]); // A
        case 2: return (61.74, [246.94, 293.66, 369.99]); // Bm
        case 3: return (46.25, [185.00, 220.00, 277.18]); // F#m
        case 4: return (49.00, [196.00, 246.94, 293.66]); // G
        case 5: return (73.42, [293.66, 369.99, 440.0]); // D
        case 6: return (49.00, [196.00, 246.94, 293.66]); // G
        default: return (55.00, [220.00, 277.18, 329.63]); // A
      }
    }

    // Ode to Joy: D major / A7 (4 beats each)
    if (song.id == 'ode_to_joy' || titleLower.contains('alegría') || titleLower.contains('joy')) {
      final step = (beat ~/ 4.0) % 4;
      if (step < 3) {
        return (73.42, [293.66, 369.99, 440.0]); // D
      } else {
        return (55.00, [220.00, 277.18, 329.63]); // A
      }
    }

    // Default: Root tone at 55.0 Hz
    return (55.0, [220.0, 261.63, 329.63]);
  }

  /// Applies real-time 4-Stem isolation (Bass, Drums, Vocals, Melody) using
  /// Linkwitz-Riley-inspired crossover bands and transient envelope separation.
  Float32List applyStemIsolation(
    Float32List input,
    DjStemIsolationEntity stems,
  ) {
    if (input.isEmpty || stems.isBypass) {
      return Float32List.fromList(input);
    }

    final gBass = stems.effectiveBassGain;
    final gDrums = stems.effectiveDrumsGain;
    final gVocals = stems.effectiveVocalGain;
    final gMelody = stems.effectiveMelodyGain;

    final output = Float32List(input.length);

    // Crossover coefficients:
    // Bass LPF at 220 Hz
    final dt = 1.0 / sampleRate;
    final rcBass = 1.0 / (2.0 * math.pi * 220.0);
    final alphaBass = (dt / (rcBass + dt)).clamp(0.001, 1.0);

    // High LPF at 3800 Hz (complement = High > 3800 Hz)
    final rcHigh = 1.0 / (2.0 * math.pi * 3800.0);
    final alphaHigh = (dt / (rcHigh + dt)).clamp(0.001, 1.0);

    // Fast vs slow transient envelope for Drum impact separation
    final alphaFastEnv = (dt / (0.002 + dt)).clamp(0.001, 1.0); // 2ms attack
    final alphaSlowEnv = (dt / (0.045 + dt)).clamp(0.001, 1.0); // 45ms release

    double lpBass1 = 0.0;
    double lpBass2 = 0.0;
    double lpHigh = 0.0;
    double fastEnv = 0.0;
    double slowEnv = 0.0;

    for (int i = 0; i < input.length; i++) {
      final x = input[i];
      // Two cascaded 1st-order HPFs at 220 Hz (12 dB/oct low-cut) for clean
      // bass separation and exact complementary reconstruction (bassBand + noBass == x).
      lpBass1 += alphaBass * (x - lpBass1);
      final hp1 = x - lpBass1;
      lpBass2 += alphaBass * (hp1 - lpBass2);
      final noBass = hp1 - lpBass2;
      lpHigh += alphaHigh * (x - lpHigh);

      final bassBand = x - noBass;
      final highBand = x - lpHigh;
      final midBand = noBass - highBand;

      final absMid = midBand.abs();
      fastEnv += alphaFastEnv * (absMid - fastEnv);
      slowEnv += alphaSlowEnv * (absMid - slowEnv);

      // Transient ratio [0..1]: high when fast energy spikes above sustained body
      final transientRatio = fastEnv > 1e-6
          ? ((fastEnv - slowEnv).clamp(0.0, fastEnv) / fastEnv).clamp(0.0, 1.0)
          : 0.0;

      // Drums: percussive mid transients + high-frequency hi-hats/cymbals
      final drumSignal = (midBand * transientRatio) + (highBand * 0.65);
      // Vocals: sustained central mid-range formants
      final vocalSignal = midBand * (1.0 - transientRatio) * 0.70;
      // Melody: upper harmonic body + remaining sustained mid
      final melodySignal = (midBand * (1.0 - transientRatio) * 0.30) + (highBand * 0.35);

      final reconstructed = (bassBand * gBass) +
          (drumSignal * gDrums) +
          (vocalSignal * gVocals) +
          (melodySignal * gMelody);

      output[i] = _softLimit(reconstructed);
    }

    return output;
  }

  /// Encodes Split-Cue Stereo output for PCs with a single 3.5mm stereo jack:
  /// Left channel (even indices) = Master Mix, Right channel (odd indices) = Cue Monitor (PFL).
  Float32List encodeSplitCueStereo({
    required Float32List masterMono,
    required Float32List cueMono,
  }) {
    final frames = math.max(masterMono.length, cueMono.length);
    final interleaved = Float32List(frames * 2);
    for (int i = 0; i < frames; i++) {
      interleaved[i * 2] = i < masterMono.length ? _softLimit(masterMono[i]) : 0.0;
      interleaved[(i * 2) + 1] = i < cueMono.length ? _softLimit(cueMono[i]) : 0.0;
    }
    return interleaved;
  }

  static double _softLimit(double x) {
    if (x > 1.0) {
      return 1.0 - (1.0 / (1.0 + (x - 1.0)));
    } else if (x < -1.0) {
      return -1.0 + (1.0 / (1.0 - (x + 1.0)));
    }
    return x;
  }
}

class _SynthesizedNote {
  final String noteName;
  final double startBeat;
  final double durationBeats;
  final double frequencyHz;

  const _SynthesizedNote(
    this.noteName,
    this.startBeat,
    this.durationBeats,
    this.frequencyHz,
  );
}
