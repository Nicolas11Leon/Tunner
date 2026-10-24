/// Contrato de dominio abstracto para el servicio de reloj y temporización determinista.
abstract class IMetronomeService {
  /// Callback invocado en cada sub-tick de alta resolución.
  Function(int currentSubTick)? onSubTick;

  /// Inicia el temporizador de reloj con el BPM y resolución deseada sin busy-waiting.
  Future<void> start(int bpm, {int ticksPerMeasure = 16});

  /// Detiene el reloj y libera los puertos de temporización en segundo plano.
  Future<void> stop();
}
