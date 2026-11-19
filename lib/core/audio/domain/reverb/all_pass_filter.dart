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

  /// Procesa una muestra de audio flotante según la forma canónica Direct Form II de Schroeder:
  /// $v[n] = x[n] + g \cdot w[n-D]$
  /// $y[n] = -g \cdot v[n] + w[n-D]$
  /// $w[n-D] \leftarrow v[n]$
  /// Garantiza $|H(e^{j\omega})| \equiv 1.0$ y conservación rigurosa de energía para toda frecuencia.
  double process(double input) {
    final bufOut = _buffer[_bufferIndex];
    final v = input + (bufOut * feedback);
    final output = -feedback * v + bufOut;
    _buffer[_bufferIndex] = v;

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
