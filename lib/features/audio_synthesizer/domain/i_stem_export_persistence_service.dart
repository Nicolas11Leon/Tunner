import '../domain/stem_export_entity.dart';

/// Contrato abstracto de dominio para persistir paquetes de stems exportados.
abstract class IStemExportPersistenceService {
  Future<List<String>> saveExportBundle(
    ExportBundleResult bundle, {
    String? customSubfolder,
  });
}

/// Implementación No-Op en memoria para pruebas aisladas sin escritura en disco.
class NoOpStemExportPersistenceService implements IStemExportPersistenceService {
  const NoOpStemExportPersistenceService();

  @override
  Future<List<String>> saveExportBundle(
    ExportBundleResult bundle, {
    String? customSubfolder,
  }) async =>
      const [];
}
