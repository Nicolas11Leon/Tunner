import 'dart:async';
import 'dart:isolate';
import '../domain/i_metronome_service.dart';

/// Implementación de infraestructura para la temporización de alta resolución en Isolate de Dart.
/// Implementa [IMetronomeService], rinde el tiempo al sistema operativo sin busy-waiting
/// y libera determinísticamente el puerto e Isolate en cada llamada a [stop].
class MetronomeService implements IMeteredMetronomeService {
  Isolate? _isolate;
  ReceivePort? _fromIsolatePort;
  StreamSubscription<dynamic>? _portSubscription;
  int _generation = 0;

  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> startWithMeter(int bpm, {int ticksPerMeasure = 16, int meterDenominator = 4}) =>
      start(bpm, ticksPerMeasure: ticksPerMeasure, meterDenominator: meterDenominator);

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16, int meterDenominator = 4}) async {
    final int opGen = ++_generation;
    if (_isolate != null || _fromIsolatePort != null) {
      await stop();
      _generation = opGen;
    }

    final safeBpm = bpm.clamp(20, 300);
    final safeTicks = ticksPerMeasure.clamp(1, 64);
    final safeDenominator = meterDenominator.clamp(1, 16);

    final receivePort = ReceivePort();
    _fromIsolatePort = receivePort;
    _portSubscription = receivePort.listen((message) {
      if (opGen == _generation && message is int && onSubTick != null) {
        onSubTick!(message);
      }
    });

    try {
      final spawned = await Isolate.spawn(_highResolutionTicksLogic, {
        'port': receivePort.sendPort,
        'bpm': safeBpm,
        'ticksPerMeasure': safeTicks,
        'meterDenominator': safeDenominator,
      });
      if (opGen != _generation) {
        spawned.kill(priority: Isolate.immediate);
        return;
      }
      _isolate = spawned;
    } catch (_) {
      if (opGen == _generation) {
        await stop();
      }
      rethrow;
    }
  }

  /// Calcula la cantidad de sub-ticks de semicorchea (1/16) por unidad de pulso del denominador.
  /// - Denominador 2 (x/2 alla breve): 16.0 / 2 = 8.0 semicorcheas por blanca.
  /// - Denominador 4 (x/4 compas simple): 16.0 / 4 = 4.0 semicorcheas por negra.
  /// - Denominador 8 (6/8, 9/8, 12/8 compuesto): 16.0 / 8 = 2.0 semicorcheas por corchea.
  /// - Denominador 16 (x/16): 16.0 / 16 = 1.0 semicorchea por pulso.
  static double computeSubTicksPerBeat(int meterDenominator) {
    final safeDenominator = meterDenominator.clamp(1, 16);
    return 16.0 / safeDenominator;
  }

  static void _highResolutionTicksLogic(Map<String, dynamic> args) {
    final SendPort toMainPort = args['port'] as SendPort;
    final int bpm = ((args['bpm'] as int?) ?? 120).clamp(20, 300);
    final int ticksPerMeasure = ((args['ticksPerMeasure'] as int?) ?? 16).clamp(1, 64);
    final int meterDenominator = ((args['meterDenominator'] as int?) ?? 4).clamp(1, 16);

    final double subTicksPerBeat = computeSubTicksPerBeat(meterDenominator);
    final double intervalMicros = 60000000.0 / (bpm * subTicksPerBeat);
    final Stopwatch stopwatch = Stopwatch()..start();
    int totalEmitted = 0;

    void scheduleNext() {
      final int subTick = totalEmitted % ticksPerMeasure;
      toMainPort.send(subTick);
      totalEmitted++;

      final int targetMicros = (totalEmitted * intervalMicros).round();
      final int waitMicros = targetMicros - stopwatch.elapsedMicroseconds;
      Timer(Duration(microseconds: waitMicros > 0 ? waitMicros : 0), scheduleNext);
    }

    // Emision inmediata del pulso 1 en t=0 sin espera de polling
    scheduleNext();
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _portSubscription?.cancel();
    _portSubscription = null;
    _fromIsolatePort?.close();
    _fromIsolatePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  Future<void> dispose() => stop();
}
