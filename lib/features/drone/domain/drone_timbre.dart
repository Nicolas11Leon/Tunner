/// Timbres sonoros disponibles para la síntesis del tono pedal en el estudio de dron.
/// Pure Dart: Cero dependencias de Flutter UI.
enum DroneTimbre {
  /// Onda senoidal pura sin armonicos superiores, ideal para afinacion intervalica clinica.
  pureSine,

  /// Sonido calido y redondo con armonicos impares suaves semejante a una flauta o diapason acustico.
  warmFlute,

  /// Sonido rico en armonicos semejante a la cuerda frotada de un violonchelo o viola da gamba.
  richCello,

  /// Sonido denso y majestuoso semejante a un organo de tubos de catedral.
  organ,
}

extension DroneTimbreExtension on DroneTimbre {
  String get displayName {
    switch (this) {
      case DroneTimbre.pureSine:
        return 'Senoidal Pura';
      case DroneTimbre.warmFlute:
        return 'Flauta Calida';
      case DroneTimbre.richCello:
        return 'Cello / Cuerda';
      case DroneTimbre.organ:
        return 'Organo Tubular';
    }
  }

  String get description {
    switch (this) {
      case DroneTimbre.pureSine:
        return 'Tono puro sin armonicos para maxima claridad clinica';
      case DroneTimbre.warmFlute:
        return 'Armonicos suaves y redondeados para entrenamiento calido';
      case DroneTimbre.richCello:
        return 'Espectro armónico resonante para cuerdas y metales';
      case DroneTimbre.organ:
        return 'Densidad polifonica rica para soporte vocal y de vientos';
    }
  }
}
