import 'dart:typed_data';
import 'tunner_project_manifest_entity.dart';
import 'tunner_project_package_entity.dart';

/// Contrato abstracto de dominio para la serialización y deserialización
/// de paquetes canónicos de proyectos Tunner (.tunner).
///
/// Define las operaciones fundamentales para:
/// 1. Empaquetar un `TunnerProjectPackageEntity` a un flujo de bytes binarios comprimidos.
/// 2. Desempaquetar un archivo `.tunner` y reconstruir el agregado de proyecto,
///    validando opcionalmente las firmas criptográficas de integridad SHA-256.
/// 3. Leer únicamente el manifiesto de un paquete sin requerir la descompresión
///    de las pistas de audio pesadas asociadas.
abstract class ITunnerPackageCodec {
  /// Codifica el paquete de proyecto completo en un flujo binario `.tunner` (ZIP).
  ///
  /// Calcula automáticamente los hashes criptográficos SHA-256 de cada archivo
  /// interno y los inyecta en el `manifest.json`.
  Uint8List encodePackage(TunnerProjectPackageEntity package);

  /// Decodifica un flujo binario `.tunner`, reconstruyendo el proyecto completo.
  ///
  /// Si [verifyHashes] es `true`, comprueba que el hash SHA-256 de cada archivo
  /// extraído coincida exactamente con el declarado en el manifiesto.
  /// Si se detecta una discrepancia, arroja `TunnerPackageCorruptedException`.
  TunnerProjectPackageEntity decodePackage(
    Uint8List packageBytes, {
    bool verifyHashes = true,
  });

  /// Lee e inspecciona únicamente el manifiesto `manifest.json` del paquete
  /// sin descomprimir el resto de contenidos o pistas de audio en memoria.
  TunnerProjectManifestEntity readManifest(Uint8List packageBytes);
}

/// Implementación nula / no-op en dominio puro para entornos sin códec configurado.
class NoOpTunnerPackageCodec implements ITunnerPackageCodec {
  const NoOpTunnerPackageCodec();

  @override
  Uint8List encodePackage(TunnerProjectPackageEntity package) => Uint8List(0);

  @override
  TunnerProjectPackageEntity decodePackage(
    Uint8List packageBytes, {
    bool verifyHashes = true,
  }) {
    throw UnsupportedError('No tunner package codec configured');
  }

  @override
  TunnerProjectManifestEntity readManifest(Uint8List packageBytes) {
    throw UnsupportedError('No tunner package codec configured');
  }
}
