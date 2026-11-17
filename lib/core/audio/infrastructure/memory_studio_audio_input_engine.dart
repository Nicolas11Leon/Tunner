import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../domain/audio_device_entity.dart';
import '../domain/audio_pcm_frame.dart';
import '../domain/audio_ring_buffer.dart';
import '../domain/i_studio_audio_input_engine.dart';

/// Implementación en memoria del motor de captura de audio para pruebas unitarias e integración en CI.
class MemoryStudioAudioInputEngine implements IStudioAudioInputEngine {
  final List<AudioDeviceEntity> _devices = [
    AudioDeviceEntity.systemDefault(),
    const AudioDeviceEntity(
      id: 'mock_scarlett_usb',
      label: 'Focusrite Scarlett 2i2 USB Mock',
      isDefault: false,
      inputChannels: 2,
    ),
    const AudioDeviceEntity(
      id: 'mock_shure_mv7',
      label: 'Shure MV7 Dynamic USB Mic',
      isDefault: false,
      inputChannels: 1,
    ),
  ];

  AudioDeviceEntity? _currentDevice;
  bool _isCapturing = false;
  final AudioRingBuffer ringBuffer = AudioRingBuffer(requestedCapacity: 8192);

  final StreamController<AudioPcmFrame> _pcmFrameController =
      StreamController<AudioPcmFrame>.broadcast();
  final StreamController<double> _rmsDbController =
      StreamController<double>.broadcast();
  final StreamController<double> _peakDbController =
      StreamController<double>.broadcast();

  Timer? _generatorTimer;

  MemoryStudioAudioInputEngine() {
    _currentDevice = _devices.first;
  }

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
    return List.unmodifiable(_devices);
  }

  @override
  Future<void> setInputDevice(String deviceId) async {
    _currentDevice = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => AudioDeviceEntity(id: deviceId, label: 'Custom Device $deviceId'),
    );
  }

  @override
  Future<void> startCapture({int sampleRate = 44100, int bufferSize = 1024}) async {
    _isCapturing = true;
    _generatorTimer?.cancel();

    // Generador periódico de prueba: Tono de 440 Hz (La4) a -12 dBFS
    double phase = 0.0;
    const freq = 440.0;
    final phaseIncrement = (2.0 * math.pi * freq) / sampleRate;

    _generatorTimer = Timer.periodic(const Duration(milliseconds: 23), (_) {
      if (!_isCapturing) return;

      final samples = Float32List(bufferSize);
      final rawBytes = Uint8List(bufferSize * 2);
      final byteData = ByteData.sublistView(rawBytes);

      for (int i = 0; i < bufferSize; i++) {
        final val = (math.sin(phase) * 0.25).clamp(-1.0, 1.0);
        samples[i] = val;
        byteData.setInt16(i * 2, (val * 32767.0).round(), Endian.little);
        phase += phaseIncrement;
        if (phase > 2.0 * math.pi) phase -= 2.0 * math.pi;
      }

      final frame = AudioPcmFrame.fromPcm16Bytes(
        bytes: rawBytes,
        sampleRate: sampleRate,
      );

      ringBuffer.write(frame.samples);

      if (!_pcmFrameController.isClosed) _pcmFrameController.add(frame);
      if (!_rmsDbController.isClosed) _rmsDbController.add(frame.rmsDb);
      if (!_peakDbController.isClosed) _peakDbController.add(frame.peakDb);
    });
  }

  @override
  Future<void> stopCapture() async {
    _isCapturing = false;
    _generatorTimer?.cancel();
    _generatorTimer = null;
    ringBuffer.clear();
  }

  /// Inyecta un cuadro de audio directamente para aserciones deterministas de test.
  void emitMockFrame(AudioPcmFrame frame) {
    ringBuffer.write(frame.samples);
    if (!_pcmFrameController.isClosed) _pcmFrameController.add(frame);
    if (!_rmsDbController.isClosed) _rmsDbController.add(frame.rmsDb);
    if (!_peakDbController.isClosed) _peakDbController.add(frame.peakDb);
  }

  @override
  void dispose() {
    stopCapture();
    _pcmFrameController.close();
    _rmsDbController.close();
    _peakDbController.close();
  }
}
