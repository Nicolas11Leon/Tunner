/// Excepciones formales de dominio para el subsistema de empaquetado
/// canónico de proyectos Tunner (.tunner).
library;

/// Se dispara cuando el contenedor binario no puede ser interpretado como
/// un archivo ZIP o carece del manifiesto obligatorio `manifest.json`.
class TunnerPackageInvalidFormatException implements Exception {
  final String message;
  final String? path;

  const TunnerPackageInvalidFormatException(this.message, {this.path});

  @override
  String toString() {
    if (path != null) {
      return 'TunnerPackageInvalidFormatException: $message (en "$path")';
    }
    return 'TunnerPackageInvalidFormatException: $message';
  }
}

/// Se dispara cuando la comprobación criptográfica SHA-256 de uno o más
/// archivos contenidos en el paquete `.tunner` no coincide con el digest
/// registrado en el `manifest.json`, evidenciando daño de almacenamiento
/// o manipulación externa no autorizada.
class TunnerPackageCorruptedException implements Exception {
  final String filePath;
  final String expectedHash;
  final String actualHash;

  const TunnerPackageCorruptedException({
    required this.filePath,
    required this.expectedHash,
    required this.actualHash,
  });

  @override
  String toString() {
    return 'TunnerPackageCorruptedException: Integridad violada en "$filePath". '
        'Hash esperado: $expectedHash, Hash calculado: $actualHash';
  }
}
