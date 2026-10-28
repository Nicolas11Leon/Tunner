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
    this.windowSize = 2048,
    this.hopSize = 512,
    this.minClarity = 0.65,
    this.silenceRms = 0.005,
  });

  /// Transcribe un archivo o buffer de audio a un [HierarchicalScore].
  HierarchicalScore transcribeAudioFile({
    required Uint8List audioBytes,
    String title = 'Transcripción de Audio',
    int bpm = 120,
  }) {
    if (audioBytes.isEmpty) {
      return HierarchicalScore(
        title: title,
        baseBpm: bpm,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.rest(startTick: 0, durationTicks: 16),
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
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.rest(startTick: 0, durationTicks: 16),
            ],
          ),
        ],
      );
    }

    // 2. Ventaneo deslizante con MPM
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
      if (result.pitched && result.clarity >= minClarity && result.pitchHz >= 50.0) {
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

    // 4. Proyección y Cuantización Rítmica a Compases de 4/4
    final measures = _quantizeSegmentsToMeasures(segments, bpm);

    return HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: measures.isNotEmpty
          ? measures
          : [
              MeasureEntity(
                index: 0,
                timeSignature: TimeSignature.commonTime44,
                notes: [
                  HierarchicalNote.rest(startTick: 0, durationTicks: 16),
                ],
              )
            ],
    );
  }

  /// Decodifica encabezados RIFF/WAVE PCM 16-bit o procesa como PCM mono directo.
  _DecodedAudio _decodeAudioToMonoFloats(Uint8List bytes) {
    int sampleRate = 44100;
    int channels = 1;
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
      // Buscar chunk 'fmt '
      int offset = 12;
      while (offset + 8 <= bytes.length) {
        final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final chunkSize = byteData.getUint32(offset + 4, Endian.little);
        if (chunkId == 'fmt ') {
          channels = byteData.getUint16(offset + 10, Endian.little);
          sampleRate = byteData.getUint32(offset + 12, Endian.little);
        } else if (chunkId == 'data') {
          dataOffset = offset + 8;
          dataLength = math.min(chunkSize, bytes.length - dataOffset);
          break;
        }
        offset += 8 + chunkSize;
      }
    }

    final pcmBytes = Uint8List.sublistView(bytes, dataOffset, dataOffset + dataLength);
    final totalSamples = pcmBytes.length ~/ (2 * channels);
    final floats = Float64List(totalSamples);
    final byteData = ByteData.sublistView(pcmBytes);

    for (int i = 0; i < totalSamples; i++) {
      double sum = 0.0;
      for (int c = 0; c < channels; c++) {
        final byteIndex = (i * channels + c) * 2;
        if (byteIndex + 1 < pcmBytes.length) {
          sum += byteData.getInt16(byteIndex, Endian.little) / 32768.0;
        }
      }
      floats[i] = sum / channels;
    }

    return _DecodedAudio(samples: floats, sampleRate: sampleRate);
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
  ) {
    final measures = <MeasureEntity>[];
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

    // Empaquetar notas secuenciales en compases de 4/4 (16 sub-ticks por compás)
    int measureIndex = 0;
    var currentMeasureNotes = <HierarchicalNote>[];
    int currentTickInMeasure = 0;

    for (final note in parsedNotes) {
      int remainingTicks = note.durationTicks;

      while (remainingTicks > 0) {
        final spaceInMeasure = 16 - currentTickInMeasure;
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

        if (currentTickInMeasure >= 16) {
          measures.add(MeasureEntity(
            index: measureIndex++,
            timeSignature: TimeSignature.commonTime44,
            notes: List.from(currentMeasureNotes),
          ));
          currentMeasureNotes.clear();
          currentTickInMeasure = 0;
        }
      }
    }

    if (currentMeasureNotes.isNotEmpty) {
      // Rellenar resto del compás con silencio si es necesario
      if (currentTickInMeasure < 16) {
        currentMeasureNotes.add(HierarchicalNote.rest(
          startTick: currentTickInMeasure,
          durationTicks: 16 - currentTickInMeasure,
        ));
      }
      measures.add(MeasureEntity(
        index: measureIndex,
        timeSignature: TimeSignature.commonTime44,
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
