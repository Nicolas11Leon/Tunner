/// Zonas de anclaje para el sistema de acoplamiento y partición de ventanas tipo DAW.
enum StudioDockZone {
  /// Zona central principal (ocupa el espacio de trabajo primario).
  center,

  /// Panel dividido a la izquierda (columna vertical).
  left,

  /// Panel dividido a la derecha (columna vertical).
  right,

  /// Panel inferior acoplado (fila horizontal inferior).
  bottom,

  /// Ventana flotante desacoplada e independiente.
  floating,
}

extension StudioDockZoneExtension on StudioDockZone {
  String get displayName {
    switch (this) {
      case StudioDockZone.center:
        return 'Centro / Principal';
      case StudioDockZone.left:
        return 'Panel Izquierdo';
      case StudioDockZone.right:
        return 'Panel Derecho';
      case StudioDockZone.bottom:
        return 'Panel Inferior';
      case StudioDockZone.floating:
        return 'Ventana Flotante';
    }
  }
}
