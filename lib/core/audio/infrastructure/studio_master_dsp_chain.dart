import 'dart:typed_data';

import '../domain/ffi/i_native_dsp_bridge.dart';
import 'ffi/native_dsp_ffi_bridge.dart';

/// Resultado cuantitativo de la ejecución del benchmark determinista del motor DSP.
class DspBenchmarkResult {
  final String engineName;
  final bool isNative;
  final int iterations;
  final int blockSize;
  final int elapsedMicroseconds;
  final double throughputMegaSamplesPerSec;

  const DspBenchmarkResult({
    required this.engineName,
    required this.isNative,
    required this.iterations,
    required this.blockSize,
    required this.elapsedMicroseconds,
    required this.throughputMegaSamplesPerSec,
  });

  @override
  String toString() {
    return 'DspBenchmarkResult(engine: $engineName, native: $isNative, time: ${elapsedMicroseconds}us, throughput: ${throughputMegaSamplesPerSec.toStringAsFixed(2)} MSamples/s)';
  }
}

/// Orquestador de la cadena de masterización de audio y mezcla multicanal de Tunner Studio.
/// Integra el puente acelerador nativo FFI para ejecutar sumas vectoriales, atenuaciones
/// balísticas y cálculo de autocorrelación en tiempo real.
class StudioMasterDspChain {
  final INativeDspBridge _bridge;
  Float32List _scratchBuffer = Float32List(0);

  StudioMasterDspChain({
    INativeDspBridge? bridge,
  }) : _bridge = bridge ?? NativeDspFfiBridge();

  /// Acceso al puente DSP subyacente (nativo o fallback).
  INativeDspBridge get bridge => _bridge;

  Float32List _getScratchView(int length) {
    if (_scratchBuffer.length < length) {
      _scratchBuffer = Float32List(length);
    }
    return Float32List.sublistView(_scratchBuffer, 0, length);
  }

  /// Procesa un bloque de audio estéreo aplicando volumen maestro, mute, atenuación (dim)
  /// y colapso de fase monoaural mediante primitivas vectoriales aceleradas.
  void processMasterBlock(
    Float32List left,
    Float32List right, {
    double masterGain = 1.0,
    bool isMuted = false,
    bool isDimmed = false,
    bool isMono = false,
  }) {
    if (left.isEmpty || right.isEmpty) return;

    if (isMuted) {
      left.fillRange(0, left.length, 0.0);
      right.fillRange(0, right.length, 0.0);
      return;
    }

    final effectiveGain = masterGain * (isDimmed ? 0.35 : 1.0);

    if (isMono) {
      // Colapso monoaural: Out = 0.5 * (Left + Right) sobre la longitud mínima común
      final length = left.length < right.length ? left.length : right.length;
      final leftView = left.length == length ? left : Float32List.sublistView(left, 0, length);
      final rightView = right.length == length ? right : Float32List.sublistView(right, 0, length);
      final tempSum = _getScratchView(length);

      _bridge.vectorSum(leftView, rightView, tempSum);
      _bridge.applyGain(tempSum, 0.5 * effectiveGain);

      left.setRange(0, length, tempSum);
      right.setRange(0, length, tempSum);
    } else {
      if ((effectiveGain - 1.0).abs() > 0.0001) {
        _bridge.applyGain(left, effectiveGain);
        _bridge.applyGain(right, effectiveGain);
      }
    }
  }

  /// Suma linealmente un conjunto de canales de audio con sus respectivas ganancias ponderadas.
  /// Ideal para mezcla de stems, reproducción simultánea de metrónomo y pistas de audio.
  void mixChannels(
    List<Float32List> channels,
    List<double> gains,
    Float32List out,
  ) {
    if (channels.isEmpty || out.isEmpty) return;

    final outLength = out.length;
    out.fillRange(0, outLength, 0.0);

    for (int c = 0; c < channels.length; c++) {
      final ch = channels[c];
      final gain = c < gains.length ? gains[c] : 1.0;

      if (gain <= 0.00001 || ch.isEmpty) continue;

      final processLen = ch.length < outLength ? ch.length : outLength;
      final temp = _getScratchView(processLen);
      temp.setRange(0, processLen, ch);

      if ((gain - 1.0).abs() > 0.0001) {
        _bridge.applyGain(temp, gain);
      }

      final outView = processLen == outLength
          ? out
          : Float32List.sublistView(out, 0, processLen);
      _bridge.vectorSum(outView, temp, outView);
    }
  }

  /// Ejecuta autocorrelación directa en el dominio temporal para estimación de pitch fundamental.
  void computeCorrelations(Float32List input, Float32List output) {
    if (input.isEmpty || output.isEmpty) return;
    _bridge.autoCorrelate(input, output);
  }

  /// Ejecuta una prueba de rendimiento estandarizada para evaluar el rendimiento del motor
  /// en microsegundos y mega-muestras procesadas por segundo.
  DspBenchmarkResult runBenchmark({
    int iterations = 100,
    int blockSize = 2048,
  }) {
    final a = Float32List(blockSize);
    final b = Float32List(blockSize);
    final out = Float32List(blockSize);

    for (int i = 0; i < blockSize; i++) {
      a[i] = (i % 100) / 100.0;
      b[i] = ((i + 50) % 100) / 100.0;
    }

    final stopwatch = Stopwatch()..start();

    for (int iter = 0; iter < iterations; iter++) {
      _bridge.applyGain(a, 0.95);
      _bridge.vectorSum(a, b, out);
    }

    stopwatch.stop();
    final elapsedMicros = stopwatch.elapsedMicroseconds > 0 ? stopwatch.elapsedMicroseconds : 1;
    final totalSamples = iterations * blockSize * 2;
    final throughput = totalSamples / elapsedMicros; // Samples / us = MSamples / s

    return DspBenchmarkResult(
      engineName: _bridge.engineName,
      isNative: _bridge.isNativeAvailable,
      iterations: iterations,
      blockSize: blockSize,
      elapsedMicroseconds: elapsedMicros,
      throughputMegaSamplesPerSec: throughput,
    );
  }
}
