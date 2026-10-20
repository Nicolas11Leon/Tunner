import 'dart:async';
import 'dart:isolate';

class MetronomeService {
  Isolate? _isolate;
  final ReceivePort _fromIsolatePort = ReceivePort();
  Function(int currentSubTick)? onSubTick;

  MetronomeService() {
    _fromIsolatePort.listen((message) {
      if (message is int && onSubTick != null) {
        onSubTick!(message);
      }
    });
  }

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

  Future<void> stop() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}