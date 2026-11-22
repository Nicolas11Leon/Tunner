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
  final int windowSize;
  final int hopSize;
  final double minClarity;
  final double silenceRms;

  const AudioToScoreTranscriptionEngine({
    this.windowSize = 4096,
    this.hopSize = 512,
    this.minClarity = 0.65,
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
    final totalFrames = (samples.length - windowSize) ~/ hopSize;

    for (int frameIdx = 0; frameIdx < totalFrames; frameIdx++) {
      final start = frameIdx * hopSize;
      final window = Float64List.sublistView(samples, start, start + windowSize);

      final result = mpm.estimatePitch(window, sampleRate: sampleRate);
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
    final segments = _segmentFrames(rawEvents, hopSize, sampleRate);

    // 4. Proyección y Cuantización Rítmica al compás configurado
    final measures = _quantizeSegmentsToMeasures(segments, bpm, timeSignature);

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
