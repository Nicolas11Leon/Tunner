import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../domain/i_pitch_detector_service.dart';
import '../domain/mcleod_pitch_method.dart';
import '../domain/instrument_acoustic_filter.dart';
import '../domain/microphone_calibration_models.dart';
import '../domain/signal_conditioning_filter.dart';

/// Implementación de infraestructura para la captura de micrófono y procesamiento DSP en Isolate.
/// Implementa estrictamente el contrato [IPitchDetectorService] del dominio
/// utilizando el algoritmo McLeod Pitch Method (MPM) con NSDF e interpolación parabólica,
/// complementado con acondicionamiento de señal en tiempo real (DC-Blocker y Ganancia Adaptativa)
/// y aislamiento acústico por tesitura y Tone Lock para rechazo de habla humana.
class PitchDetectorService implements IPitchDetectorService {
  final _audioRecorder = AudioRecorder();
  StreamSubscription? _audioSubscription;
  
  Isolate? _dspIsolate;
  ReceivePort? _fromWorkerPort;
  SendPort? _toWorkerPort;
  Completer<void>? _workerReadyCompleter;

  MicrophoneCalibrationProfile _activeProfile = const MicrophoneCalibrationProfile();
  InstrumentAcousticFilterConfig _activeInstrumentFilter = InstrumentAcousticFilterConfig.universal();
  String _selectedDeviceId = '';

  @override
  Function(double)? onPitchDetected;

  @override
  Function(double)? onRmsLevelChanged;

  MicrophoneCalibrationProfile get activeProfile => _activeProfile;
  InstrumentAcousticFilterConfig get activeInstrumentFilter => _activeInstrumentFilter;

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
        // Enviar perfiles de calibración e instrumento inicial
        _toWorkerPort!.send(_activeProfile);
        _toWorkerPort!.send(_activeInstrumentFilter);
        if (!_workerReadyCompleter!.isCompleted) {
          _workerReadyCompleter!.complete();
        }
      } else if (message is double) {
        onPitchDetected?.call(message);
      } else if (message is Map<String, dynamic>) {
        if (message.containsKey('rms') && onRmsLevelChanged != null) {
          onRmsLevelChanged!(message['rms'] as double);
        }
      }
    });

    await _workerReadyCompleter!.future;
  }

  static void _dspWorkerEntryPoint(SendPort toMainPort) {
    final workerReceivePort = ReceivePort();
    toMainPort.send(workerReceivePort.sendPort);

    final filter = SignalConditioningFilter();
    final toneLockTracker = ToneLockTracker();
    var filterConfig = InstrumentAcousticFilterConfig.universal();
    McleodPitchMethod mpm = const McleodPitchMethod(minClarity: 0.65);
    double currentGain = 1.0;
    bool enableDc = true;

    // Ventana deslizante de análisis: 4096 bytes (2048 muestras a 16 bits = 46.4 ms a 44.1 kHz)
    const windowSizeBytes = 4096;
    final slidingBuffer = Uint8List(windowSizeBytes);
    int bufferFilled = 0;
    int rmsThrottleCounter = 0;

    workerReceivePort.listen((message) {
      if (message is MicrophoneCalibrationProfile) {
        currentGain = message.digitalGain;
        enableDc = message.enableDcBlocker;
        mpm = McleodPitchMethod(
          silenceThreshold: message.noiseGateThreshold,
          minClarity: filterConfig.enabled ? filterConfig.minClarity : 0.65,
        );
        filter.reset();
        toneLockTracker.reset();
      } else if (message is InstrumentAcousticFilterConfig) {
        filterConfig = message;
        mpm = McleodPitchMethod(
          silenceThreshold: mpm.silenceThreshold,
          minClarity: filterConfig.enabled ? filterConfig.minClarity : 0.65,
        );
        toneLockTracker.reset();
      } else if (message is Uint8List || message is List<int>) {
        final incoming = message is Uint8List ? message : Uint8List.fromList(message as List<int>);
        if (incoming.isEmpty) return;

        // Acumular en la ventana deslizante
        if (incoming.length >= windowSizeBytes) {
          slidingBuffer.setRange(0, windowSizeBytes, incoming, incoming.length - windowSizeBytes);
          bufferFilled = windowSizeBytes;
        } else {
          final toShift = incoming.length;
          if (bufferFilled + toShift > windowSizeBytes) {
            final keep = windowSizeBytes - toShift;
            slidingBuffer.setRange(0, keep, slidingBuffer, toShift);
            slidingBuffer.setRange(keep, windowSizeBytes, incoming);
            bufferFilled = windowSizeBytes;
          } else {
            slidingBuffer.setRange(bufferFilled, bufferFilled + toShift, incoming);
            bufferFilled += toShift;
          }
        }

        // Ejecutar estimación si se dispone de al menos media ventana (1024 muestras = 2048 bytes)
        if (bufferFilled >= 2048) {
          final activeBytes = Uint8List.sublistView(slidingBuffer, 0, bufferFilled);
          final rawFloats = McleodPitchMethod.convertPcm16BytesToFloats(activeBytes);

          // Acondicionar señal con DC-Blocker y Ganancia Digital
          final conditionedFloats = filter.conditionSamples(
            rawFloats,
            gain: currentGain,
            enableDcBlocker: enableDc,
          );

          final result = mpm.estimatePitch(conditionedFloats, sampleRate: 44100);

          // Notificar nivel RMS para el medidor VU cada ~4 frames (aprox 20-25 Hz)
          rmsThrottleCounter++;
          if (rmsThrottleCounter % 4 == 0) {
            toMainPort.send({'rms': result.rms});
          }

          if (result.pitched) {
            final confirmedPitch = toneLockTracker.processFrame(
              rawPitchHz: result.pitchHz,
              clarity: result.clarity,
              config: filterConfig,
            );
            if (confirmedPitch != null) {
              toMainPort.send(confirmedPitch);
            }
          } else {
            toneLockTracker.reset();
          }
        }
      }
    });
  }

  @override
  void updateCalibrationProfile(MicrophoneCalibrationProfile profile) {
    _activeProfile = profile;
    _toWorkerPort?.send(profile);
  }

  @override
  void setInstrumentAcousticFilter(InstrumentAcousticFilterConfig filterConfig) {
    _activeInstrumentFilter = filterConfig;
    _toWorkerPort?.send(filterConfig);
  }

  @override
  Future<List<String>> listInputDevices() async {
    try {
      final devices = await _audioRecorder.listInputDevices();
      return devices.map((d) => d.label.isNotEmpty ? d.label : d.id).toList();
    } catch (e) {
      debugPrint("Error enumerando dispositivos de entrada: $e");
      return [];
    }
  }

  @override
  Future<void> setInputDevice(String deviceId) async {
    _selectedDeviceId = deviceId;
    _activeProfile = _activeProfile.copyWith(deviceId: deviceId);
    if (_audioSubscription != null) {
      // Reiniciar captura con el nuevo dispositivo
      await stopRecording();
      await startRecording();
    }
  }

  @override
  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _startDspWorker();

        InputDevice? targetDevice;
        if (_selectedDeviceId.isNotEmpty) {
          try {
            final devices = await _audioRecorder.listInputDevices();
            for (final d in devices) {
              if (d.id == _selectedDeviceId || d.label == _selectedDeviceId) {
                targetDevice = d;
                break;
              }
            }
          } catch (_) {}
        }

        final config = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
          device: targetDevice,
        );

        final stream = await _audioRecorder.startStream(config);

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
