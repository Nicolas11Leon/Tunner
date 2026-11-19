import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../../logging/infrastructure/studio_debug_logger.dart';
import '../domain/audio_device_entity.dart';
import '../domain/audio_pcm_frame.dart';
import '../domain/audio_ring_buffer.dart';
import '../domain/i_studio_audio_input_engine.dart';

/// Implementación de infraestructura para el motor de captura e ingesta de audio de Tunner Studio.
/// Conecta el hardware físico del host (micrófono o interfaz USB) con el [AudioRingBuffer]
/// y emite cuadros de audio [AudioPcmFrame] normalizados para procesamiento en tiempo real.
class StudioAudioInputEngine implements IStudioAudioInputEngine {
  AudioRecorder? _recorderInstance;
  final AudioRecorder? _injectedRecorder;

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  AudioRecorder get _recorder =>
      _injectedRecorder ?? (_recorderInstance ??= AudioRecorder());

  final AudioRingBuffer _ringBuffer;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _isCapturing = false;

  AudioDeviceEntity? _currentDevice;
  String _selectedDeviceId = '';

  final StreamController<AudioPcmFrame> _pcmFrameController =
      StreamController<AudioPcmFrame>.broadcast();
  final StreamController<double> _rmsDbController =
      StreamController<double>.broadcast();
  final StreamController<double> _peakDbController =
      StreamController<double>.broadcast();

  StudioAudioInputEngine({
    AudioRecorder? injectedRecorder,
    int ringBufferCapacity = 16384,
  })  : _injectedRecorder = injectedRecorder,
        _ringBuffer = AudioRingBuffer(requestedCapacity: ringBufferCapacity);

  @override
  AudioDeviceEntity? get currentDevice => _currentDevice;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Stream<AudioPcmFrame> get pcmFrameStream => _pcmFrameController.stream;

  @override
  Stream<double> get rmsDbStream => _rmsDbController.stream;

  @override
  Stream<double> get peakDbStream => _peakDbController.stream;

  @override
  Future<List<AudioDeviceEntity>> listInputDevices() async {
    if (_isTestEnvironment) {
      return [
        AudioDeviceEntity.systemDefault(),
        const AudioDeviceEntity(
          id: 'test_interface_scarlett',
          label: 'Focusrite Scarlett 2i2 USB',
          isDefault: false,
          inputChannels: 2,
        ),
      ];
    }

    try {
      final devices = await _recorder.listInputDevices();
      if (devices.isEmpty) {
        return [AudioDeviceEntity.systemDefault()];
      }

      return devices.map((d) {
        return AudioDeviceEntity(
          id: d.id,
          label: d.label.isNotEmpty ? d.label : 'Dispositivo (${d.id})',
          isDefault: d.id == _selectedDeviceId || _selectedDeviceId.isEmpty,
          inputChannels: 1,
        );
      }).toList();
    } catch (e) {
      debugPrint('StudioAudioInputEngine: Error listando dispositivos: $e');
      return [AudioDeviceEntity.systemDefault()];
    }
  }

  @override
  Future<void> setInputDevice(String deviceId) async {
    _selectedDeviceId = deviceId;
    final devices = await listInputDevices();
    _currentDevice = devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => AudioDeviceEntity(id: deviceId, label: 'Dispositivo $deviceId'),
    );

    // Si se encuentra capturando activamente, reinicia la captura en caliente
    if (_isCapturing) {
      await stopCapture();
      await startCapture();
    }
  }

  @override
  Future<void> startCapture({int sampleRate = 44100, int bufferSize = 1024}) async {
    if (_isCapturing) return;

    if (_isTestEnvironment) {
      _isCapturing = true;
      return;
    }

    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        debugPrint('StudioAudioInputEngine: Permiso de micrófono denegado');
        return;
      }

      InputDevice? targetDevice;
      if (_selectedDeviceId.isNotEmpty && _selectedDeviceId != 'default') {
        try {
          final devices = await _recorder.listInputDevices();
          for (final d in devices) {
            if (d.id == _selectedDeviceId) {
              targetDevice = d;
              break;
            }
          }
        } catch (e, st) {
          StudioDebugLogger.instance.warning(
            'StudioAudioInputEngine',
            'Failed to enumerate audio input devices; falling back to default',
            error: e,
            stackTrace: st,
          );
        }
      }

      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        device: targetDevice,
      );

      final stream = await _recorder.startStream(config);
      _ringBuffer.clear();
      _isCapturing = true;

      _audioSubscription = stream.listen((Uint8List chunk) {
        if (chunk.isEmpty) return;

        final frame = AudioPcmFrame.fromPcm16Bytes(
          bytes: chunk,
          sampleRate: sampleRate,
        );

        _ringBuffer.write(frame.samples);

        if (!_pcmFrameController.isClosed) {
          _pcmFrameController.add(frame);
        }
        if (!_rmsDbController.isClosed) {
          _rmsDbController.add(frame.rmsDb);
        }
        if (!_peakDbController.isClosed) {
          _peakDbController.add(frame.peakDb);
        }
      }, onError: (e) {
        debugPrint('StudioAudioInputEngine: Error en stream de audio: $e');
      });
    } catch (e) {
      debugPrint('StudioAudioInputEngine: Error iniciando captura: $e');
      _isCapturing = false;
    }
  }

  @override
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      if (!_isTestEnvironment) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('StudioAudioInputEngine: Error deteniendo captura: $e');
    } finally {
      _isCapturing = false;
      _ringBuffer.clear();
    }
  }

  @override
  void dispose() {
    stopCapture();
    _pcmFrameController.close();
    _rmsDbController.close();
    _peakDbController.close();
    _recorderInstance?.dispose();
  }
}
