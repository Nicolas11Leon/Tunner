import 'dart:typed_data';

/// Filtro en peine con realimentación y amortiguación paso-bajo (Moorer Comb Filter).
///
/// Modela una línea de retardo con búfer circular preasignado y un filtro de un polo
/// en el lazo de feedback que simula la absorción acústica de frecuencias agudas.
class CombFilter {
  final Float32List _buffer;
  final int bufferSize;
  int _bufferIndex = 0;

  double feedback = 0.5;
  double damp = 0.5;
  double _filterStore = 0.0;

  CombFilter(this.bufferSize) : _buffer = Float32List(bufferSize);

  /// Procesa una muestra de audio flotante.
  double process(double input) {
    final output = _buffer[_bufferIndex];

    // Filtro paso-bajo de un polo en el lazo de amortiguación
    _filterStore = (output * (1.0 - damp)) + (_filterStore * damp);

    // Almacena en la línea de retardo la señal directa más la realimentada
    _buffer[_bufferIndex] = input + (_filterStore * feedback);

    // Puntero circular determinista
    if (++_bufferIndex >= bufferSize) {
      _bufferIndex = 0;
    }

    return output;
  }

  /// Limpia el estado interno del búfer para evitar colas de audio residuales.
  void mute() {
    _buffer.fillRange(0, bufferSize, 0.0);
    _filterStore = 0.0;
    _bufferIndex = 0;
  }
}
