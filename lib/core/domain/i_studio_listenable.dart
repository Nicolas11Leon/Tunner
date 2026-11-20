/// Tipo de callback sin argumentos en Dart puro para notificaciones de dominio.
typedef StudioVoidCallback = void Function();

/// Contrato observable agnóstico de framework para la capa de dominio.
/// Evita que los puertos de dominio dependan de `package:flutter/foundation.dart`.
abstract class IStudioListenable {
  void addListener(StudioVoidCallback listener);
  void removeListener(StudioVoidCallback listener);
}

/// Implementación mínima en Dart puro para objetos observables de dominio o NoOp.
mixin StudioPureNotifierMixin implements IStudioListenable {
  final List<StudioVoidCallback> _listeners = <StudioVoidCallback>[];
  bool _isDisposed = false;

  @override
  void addListener(StudioVoidCallback listener) {
    if (_isDisposed) return;
    _listeners.add(listener);
  }

  @override
  void removeListener(StudioVoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    if (_isDisposed) return;
    final snapshot = List<StudioVoidCallback>.of(_listeners, growable: false);
    for (final listener in snapshot) {
      listener();
    }
  }

  void dispose() {
    _isDisposed = true;
    _listeners.clear();
  }
}
