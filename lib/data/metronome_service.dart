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

  Future<void> start(int bpm) async {
    if (_isolate != null) await stop();
    _isolate = await Isolate.spawn(_highResolutionTicksLogic, {
      'port': _fromIsolatePort.sendPort,
      'bpm': bpm,
    });
  }

  static void _highResolutionTicksLogic(Map<String, dynamic> args) {
    SendPort toMainPort = args['port'];
    int bpm = args['bpm'];
    
    // Calculamos el intervalo para semicorcheas (4 ticks por cada negra)
    double intervalMs = (60000 / bpm) / 4;
    
    final stopwatch = Stopwatch()..start();
    int nextTick = stopwatch.elapsedMilliseconds;
    int subTickCounter = 0; // Va de 0 a 15 (16 pasos)

    while (true) {
      int now = stopwatch.elapsedMilliseconds;
      if (now >= nextTick) {
        toMainPort.send(subTickCounter);
        subTickCounter = (subTickCounter + 1) % 16;
        nextTick += intervalMs.round();
      }
    }
  }

  Future<void> stop() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}