import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../domain/i_tunner_package_codec.dart';
import '../domain/tunner_package_exceptions.dart';
import '../domain/tunner_project_manifest_entity.dart';
import '../domain/tunner_project_package_entity.dart';

/// Implementación de infraestructura para la serialización y deserialización
/// de proyectos musicales canónicos `.tunner` en memoria.
///
/// Utiliza el algoritmo estándar DEFLATE (ZIP) mediante el paquete `archive`
/// y genera firmas de verificación criptográfica SHA-256 mediante `package:crypto`.
class TunnerPackageCodecService implements ITunnerPackageCodec {
  /// Constructor canónico.
  const TunnerPackageCodecService();

  /// Ruta canónica del manifiesto maestro dentro del contenedor.
  static const String manifestFileName = 'manifest.json';

  /// Ruta de la matriz de enrutamiento y mastering de hardware.
  static const String routingMatrixFileName = 'routing_matrix.json';

  /// Ruta de la partitura musical vectorial estructurada.
  static const String scoreFileName = 'notation/score.json';

  /// Ruta del preset tímbrico y envolventes del sintetizador polifónico.
  static const String synthPresetFileName = 'instruments/synth_preset.json';

  /// Ruta del estado de sesión y platos de la consola DJ.
  static const String djSessionFileName = 'dj_workstation/session.json';

  /// Prefijo de directorio para archivos y stems de audio PCM.
  static const String audioVaultPrefix = 'audio_vault/stems/';

  /// Limite maximo de descompresion en memoria (250 MB) para prevenir ataques Zip-Bomb.
  static const int maxDecompressedSizeBytes = 250 * 1024 * 1024;

  @override
  Uint8List encodePackage(TunnerProjectPackageEntity package) {
    final archive = Archive();
    final generatedHashes = <String, String>{};

    // 1. Matriz de hardware de audio
    if (package.routingMatrixJson != null && package.routingMatrixJson!.isNotEmpty) {
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(package.routingMatrixJson)),
      );
      generatedHashes[routingMatrixFileName] = _computeSha256Hex(bytes);
      archive.addFile(ArchiveFile(routingMatrixFileName, bytes.length, bytes));
    }

    // 2. Partitura musical activa
    if (package.scoreJson != null && package.scoreJson!.isNotEmpty) {
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(package.scoreJson)),
      );
      generatedHashes[scoreFileName] = _computeSha256Hex(bytes);
      archive.addFile(ArchiveFile(scoreFileName, bytes.length, bytes));
    }

    // 3. Preset de sintetizador polifónico
    if (package.synthPresetJson != null && package.synthPresetJson!.isNotEmpty) {
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(package.synthPresetJson)),
      );
      generatedHashes[synthPresetFileName] = _computeSha256Hex(bytes);
      archive.addFile(ArchiveFile(synthPresetFileName, bytes.length, bytes));
    }

    // 4. Sesión DJ Pro
    if (package.djSessionJson != null && package.djSessionJson!.isNotEmpty) {
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(package.djSessionJson)),
      );
      generatedHashes[djSessionFileName] = _computeSha256Hex(bytes);
      archive.addFile(ArchiveFile(djSessionFileName, bytes.length, bytes));
    }

    // 5. Archivos de audio PCM / Stems
    for (final entry in package.audioFiles.entries) {
      final normalizedPath = entry.key.startsWith('audio_vault/')
          ? entry.key
          : '$audioVaultPrefix${entry.key}';
      final bytes = entry.value;
      generatedHashes[normalizedPath] = _computeSha256Hex(bytes);
      archive.addFile(ArchiveFile(normalizedPath, bytes.length, bytes));
    }

    // 6. Ensamblar manifest.json actualizado con todos los hashes calculados
    final updatedManifest = package.manifest.copyWith(
      fileHashes: generatedHashes,
      modifiedAt: DateTime.now(),
    );
    final manifestBytes = Uint8List.fromList(
      utf8.encode(updatedManifest.serializeJson(pretty: true)),
    );
    archive.addFile(ArchiveFile(manifestFileName, manifestBytes.length, manifestBytes));

    // 7. Comprimir contenedor ZIP en memoria
    final zipEncoder = ZipEncoder();
    final encodedData = zipEncoder.encode(archive);
    return Uint8List.fromList(encodedData);
  }

  @override
  TunnerProjectPackageEntity decodePackage(
    Uint8List packageBytes, {
    bool verifyHashes = true,
  }) {
    if (packageBytes.isEmpty) {
      throw const TunnerPackageInvalidFormatException('El paquete .tunner está vacío.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(packageBytes);
    } catch (e) {
      throw TunnerPackageInvalidFormatException(
        'El archivo no corresponde a un contenedor ZIP válido: $e',
      );
    }

    // Validar proteccion anti-Zip-Slip y anti-Zip-Bomb
    int totalDecompressedBytes = 0;
    for (final file in archive.files) {
      final normalized = file.name.replaceAll('\\', '/');
      final segments = normalized.split('/');
      if (segments.any((s) => s == '..' || s.contains('\x00')) || normalized.startsWith('/')) {
        throw TunnerPackageCorruptedException(
          filePath: file.name,
          expectedHash: '',
          actualHash: 'ZIP_SLIP_ATTEMPT',
        );
      }
      totalDecompressedBytes += file.size;
      if (totalDecompressedBytes > maxDecompressedSizeBytes) {
        throw const TunnerPackageInvalidFormatException(
          'Cuota maxima de descompresion superada (posible Zip Bomb).',
        );
      }
    }

    // 1. Localizar y deserializar manifest.json
    final manifestFile = archive.findFile(manifestFileName);
    if (manifestFile == null) {
      throw const TunnerPackageInvalidFormatException(
        'Estructura inválida: no se encontró el manifiesto maestro "manifest.json".',
      );
    }

    final manifestBytes = _extractFileBytes(manifestFile);
    final manifestContent = utf8.decode(manifestBytes);
    final Map<String, dynamic> manifestMap;
    try {
      manifestMap = jsonDecode(manifestContent) as Map<String, dynamic>;
    } catch (e) {
      throw TunnerPackageInvalidFormatException('El archivo "manifest.json" no es un JSON válido: $e');
    }

    final manifest = TunnerProjectManifestEntity.fromJson(manifestMap);

    // 2. Verificación criptográfica de integridad SHA-256
    if (verifyHashes) {
      if (manifest.fileHashes.isEmpty) {
        throw const TunnerPackageCorruptedException(
          filePath: manifestFileName,
          expectedHash: 'SHA-256 no vacio',
          actualHash: 'HASHES_VACIOS',
        );
      }
      for (final entry in manifest.fileHashes.entries) {
        final expectedPath = entry.key;
        final expectedHash = entry.value;

        final file = archive.findFile(expectedPath);
        if (file == null) {
          throw TunnerPackageCorruptedException(
            filePath: expectedPath,
            expectedHash: expectedHash,
            actualHash: 'ARCHIVO_FALTANTE',
          );
        }

        final fileBytes = _extractFileBytes(file);
        final actualHash = _computeSha256Hex(fileBytes);
        if (actualHash.toLowerCase() != expectedHash.toLowerCase()) {
          throw TunnerPackageCorruptedException(
            filePath: expectedPath,
            expectedHash: expectedHash,
            actualHash: actualHash,
          );
        }
      }
    }

    // 3. Extracción de componentes
    Map<String, dynamic>? routingMatrixJson;
    final routingFile = archive.findFile(routingMatrixFileName);
    if (routingFile != null) {
      routingMatrixJson = jsonDecode(utf8.decode(_extractFileBytes(routingFile))) as Map<String, dynamic>?;
    }

    Map<String, dynamic>? scoreJson;
    final scoreFile = archive.findFile(scoreFileName);
    if (scoreFile != null) {
      scoreJson = jsonDecode(utf8.decode(_extractFileBytes(scoreFile))) as Map<String, dynamic>?;
    }

    Map<String, dynamic>? synthPresetJson;
    final synthFile = archive.findFile(synthPresetFileName);
    if (synthFile != null) {
      synthPresetJson = jsonDecode(utf8.decode(_extractFileBytes(synthFile))) as Map<String, dynamic>?;
    }

    Map<String, dynamic>? djSessionJson;
    final djFile = archive.findFile(djSessionFileName);
    if (djFile != null) {
      djSessionJson = jsonDecode(utf8.decode(_extractFileBytes(djFile))) as Map<String, dynamic>?;
    }

    // 4. Extracción de archivos de audio
    final audioFiles = <String, Uint8List>{};
    for (final file in archive.files) {
      if (file.name.startsWith('audio_vault/')) {
        final relativeAudioName = file.name.startsWith(audioVaultPrefix)
            ? file.name.substring(audioVaultPrefix.length)
            : file.name.substring('audio_vault/'.length);
        if (relativeAudioName.isNotEmpty) {
          audioFiles[relativeAudioName] = _extractFileBytes(file);
        }
      }
    }

    return TunnerProjectPackageEntity(
      manifest: manifest,
      routingMatrixJson: routingMatrixJson,
      scoreJson: scoreJson,
      synthPresetJson: synthPresetJson,
      djSessionJson: djSessionJson,
      audioFiles: audioFiles,
    );
  }

  @override
  TunnerProjectManifestEntity readManifest(Uint8List packageBytes) {
    if (packageBytes.isEmpty) {
      throw const TunnerPackageInvalidFormatException('El paquete .tunner está vacío.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(packageBytes);
    } catch (e) {
      throw TunnerPackageInvalidFormatException(
        'El archivo no corresponde a un contenedor ZIP válido: $e',
      );
    }

    for (final file in archive.files) {
      final normalized = file.name.replaceAll('\\', '/');
      final segments = normalized.split('/');
      if (segments.any((s) => s == '..' || s.contains('\x00')) || normalized.startsWith('/')) {
        throw TunnerPackageCorruptedException(
          filePath: file.name,
          expectedHash: '',
          actualHash: 'ZIP_SLIP_ATTEMPT',
        );
      }
    }

    final manifestFile = archive.findFile(manifestFileName);
    if (manifestFile == null) {
      throw const TunnerPackageInvalidFormatException(
        'Estructura inválida: no se encontró el archivo "manifest.json".',
      );
    }

    final manifestBytes = _extractFileBytes(manifestFile);
    final manifestContent = utf8.decode(manifestBytes);
    final manifestMap = jsonDecode(manifestContent) as Map<String, dynamic>;
    return TunnerProjectManifestEntity.fromJson(manifestMap);
  }

  /// Calcula el resumen criptográfico SHA-256 en formato hexadecimal minúscula.
  String _computeSha256Hex(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Extrae el contenido en bytes de un `ArchiveFile` de forma segura.
  Uint8List _extractFileBytes(ArchiveFile file) {
    final dynamic content = file.content;
    if (content is Uint8List) {
      return content;
    } else if (content is List<int>) {
      return Uint8List.fromList(content);
    }
    throw TunnerPackageInvalidFormatException(
      'Contenido no binario detectado en archivo interno: ${file.name}',
    );
  }
}
