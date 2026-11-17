import 'dart:math' as math;
import 'dart:typed_data';

/// Ring Buffer circular lock-free de alto rendimiento para flujos continuos de audio PCM.
/// Diseñado con capacidad de potencia de dos ($2^k$) para indexación binaria rápida mediante máscaras bitwise.
class AudioRingBuffer {
  final int capacity;
  final int _mask;
  final Float32List _buffer;

  int _writePointer = 0;
  int _readPointer = 0;

  AudioRingBuffer({int requestedCapacity = 8192})
      : capacity = _nextPowerOfTwo(requestedCapacity),
        _mask = _nextPowerOfTwo(requestedCapacity) - 1,
        _buffer = Float32List(_nextPowerOfTwo(requestedCapacity));

  static int _nextPowerOfTwo(int value) {
    if (value <= 2) return 2;
    int v = value - 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    return v + 1;
  }

  /// Cantidad de muestras disponibles para lectura inmediata.
  int get availableRead => _writePointer - _readPointer;

  /// Capacidad disponible para escritura sin sobreescribir datos no leídos.
  int get availableWrite => capacity - availableRead;

  /// Escribe un arreglo de muestras en el buffer circular.
  /// Si el espacio disponible es menor que la longitud de los datos, escribe el máximo posible.
  int write(Float32List data) {
    final toWrite = math.min(data.length, availableWrite);
    for (int i = 0; i < toWrite; i++) {
      _buffer[(_writePointer + i) & _mask] = data[i];
    }
    _writePointer += toWrite;
    return toWrite;
  }

  /// Lee muestras del buffer y las deposita en [target].
  /// Retorna el número real de muestras leídas.
  int read(Float32List target) {
    final toRead = math.min(target.length, availableRead);
    for (int i = 0; i < toRead; i++) {
      target[i] = _buffer[(_readPointer + i) & _mask];
    }
    _readPointer += toRead;
    return toRead;
  }

  /// Lee muestras sin avanzar el puntero de lectura (inspección / lookahead).
  int peek(Float32List target) {
    final toRead = math.min(target.length, availableRead);
    for (int i = 0; i < toRead; i++) {
      target[i] = _buffer[(_readPointer + i) & _mask];
    }
    return toRead;
  }

  /// Restablece los punteros de lectura y escritura a cero.
  void clear() {
    _writePointer = 0;
    _readPointer = 0;
    _buffer.fillRange(0, _buffer.length, 0.0);
  }
}
