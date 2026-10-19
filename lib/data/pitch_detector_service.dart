import 'dart:async';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

class PitchDetectorService {
  final _audioRecorder = AudioRecorder();
  late PitchDetector _pitchDetector;
  StreamSubscription? _audioSubscription;
  
  Function(double)? onPitchDetected;

  PitchDetectorService() {
    _pitchDetector = PitchDetector();
  }

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // Configuración PCM óptima para navegadores y móviles
        final stream = await _audioRecorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ));

        _audioSubscription = stream.listen((data) {
          // Procesamiento asíncrono inmediato para no trabar la UI
          _pitchDetector.getPitchFromIntBuffer(data).then((pitchResult) {
            if (pitchResult.pitched && onPitchDetected != null) {
              // Filtro de frecuencias útil para flauta traversa (Rango: 200Hz - 3000Hz)
              if (pitchResult.pitch >= 200 && pitchResult.pitch <= 3000) {
                onPitchDetected!(pitchResult.pitch);
              }
            }
          });
        }, onError: (error) {
          print("Error en el flujo de audio: $error");
        });
      }
    } catch (e) {
      print("Error al inicializar micrófono: $e");
    }
  }

  Future<void> stopRecording() async {
    await _audioSubscription?.cancel();
    await _audioRecorder.stop();
  }
}