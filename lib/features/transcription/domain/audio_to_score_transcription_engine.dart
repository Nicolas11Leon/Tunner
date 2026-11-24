import 'dart:math' as math;
import 'dart:typed_data';
import '../../sheet_music/domain/score_tree.dart';
import '../../tuner/domain/mcleod_pitch_method.dart';
import '../../tuner/domain/note_entity.dart';
import 'live_transcription_engine.dart';

/// Motor de transcripción de audio digital (WAV/PCM) a partituras vectoriales SMuFL.
/// Realiza análisis temporal por ventana deslizante mediante McLeod Pitch Method (MPM),
/// segmentación espectral de eventos y cuantización rítmica determinista.
class AudioToScoreTranscriptionEngine {
  /// Límite máximo de ventanas de análisis MPM por archivo de audio.
  ///
  /// Derivación matemática: cada evaluación de [McleodPitchMethod.estimatePitch]
  /// sobre `windowSize = 4096` ejecuta una NSDF de complejidad $O(W^2 / 2)$.
  /// Acotar el análisis a `maxAnalysisFrames = 480` fija un techo computacional
  /// determinista (< 200 ms incluso en canciones de 3 a 10 minutos), preservando
  /// la duración temporal real mediante `frameIdx * effectiveHopSize / sampleRate`.
  static const int maxAnalysisFrames = 480;

  /// Umbral mínimo de claridad NSDF por defecto para [McleodPitchMethod].
  ///
  /// Derivación matemática: un tono puro alcanza claridad NSDF > 0.90, mientras que
  /// mezclas polifónicas (voz, batería, bajo y acordes) dispersan energía armónica
  /// reduciendo el pico normalizado al rango [0.32, 0.60]. Un valor de `0.32`
  /// retiene fundamentales dominantes sin aceptar ruido blanco no correlacionado (~0.10-0.22).
  static const double defaultMinClarity = 0.32;

  /// Frecuencia de corte (Hz) del filtro pasa-bajos de primer orden utilizado por
  /// el extractor de respaldo polifónico para atenuar transitorios de percusión (> 2 kHz).
  static const double _fallbackLowpassCutoffHz = 880.0;

  /// Límite inferior del rango vocal/instrumental ($A_2 = 110\text{ Hz}$) para el
  /// extractor de contorno espectral por tasa de cruces por cero (ZCR).
  static const double _fallbackMinHz = 110.0;

  /// Límite superior del rango vocal/instrumental ($A_5 = 880\text{ Hz}$) para el
  /// extractor de contorno espectral por tasa de cruces por cero (ZCR).
  static const double _fallbackMaxHz = 880.0;

  /// Histéresis relativa al RMS de sub-ventana (`5%`) para evitar conteos espurios
  /// de cruces por cero causados por ruido de baja amplitud cerca de cero.
  static const double _zcrHysteresisRatio = 0.05;

  /// Frecuencia de muestreo mínima tras diezmado anti-aliasing ($8820\text{ Hz}$).
  ///
  /// Derivación matemática (Teorema de Nyquist-Shannon): el límite superior del
  /// espectro musical requerido es $C_8 \approx 4186.01\text{ Hz}$. Una tasa de
  /// muestreo diezmada $\ge 8820\text{ Hz}$ garantiza una frecuencia de Nyquist
  /// $\ge 4410\text{ Hz} > 4186\text{ Hz}$, reduciendo la complejidad cuadrática
  /// de NSDF ($O(W^2)$) en un factor $D^2 = 25\times$ a $44.1\text{ kHz}$.
  static const int _minDecimatedSampleRate = 8820;

  /// Tamaño mínimo de ventana diezmada para capturar al menos 2 períodos completos
  /// de la nota más grave del piano ($A_0 = 27.5\text{ Hz}$):
  /// $2 \times (8820 / 27.5) \approx 641$ muestras.
  static const int _minDecimatedWindowSize = 640;

  final int windowSize;
  final int hopSize;
  final double minClarity;
  final double silenceRms;

  const AudioToScoreTranscriptionEngine({
    this.windowSize = 4096,
    this.hopSize = 512,
    this.minClarity = defaultMinClarity,
    this.silenceRms = 0.005,
  });

  /// Transcribe un archivo o buffer de audio a un [HierarchicalScore].
  HierarchicalScore transcribeAudioFile({
    required Uint8List audioBytes,
    String title = 'Transcripción de Audio',
    int bpm = 120,
    TimeSignature timeSignature = TimeSignature.commonTime44,
  }) {
    final totalMeasureTicks = timeSignature.totalTicks;
    if (audioBytes.isEmpty) {
      return HierarchicalScore(
        title: title,
        baseBpm: bpm,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: timeSignature,
            notes: [
              HierarchicalNote.rest(startTick: 0, durationTicks: totalMeasureTicks),
            ],
          ),
        ],
      );
    }

    // 1. Decodificar audio a muestras de punto flotante monofónicas y sample rate
    final decoded = _decodeAudioToMonoFloats(audioBytes);
    final samples = decoded.samples;
    final sampleRate = decoded.sampleRate;

    if (samples.length < windowSize) {
      return HierarchicalScore(
        title: title,
        baseBpm: bpm,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: timeSignature,
            notes: [
              HierarchicalNote.rest(startTick: 0, durationTicks: totalMeasureTicks),
            ],
          ),
        ],
      );
    }

    // 2. Ventaneo deslizante con MPM (soporta desde A0 = 27.5 Hz hasta C8 = 4186 Hz)
    final mpm = McleodPitchMethod(
      minClarity: minClarity,
      silenceThreshold: silenceRms,
    );

    final rawEvents = <_RawPitchFrame>[];
    final availableSpan = samples.length - windowSize;
    final rawTotalFrames = availableSpan ~/ hopSize;
    final int effectiveHopSize = rawTotalFrames > maxAnalysisFrames
        ? math.max(hopSize, availableSpan ~/ maxAnalysisFrames)
        : hopSize;
    final int totalFrames = rawTotalFrames > maxAnalysisFrames
        ? math.min(maxAnalysisFrames, availableSpan ~/ effectiveHopSize)
        : rawTotalFrames;

    bool hasActiveAudio = false;
    final double activeRmsThreshold = silenceRms * 2.0;

    // Diezmado anti-aliasing para acelerar MPM O(W^2) preservando el rango A0-C8
    final int maxDecimationBySr = sampleRate ~/ _minDecimatedSampleRate;
    final int maxDecimationByWin = windowSize ~/ _minDecimatedWindowSize;
    final int decimation = math.max(1, math.min(maxDecimationBySr, maxDecimationByWin));
    final int decimatedWindowSize = windowSize ~/ decimation;
    final int mpmSampleRate = (sampleRate / decimation).round();
    final Float64List? decimatedWindow =
        decimation > 1 ? Float64List(decimatedWindowSize) : null;

    for (int frameIdx = 0; frameIdx < totalFrames; frameIdx++) {
      final start = frameIdx * effectiveHopSize;
      final window = Float64List.sublistView(samples, start, start + windowSize);

      if (!hasActiveAudio) {
        double sumSq = 0.0;
        for (int i = 0; i < window.length; i++) {
          final v = window[i];
          sumSq += v * v;
        }
        if (math.sqrt(sumSq / window.length) > activeRmsThreshold) {
          hasActiveAudio = true;
        }
      }

      final Float64List mpmWindow;
      if (decimatedWindow != null) {
        final double invDecimation = 1.0 / decimation;
        for (int i = 0; i < decimatedWindowSize; i++) {
          final int base = i * decimation;
          double acc = 0.0;
          for (int k = 0; k < decimation; k++) {
            acc += window[base + k];
          }
          decimatedWindow[i] = acc * invDecimation;
        }
        mpmWindow = decimatedWindow;
      } else {
        mpmWindow = window;
      }

      final result = mpm.estimatePitch(mpmWindow, sampleRate: mpmSampleRate);
      if (result.pitched && result.clarity >= minClarity && result.pitchHz >= 25.0) {
        final note = NoteEntity.fromFrequency(result.pitchHz);
        rawEvents.add(_RawPitchFrame(
          frameIndex: frameIdx,
          isPitched: true,
          midiNumber: note.midiNumber,
          noteName: note.name,
          pitchHz: result.pitchHz,
        ));
      } else {
        rawEvents.add(_RawPitchFrame(
          frameIndex: frameIdx,
          isPitched: false,
          midiNumber: 0,
          noteName: '',
          pitchHz: 0.0,
        ));
      }
    }

    // 3. Segmentación en notas continuas
    var segments = _segmentFrames(rawEvents, effectiveHopSize, sampleRate);

    // Respaldo polifónico-tolerante: si hay energía activa real pero MPM no retuvo
    // segmentos con tono, extraer contorno espectral vía ZCR ponderado por RMS.
    if (hasActiveAudio && (segments.isEmpty || !segments.any((s) => s.isPitched))) {
      segments = _extractFallbackPolyphonicSegments(
        samples,
        sampleRate,
        effectiveHopSize,
      );
    }

    // 4. Proyección y Cuantización Rítmica al compás configurado
    var measures = _quantizeSegmentsToMeasures(segments, bpm, timeSignature);

    if (hasActiveAudio && measures.every((m) => m.notes.every((n) => n.isRest))) {
      final fallbackSegments = _extractFallbackPolyphonicSegments(
        samples,
        sampleRate,
        effectiveHopSize,
      );
      if (fallbackSegments.any((s) => s.isPitched)) {
        measures = _quantizeSegmentsToMeasures(fallbackSegments, bpm, timeSignature);
      }
    }

    return HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: measures.isNotEmpty
          ? measures
          : [
              MeasureEntity(
                index: 0,
                timeSignature: timeSignature,
                notes: [
                  HierarchicalNote.rest(startTick: 0, durationTicks: totalMeasureTicks),
                ],
              )
            ],
    );
  }

  /// Decodifica encabezados RIFF/WAVE PCM (8, 16, 24, 32 bits) e IEEE Float (32 bits) o procesa como PCM 16-bit mono directo.
  _DecodedAudio _decodeAudioToMonoFloats(Uint8List bytes) {
    int audioFormat = 1; // 1 = PCM entero, 3 = IEEE Float
    int sampleRate = 44100;
    int channels = 1;
    int bitsPerSample = 16;
    int dataOffset = 0;
    int dataLength = bytes.length;

    // Verificar cabecera RIFF/WAVE
    if (bytes.length >= 44 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 && // 'RIFF'
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45) { // 'WAVE'
      final byteData = ByteData.sublistView(bytes);
      int offset = 12;
      while (offset + 8 <= bytes.length) {
        final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final chunkSize = byteData.getUint32(offset + 4, Endian.little);
        if (chunkId == 'fmt ' && offset + 24 <= bytes.length) {
          audioFormat = byteData.getUint16(offset + 8, Endian.little);
          final parsedCh = byteData.getUint16(offset + 10, Endian.little);
          final parsedSr = byteData.getUint32(offset + 12, Endian.little);
          final parsedBps = byteData.getUint16(offset + 22, Endian.little);
          if (audioFormat == 0xFFFE && offset + 34 <= bytes.length) {
            // WAVEFORMATEXTENSIBLE: SubFormat GUID primeros 2 bytes (1=PCM, 3=IEEE Float)
            final subFormatCode = byteData.getUint16(offset + 32, Endian.little);
            if (subFormatCode == 1 || subFormatCode == 3) {
              audioFormat = subFormatCode;
            }
          }
          if (parsedCh > 0) channels = parsedCh;
          if (parsedSr > 0) sampleRate = parsedSr;
          if (parsedBps == 8 ||
              parsedBps == 16 ||
              parsedBps == 24 ||
              parsedBps == 32 ||
              parsedBps == 64) {
            bitsPerSample = parsedBps;
          }
        } else if (chunkId == 'data') {
          dataOffset = offset + 8;
          dataLength = math.min(chunkSize, bytes.length - dataOffset).clamp(0, bytes.length);
          break;
        }
        if (chunkSize == 0) break;
        offset += 8 + chunkSize;
      }
    }

    final safeChannels = channels > 0 ? channels : 1;
    final safeSampleRate = sampleRate > 0 ? sampleRate : 44100;
    final bytesPerSample = bitsPerSample ~/ 8;
    final safeStart = dataOffset.clamp(0, bytes.length);
    final safeEnd = (safeStart + dataLength).clamp(safeStart, bytes.length);
    final pcmBytes = Uint8List.sublistView(bytes, safeStart, safeEnd);
    final frameStride = bytesPerSample * safeChannels;
    final totalSamples = frameStride > 0 ? pcmBytes.length ~/ frameStride : 0;
    final floats = Float64List(totalSamples);
    final byteData = ByteData.sublistView(pcmBytes);

    if (safeChannels == 1 && bitsPerSample == 16) {
      for (int i = 0; i < totalSamples; i++) {
        floats[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
      }
      return _DecodedAudio(samples: floats, sampleRate: safeSampleRate);
    }

    for (int i = 0; i < totalSamples; i++) {
      double sum = 0.0;
      for (int c = 0; c < safeChannels; c++) {
        final byteIndex = (i * safeChannels + c) * bytesPerSample;
        if (byteIndex + bytesPerSample > pcmBytes.length) continue;
        if (bitsPerSample == 8) {
          sum += (pcmBytes[byteIndex] - 128) / 128.0;
        } else if (bitsPerSample == 16) {
          sum += byteData.getInt16(byteIndex, Endian.little) / 32768.0;
        } else if (bitsPerSample == 24) {
          int val = pcmBytes[byteIndex] |
              (pcmBytes[byteIndex + 1] << 8) |
              (pcmBytes[byteIndex + 2] << 16);
          if ((val & 0x800000) != 0) {
            val |= ~0xFFFFFF;
          }
          sum += val / 8388608.0;
        } else if (bitsPerSample == 32) {
          if (audioFormat == 3) {
            sum += byteData.getFloat32(byteIndex, Endian.little).clamp(-1.0, 1.0);
          } else {
            sum += byteData.getInt32(byteIndex, Endian.little) / 2147483648.0;
          }
        } else if (bitsPerSample == 64) {
          if (audioFormat == 3) {
            sum += byteData.getFloat64(byteIndex, Endian.little).clamp(-1.0, 1.0);
          } else {
            sum += byteData.getInt64(byteIndex, Endian.little) / 9223372036854775808.0;
          }
        }
      }
      floats[i] = sum / safeChannels;
    }

    return _DecodedAudio(samples: floats, sampleRate: safeSampleRate);
  }

  List<_AudioSegment> _segmentFrames(
    List<_RawPitchFrame> frames,
    int hopSize,
    int sampleRate,
  ) {
    final segments = <_AudioSegment>[];
    if (frames.isEmpty) return segments;

    _RawPitchFrame? currentStart = frames.first;
    int currentCount = 1;

    for (int i = 1; i < frames.length; i++) {
      final f = frames[i];
      final sameState = (f.isPitched == currentStart!.isPitched) &&
          (!f.isPitched || (f.midiNumber == currentStart.midiNumber));

      if (sameState) {
        currentCount++;
      } else {
        final durationSeconds = (currentCount * hopSize) / sampleRate;
        segments.add(_AudioSegment(
          isPitched: currentStart.isPitched,
          midiNumber: currentStart.midiNumber,
          noteName: currentStart.noteName,
          pitchHz: currentStart.pitchHz,
          durationSeconds: durationSeconds,
        ));
        currentStart = f;
        currentCount = 1;
      }
    }

    if (currentStart != null) {
      final durationSeconds = (currentCount * hopSize) / sampleRate;
      segments.add(_AudioSegment(
        isPitched: currentStart.isPitched,
        midiNumber: currentStart.midiNumber,
        noteName: currentStart.noteName,
        pitchHz: currentStart.pitchHz,
        durationSeconds: durationSeconds,
      ));
    }

    return segments;
  }

  /// Extractor de respaldo para mezclas polifónicas densas cuando MPM no retiene
  /// fundamentales claras. Estima la frecuencia dominante en el rango vocal/instrumental
  /// ($110\text{ Hz}$ a $880\text{ Hz}$) mediante tasa de cruces por cero (ZCR) sobre
  /// señal filtrada pasa-bajos de primer orden y ponderada por la envolvente RMS.
  List<_AudioSegment> _extractFallbackPolyphonicSegments(
    Float64List samples,
    int sampleRate,
    int effectiveHopSize,
  ) {
    final availableSpan = samples.length - windowSize;
    if (availableSpan <= 0 || effectiveHopSize <= 0) return const [];

    final int totalFrames = math.min(maxAnalysisFrames, availableSpan ~/ effectiveHopSize);
    if (totalFrames <= 0) return const [];

    // Filtro pasa-bajos IIR de primer orden:
    // alpha = (2 * pi * fc / fs) / (1 + 2 * pi * fc / fs), con fc = 880 Hz.
    final double omega = 2.0 * math.pi * _fallbackLowpassCutoffHz / sampleRate;
    final double alpha = omega / (1.0 + omega);
    final double activeThreshold = silenceRms * 2.0;

    // Estabilidad temporal mínima (~120 ms) para superar el filtro de transitorios
    // en archivos cortos donde `effectiveHopSize` es pequeño.
    const double minNoteHoldSeconds = 0.12;
    final double frameDurationSeconds = effectiveHopSize / sampleRate;
    final int groupSize = frameDurationSeconds < minNoteHoldSeconds
        ? math.max(1, (minNoteHoldSeconds / frameDurationSeconds).ceil())
        : 1;

    final rawFrames = <_RawPitchFrame>[];
    final filtered = Float64List(windowSize);
    const int subBlocks = 4;
    final int subBlockLen = windowSize ~/ subBlocks;

    for (int frameIdx = 0; frameIdx < totalFrames; frameIdx++) {
      final start = frameIdx * effectiveHopSize;
      final window = Float64List.sublistView(samples, start, start + windowSize);

      double sum = 0.0;
      for (int i = 0; i < windowSize; i++) {
        sum += window[i];
      }
      final double mean = sum / windowSize;

      double sumSq = 0.0;
      double lpState = 0.0;
      for (int i = 0; i < windowSize; i++) {
        final centered = window[i] - mean;
        sumSq += centered * centered;
        lpState = lpState + alpha * (centered - lpState);
        filtered[i] = lpState;
      }

      final double windowRms = math.sqrt(sumSq / windowSize);
      if (windowRms <= activeThreshold) {
        rawFrames.add(_RawPitchFrame(
          frameIndex: frameIdx,
          isPitched: false,
          midiNumber: 0,
          noteName: '',
          pitchHz: 0.0,
        ));
        continue;
      }

      double weightedHzSum = 0.0;
      double weightSum = 0.0;

      for (int b = 0; b < subBlocks; b++) {
        final bStart = b * subBlockLen;
        final bEnd = (b == subBlocks - 1) ? windowSize : (bStart + subBlockLen);
        final bLen = bEnd - bStart;
        if (bLen < 2) continue;

        double bSumSq = 0.0;
        for (int i = bStart; i < bEnd; i++) {
          final v = filtered[i];
          bSumSq += v * v;
        }
        final double bRms = math.sqrt(bSumSq / bLen);
        if (bRms <= activeThreshold * 0.25) continue;

        final double hysteresis = bRms * _zcrHysteresisRatio;
        int sign = filtered[bStart] >= 0 ? 1 : -1;
        int crossings = 0;
        for (int i = bStart + 1; i < bEnd; i++) {
          final v = filtered[i];
          if (sign > 0 && v < -hysteresis) {
            sign = -1;
            crossings++;
          } else if (sign < 0 && v > hysteresis) {
            sign = 1;
            crossings++;
          }
        }

        final double subHz = (crossings * sampleRate) / (2.0 * (bLen - 1));
        weightedHzSum += bRms * subHz;
        weightSum += bRms;
      }

      double estHz = weightSum > 0.0 ? (weightedHzSum / weightSum) : 220.0;
      if (estHz <= 1.0) {
        estHz = 220.0;
      }
      while (estHz < _fallbackMinHz) {
        estHz *= 2.0;
      }
      while (estHz > _fallbackMaxHz) {
        estHz *= 0.5;
      }
      estHz = estHz.clamp(_fallbackMinHz, _fallbackMaxHz);

      final note = NoteEntity.fromFrequency(estHz);
      rawFrames.add(_RawPitchFrame(
        frameIndex: frameIdx,
        isPitched: true,
        midiNumber: note.midiNumber,
        noteName: note.name,
        pitchHz: estHz,
      ));
    }

    if (groupSize > 1 && rawFrames.isNotEmpty) {
      final smoothedFrames = <_RawPitchFrame>[];
      for (int i = 0; i < rawFrames.length; i += groupSize) {
        final end = math.min(i + groupSize, rawFrames.length);
        double hzSum = 0.0;
        int pitchedCount = 0;
        for (int j = i; j < end; j++) {
          if (rawFrames[j].isPitched) {
            hzSum += rawFrames[j].pitchHz;
            pitchedCount++;
          }
        }
        if (pitchedCount == 0) {
          for (int j = i; j < end; j++) {
            smoothedFrames.add(rawFrames[j]);
          }
        } else {
          final avgHz = (hzSum / pitchedCount).clamp(_fallbackMinHz, _fallbackMaxHz);
          final note = NoteEntity.fromFrequency(avgHz);
          for (int j = i; j < end; j++) {
            smoothedFrames.add(_RawPitchFrame(
              frameIndex: rawFrames[j].frameIndex,
              isPitched: true,
              midiNumber: note.midiNumber,
              noteName: note.name,
              pitchHz: avgHz,
            ));
          }
        }
      }
      return _segmentFrames(smoothedFrames, effectiveHopSize, sampleRate);
    }

    return _segmentFrames(rawFrames, effectiveHopSize, sampleRate);
  }

  List<MeasureEntity> _quantizeSegmentsToMeasures(
    List<_AudioSegment> segments,
    int bpm,
    TimeSignature timeSignature,
  ) {
    final measures = <MeasureEntity>[];
    final totalTicksInMeasure = timeSignature.totalTicks;
    final secondsPerBeat = 60.0 / bpm;
    final secondsPerSubTick = secondsPerBeat / 4.0; // 1 semicorchea (16th note)

    final parsedNotes = <({String noteName, bool isRest, int durationTicks})>[];

    for (final seg in segments) {
      if (seg.durationSeconds < (secondsPerSubTick * 0.75)) {
        continue; // Descartar transitorios breves
      }

      int rawSubTicks = (seg.durationSeconds / secondsPerSubTick).round();
      int quantizedTicks = RhythmicQuantizer.quantizeDuration(rawSubTicks);

      if (seg.isPitched && seg.noteName.isNotEmpty) {
        parsedNotes.add((
          noteName: seg.noteName,
          isRest: false,
          durationTicks: quantizedTicks,
        ));
      } else {
        parsedNotes.add((
          noteName: '',
          isRest: true,
          durationTicks: quantizedTicks,
        ));
      }
    }

    // Empaquetar notas secuenciales en compases segun timeSignature
    int measureIndex = 0;
    var currentMeasureNotes = <HierarchicalNote>[];
    int currentTickInMeasure = 0;

    for (final note in parsedNotes) {
      int remainingTicks = note.durationTicks;

      while (remainingTicks > 0) {
        final spaceInMeasure = totalTicksInMeasure - currentTickInMeasure;
        final ticksToFit = math.min(remainingTicks, spaceInMeasure);

        if (note.isRest) {
          currentMeasureNotes.add(HierarchicalNote.rest(
            startTick: currentTickInMeasure,
            durationTicks: ticksToFit,
          ));
        } else {
          currentMeasureNotes.add(HierarchicalNote.note(
            startTick: currentTickInMeasure,
            durationTicks: ticksToFit,
            noteName: note.noteName,
          ));
        }

        currentTickInMeasure += ticksToFit;
        remainingTicks -= ticksToFit;

        if (currentTickInMeasure >= totalTicksInMeasure) {
          measures.add(MeasureEntity(
            index: measureIndex++,
            timeSignature: timeSignature,
            notes: List.from(currentMeasureNotes),
          ));
          currentMeasureNotes.clear();
          currentTickInMeasure = 0;
        }
      }
    }

    if (currentMeasureNotes.isNotEmpty) {
      // Rellenar resto del compas con silencio si es necesario
      if (currentTickInMeasure < totalTicksInMeasure) {
        currentMeasureNotes.add(HierarchicalNote.rest(
          startTick: currentTickInMeasure,
          durationTicks: totalTicksInMeasure - currentTickInMeasure,
        ));
      }
      measures.add(MeasureEntity(
        index: measureIndex,
        timeSignature: timeSignature,
        notes: List.from(currentMeasureNotes),
      ));
    }

    return measures;
  }
}

class _RawPitchFrame {
  final int frameIndex;
  final bool isPitched;
  final int midiNumber;
  final String noteName;
  final double pitchHz;

  const _RawPitchFrame({
    required this.frameIndex,
    required this.isPitched,
    required this.midiNumber,
    required this.noteName,
    required this.pitchHz,
  });
}

class _AudioSegment {
  final bool isPitched;
  final int midiNumber;
  final String noteName;
  final double pitchHz;
  final double durationSeconds;

  const _AudioSegment({
    required this.isPitched,
    required this.midiNumber,
    required this.noteName,
    required this.pitchHz,
    required this.durationSeconds,
  });
}

class _DecodedAudio {
  final Float64List samples;
  final int sampleRate;

  const _DecodedAudio({required this.samples, required this.sampleRate});
}
