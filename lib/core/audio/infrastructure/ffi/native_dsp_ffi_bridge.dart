import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../domain/ffi/i_native_dsp_bridge.dart';
import '../../domain/ffi/native_dsp_bridge_fallback.dart';

typedef _ApplyGainC = Void Function(Pointer<Float>, Int32, Float);
typedef _ApplyGainDart = void Function(Pointer<Float>, int, double);

typedef _VectorSumC = Void Function(Pointer<Float>, Pointer<Float>, Pointer<Float>, Int32);
typedef _VectorSumDart = void Function(Pointer<Float>, Pointer<Float>, Pointer<Float>, int);

typedef _AutoCorrelateC = Void Function(Pointer<Float>, Int32, Pointer<Float>, Int32);
typedef _AutoCorrelateDart = void Function(Pointer<Float>, int, Pointer<Float>, int);

/// Implementación de infraestructura para la aceleración DSP nativa mediante `dart:ffi`.
/// Resuelve y enlaza símbolos de bajo nivel en C/C++ (`libtunner_dsp`).
/// En caso de no encontrar el binario en el sistema, conmuta de forma transparente y determinista
/// al motor de respaldo en Dart puro `NativeDspBridgeFallback`.
class NativeDspFfiBridge implements INativeDspBridge {
  final INativeDspBridge _fallback;
  DynamicLibrary? _dylib;
  bool _isNative = false;
  String _activeEngineName = 'Pure Dart SIMD Fallback';

  _ApplyGainDart? _applyGainNative;
  _VectorSumDart? _vectorSumNative;
  _AutoCorrelateDart? _autoCorrelateNative;

  /// Acceso opcional a la biblioteca dinámica cargada (para depuración o inspección).
  DynamicLibrary? get dynamicLibrary => _dylib;

  NativeDspFfiBridge({
    INativeDspBridge? fallback,
    String? customLibraryPath,
  }) : _fallback = fallback ?? const NativeDspBridgeFallback() {
    _initDynamicLibrary(customLibraryPath);
  }

  void _initDynamicLibrary(String? customLibraryPath) {
    try {
      if (customLibraryPath != null && customLibraryPath.isNotEmpty) {
        _dylib = DynamicLibrary.open(customLibraryPath);
      } else {
        final libraryName = _getPlatformLibraryName();
        if (libraryName != null) {
          // Intentar resolver primero en el directorio de trabajo local
          final localFile = File(libraryName);
          if (localFile.existsSync()) {
            _dylib = DynamicLibrary.open(localFile.absolute.path);
          } else {
            // Intentar resolver en los directorios de librerías del sistema operativo
            _dylib = DynamicLibrary.open(libraryName);
          }
        }
      }

      if (_dylib != null) {
        _applyGainNative = _dylib!.lookupFunction<_ApplyGainC, _ApplyGainDart>(
          'tunner_apply_gain',
        );
        _vectorSumNative = _dylib!.lookupFunction<_VectorSumC, _VectorSumDart>(
          'tunner_vector_sum',
        );
        _autoCorrelateNative = _dylib!.lookupFunction<_AutoCorrelateC, _AutoCorrelateDart>(
          'tunner_autocorrelate',
        );

        _isNative = true;
        _activeEngineName = 'Native C/Rust SIMD (${customLibraryPath ?? _getPlatformLibraryName()})';
      }
    } catch (_) {
      // Fallback seguro: la biblioteca compartida no está compilada o presente en el SO.
      _dylib = null;
      _applyGainNative = null;
      _vectorSumNative = null;
      _autoCorrelateNative = null;
      _isNative = false;
      _activeEngineName = 'Pure Dart SIMD Fallback (Native dylib not found)';
    }
  }

  static String? _getPlatformLibraryName() {
    if (Platform.isLinux || Platform.isAndroid) {
      return 'libtunner_dsp.so';
    } else if (Platform.isMacOS || Platform.isIOS) {
      return 'libtunner_dsp.dylib';
    } else if (Platform.isWindows) {
      return 'tunner_dsp.dll';
    }
    return null;
  }

  @override
  bool get isNativeAvailable => _isNative;

  @override
  String get engineName => _activeEngineName;

  @override
  void applyGain(Float32List buffer, double gain) {
    if (!_isNative || _applyGainNative == null || buffer.isEmpty) {
      _fallback.applyGain(buffer, gain);
      return;
    }

    final length = buffer.length;
    final ptr = calloc<Float>(length);
    try {
      final nativeList = ptr.asTypedList(length);
      nativeList.setAll(0, buffer);
      _applyGainNative!(ptr, length, gain);
      buffer.setAll(0, nativeList);
    } catch (_) {
      _fallback.applyGain(buffer, gain);
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void vectorSum(Float32List a, Float32List b, Float32List out) {
    if (!_isNative || _vectorSumNative == null || a.isEmpty || a.length != b.length || a.length != out.length) {
      _fallback.vectorSum(a, b, out);
      return;
    }

    final length = a.length;
    final ptrA = calloc<Float>(length);
    final ptrB = calloc<Float>(length);
    final ptrOut = calloc<Float>(length);
    try {
      ptrA.asTypedList(length).setAll(0, a);
      ptrB.asTypedList(length).setAll(0, b);
      _vectorSumNative!(ptrA, ptrB, ptrOut, length);
      out.setAll(0, ptrOut.asTypedList(length));
    } catch (_) {
      _fallback.vectorSum(a, b, out);
    } finally {
      calloc.free(ptrA);
      calloc.free(ptrB);
      calloc.free(ptrOut);
    }
  }

  @override
  void autoCorrelate(Float32List input, Float32List output) {
    if (!_isNative || _autoCorrelateNative == null || input.isEmpty || output.isEmpty) {
      _fallback.autoCorrelate(input, output);
      return;
    }

    final inLen = input.length;
    final outLen = output.length;
    final ptrIn = calloc<Float>(inLen);
    final ptrOut = calloc<Float>(outLen);
    try {
      ptrIn.asTypedList(inLen).setAll(0, input);
      _autoCorrelateNative!(ptrIn, inLen, ptrOut, outLen);
      output.setAll(0, ptrOut.asTypedList(outLen));
    } catch (_) {
      _fallback.autoCorrelate(input, output);
    } finally {
      calloc.free(ptrIn);
      calloc.free(ptrOut);
    }
  }
}
