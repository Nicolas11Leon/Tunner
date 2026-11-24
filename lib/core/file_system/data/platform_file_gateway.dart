import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/i_platform_file_gateway.dart';

/// Implementación concreta de infraestructura para selector nativo de archivos,
/// exploración local didáctica y rutas de documentos.
class PlatformFileGateway
    implements IPlatformFileGateway, IStudioDiskBrowserGateway {
  const PlatformFileGateway();

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async {
    final normalizedExts = allowedExtensions
        ?.expand((e) => <String>[e.toLowerCase(), e.toUpperCase()])
        .toSet()
        .toList();

    // En Linux (zenity/kdialog/portal), FileType.custom con listas largas de
    // extensiones mixtas puede bloquear el filtro a un solo tipo (p. ej. PDF).
    // Para selectores multi-formato usamos FileType.any para mostrar MP3, WAV,
    // MusicXML, MIDI, ABC y PDF sin restricciones.
    final useCustomFilter = normalizedExts != null &&
        normalizedExts.isNotEmpty &&
        (!Platform.isLinux || normalizedExts.length <= 2);

    final files = await FilePicker.pickFiles(
      type: useCustomFilter ? FileType.custom : FileType.any,
      allowedExtensions: useCustomFilter ? normalizedExts : null,
    );

    if (files.isEmpty) return null;
    final picked = files.first;
    final bytes = await picked.readAsBytes();
    return PlatformPickedFile(
      name: picked.name,
      path: picked.path,
      bytes: bytes,
    );
  }

  @override
  Future<String> getDocumentsDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  @override
  Future<String> getTemporaryDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  /// Guarda bytes exportados (MIDI, PDF, MusicXML) en el directorio de documentos del dispositivo.
  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async {
    final dirPath = await getDocumentsDirectoryPath();
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('$dirPath${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<List<StudioQuickDirectory>> getQuickDirectories() async {
    final results = <StudioQuickDirectory>[];
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

    if (home != null && home.isNotEmpty) {
      final candidates = <(String label, List<String> subdirs, String icon)>[
        ('Música', ['Música', 'Music'], 'music'),
        ('Descargas', ['Descargas', 'Downloads'], 'downloads'),
        ('Documentos', ['Documentos', 'Documents'], 'docs'),
        ('Escritorio', ['Escritorio', 'Desktop'], 'desktop'),
      ];
      for (final (label, subdirs, icon) in candidates) {
        for (final sub in subdirs) {
          final dir = Directory('$home${Platform.pathSeparator}$sub');
          if (await dir.exists()) {
            results.add(StudioQuickDirectory(
              label: label,
              path: dir.path,
              iconKey: icon,
            ));
            break;
          }
        }
      }
      final homeDir = Directory(home);
      if (await homeDir.exists()) {
        results.add(StudioQuickDirectory(
          label: 'Inicio',
          path: homeDir.path,
          iconKey: 'home',
        ));
      }
    }

    try {
      final appDocs = await getDocumentsDirectoryPath();
      if (appDocs.isNotEmpty && results.every((r) => r.path != appDocs)) {
        results.add(StudioQuickDirectory(
          label: 'Estudio',
          path: appDocs,
          iconKey: 'studio',
        ));
      }
    } catch (_) {
      // Ignorar si no hay path_provider disponible
    }

    return results;
  }

  @override
  Future<List<StudioDiskEntry>> listDirectoryEntries(
    String directoryPath, {
    Set<String>? allowedExtensions,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return const <StudioDiskEntry>[];

    final entries = <StudioDiskEntry>[];
    final allowedLower = allowedExtensions
        ?.map((e) => e.toLowerCase().replaceFirst(RegExp(r'^\.'), ''))
        .toSet();

    await for (final entity in dir.list(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        entries.add(StudioDiskEntry(
          name: name,
          path: entity.path,
          isDirectory: true,
        ));
      } else if (entity is File) {
        final dotIdx = name.lastIndexOf('.');
        final ext = dotIdx >= 0 ? name.substring(dotIdx + 1).toLowerCase() : '';
        if (allowedLower != null &&
            allowedLower.isNotEmpty &&
            !allowedLower.contains(ext)) {
          continue;
        }
        int size = 0;
        try {
          size = await entity.length();
        } catch (_) {}
        entries.add(StudioDiskEntry(
          name: name,
          path: entity.path,
          isDirectory: false,
          sizeBytes: size,
          extensionName: ext,
        ));
      }
    }

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  @override
  Future<Uint8List?> readFileBytes(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}
