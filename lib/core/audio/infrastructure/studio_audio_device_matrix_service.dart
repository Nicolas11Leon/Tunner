import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/audio_device_entity.dart';
import '../domain/audio_device_matrix_entity.dart';
import '../domain/i_studio_audio_engine.dart';
import '../domain/i_studio_audio_input_engine.dart';
import '../domain/studio_master_audio_mixer.dart';

/// Servicio de infraestructura que gestiona la matriz de enrutamiento de dispositivos
/// y el estado de la consola maestra de audio de Tunner Studio.
class StudioAudioDeviceMatrixService extends ChangeNotifier {
  final IStudioAudioEngine _outputEngine;
  final IStudioAudioInputEngine _inputEngine;

  AudioDeviceMatrixEntity _matrix;
  StudioStereoLevelMeterData _masterMeterData = StudioStereoLevelMeterData.zero;

  Timer? _vuMeterSimulationTimer;
  final StreamController<StudioStereoLevelMeterData> _meterController =
      StreamController<StudioStereoLevelMeterData>.broadcast();

  StudioAudioDeviceMatrixService({
    required IStudioAudioEngine outputEngine,
    required IStudioAudioInputEngine inputEngine,
    AudioDeviceMatrixEntity? initialMatrix,
  })  : _outputEngine = outputEngine,
        _inputEngine = inputEngine,
        _matrix = initialMatrix ?? AudioDeviceMatrixEntity.defaultConfiguration() {
    _initHardwareEndpoints();
    _startMeterLoop();
  }

  AudioDeviceMatrixEntity get matrix => _matrix;
  StudioStereoLevelMeterData get masterMeterData => _masterMeterData;
  Stream<StudioStereoLevelMeterData> get masterMeterStream => _meterController.stream;

  IStudioAudioEngine get outputEngine => _outputEngine;
  IStudioAudioInputEngine get inputEngine => _inputEngine;

  Future<void> _initHardwareEndpoints() async {
    try {
      final inputDevices = await _inputEngine.listInputDevices();
      final outputDevices = _getAvailableOutputs();

      AudioDeviceEntity activeIn = _matrix.activeInputDevice;
      if (inputDevices.isNotEmpty) {
        activeIn = inputDevices.firstWhere(
          (d) => d.id == _matrix.activeInputDevice.id,
          orElse: () => inputDevices.first,
        );
      }

      AudioDeviceEntity activeOut = _matrix.activeOutputDevice;
      if (outputDevices.isNotEmpty) {
        activeOut = outputDevices.firstWhere(
          (d) => d.id == _matrix.activeOutputDevice.id,
          orElse: () => outputDevices.first,
        );
      }

      _matrix = _matrix.copyWith(
        availableInputs: inputDevices.isNotEmpty ? inputDevices : [AudioDeviceEntity.systemDefault()],
        availableOutputs: outputDevices,
        activeInputDevice: activeIn,
        activeOutputDevice: activeOut,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error inicializando endpoints de audio de hardware: $e');
    }
  }

  List<AudioDeviceEntity> _getAvailableOutputs() {
    return [
      AudioDeviceEntity.defaultOutput(),
      AudioDeviceEntity.cueHeadphones(),
      const AudioDeviceEntity(
        id: 'external_dac_usb',
        label: 'Interfaz USB / DAC Externo',
        direction: AudioDeviceDirection.output,
        channels: 2,
        supportedSampleRates: [44100, 48000, 96000],
      ),
    ];
  }

  /// Conmuta el dispositivo físico de captura de audio (Micrófono / Entrada de línea).
  Future<void> selectInputDevice(String deviceId) async {
    final dev = _matrix.availableInputs.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => AudioDeviceEntity(
        id: deviceId,
        label: 'Dispositivo $deviceId',
        direction: AudioDeviceDirection.input,
      ),
    );

    await _inputEngine.setInputDevice(deviceId);
    _matrix = _matrix.copyWith(activeInputDevice: dev);
    notifyListeners();
  }

  /// Conmuta el dispositivo físico de salida de audio (Monitores / Auriculares / DAC).
  Future<void> selectOutputDevice(String deviceId) async {
    final dev = _matrix.availableOutputs.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => AudioDeviceEntity(
        id: deviceId,
        label: 'Dispositivo $deviceId',
        direction: AudioDeviceDirection.output,
      ),
    );

    _matrix = _matrix.copyWith(activeOutputDevice: dev);
    notifyListeners();
  }

  /// Ajusta la ganancia lineal del bus maestro (0.0 a 1.5).
  void setMasterGain(double gain) {
    final clamped = gain.clamp(0.0, 1.5);
    _matrix = _matrix.copyWith(masterGain: clamped);
    _applyMasterGainToOutputs();
    notifyListeners();
  }

  /// Ajusta la ganancia maestra en decibelios (dB).
  void setMasterGainDb(double db) {
    final linear = StudioMasterAudioMixer.linearGainFromDb(db);
    setMasterGain(linear);
  }

  /// Conmuta el estado de silenciado instantáneo (Mute).
  void toggleMute() {
    _matrix = _matrix.copyWith(isMuted: !_matrix.isMuted);
    _applyMasterGainToOutputs();
    notifyListeners();
  }

  /// Conmuta la atenuación de escucha de referencia de -20 dB (DIM).
  void toggleDim() {
    _matrix = _matrix.copyWith(isDimmed: !_matrix.isDimmed);
    _applyMasterGainToOutputs();
    notifyListeners();
  }

  /// Conmuta el colapso de fase monoaural (MONO).
  void toggleMono() {
    _matrix = _matrix.copyWith(isMono: !_matrix.isMono);
    notifyListeners();
  }

  /// Configura el tamaño del búfer de audio (128, 256, 512, 1024 muestras).
  void setBufferSize(int bufferSize) {
    final validSize = [128, 256, 512, 1024].contains(bufferSize) ? bufferSize : 512;
    _matrix = _matrix.copyWith(bufferSize: validSize);
    notifyListeners();
  }

  /// Asigna un canal virtual a un bus de destino ('master' o 'cue').
  void setChannelRouting(String channelId, String destinationBus) {
    final currentRoutings = Map<String, String>.from(_matrix.channelRoutings);
    currentRoutings[channelId] = destinationBus;
    _matrix = _matrix.copyWith(channelRoutings: currentRoutings);
    notifyListeners();
  }

  void _applyMasterGainToOutputs() {
    // Escala los canales principales en función de la ganancia efectiva
    final effGain = _matrix.effectiveMasterGain;
    for (final channelId in ['dj_deck_a', 'dj_deck_b', 'metronome_click', 'practice_take']) {
      final ch = _outputEngine.getChannel(channelId);
      ch.setVolume(ch.volume * effGain);
    }
  }

  void _startMeterLoop() {
    _vuMeterSimulationTimer?.cancel();
    // Bucle a 60 FPS (~16.6 ms) para balística visual de vúmetro estéreo
    _vuMeterSimulationTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_meterController.isClosed) return;

      final effGain = _matrix.effectiveMasterGain;
      if (effGain <= 0.001) {
        _masterMeterData = StudioStereoLevelMeterData.zero;
      } else {
        // En ausencia de DSP nativo estéreo continuo, estimamos nivel ponderado
        final basePeak = (0.75 * effGain).clamp(0.0, 1.2);
        final basePeakDb = StudioMasterAudioMixer.dbFromLinearGain(basePeak);
        _masterMeterData = StudioStereoLevelMeterData(
          leftRms: 0.60 * effGain,
          rightRms: 0.62 * effGain,
          leftPeakDb: basePeakDb,
          rightPeakDb: basePeakDb + 0.2,
          isClipping: basePeakDb >= StudioMasterAudioMixer.clippingThresholdDb,
        );
      }
      _meterController.add(_masterMeterData);
    });
  }

  @override
  void dispose() {
    _vuMeterSimulationTimer?.cancel();
    _meterController.close();
    super.dispose();
  }
}
