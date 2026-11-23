import 'dart:math' as math;
import 'dart:typed_data';
import '../../sheet_music/domain/score_tree.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../practice_recorder/domain/practice_recording_entity.dart';
import '../../universal_importer/domain/canonical_midi_exporter.dart';
import '../../tuner/domain/note_entity.dart';
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

  /// Convierte un número de nota MIDI a su frecuencia fundamental $f_0$ en Hz (con referencia A4 configurable, por defecto 440 Hz).
  static double midiPitchToFrequency(
    int midiPitch, {
    double referencePitchHz = 440.0,
  }) {
    final safeRef = referencePitchHz > 0.0 ? referencePitchHz : 440.0;
    return safeRef * math.pow(2.0, (midiPitch - 69) / 12.0);
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

  /// Sintetiza un stem de audio adaptado al rol tímbrico e instrumentación de la pista [track].
  Float64List synthesizeTrackSamples({
    required AudioTrack track,
    required HierarchicalScore score,
    required int bpm,
    int sampleRate = defaultSampleRate,
    required int totalSamples,
  }) {
    final buffer = Float64List(totalSamples);
    if (score.measures.isEmpty) return buffer;

    // Multiplicador armónico adaptativo según el icono o id del instrumento
    double freqMultiplier = 1.0;
    final icon = track.instrumentIcon.toLowerCase();
    final id = track.id.toLowerCase();

    if (icon == 'bass' || id.contains('bass') || id.contains('bajo')) {
      freqMultiplier = 0.5; // Octava grave
    } else if (icon == 'flute' || id.contains('flute') || id.contains('flauta')) {
      freqMultiplier = 2.0; // Octava aguda
    } else if (icon == 'guitar' || id.contains('guitar') || id.contains('guitarra')) {
      freqMultiplier = 1.5; // Quinta justa armonica (neutral entre mayor y menor)
    } else {
      freqMultiplier = 1.0; // Registro unisono seguro sin disonancias modales
    }

    final safeBpm = bpm.clamp(20, 300);
    final double secondsPerTick = (60.0 / safeBpm) / ticksPerBeat;
    int currentMeasureStartTick = 0;

    for (int mIdx = 0; mIdx < score.measures.length; mIdx++) {
      final measure = score.measures[mIdx];
      for (final note in measure.notes) {
        if (note.isRest || note.noteName.isEmpty || note.noteName == "--") continue;

        final double baseFreq = NoteEntity.frequencyForNote(note.noteName);
        if (baseFreq <= 20.0) continue;
        final double noteFreq = (baseFreq * freqMultiplier).clamp(30.0, 4200.0);

        final startTickGlobal = currentMeasureStartTick + note.startTick;
        final startSample = (startTickGlobal * secondsPerTick * sampleRate).round();
        final noteSamples = (note.durationTicks * secondsPerTick * sampleRate).round();
        final endSample = math.min(totalSamples, startSample + noteSamples);
        final activeLength = endSample - startSample;

        final attackSamples = (sampleRate * 0.015).round();
        final releaseSamples = (sampleRate * 0.030).round();
        final releaseStartIndex = math.max(0, activeLength - releaseSamples);

        for (int s = 0; s < activeLength; s++) {
          final targetIndex = startSample + s;
          if (targetIndex >= totalSamples) break;

          final double t = s / sampleRate;

          double envelope = 0.85;
          if (s < attackSamples && attackSamples > 0) {
            envelope = (s / attackSamples) * 0.85;
          } else if (s >= releaseStartIndex && releaseSamples > 0) {
            envelope = 0.85 * (1.0 - (s - releaseStartIndex) / releaseSamples);
          }

          final double sampleValue = (math.sin(2.0 * math.pi * noteFreq * t) +
                  0.35 * math.sin(4.0 * math.pi * noteFreq * t)) *
              envelope *
              22000.0;

          buffer[targetIndex] += sampleValue;
        }
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

  /// Convierte dos búferes de muestras (Izquierda y Derecha) en punto flotante a un archivo canónico WAV PCM de 16 bits estéreo (2 canales).
  Uint8List floatStereoBufferToWav({
    required Float64List leftBuffer,
    required Float64List rightBuffer,
    int sampleRate = defaultSampleRate,
  }) {
    final length = math.min(leftBuffer.length, rightBuffer.length);
    // 2 canales * 2 bytes por muestra = 4 bytes por cuadro
    final pcmBytes = ByteData(length * 4);

    for (int i = 0; i < length; i++) {
      final double normalizedL = leftBuffer[i] / 32768.0;
      final double saturatedL = _tanh(normalizedL);
      final int sampleL = (saturatedL * 32767.0).round().clamp(-32768, 32767);

      final double normalizedR = rightBuffer[i] / 32768.0;
      final double saturatedR = _tanh(normalizedR);
      final int sampleR = (saturatedR * 32767.0).round().clamp(-32768, 32767);

      pcmBytes.setInt16((i * 2) * 2, sampleL, Endian.little);
      pcmBytes.setInt16((i * 2 + 1) * 2, sampleR, Endian.little);
    }

    final header = PcmWavSynthesizer.buildWavHeader(
      pcmDataBytes: pcmBytes.lengthInBytes,
      sampleRate: sampleRate,
      channels: 2,
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

    // 1. Sintetizar las capas individuales de audio en Float64 para todos los stems de la consola
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

    // Mapeo dinámico de todas las pistas presentes en la consola del mezclador
    final Map<String, Float64List> synthesizedStems = {};

    for (int i = 0; i < mixerConsole.stems.length; i++) {
      final track = mixerConsole.stems[i];
      if (i == 0) {
        synthesizedStems[track.id] = melodySamples;
      } else if (i == 1) {
        synthesizedStems[track.id] = accompanimentSamples;
      } else {
        synthesizedStems[track.id] = synthesizeTrackSamples(
          track: track,
          score: score,
          bpm: bpm,
          sampleRate: sampleRate,
          totalSamples: totalSamples,
        );
      }
    }

    // 2. Generar Master Mixdown Estéreo (2 canales) si está solicitado
    if (config.includeMasterMixdown) {
      final masterLeft = Float64List(totalSamples);
      final masterRight = Float64List(totalSamples);

      for (int i = 0; i < mixerConsole.stems.length; i++) {
        final track = mixerConsole.stems[i];
        final stemSamples = synthesizedStems[track.id];
        if (stemSamples == null) continue;

        // Distribución estereofónica (Panning)
        double panL = 1.0;
        double panR = 1.0;
        if (i == 1) {
          panL = 1.0;
          panR = 0.8;
        } else if (i == 2) {
          panL = 0.75;
          panR = 1.0;
        } else if (i > 2) {
          if (i % 2 == 1) {
            panL = 1.0;
            panR = 0.65;
          } else {
            panL = 0.65;
            panR = 1.0;
          }
        }

        final stemGain = mixerConsole.getEffectiveGain(track.id);
        final effL = stemGain * panL;
        final effR = stemGain * panR;

        for (int s = 0; s < totalSamples; s++) {
          masterLeft[s] += stemSamples[s] * effL;
          masterRight[s] += stemSamples[s] * effR;
        }
      }

      if (config.includeMetronomeTrack) {
        final double metroGain = mixerConsole.getEffectiveGain("metronome");
        for (int s = 0; s < totalSamples; s++) {
          masterLeft[s] += metronomeSamples[s] * metroGain;
          masterRight[s] += metronomeSamples[s] * metroGain;
        }
      }

      final masterWavBytes = floatStereoBufferToWav(
        leftBuffer: masterLeft,
        rightBuffer: masterRight,
        sampleRate: sampleRate,
      );
      files.add(ExportedStemFile(
        fileName: "${trackTitle.toLowerCase().replaceAll(' ', '_')}_master_mixdown.wav",
        bytes: masterWavBytes,
        mimeType: "audio/wav",
        duration: duration,
        description: "Master Mixdown WAV Estéreo 2 Canales 16-bit 44.1 kHz con balance del mezclador",
      ));
    }

    // 3. Generar Stems individuales si está solicitado
    if (config.includeIndividualStems) {
      for (int i = 0; i < mixerConsole.stems.length; i++) {
        final track = mixerConsole.stems[i];
        final stemSamples = synthesizedStems[track.id];
        if (stemSamples != null) {
          final wavBytes = floatBufferToWav(buffer: stemSamples, sampleRate: sampleRate);
          final numStr = (i + 1).toString().padLeft(2, '0');
          files.add(ExportedStemFile(
            fileName: "stem_${numStr}_${track.id.toLowerCase().replaceAll(' ', '_')}.wav",
            bytes: wavBytes,
            mimeType: "audio/wav",
            duration: duration,
            description: "Pista individual de ${track.title} (WAV)",
          ));
        }
      }

      if (config.includeMetronomeTrack) {
        final metroWavBytes = floatBufferToWav(buffer: metronomeSamples, sampleRate: sampleRate);
        final numStr = (mixerConsole.stems.length + 1).toString().padLeft(2, '0');
        files.add(ExportedStemFile(
          fileName: "stem_${numStr}_metronome_click.wav",
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

        final numStr = (mixerConsole.stems.length + 2).toString().padLeft(2, '0');
        files.add(ExportedStemFile(
          fileName: "stem_${numStr}_user_recorded_take.wav",
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
