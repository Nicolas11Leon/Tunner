import 'dart:async';
import 'package:flutter/foundation.dart';
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
          // 1. Noise Gate: calcular potencia acústica cuadrática media (RMS)
          // para descartar silencio o ruido ambiental antes de correr el detector
          if (data.isEmpty) return;
          
          double sumSquares = 0.0;
          for (int i = 0; i < data.length; i++) {
            double sample = data[i].toDouble();
            sumSquares += sample * sample;
          }
          double rms = (sumSquares / data.length);
          
          // Umbral mínimo de amplitud para evitar saltos con el ruido ambiente
          if (rms < 50.0) return;

          // 2. Procesamiento asíncrono de estimación de tono
          _pitchDetector.getPitchFromIntBuffer(data).then((pitchResult) {
            if (pitchResult.pitched && onPitchDetected != null) {
              // Rango acústico universal: A0 (27.5 Hz) a C8 (4186.0 Hz)
              // Cubre desde bajos profundos y voz humana hasta violín/piccolo
              if (pitchResult.pitch >= 27.5 && pitchResult.pitch <= 4186.0) {
                onPitchDetected!(pitchResult.pitch);
              }
            }
          });
        }, onError: (error) {
          debugPrint("Error en el flujo de audio: $error");
        });
      }
    } catch (e) {
      debugPrint("Error al inicializar micrófono: $e");
    }
  }

  Future<void> stopRecording() async {
    await _audioSubscription?.cancel();
    await _audioRecorder.stop();
  }
}