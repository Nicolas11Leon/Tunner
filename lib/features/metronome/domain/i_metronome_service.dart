/// Contrato de dominio abstracto para el servicio de reloj y temporización determinista.
abstract class IMetronomeService {
  /// Callback invocado en cada sub-tick de alta resolución.
  Function(int currentSubTick)? onSubTick;

  /// Inicia el temporizador de reloj con el BPM y resolución deseada sin busy-waiting.
  Future<void> start(int bpm, {int ticksPerMeasure = 16});

  /// Detiene el reloj y libera los puertos de temporización en segundo plano.
  Future<void> stop();
}

/// Capacidad opcional de dominio para relojes que ajustan dinámicamente su acento por denominador de compás.
abstract class IMeteredMetronomeService implements IMetronomeService {
  Future<void> startWithMeter(int bpm, {int ticksPerMeasure = 16, int meterDenominator = 4});
}

/// Implementación nula / no-op en dominio puro para pruebas y entornos aislados.
class NoOpMetronomeService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}
