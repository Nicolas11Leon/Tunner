import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../../../core/audio/domain/i_studio_audio_input_engine.dart';
import '../../../core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import '../../../core/audio/infrastructure/studio_audio_input_engine.dart';
import '../domain/i_pitch_detector_service.dart';
import '../domain/mcleod_pitch_method.dart';
import '../domain/instrument_acoustic_filter.dart';
import '../domain/microphone_calibration_models.dart';
import '../domain/signal_conditioning_filter.dart';

/// Implementación de infraestructura para la captura de micrófono y procesamiento DSP en Isolate.
/// Conecta la ingesta física al motor canónico [IStudioAudioInputEngine] en el núcleo de la aplicación,
/// ejecutando el algoritmo McLeod Pitch Method (MPM) con NSDF e interpolación parabólica en segundo plano.
class PitchDetectorService implements IPitchDetectorService {
  final IStudioAudioInputEngine _inputEngine;
  StreamSubscription? _audioSubscription;
  bool _isRecording = false;
  
  Isolate? _dspIsolate;
  ReceivePort? _fromWorkerPort;
  SendPort? _toWorkerPort;
  Completer<void>? _workerReadyCompleter;

  MicrophoneCalibrationProfile _activeProfile = const MicrophoneCalibrationProfile();
  InstrumentAcousticFilterConfig _activeInstrumentFilter = InstrumentAcousticFilterConfig.universal();
  String _selectedDeviceId = '';

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  PitchDetectorService({
    AudioRecorder? audioRecorder,
    IStudioAudioInputEngine? inputEngine,
  }) : _inputEngine = inputEngine ??
            (_isTestEnvironment
                ? MemoryStudioAudioInputEngine()
                : StudioAudioInputEngine(injectedRecorder: audioRecorder));

  @override
  Function(double)? onPitchDetected;

  @override
  Function(double)? onRmsLevelChanged;

  MicrophoneCalibrationProfile get activeProfile => _activeProfile;
  InstrumentAcousticFilterConfig get activeInstrumentFilter => _activeInstrumentFilter;
  String get selectedDeviceId => _selectedDeviceId;

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
    int activeSampleRate = 44100;

    // Ventana deslizante de análisis: 4096 muestras a 16 bits (92.8 ms a 44.1 kHz, 85.3 ms a 48 kHz)
    // Garantiza longitud de correlación NSDF para detectar el registro más grave hasta La0 = 27.5 Hz
    const windowSizeSamples = 4096;
    final slidingFloatBuffer = Float64List(windowSizeSamples);
    int bufferFilledSamples = 0;
    int rmsThrottleCounter = 0;
    Uint8List? leftoverBytes;

    workerReceivePort.listen((message) {
      if (message is int) {
        activeSampleRate = message;
      } else if (message is MicrophoneCalibrationProfile) {
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
        var incoming = message is Uint8List ? message : Uint8List.fromList(message as List<int>);
        if (incoming.isEmpty) return;

        // Protección contra bytes impares (alineación a 16 bits Little-Endian)
        if (leftoverBytes != null) {
          final merged = Uint8List(leftoverBytes!.length + incoming.length);
          merged.setRange(0, leftoverBytes!.length, leftoverBytes!);
          merged.setRange(leftoverBytes!.length, merged.length, incoming);
          incoming = merged;
          leftoverBytes = null;
        }
        if (incoming.length.isOdd) {
          leftoverBytes = Uint8List.fromList([incoming.last]);
          incoming = Uint8List.sublistView(incoming, 0, incoming.length - 1);
        }
        if (incoming.isEmpty) return;

        // Convertir y acondicionar continuamente (DC-Blocker causal y ganancia) solo las nuevas muestras
        final rawIncomingFloats = McleodPitchMethod.convertPcm16BytesToFloats(incoming);
        final conditionedFloats = filter.conditionSamples(
          rawIncomingFloats,
          gain: currentGain,
          enableDcBlocker: enableDc,
        );

        // Desplazar y acumular en el búfer flotante
        final newSamples = conditionedFloats.length;
        if (newSamples >= windowSizeSamples) {
          slidingFloatBuffer.setRange(0, windowSizeSamples, conditionedFloats, newSamples - windowSizeSamples);
          bufferFilledSamples = windowSizeSamples;
        } else {
          if (bufferFilledSamples + newSamples > windowSizeSamples) {
            final keep = windowSizeSamples - newSamples;
            slidingFloatBuffer.setRange(0, keep, slidingFloatBuffer, newSamples);
            slidingFloatBuffer.setRange(keep, windowSizeSamples, conditionedFloats);
            bufferFilledSamples = windowSizeSamples;
          } else {
            slidingFloatBuffer.setRange(bufferFilledSamples, bufferFilledSamples + newSamples, conditionedFloats);
            bufferFilledSamples += newSamples;
          }
        }

        // Ejecutar estimación si se dispone de al menos 2048 muestras (46.4 ms)
        if (bufferFilledSamples >= 2048) {
          final activeFloats = Float64List.sublistView(slidingFloatBuffer, 0, bufferFilledSamples);
          final result = mpm.estimatePitch(activeFloats, sampleRate: activeSampleRate);

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

  final Map<String, String> _deviceLabelToId = {};

  @override
  Future<List<String>> listInputDevices() async {
    try {
      final devices = await _inputEngine.listInputDevices();
      _deviceLabelToId.clear();
      return devices.map((d) {
        final display = d.label.isNotEmpty ? d.label : d.id;
        _deviceLabelToId[display] = d.id;
        return display;
      }).toList();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'PitchDetectorService',
        'Error enumerando dispositivos de entrada',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  @override
  Future<void> setInputDevice(String deviceId) async {
    final resolvedId = _deviceLabelToId[deviceId] ?? deviceId;
    _selectedDeviceId = resolvedId;
    _activeProfile = _activeProfile.copyWith(deviceId: resolvedId);
    await _inputEngine.setInputDevice(resolvedId);
  }

  @override
  Future<void> startRecording({int sampleRate = 44100}) async {
    if (_isRecording) return;
    try {
      await _startDspWorker();
      _toWorkerPort?.send(sampleRate);
      await _inputEngine.startCapture(sampleRate: sampleRate, bufferSize: 1024);
      _isRecording = true;

      _audioSubscription = _inputEngine.pcmFrameStream.listen((frame) {
        _toWorkerPort?.send(frame.rawBytes);
      }, onError: (error, st) {
        StudioDebugLogger.instance.warning(
          'PitchDetectorService',
          'Error en el flujo de audio de entrada',
          error: error,
          stackTrace: st is StackTrace ? st : null,
        );
      });
    } catch (e, st) {
      StudioDebugLogger.instance.error(
        'PitchDetectorService',
        'Error al inicializar microfono y DSP Isolate',
        error: e,
        stackTrace: st,
      );
      _isRecording = false;
      await stopRecording();
    }
  }

  /// Libera los recursos de captura y finaliza el Isolate DSP.
  Future<void> dispose() async {
    await stopRecording();
  }

  @override
  Future<void> stopRecording() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_isRecording) {
      _isRecording = false;
      await _inputEngine.stopCapture();
    }

    _fromWorkerPort?.close();
    _fromWorkerPort = null;
    _toWorkerPort = null;

    _dspIsolate?.kill(priority: Isolate.immediate);
    _dspIsolate = null;
  }
}
