import 'dart:async';
import 'dart:isolate';
import '../domain/i_metronome_service.dart';

/// Implementación de infraestructura para la temporización de alta resolución en Isolate de Dart.
/// Implementa [IMetronomeService] y rinde el tiempo al sistema operativo sin busy-waiting.
class MetronomeService implements IMetronomeService {
  Isolate? _isolate;
  final ReceivePort _fromIsolatePort = ReceivePort();

  @override
  Function(int currentSubTick)? onSubTick;

  MetronomeService() {
    _fromIsolatePort.listen((message) {
      if (message is int && onSubTick != null) {
        onSubTick!(message);
      }
    });
  }

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {
    if (_isolate != null) await stop();
    _isolate = await Isolate.spawn(_highResolutionTicksLogic, {
      'port': _fromIsolatePort.sendPort,
      'bpm': bpm,
      'ticksPerMeasure': ticksPerMeasure,
    });
  }

  static void _highResolutionTicksLogic(Map<String, dynamic> args) {
    SendPort toMainPort = args['port'];
    int bpm = args['bpm'];
    int ticksPerMeasure = args['ticksPerMeasure'] ?? 16;
    
    // Intervalo exacto en microsegundos para resolución de semicorcheas
    // 60,000,000 microsegundos por minuto / bpm / 4
    int intervalMicros = (60000000 / bpm / 4).round();
    int subTickCounter = 0;

    // Timer.periodic rinde el tiempo al planificador del sistema operativo (0% busy-waiting)
    Timer.periodic(Duration(microseconds: intervalMicros), (timer) {
      toMainPort.send(subTickCounter);
      subTickCounter = (subTickCounter + 1) % ticksPerMeasure;
    });
  }

  @override
  Future<void> stop() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}
