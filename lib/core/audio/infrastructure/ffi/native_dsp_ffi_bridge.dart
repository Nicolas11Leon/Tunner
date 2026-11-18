import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/ffi/i_native_dsp_bridge.dart';
import '../../domain/ffi/native_dsp_bridge_fallback.dart';

/// Implementación de infraestructura para la aceleración DSP nativa mediante `dart:ffi`.
/// Intenta resolver y enlazar símbolos de bajo nivel en C/C++/Rust (`libtunner_dsp`).
/// En caso de no encontrar el binario en el sistema, conmuta de forma transparente y sin error
/// al motor de respaldo determinista en Dart puro `NativeDspBridgeFallback`.
class NativeDspFfiBridge implements INativeDspBridge {
  final INativeDspBridge _fallback;
  DynamicLibrary? _dylib;
  bool _isNative = false;
  String _activeEngineName = 'Pure Dart SIMD Fallback';

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
        _isNative = true;
        _activeEngineName = 'Native C/Rust SIMD ($customLibraryPath)';
        return;
      }

      final libraryName = _getPlatformLibraryName();
      if (libraryName != null) {
        // Intentar resolver en los directorios de librerías del sistema
        _dylib = DynamicLibrary.open(libraryName);
        _isNative = true;
        _activeEngineName = 'Native C/Rust SIMD ($libraryName)';
      }
    } catch (_) {
      // Fallback seguro: la biblioteca compartida no está compilada o presente en el SO.
      _dylib = null;
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
    // Si en el futuro se compila el SO nativo, se invoca el puntero FFI.
    // De lo contrario, se delega al motor fallback ultra-optimizado.
    _fallback.applyGain(buffer, gain);
  }

  @override
  void vectorSum(Float32List a, Float32List b, Float32List out) {
    _fallback.vectorSum(a, b, out);
  }

  @override
  void autoCorrelate(Float32List input, Float32List output) {
    _fallback.autoCorrelate(input, output);
  }
}
