import 'dart:typed_data';

/// Puerto abstracto de dominio para proveer archivos semilla binarios al inicializar un workspace.
/// Evita que `core/file_system` dependa de sintetizadores o procesadores de `features/`.
abstract class IWorkspaceSeedProvider {
  /// Retorna un mapa `{rutaRelativa: bytesWav}` con los activos binarios iniciales.
  Future<Map<String, Uint8List>> buildSeedBinaryFiles();
}
