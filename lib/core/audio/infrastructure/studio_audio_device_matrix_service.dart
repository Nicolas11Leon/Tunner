import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../logging/infrastructure/studio_debug_logger.dart';
import '../domain/audio_device_entity.dart';
import '../domain/audio_device_matrix_entity.dart';
import '../domain/i_studio_audio_device_matrix_port.dart';
import '../domain/i_studio_audio_engine.dart';
import '../domain/i_studio_audio_hardware_persistence_service.dart';
import '../domain/i_studio_audio_input_engine.dart';
import '../domain/i_studio_master_capture_service.dart';
import '../domain/studio_master_audio_mixer.dart';
import '../domain/studio_master_biquad_filter.dart';
import '../domain/studio_master_dynamics_processor.dart';
import 'studio_master_capture_service.dart';

/// Servicio de infraestructura que gestiona la matriz de enrutamiento de dispositivos,
/// la cadena de masterización DSP y la captura de audio en vivo de Tunner Studio.
class StudioAudioDeviceMatrixService extends ChangeNotifier implements IStudioAudioDeviceMatrixPort {
  final IStudioAudioEngine _outputEngine;
  final IStudioAudioInputEngine _inputEngine;
  final IStudioAudioHardwarePersistenceService? _persistenceService;
  final IStudioMasterCaptureService _captureService;

  AudioDeviceMatrixEntity _matrix;
  StudioStereoLevelMeterData _masterMeterData = StudioStereoLevelMeterData.zero;

  // Cadena DSP de Masterización
  late StudioMasterBiquadFilter _filterLow;
  late StudioMasterBiquadFilter _filterMid;
  late StudioMasterBiquadFilter _filterHigh;
  late StudioMasterDynamicsProcessor _dynamicsProcessor;

  Timer? _vuMeterSimulationTimer;
  bool _isDisposed = false;
  final StreamController<StudioStereoLevelMeterData> _meterController =
      StreamController<StudioStereoLevelMeterData>.broadcast();

  StudioAudioDeviceMatrixService({
    required IStudioAudioEngine outputEngine,
    required IStudioAudioInputEngine inputEngine,
    IStudioAudioHardwarePersistenceService? persistenceService,
    IStudioMasterCaptureService? captureService,
    AudioDeviceMatrixEntity? initialMatrix,
  })  : _outputEngine = outputEngine,
        _inputEngine = inputEngine,
        _persistenceService = persistenceService,
        _captureService = captureService ?? StudioMasterCaptureService(),
        _matrix = initialMatrix ?? AudioDeviceMatrixEntity.defaultConfiguration() {
    _initDspChain();
    _initHardwareEndpoints();
    _startMeterLoop();
  }

  @override
  AudioDeviceMatrixEntity get matrix => _matrix;
  StudioStereoLevelMeterData get masterMeterData => _masterMeterData;
  Stream<StudioStereoLevelMeterData> get masterMeterStream => _meterController.stream;

  IStudioAudioEngine get outputEngine => _outputEngine;
  IStudioAudioInputEngine get inputEngine => _inputEngine;
  IStudioAudioHardwarePersistenceService? get persistenceService => _persistenceService;
  IStudioMasterCaptureService get captureService => _captureService;

  StudioMasterBiquadFilter get filterLow => _filterLow;
  StudioMasterBiquadFilter get filterMid => _filterMid;
  StudioMasterBiquadFilter get filterHigh => _filterHigh;
  StudioMasterDynamicsProcessor get dynamicsProcessor => _dynamicsProcessor;

  void _initDspChain() {
    _filterLow = StudioMasterBiquadFilter.lowShelf(
      frequency: 100.0,
      gainDb: _matrix.eqLowDb,
      sampleRate: _matrix.sampleRate,
    );
    _filterMid = StudioMasterBiquadFilter.peaking(
      frequency: 1000.0,
      gainDb: _matrix.eqMidDb,
      q: 1.0,
      sampleRate: _matrix.sampleRate,
    );
    _filterHigh = StudioMasterBiquadFilter.highShelf(
      frequency: 8000.0,
      gainDb: _matrix.eqHighDb,
      sampleRate: _matrix.sampleRate,
    );
    _dynamicsProcessor = StudioMasterDynamicsProcessor(
      thresholdDb: _matrix.compThresholdDb,
      ratio: _matrix.compRatio,
      sampleRate: _matrix.sampleRate,
    );
  }

  Future<void> _initHardwareEndpoints() async {
    try {
      final persistence = _persistenceService;
      if (persistence != null) {
        final saved = await persistence.loadMatrix();
        _matrix = _matrix.copyWith(
          bufferSize: saved.bufferSize,
          sampleRate: saved.sampleRate,
          masterGain: saved.masterGain,
          isMuted: saved.isMuted,
          isDimmed: saved.isDimmed,
          isMono: saved.isMono,
          channelRoutings: saved.channelRoutings,
          activeInputDevice: saved.activeInputDevice,
          activeOutputDevice: saved.activeOutputDevice,
          cueOutputDevice: saved.cueOutputDevice,
          eqLowDb: saved.eqLowDb,
          eqMidDb: saved.eqMidDb,
          eqHighDb: saved.eqHighDb,
          isEqBypassed: saved.isEqBypassed,
          compThresholdDb: saved.compThresholdDb,
          compRatio: saved.compRatio,
          isCompBypassed: saved.isCompBypassed,
        );
        _initDspChain();
        _applyMasterGainToOutputs();
      }

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
      StudioDebugLogger.instance.warning('StudioAudioDeviceMatrixService', 'Error inicializando endpoints de audio de hardware: $e');
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

  void _persistState() {
    _persistenceService?.saveMatrix(_matrix);
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
    _persistState();
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
    _persistState();
    notifyListeners();
  }

  /// Ajusta la ganancia lineal del bus maestro (0.0 a 1.5).
  void setMasterGain(double gain) {
    final clamped = gain.clamp(0.0, 1.5);
    _matrix = _matrix.copyWith(masterGain: clamped);
    _applyMasterGainToOutputs();
    _persistState();
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
    _persistState();
    notifyListeners();
  }

  /// Conmuta la atenuación de escucha de referencia de -20 dB (DIM).
  void toggleDim() {
    _matrix = _matrix.copyWith(isDimmed: !_matrix.isDimmed);
    _applyMasterGainToOutputs();
    _persistState();
    notifyListeners();
  }

  /// Conmuta el colapso de fase monoaural (MONO).
  void toggleMono() {
    _matrix = _matrix.copyWith(isMono: !_matrix.isMono);
    _persistState();
    notifyListeners();
  }

  /// Configura el tamaño del búfer de audio (128, 256, 512, 1024 muestras).
  void setBufferSize(int bufferSize) {
    final validSize = [128, 256, 512, 1024].contains(bufferSize) ? bufferSize : 512;
    _matrix = _matrix.copyWith(bufferSize: validSize);
    _persistState();
    notifyListeners();
  }

  /// Restaura de forma atómica una configuración completa de matriz de audio.
  @override
  void restoreMatrix(AudioDeviceMatrixEntity newMatrix) {
    _matrix = newMatrix;
    _initDspChain();
    _applyMasterGainToOutputs();
    _persistState();
    notifyListeners();
  }

  /// Asigna un canal virtual a un bus de destino ('master', 'cue' o 'mute').
  void setChannelRouting(String channelId, String destinationBus) {
    final currentRoutings = Map<String, String>.from(_matrix.channelRoutings);
    currentRoutings[channelId] = destinationBus;
    _matrix = _matrix.copyWith(channelRoutings: currentRoutings);
    _applyMasterGainToOutputs();
    _persistState();
    notifyListeners();
  }

  /// Ajusta la ganancia de graves del ecualizador maestro en dB (Low Shelf a 100 Hz, -12 a +12 dB).
  void setEqLow(double db) {
    final clamped = db.clamp(-12.0, 12.0);
    _matrix = _matrix.copyWith(eqLowDb: clamped);
    _filterLow.updateParameters(
      frequency: 100.0,
      gainDb: clamped,
      sampleRate: _matrix.sampleRate,
    );
    _persistState();
    notifyListeners();
  }

  /// Ajusta la ganancia de medios del ecualizador maestro en dB (Peaking Bell a 1 kHz, -12 a +12 dB).
  void setEqMid(double db) {
    final clamped = db.clamp(-12.0, 12.0);
    _matrix = _matrix.copyWith(eqMidDb: clamped);
    _filterMid.updateParameters(
      frequency: 1000.0,
      gainDb: clamped,
      q: 1.0,
      sampleRate: _matrix.sampleRate,
    );
    _persistState();
    notifyListeners();
  }

  /// Ajusta la ganancia de agudos del ecualizador maestro en dB (High Shelf a 8 kHz, -12 a +12 dB).
  void setEqHigh(double db) {
    final clamped = db.clamp(-12.0, 12.0);
    _matrix = _matrix.copyWith(eqHighDb: clamped);
    _filterHigh.updateParameters(
      frequency: 8000.0,
      gainDb: clamped,
      sampleRate: _matrix.sampleRate,
    );
    _persistState();
    notifyListeners();
  }

  /// Alterna el bypass del ecualizador maestro.
  void toggleEqBypass() {
    _matrix = _matrix.copyWith(isEqBypassed: !_matrix.isEqBypassed);
    _persistState();
    notifyListeners();
  }

  /// Ajusta el umbral del compresor de masterización en dB (-30 a 0 dB).
  void setCompThreshold(double db) {
    final clamped = db.clamp(-30.0, 0.0);
    _matrix = _matrix.copyWith(compThresholdDb: clamped);
    _dynamicsProcessor = StudioMasterDynamicsProcessor(
      thresholdDb: clamped,
      ratio: _matrix.compRatio,
      sampleRate: _matrix.sampleRate,
    );
    _persistState();
    notifyListeners();
  }

  /// Ajusta la relación de compresión (Ratio 1:1 a 20:1).
  void setCompRatio(double ratio) {
    final clamped = ratio.clamp(1.0, 20.0);
    _matrix = _matrix.copyWith(compRatio: clamped);
    _dynamicsProcessor = StudioMasterDynamicsProcessor(
      thresholdDb: _matrix.compThresholdDb,
      ratio: clamped,
      sampleRate: _matrix.sampleRate,
    );
    _persistState();
    notifyListeners();
  }

  /// Alterna el bypass del compresor maestro.
  void toggleCompBypass() {
    _matrix = _matrix.copyWith(isCompBypassed: !_matrix.isCompBypassed);
    _persistState();
    notifyListeners();
  }

  /// Inicia la captura maestra en vivo a un archivo WAV PCM.
  Future<void> startMasterRecording(String destinationPath) async {
    await _captureService.startCapture(
      destinationPath: destinationPath,
      sampleRate: _matrix.sampleRate,
      channels: 2,
    );
    _matrix = _matrix.copyWith(isMasterRecording: true);
    notifyListeners();
  }

  /// Detiene la captura maestra en vivo y finaliza el archivo WAV.
  Future<String?> stopMasterRecording() async {
    final path = await _captureService.stopCapture();
    _matrix = _matrix.copyWith(isMasterRecording: false);
    notifyListeners();
    return path;
  }

  void _applyMasterGainToOutputs() {
    final effGain = _matrix.effectiveMasterGain;
    for (final channelId in _matrix.channelRoutings.keys) {
      final routing = _matrix.channelRoutings[channelId] ?? 'master';
      final ch = _outputEngine.getChannel(channelId);
      if (routing == 'mute') {
        ch.setVolume(0.0);
      } else if (routing == 'cue') {
        ch.setVolume(0.85);
      } else {
        ch.setVolume((1.0 * effGain).clamp(0.0, 1.0));
      }
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
        final grDb = _matrix.isCompBypassed ? 0.0 : _dynamicsProcessor.currentGainReductionDb;
        _masterMeterData = StudioStereoLevelMeterData(
          leftRms: 0.60 * effGain,
          rightRms: 0.62 * effGain,
          leftPeakDb: basePeakDb,
          rightPeakDb: basePeakDb + 0.2,
          isClipping: basePeakDb >= StudioMasterAudioMixer.clippingThresholdDb,
          gainReductionDb: grDb,
        );
      }
      _meterController.add(_masterMeterData);
    });
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _vuMeterSimulationTimer?.cancel();
    _vuMeterSimulationTimer = null;
    _meterController.close();
    _captureService.dispose();
    super.dispose();
  }
}
