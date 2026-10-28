import 'dart:math' as math;
import 'dart:typed_data';
import '../../sheet_music/domain/score_tree.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../practice_recorder/domain/practice_recording_entity.dart';
import '../../universal_importer/domain/canonical_midi_exporter.dart';
import 'pcm_wav_synthesizer.dart';
import 'stem_export_entity.dart';

/// Motor matemático en Pure Dart para la síntesis de pistas de audio (stems),
/// mezcla multicanal con limitación analógica suave y exportación MIDI.
class StemAudioSynthesizer {
  const StemAudioSynthesizer();

  /// Frecuencia de muestreo estándar para masterización digital (44100 Hz).
  static const int defaultSampleRate = 44100;

  /// Ticks de Tunner por negra (4 ticks = 1 beat).
  static const int ticksPerBeat = 4;

  /// Calcula la duración total en segundos de una partitura jerárquica a un tempo dado.
  double calculateScoreDurationSeconds({
    required HierarchicalScore score,
    required int bpm,
  }) {
    if (score.measures.isEmpty) return 2.0;
    final safeBpm = bpm.clamp(20, 300);
    final secondsPerTick = (60.0 / safeBpm) / ticksPerBeat;
    int totalTicks = 0;
    for (final m in score.measures) {
      totalTicks += m.timeSignature.totalTicks;
    }
    return math.max(1.0, totalTicks * secondsPerTick);
  }

  /// Convierte un número de nota MIDI a su frecuencia fundamental $f_0$ en Hz (con A4 = 440 Hz).
  static double midiPitchToFrequency(int midiPitch) {
    return 440.0 * math.pow(2.0, (midiPitch - 69) / 12.0);
  }

  /// Sintetiza el stem de la melodía de la partitura como arreglo PCM de 16 bits.
  Float64List synthesizeMelodySamples({
    required HierarchicalScore score,
    required int bpm,
    int sampleRate = defaultSampleRate,
    required int totalSamples,
  }) {
    final buffer = Float64List(totalSamples);
    if (score.measures.isEmpty) return buffer;

    final safeBpm = bpm.clamp(20, 300);
    final double secondsPerTick = (60.0 / safeBpm) / ticksPerBeat;

    int currentMeasureStartTick = 0;

    for (final measure in score.measures) {
      for (final note in measure.notes) {
        final isRest = note.noteName == "--" ||
            note.noteName.toLowerCase() == "rest" ||
            note.noteName.isEmpty;

        if (!isRest) {
          final midiPitch = CanonicalMidiExporter.noteNameToMidiPitch(note.noteName);
          final frequency = midiPitchToFrequency(midiPitch);

          final noteStartSeconds = (currentMeasureStartTick + note.startTick) * secondsPerTick;
          final noteDurationSeconds = note.durationTicks * secondsPerTick;

          final startSample = (noteStartSeconds * sampleRate).round();
          final noteTotalSamples = (noteDurationSeconds * sampleRate).round();
          final endSample = math.min(totalSamples, startSample + noteTotalSamples);

          if (startSample < totalSamples && endSample > startSample) {
            final activeLength = endSample - startSample;
            // Generar envolvente ADSR suave para evitar clics
            final attackSamples = math.min((sampleRate * 0.015).round(), (activeLength * 0.15).round());
            final releaseSamples = math.min((sampleRate * 0.025).round(), (activeLength * 0.20).round());
            final releaseStartIndex = math.max(0, activeLength - releaseSamples);

            for (int s = 0; s < activeLength; s++) {
              final int sampleIndex = startSample + s;
              if (sampleIndex >= totalSamples) break;

              final double t = s / sampleRate;

              double envelope = 0.85;
              if (s < attackSamples && attackSamples > 0) {
                envelope = s / attackSamples;
              } else if (s >= releaseStartIndex && releaseSamples > 0) {
                envelope = 0.85 * (1.0 - (s - releaseStartIndex) / releaseSamples);
              }

              // Síntesis aditiva (armónicos ricos para timbre de viento/cuerda)
              final double signal = 0.75 * math.sin(2.0 * math.pi * frequency * t) +
                  0.18 * math.sin(4.0 * math.pi * frequency * t) +
                  0.07 * math.sin(6.0 * math.pi * frequency * t);

              buffer[sampleIndex] += signal * envelope * 24000.0;
            }
          }
        }
      }
      currentMeasureStartTick += measure.timeSignature.totalTicks;
    }

    return buffer;
  }

  /// Sintetiza el stem de clics métricos del metrónomo como arreglo PCM.
  Float64List synthesizeMetronomeSamples({
    required HierarchicalScore score,
    required int bpm,
    int sampleRate = defaultSampleRate,
    required int totalSamples,
  }) {
    final buffer = Float64List(totalSamples);
    if (score.measures.isEmpty) return buffer;

    final safeBpm = bpm.clamp(20, 300);
    final double secondsPerBeat = 60.0 / safeBpm;
    final int samplesPerBeat = (secondsPerBeat * sampleRate).round();

    int currentMeasureStartTick = 0;

    for (final measure in score.measures) {
      final beatsInMeasure = measure.timeSignature.numerator;
      final measureStartSeconds = (currentMeasureStartTick * (60.0 / safeBpm)) / ticksPerBeat;
      final measureStartSample = (measureStartSeconds * sampleRate).round();

      for (int b = 0; b < beatsInMeasure; b++) {
        final beatStartSample = measureStartSample + (b * samplesPerBeat);
        if (beatStartSample >= totalSamples) break;

        final isDownbeat = (b == 0);
        final clickBytes = PcmWavSynthesizer.generateMetronomeClickWav(
          isDownbeat: isDownbeat,
          sampleRate: sampleRate,
        );

        // Extraer muestras PCM de los datos del WAV (después de la cabecera de 44 bytes)
        final pcmData = ByteData.sublistView(clickBytes, 44);
        final clickSampleCount = pcmData.lengthInBytes ~/ 2;

        for (int c = 0; c < clickSampleCount; c++) {
          final targetIndex = beatStartSample + c;
          if (targetIndex >= totalSamples) break;
          final sampleVal = pcmData.getInt16(c * 2, Endian.little);
          buffer[targetIndex] += sampleVal.toDouble();
        }
      }

      currentMeasureStartTick += measure.timeSignature.totalTicks;
    }

    return buffer;
  }

  /// Sintetiza el stem de acompañamiento armónico (pads/acordes de fondo).
  Float64List synthesizeAccompanimentSamples({
    required HierarchicalScore score,
    required int bpm,
    int sampleRate = defaultSampleRate,
    required int totalSamples,
  }) {
    final buffer = Float64List(totalSamples);
    if (score.measures.isEmpty) return buffer;

    final safeBpm = bpm.clamp(20, 300);
    final double secondsPerTick = (60.0 / safeBpm) / ticksPerBeat;
    int currentMeasureStartTick = 0;

    for (int mIdx = 0; mIdx < score.measures.length; mIdx++) {
      final measure = score.measures[mIdx];
      final measureDuration = measure.timeSignature.totalTicks * secondsPerTick;
      final startSample = (currentMeasureStartTick * secondsPerTick * sampleRate).round();
      final measureSamples = (measureDuration * sampleRate).round();
      final endSample = math.min(totalSamples, startSample + measureSamples);

      // Determinar nota tónica aproximada para el acorde
      int rootMidi = 48; // C3
      if (measure.notes.isNotEmpty) {
        final firstNote = measure.notes.firstWhere(
          (n) => n.noteName != "--" && n.noteName.isNotEmpty,
          orElse: () => measure.notes.first,
        );
        if (firstNote.noteName != "--" && firstNote.noteName.isNotEmpty) {
          rootMidi = CanonicalMidiExporter.noteNameToMidiPitch(firstNote.noteName) - 12;
          if (rootMidi < 36) rootMidi += 12;
        }
      }

      final fRoot = midiPitchToFrequency(rootMidi);
      final fThird = midiPitchToFrequency(rootMidi + 4); // Tercera mayor
      final fFifth = midiPitchToFrequency(rootMidi + 7); // Quinta justa

      final attackSamples = (sampleRate * 0.050).round();
      final releaseSamples = (sampleRate * 0.080).round();
      final activeLength = endSample - startSample;
      final releaseStartIndex = math.max(0, activeLength - releaseSamples);

      for (int s = 0; s < activeLength; s++) {
        final targetIndex = startSample + s;
        if (targetIndex >= totalSamples) break;

        final double t = s / sampleRate;

        double envelope = 0.60;
        if (s < attackSamples && attackSamples > 0) {
          envelope = (s / attackSamples) * 0.60;
        } else if (s >= releaseStartIndex && releaseSamples > 0) {
          envelope = 0.60 * (1.0 - (s - releaseStartIndex) / releaseSamples);
        }

        final double signal = 0.50 * math.sin(2.0 * math.pi * fRoot * t) +
            0.30 * math.sin(2.0 * math.pi * fThird * t) +
            0.20 * math.sin(2.0 * math.pi * fFifth * t);

        buffer[targetIndex] += signal * envelope * 16000.0;
      }

      currentMeasureStartTick += measure.timeSignature.totalTicks;
    }

    return buffer;
  }

  /// Función de activación tangente hiperbólica analógica para limitar saturación sin clipping.
  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final double e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }

  /// Convierte un búfer de muestras en punto flotante a un archivo canónico WAV PCM de 16 bits.
  Uint8List floatBufferToWav({
    required Float64List buffer,
    int sampleRate = defaultSampleRate,
  }) {
    final pcmBytes = ByteData(buffer.length * 2);

    for (int i = 0; i < buffer.length; i++) {
      // Limitador analógico suave con tangente hiperbólica para prevenir clipping digital
      final double normalized = buffer[i] / 32768.0;
      final double saturated = _tanh(normalized);
      final int sampleInt16 = (saturated * 32767.0).round().clamp(-32768, 32767);
      pcmBytes.setInt16(i * 2, sampleInt16, Endian.little);
    }

    final header = PcmWavSynthesizer.buildWavHeader(
      pcmDataBytes: pcmBytes.lengthInBytes,
      sampleRate: sampleRate,
      channels: 1,
      bitsPerSample: 16,
    );

    final builder = BytesBuilder(copy: false);
    builder.add(header);
    builder.add(pcmBytes.buffer.asUint8List());
    return builder.toBytes();
  }

  /// Ejecuta la síntesis completa de stems individuales, master mixdown y archivo MIDI.
  ExportBundleResult exportStemsAndMidi({
    required HierarchicalScore score,
    required MixerConsoleEntity mixerConsole,
    required int bpm,
    required String trackTitle,
    StemExportConfig config = const StemExportConfig(),
    PracticeRecordingEntity? recordedTake,
    Uint8List? recordedPcmBytes,
  }) {
    final files = <ExportedStemFile>[];
    final sampleRate = config.sampleRate;

    final durationSeconds = calculateScoreDurationSeconds(score: score, bpm: bpm);
    final totalSamples = (durationSeconds * sampleRate).round();
    final duration = Duration(milliseconds: (durationSeconds * 1000).round());

    // 1. Sintetizar las capas individuales de audio en Float64
    final melodySamples = synthesizeMelodySamples(
      score: score,
      bpm: bpm,
      sampleRate: sampleRate,
      totalSamples: totalSamples,
    );

    final metronomeSamples = synthesizeMetronomeSamples(
      score: score,
      bpm: bpm,
      sampleRate: sampleRate,
      totalSamples: totalSamples,
    );

    final accompanimentSamples = synthesizeAccompanimentSamples(
      score: score,
      bpm: bpm,
      sampleRate: sampleRate,
      totalSamples: totalSamples,
    );

    // 2. Obtener ganancias efectivas del mezclador virtual
    final melodyGain = mixerConsole.getEffectiveGain("voice");
    final metroGain = mixerConsole.getEffectiveGain("metronome");
    final accompGain = mixerConsole.getEffectiveGain("piano");

    // 3. Generar Master Mixdown si está solicitado
    if (config.includeMasterMixdown) {
      final masterBuffer = Float64List(totalSamples);

      for (int i = 0; i < totalSamples; i++) {
        double mix = 0.0;
        if (config.includeMelodyTrack) {
          mix += melodySamples[i] * melodyGain;
        }
        if (config.includeAccompanimentTrack) {
          mix += accompanimentSamples[i] * accompGain;
        }
        if (config.includeMetronomeTrack) {
          mix += metronomeSamples[i] * metroGain;
        }
        masterBuffer[i] = mix;
      }

      final masterWavBytes = floatBufferToWav(buffer: masterBuffer, sampleRate: sampleRate);
      files.add(ExportedStemFile(
        fileName: "${trackTitle.toLowerCase().replaceAll(' ', '_')}_master_mixdown.wav",
        bytes: masterWavBytes,
        mimeType: "audio/wav",
        duration: duration,
        description: "Master Mixdown WAV 16-bit 44.1 kHz con balance del mezclador",
      ));
    }

    // 4. Generar Stems individuales si está solicitado
    if (config.includeIndividualStems) {
      if (config.includeMelodyTrack) {
        final melodyWavBytes = floatBufferToWav(buffer: melodySamples, sampleRate: sampleRate);
        files.add(ExportedStemFile(
          fileName: "stem_01_melody.wav",
          bytes: melodyWavBytes,
          mimeType: "audio/wav",
          duration: duration,
          description: "Pista individual de Melodía / Voz solista (WAV)",
        ));
      }

      if (config.includeAccompanimentTrack) {
        final accompWavBytes = floatBufferToWav(buffer: accompanimentSamples, sampleRate: sampleRate);
        files.add(ExportedStemFile(
          fileName: "stem_02_accompaniment.wav",
          bytes: accompWavBytes,
          mimeType: "audio/wav",
          duration: duration,
          description: "Pista individual de Acompañamiento Armónico (WAV)",
        ));
      }

      if (config.includeMetronomeTrack) {
        final metroWavBytes = floatBufferToWav(buffer: metronomeSamples, sampleRate: sampleRate);
        files.add(ExportedStemFile(
          fileName: "stem_03_metronome_click.wav",
          bytes: metroWavBytes,
          mimeType: "audio/wav",
          duration: duration,
          description: "Pista individual de Metrónomo Percusivo Clic (WAV)",
        ));
      }

      if (config.includeRecordedTake && recordedPcmBytes != null && recordedPcmBytes.isNotEmpty) {
        final takeHeader = PcmWavSynthesizer.buildWavHeader(
          pcmDataBytes: recordedPcmBytes.lengthInBytes,
          sampleRate: sampleRate,
          channels: 1,
          bitsPerSample: 16,
        );
        final takeBuilder = BytesBuilder(copy: false);
        takeBuilder.add(takeHeader);
        takeBuilder.add(recordedPcmBytes);
        final takeWav = takeBuilder.toBytes();

        files.add(ExportedStemFile(
          fileName: "stem_04_user_recorded_take.wav",
          bytes: takeWav,
          mimeType: "audio/wav",
          duration: recordedTake?.duration ?? duration,
          description: "Toma acústica grabada por el micrófono durante el ensayo",
        ));
      }
    }

    // 5. Generar archivo Standard MIDI File si está solicitado
    if (config.includeMidiFile) {
      const midiExporter = CanonicalMidiExporter();
      final midiBytes = midiExporter.exportScore(
        score: score,
        bpm: bpm,
        trackName: trackTitle,
      );

      files.add(ExportedStemFile(
        fileName: "${trackTitle.toLowerCase().replaceAll(' ', '_')}.mid",
        bytes: midiBytes,
        mimeType: "audio/midi",
        duration: duration,
        description: "Secuencia Standard MIDI File (SMF Formato 0 con 480 PPQN)",
      ));
    }

    return ExportBundleResult(
      files: files,
      createdAt: DateTime.now(),
    );
  }
}
