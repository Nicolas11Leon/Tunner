import 'dart:async';
import 'package:record/record.dart';
import '../domain/i_practice_recorder_service.dart';

/// Implementación de infraestructura para la grabación de audio de práctica utilizando el plugin [AudioRecorder].
/// Inicializa el plugin de forma diferida (lazy) para evitar llamadas tempranas a canales de plataforma.
class PracticeRecorderService implements IPracticeRecorderService {
  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();

  bool _isRecording = false;
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  Timer? _amplitudeTimer;

  PracticeRecorderService({AudioRecorder? recorder}) : _recorderInstance = recorder;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<void> startRecording({required String destinationPath}) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception("Permiso de micrófono no concedido por el sistema.");
    }

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
      numChannels: 1,
    );

    await _recorder.start(config, path: destinationPath);
    _isRecording = true;

    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!_isRecording) return;
      try {
        final amp = await _recorder.getAmplitude();
        final currentDb = amp.current;
        // dBFS típico: -160 dB a 0 dB. Rango audible útil: -60 dB a 0 dB.
        double normalized = 0.0;
        if (currentDb > -60.0) {
          normalized = ((currentDb + 60.0) / 60.0).clamp(0.0, 1.0);
        }
        if (!_amplitudeController.isClosed) {
          _amplitudeController.add(normalized);
        }
      } catch (_) {}
    });
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _isRecording = false;
    final path = await _recorder.stop();
    return path;
  }

  @override
  Future<void> pauseRecording() async {
    if (_isRecording) {
      await _recorder.pause();
    }
  }

  @override
  Future<void> resumeRecording() async {
    if (_isRecording) {
      await _recorder.resume();
    }
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudeController.close();
    _recorderInstance?.dispose();
  }
}
