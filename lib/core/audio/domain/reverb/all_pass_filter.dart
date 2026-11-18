import 'dart:typed_data';

/// Filtro paso-todo de Schroeder (Schroeder All-Pass Filter).
///
/// Modela una línea de retardo con dispersión de fase uniforme sin coloración de magnitud.
/// Satisface $|H(e^{j\omega})| = 1$ para toda frecuencia, incrementando la densidad de ecos.
class AllPassFilter {
  final Float32List _buffer;
  final int bufferSize;
  int _bufferIndex = 0;

  double feedback = 0.5;

  AllPassFilter(this.bufferSize, {this.feedback = 0.5}) : _buffer = Float32List(bufferSize);

  /// Procesa una muestra de audio flotante.
  double process(double input) {
    final bufOut = _buffer[_bufferIndex];

    // Salida canónica: y[n] = -input + x[n - D]
    final output = -input + bufOut;

    // Realimentación en la línea de retardo: x[n] = input + (bufOut * g)
    _buffer[_bufferIndex] = input + (bufOut * feedback);

    // Puntero circular determinista
    if (++_bufferIndex >= bufferSize) {
      _bufferIndex = 0;
    }

    return output;
  }

  /// Limpia el estado interno del búfer.
  void mute() {
    _buffer.fillRange(0, bufferSize, 0.0);
    _bufferIndex = 0;
  }
}
