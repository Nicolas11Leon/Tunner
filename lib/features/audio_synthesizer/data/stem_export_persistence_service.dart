import 'dart:io';
import '../domain/stem_export_entity.dart';

/// Servicio de infraestructura para escribir paquetes de stems y secuencias MIDI
/// en el almacenamiento local offline del dispositivo.
class StemExportPersistenceService {
  final Future<String> Function()? documentsPathProvider;

  StemExportPersistenceService({this.documentsPathProvider});

  /// Retorna el directorio base de exportaciones en el dispositivo.
  Future<Directory> getExportsDirectory({String? customSubfolder}) async {
    String basePath = "";
    if (documentsPathProvider != null) {
      basePath = await documentsPathProvider!();
    } else {
      basePath = Directory.systemTemp.path;
    }

    final folderName = customSubfolder ?? "tunner_exports";
    final targetDir = Directory('$basePath/exports/$folderName');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  /// Guarda en disco todos los archivos binarios contenidos en un [ExportBundleResult].
  /// Retorna la lista de rutas absolutas generadas.
  Future<List<String>> saveExportBundle(
    ExportBundleResult bundle, {
    String? customSubfolder,
  }) async {
    if (bundle.isEmpty) return [];

    final targetDir = await getExportsDirectory(customSubfolder: customSubfolder);
    final savedPaths = <String>[];

    for (final file in bundle.files) {
      final filePath = '${targetDir.path}/${file.fileName}';
      final ioFile = File(filePath);
      await ioFile.writeAsBytes(file.bytes, flush: true);
      savedPaths.add(filePath);
    }

    return savedPaths;
  }
}
