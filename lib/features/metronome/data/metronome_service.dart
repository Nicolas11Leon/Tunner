import 'dart:async';
import 'dart:isolate';
import '../domain/i_metronome_service.dart';

/// Implementación de infraestructura para la temporización de alta resolución en Isolate de Dart.
/// Implementa [IMetronomeService], rinde el tiempo al sistema operativo sin busy-waiting
/// y libera determinísticamente el puerto e Isolate en cada llamada a [stop].
class MetronomeService implements IMetronomeService {
  Isolate? _isolate;
  ReceivePort? _fromIsolatePort;
  StreamSubscription<dynamic>? _portSubscription;

  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16, int meterDenominator = 4}) async {
    if (_isolate != null || _fromIsolatePort != null) {
      await stop();
    }

    final safeBpm = bpm.clamp(20, 300);
    final safeTicks = ticksPerMeasure.clamp(1, 64);
    final safeDenominator = meterDenominator.clamp(1, 16);

    final receivePort = ReceivePort();
    _fromIsolatePort = receivePort;
    _portSubscription = receivePort.listen((message) {
      if (message is int && onSubTick != null) {
        onSubTick!(message);
      }
    });

    try {
      _isolate = await Isolate.spawn(_highResolutionTicksLogic, {
        'port': receivePort.sendPort,
        'bpm': safeBpm,
        'ticksPerMeasure': safeTicks,
        'meterDenominator': safeDenominator,
      });
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  static void _highResolutionTicksLogic(Map<String, dynamic> args) {
    final SendPort toMainPort = args['port'] as SendPort;
    final int bpm = ((args['bpm'] as int?) ?? 120).clamp(20, 300);
    final int ticksPerMeasure = ((args['ticksPerMeasure'] as int?) ?? 16).clamp(1, 64);
    final int meterDenominator = ((args['meterDenominator'] as int?) ?? 4).clamp(1, 16);

    // Intervalo exacto en microsegundos para resolución de subdivisión métrica:
    // 60,000,000 microsegundos por minuto / bpm / 4 (o escalado por denominador si difiere de 4)
    final double denominatorFactor = meterDenominator == 8 ? 1.0 : (meterDenominator / 4.0);
    final int intervalMicros = (60000000 / (bpm * denominatorFactor * 4)).round();
    final Stopwatch stopwatch = Stopwatch()..start();
    int nextTickMicros = 0;
    int subTickCounter = 0;

    // Timer.periodic rinde el tiempo al planificador del sistema operativo (0% busy-waiting)
    // con compensación por Stopwatch para evitar deriva temporal acumulativa.
    final int pollMicros = intervalMicros < 2000 ? intervalMicros : 2000;
    Timer.periodic(Duration(microseconds: pollMicros), (timer) {
      final elapsed = stopwatch.elapsedMicroseconds;
      if (elapsed >= nextTickMicros) {
        toMainPort.send(subTickCounter);
        subTickCounter = (subTickCounter + 1) % ticksPerMeasure;
        nextTickMicros += intervalMicros;
        if (nextTickMicros < elapsed) {
          nextTickMicros = elapsed + intervalMicros;
        }
      }
    });
  }

  @override
  Future<void> stop() async {
    await _portSubscription?.cancel();
    _portSubscription = null;
    _fromIsolatePort?.close();
    _fromIsolatePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}
