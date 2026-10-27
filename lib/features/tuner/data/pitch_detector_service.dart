import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../domain/i_pitch_detector_service.dart';
import '../domain/mcleod_pitch_method.dart';

/// Implementación de infraestructura para la captura de micrófono y procesamiento DSP en Isolate.
/// Implementa estrictamente el contrato [IPitchDetectorService] del dominio
/// utilizando el algoritmo McLeod Pitch Method (MPM) con NSDF e interpolación parabólica.
class PitchDetectorService implements IPitchDetectorService {
  final _audioRecorder = AudioRecorder();
  StreamSubscription? _audioSubscription;
  
  Isolate? _dspIsolate;
  ReceivePort? _fromWorkerPort;
  SendPort? _toWorkerPort;
  Completer<void>? _workerReadyCompleter;

  @override
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

    const mpm = McleodPitchMethod();

    // Ventana deslizante de análisis: 4096 bytes (2048 muestras a 16 bits = 46.4 ms a 44.1 kHz)
    const windowSizeBytes = 4096;
    final slidingBuffer = Uint8List(windowSizeBytes);
    int bufferFilled = 0;

    workerReceivePort.listen((message) {
      if (message is Uint8List || message is List<int>) {
        final incoming = message is Uint8List ? message : Uint8List.fromList(message as List<int>);
        if (incoming.isEmpty) return;

        // Acumular en la ventana deslizante
        if (incoming.length >= windowSizeBytes) {
          // Si el chunk entrante es igual o mayor a la ventana, tomar las últimas muestras
          slidingBuffer.setRange(0, windowSizeBytes, incoming, incoming.length - windowSizeBytes);
          bufferFilled = windowSizeBytes;
        } else {
          final toShift = incoming.length;
          if (bufferFilled + toShift > windowSizeBytes) {
            // Desplazar muestras previas a la izquierda
            final keep = windowSizeBytes - toShift;
            slidingBuffer.setRange(0, keep, slidingBuffer, toShift);
            slidingBuffer.setRange(keep, windowSizeBytes, incoming);
            bufferFilled = windowSizeBytes;
          } else {
            slidingBuffer.setRange(bufferFilled, bufferFilled + toShift, incoming);
            bufferFilled += toShift;
          }
        }

        // Ejecutar estimación si se dispone de al menos media ventana (1024 muestras)
        if (bufferFilled >= 2048) {
          final activeBytes = Uint8List.sublistView(slidingBuffer, 0, bufferFilled);
          final result = mpm.estimatePitchFromPcm16(activeBytes, sampleRate: 44100);

          if (result.pitched) {
            final pitch = result.pitchHz;
            // Rango acústico universal: A0 (27.5 Hz) a C8 (4186.0 Hz)
            if (pitch >= 27.5 && pitch <= 4186.0) {
              toMainPort.send(pitch);
            }
          }
        }
      }
    });
  }

  @override
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
          _toWorkerPort?.send(data);
        }, onError: (error) {
          debugPrint("Error en el flujo de audio: $error");
        });
      }
    } catch (e) {
      debugPrint("Error al inicializar micrófono y DSP Isolate: $e");
    }
  }

  @override
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
