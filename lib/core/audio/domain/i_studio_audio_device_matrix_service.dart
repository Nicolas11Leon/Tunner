import '../../domain/i_studio_listenable.dart';
import 'i_studio_audio_device_matrix_port.dart';
import 'i_studio_audio_engine.dart';
import 'i_studio_audio_hardware_persistence_service.dart';
import 'i_studio_audio_input_engine.dart';
import 'i_studio_master_capture_service.dart';
import 'studio_master_audio_mixer.dart';
import 'studio_master_biquad_filter.dart';
import 'studio_master_dynamics_processor.dart';

/// Contrato de dominio puro para el servicio integral de matriz de dispositivos
/// de audio, cadena de masterización DSP y captura maestra en vivo.
abstract class IStudioAudioDeviceMatrixService
    implements IStudioAudioDeviceMatrixPort, IStudioListenable {
  StudioStereoLevelMeterData get masterMeterData;
  Stream<StudioStereoLevelMeterData> get masterMeterStream;

  IStudioAudioEngine get outputEngine;
  IStudioAudioInputEngine get inputEngine;
  IStudioAudioHardwarePersistenceService? get persistenceService;
  IStudioMasterCaptureService get captureService;

  StudioMasterBiquadFilter get filterLow;
  StudioMasterBiquadFilter get filterMid;
  StudioMasterBiquadFilter get filterHigh;
  StudioMasterDynamicsProcessor get dynamicsProcessor;

  Future<void> selectInputDevice(String deviceId);
  Future<void> selectOutputDevice(String deviceId);

  void setMasterGain(double gain);
  void setMasterGainDb(double db);
  void toggleMute();
  void toggleDim();
  void toggleMono();
  void setBufferSize(int bufferSize);
  void setChannelRouting(String channelId, String destinationBus);

  void setEqLow(double db);
  void setEqMid(double db);
  void setEqHigh(double db);
  void toggleEqBypass();

  void setCompThreshold(double db);
  void setCompRatio(double ratio);
  void toggleCompBypass();

  Future<void> startMasterRecording(String destinationPath);
  Future<String?> stopMasterRecording();

  void dispose();
}
