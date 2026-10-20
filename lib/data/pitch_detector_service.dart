import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

class PitchDetectorService {
  final _audioRecorder = AudioRecorder();
  StreamSubscription? _audioSubscription;
  
  Isolate? _dspIsolate;
  ReceivePort? _fromWorkerPort;
  SendPort? _toWorkerPort;
  Completer<void>? _workerReadyCompleter;

  Function(double)? onPitchDetected;

  Future<void> _startDspWorker() async {
    _fromWorkerPort = ReceivePort();
    _workerReadyCompleter = Completer<void>();

    _dspIsolate = await Isolate.spawn(
      _dspWorkerEntryPoint,
      _fromWorkerPort!.sendPort,
    );

    _fromWorkerPort!.listen((message) {
      if (message is SendPort) {
        _toWorkerPort = message;
        if (!_workerReadyCompleter!.isCompleted) {
          _workerReadyCompleter!.complete();
        }
      } else if (message is double) {
        if (onPitchDetected != null) {
          onPitchDetected!(message);
        }
      }
    });

    await _workerReadyCompleter!.future;
  }

  static void _dspWorkerEntryPoint(SendPort toMainPort) {
    final workerReceivePort = ReceivePort();
    toMainPort.send(workerReceivePort.sendPort);

    final pitchDetector = PitchDetector();

    workerReceivePort.listen((message) {
      if (message is Uint8List || message is List<int>) {
        final uint8Buffer = message is Uint8List ? message : Uint8List.fromList(message as List<int>);
        if (uint8Buffer.isEmpty) return;

        // 1. Noise Gate: calcular potencia acústica cuadrática media (RMS)
        double sumSquares = 0.0;
        for (int i = 0; i < uint8Buffer.length; i++) {
          final sample = uint8Buffer[i].toDouble();
          sumSquares += sample * sample;
        }
        final rms = sumSquares / uint8Buffer.length;

        // Si es ruido de fondo o silencio, no consumir ciclos innecesarios
        if (rms < 50.0) return;

        // 2. Estimación matemática de tono (YIN en hilo secundario)
        pitchDetector.getPitchFromIntBuffer(uint8Buffer).then((pitchResult) {
          if (pitchResult.pitched) {
            final pitch = pitchResult.pitch;
            // Rango acústico universal: A0 (27.5 Hz) a C8 (4186.0 Hz)
            if (pitch >= 27.5 && pitch <= 4186.0) {
              toMainPort.send(pitch);
            }
          }
        });
      }
    });
  }

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _startDspWorker();

        final stream = await _audioRecorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ));

        _audioSubscription = stream.listen((data) {
          // Envío inmediato al Isolate de fondo (0 microsegundos en hilo de UI)
          _toWorkerPort?.send(data);
        }, onError: (error) {
          debugPrint("Error en el flujo de audio: $error");
        });
      }
    } catch (e) {
      debugPrint("Error al inicializar micrófono y DSP Isolate: $e");
    }
  }

  Future<void> stopRecording() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _audioRecorder.stop();

    _fromWorkerPort?.close();
    _fromWorkerPort = null;
    _toWorkerPort = null;

    _dspIsolate?.kill(priority: Isolate.immediate);
    _dspIsolate = null;
  }
}