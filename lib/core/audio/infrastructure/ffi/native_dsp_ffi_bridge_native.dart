import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../../logging/domain/i_studio_logger.dart';
import '../../domain/ffi/i_native_dsp_bridge.dart';
import '../../domain/ffi/native_dsp_bridge_fallback.dart';

typedef _ApplyGainC = Void Function(Pointer<Float>, Int32, Float);
typedef _ApplyGainDart = void Function(Pointer<Float>, int, double);

typedef _VectorSumC = Void Function(Pointer<Float>, Pointer<Float>, Pointer<Float>, Int32);
typedef _VectorSumDart = void Function(Pointer<Float>, Pointer<Float>, Pointer<Float>, int);

typedef _AutoCorrelateC = Void Function(Pointer<Float>, Int32, Pointer<Float>, Int32);
typedef _AutoCorrelateDart = void Function(Pointer<Float>, int, Pointer<Float>, int);

class _NativeScratchPool {
  Pointer<Float>? ptrA;
  int capA = 0;

  Pointer<Float>? ptrB;
  int capB = 0;

  Pointer<Float>? ptrOut;
  int capOut = 0;

  void freeAll() {
    if (ptrA != null) {
      calloc.free(ptrA!);
      ptrA = null;
      capA = 0;
    }
    if (ptrB != null) {
      calloc.free(ptrB!);
      ptrB = null;
      capB = 0;
    }
    if (ptrOut != null) {
      calloc.free(ptrOut!);
      ptrOut = null;
      capOut = 0;
    }
  }
}

/// Implementación de infraestructura para la aceleración DSP nativa mediante `dart:ffi`.
/// Resuelve y enlaza símbolos de bajo nivel en C/C++ (`libtunner_dsp`).
/// Reutiliza un pool de memoria nativa preasignado para evitar sobrecarga de `calloc`/`free`
/// por cada bloque de audio, con liberación determinista vía `dispose()` y respaldo `Finalizer`.
class NativeDspFfiBridge implements INativeDspBridge {
  static final Finalizer<_NativeScratchPool> _finalizer = Finalizer<_NativeScratchPool>(
    (pool) => pool.freeAll(),
  );

  final INativeDspBridge _fallback;
  final IStudioLogger _logger;
  final _NativeScratchPool _pool = _NativeScratchPool();
  DynamicLibrary? _dylib;
  bool _isNative = false;
  bool _isDisposed = false;
  String _activeEngineName = 'Pure Dart SIMD Fallback';

  _ApplyGainDart? _applyGainNative;
  _VectorSumDart? _vectorSumNative;
  _AutoCorrelateDart? _autoCorrelateNative;

  /// Acceso opcional a la biblioteca dinámica cargada (para depuración o inspección).
  DynamicLibrary? get dynamicLibrary => _dylib;

  NativeDspFfiBridge({
    INativeDspBridge? fallback,
    String? customLibraryPath,
    IStudioLogger logger = const NoOpStudioLogger(),
  })  : _fallback = fallback ?? const NativeDspBridgeFallback(),
        _logger = logger {
    _finalizer.attach(this, _pool, detach: this);
    _initDynamicLibrary(customLibraryPath);
  }

  void _initDynamicLibrary(String? customLibraryPath) {
    try {
      if (customLibraryPath != null && customLibraryPath.isNotEmpty) {
        _dylib = DynamicLibrary.open(customLibraryPath);
      } else if (Platform.isIOS) {
        _dylib = DynamicLibrary.process();
      } else {
        final libraryName = _getPlatformLibraryName();
        if (libraryName != null) {
          final exeDir = File(Platform.resolvedExecutable).parent.path;
          final exeSibling = File('$exeDir${Platform.pathSeparator}$libraryName');
          final exeLibSibling = File(
            '$exeDir${Platform.pathSeparator}lib${Platform.pathSeparator}$libraryName',
          );
          final localFile = File(libraryName);

          if (exeSibling.existsSync()) {
            _dylib = DynamicLibrary.open(exeSibling.absolute.path);
          } else if (exeLibSibling.existsSync()) {
            _dylib = DynamicLibrary.open(exeLibSibling.absolute.path);
          } else if (localFile.existsSync()) {
            _dylib = DynamicLibrary.open(localFile.absolute.path);
          } else {
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
    } catch (e, st) {
      _logger.warning(
        'NativeDspFfiBridge',
        'Libreria nativa DSP no disponible, usando fallback Pure Dart: $e',
        error: e,
        stackTrace: st,
      );
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

  Pointer<Float> _ensureBufferA(int requiredLength) {
    if (_pool.ptrA == null || _pool.capA < requiredLength) {
      if (_pool.ptrA != null) calloc.free(_pool.ptrA!);
      _pool.ptrA = calloc<Float>(requiredLength);
      _pool.capA = requiredLength;
    }
    return _pool.ptrA!;
  }

  Pointer<Float> _ensureBufferB(int requiredLength) {
    if (_pool.ptrB == null || _pool.capB < requiredLength) {
      if (_pool.ptrB != null) calloc.free(_pool.ptrB!);
      _pool.ptrB = calloc<Float>(requiredLength);
      _pool.capB = requiredLength;
    }
    return _pool.ptrB!;
  }

  Pointer<Float> _ensureBufferOut(int requiredLength) {
    if (_pool.ptrOut == null || _pool.capOut < requiredLength) {
      if (_pool.ptrOut != null) calloc.free(_pool.ptrOut!);
      _pool.ptrOut = calloc<Float>(requiredLength);
      _pool.capOut = requiredLength;
    }
    return _pool.ptrOut!;
  }

  @override
  bool get isNativeAvailable => _isNative && !_isDisposed;

  @override
  String get engineName => _activeEngineName;

  @override
  void applyGain(Float32List buffer, double gain) {
    final fn = _applyGainNative;
    if (_isDisposed || !_isNative || fn == null || buffer.isEmpty) {
      _fallback.applyGain(buffer, gain);
      return;
    }

    final length = buffer.length;
    try {
      final ptr = _ensureBufferA(length);
      final nativeList = ptr.asTypedList(length);
      nativeList.setAll(0, buffer);
      fn(ptr, length, gain);
      buffer.setAll(0, nativeList);
    } catch (e, st) {
      _logger.warning(
        'NativeDspFfiBridge',
        'Fallback applyGain a Pure Dart: $e',
        error: e,
        stackTrace: st,
      );
      _fallback.applyGain(buffer, gain);
    }
  }

  @override
  void vectorSum(Float32List a, Float32List b, Float32List out) {
    final fn = _vectorSumNative;
    final lenAB = a.length < b.length ? a.length : b.length;
    final length = lenAB < out.length ? lenAB : out.length;
    if (_isDisposed || !_isNative || fn == null || length <= 0) {
      _fallback.vectorSum(a, b, out);
      return;
    }

    try {
      final ptrA = _ensureBufferA(length);
      final ptrB = _ensureBufferB(length);
      final ptrOut = _ensureBufferOut(length);
      ptrA.asTypedList(length).setRange(0, length, a);
      ptrB.asTypedList(length).setRange(0, length, b);
      fn(ptrA, ptrB, ptrOut, length);
      out.setRange(0, length, ptrOut.asTypedList(length));
    } catch (e, st) {
      _logger.warning(
        'NativeDspFfiBridge',
        'Fallback vectorSum a Pure Dart: $e',
        error: e,
        stackTrace: st,
      );
      _fallback.vectorSum(a, b, out);
    }
  }

  @override
  void autoCorrelate(Float32List input, Float32List output) {
    final fn = _autoCorrelateNative;
    if (_isDisposed || !_isNative || fn == null || input.isEmpty || output.isEmpty) {
      _fallback.autoCorrelate(input, output);
      return;
    }

    final inLen = input.length;
    final outLen = output.length;
    try {
      final ptrIn = _ensureBufferA(inLen);
      final ptrOut = _ensureBufferOut(outLen);
      ptrIn.asTypedList(inLen).setAll(0, input);
      fn(ptrIn, inLen, ptrOut, outLen);
      output.setAll(0, ptrOut.asTypedList(outLen));
    } catch (e, st) {
      _logger.warning(
        'NativeDspFfiBridge',
        'Fallback autoCorrelate a Pure Dart: $e',
        error: e,
        stackTrace: st,
      );
      _fallback.autoCorrelate(input, output);
    }
  }

  /// Libera determinísticamente los búferes nativos asignados.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _finalizer.detach(this);
    _pool.freeAll();
  }
}
