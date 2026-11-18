import 'dart:math' as math;

/// Entidad inmutable que representa las coordenadas tridimensionales de una fuente sonora
/// y los parámetros físicos de la cabeza para el modelo acústico binaural.
class BinauralPannerEntity {
  /// Ángulo azimutal en el plano horizontal en grados [-180.0, 180.0].
  /// 0.0 = Frente, +90.0 = Derecha, -90.0 = Izquierda, +-180.0 = Detrás.
  final double azimuthDegrees;

  /// Ángulo de elevación en el plano vertical en grados [-90.0, 90.0].
  /// 0.0 = Nivel de los ojos, +90.0 = Cenit (arriba), -90.0 = Nadir (abajo).
  final double elevationDegrees;

  /// Distancia euclídea entre la fuente sonora y el centro de la cabeza en metros.
  /// Debe ser un valor estrictamente positivo.
  final double distanceMeters;

  /// Radio esférico de la cabeza humana en metros (por defecto 0.0875 m = 8.75 cm).
  final double headRadiusMeters;

  /// Velocidad de propagación del sonido en el aire en metros por segundo (343.0 m/s a 20°C).
  final double speedOfSoundMps;

  /// Constructor canónico con validación y valores acústicos estándar.
  const BinauralPannerEntity({
    this.azimuthDegrees = 0.0,
    this.elevationDegrees = 0.0,
    this.distanceMeters = 1.0,
    this.headRadiusMeters = 0.0875,
    this.speedOfSoundMps = 343.0,
  })  : assert(azimuthDegrees >= -180.0 && azimuthDegrees <= 180.0,
            'El azimut debe estar entre -180.0 y 180.0 grados'),
        assert(elevationDegrees >= -90.0 && elevationDegrees <= 90.0,
            'La elevacion debe estar entre -90.0 y 90.0 grados'),
        assert(distanceMeters > 0.0, 'La distancia debe ser estrictamente positiva'),
        assert(headRadiusMeters > 0.0, 'El radio de la cabeza debe ser positivo'),
        assert(speedOfSoundMps > 0.0, 'La velocidad del sonido debe ser positiva');

  /// Devuelve el ángulo azimutal en radianes.
  double get azimuthRadians => azimuthDegrees * (math.pi / 180.0);

  /// Devuelve el ángulo de elevación en radianes.
  double get elevationRadians => elevationDegrees * (math.pi / 180.0);

  /// Crea una copia inmutable actualizando únicamente los campos provistos.
  BinauralPannerEntity copyWith({
    double? azimuthDegrees,
    double? elevationDegrees,
    double? distanceMeters,
    double? headRadiusMeters,
    double? speedOfSoundMps,
  }) {
    return BinauralPannerEntity(
      azimuthDegrees: azimuthDegrees ?? this.azimuthDegrees,
      elevationDegrees: elevationDegrees ?? this.elevationDegrees,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      headRadiusMeters: headRadiusMeters ?? this.headRadiusMeters,
      speedOfSoundMps: speedOfSoundMps ?? this.speedOfSoundMps,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinauralPannerEntity &&
          runtimeType == other.runtimeType &&
          azimuthDegrees == other.azimuthDegrees &&
          elevationDegrees == other.elevationDegrees &&
          distanceMeters == other.distanceMeters &&
          headRadiusMeters == other.headRadiusMeters &&
          speedOfSoundMps == other.speedOfSoundMps;

  @override
  int get hashCode => Object.hash(
        azimuthDegrees,
        elevationDegrees,
        distanceMeters,
        headRadiusMeters,
        speedOfSoundMps,
      );

  @override
  String toString() =>
      'BinauralPannerEntity(azimuth: ${azimuthDegrees.toStringAsFixed(1)}°, '
      'elevation: ${elevationDegrees.toStringAsFixed(1)}°, '
      'distance: ${distanceMeters.toStringAsFixed(2)}m)';
}
