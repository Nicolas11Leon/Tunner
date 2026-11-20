import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../domain/tunner_project_package.dart';
import '../domain/tunner_tool_preset.dart';

/// Códec binario de ultra alta compresión para proyectos (.tunner) y herramientas (.tnt).
/// Emplea compresión Deflate/ZLib de nivel máximo con firma mágica de integridad.
class TunnerBinaryProjectCodec {
  /// Magic bytes para archivos de proyecto (.tunner): ASCII 'TUNP' (0x54, 0x55, 0x4E, 0x50).
  static const List<int> projectMagicBytes = [0x54, 0x55, 0x4E, 0x50];

  /// Magic bytes para archivos de herramientas (.tnt): ASCII 'TNTP' (0x54, 0x4E, 0x54, 0x50).
  static const List<int> toolMagicBytes = [0x54, 0x4E, 0x54, 0x50];

  static const int currentVersion = 1;
  static const int maxDecompressedPayloadBytes = 64 * 1024 * 1024;

  final ZLibCodec _zlib = ZLibCodec(level: ZLibOption.maxLevel);

  /// Codifica y comprime un proyecto completo a bytes binarios (.tunner).
  Uint8List encodeProject(TunnerProjectPackage project) {
    final jsonStr = jsonEncode(project.toJson());
    final rawBytes = utf8.encode(jsonStr);
    final compressed = _zlib.encode(rawBytes);

    final buffer = BytesBuilder(copy: false);
    buffer.add(projectMagicBytes);
    buffer.addByte(currentVersion);
    buffer.add(compressed);

    return buffer.toBytes();
  }

  /// Descomprime y valida un archivo de proyecto (.tunner) desde bytes.
  TunnerProjectPackage decodeProject(Uint8List bytes) {
    if (bytes.length < 5) {
      throw const FormatException('El archivo de proyecto es demasiado corto o está corrupto.');
    }

    // Verificar número mágico
    for (int i = 0; i < 4; i++) {
      if (bytes[i] != projectMagicBytes[i]) {
        throw const FormatException('Firma de archivo inválida. No es un proyecto Tunner (.tunner) reconocido.');
      }
    }

    final version = bytes[4];
    if (version > currentVersion) {
      throw FormatException('Versión de formato no soportada ($version). Actualice Tunner.');
    }

    final compressedPayload = bytes.sublist(5);
    final decompressed = _decodeBounded(compressedPayload);
    final jsonStr = utf8.decode(decompressed);
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;

    return TunnerProjectPackage.fromJson(jsonMap);
  }

  List<int> _decodeBounded(List<int> compressedPayload) {
    final decompressed = _zlib.decode(compressedPayload);
    if (decompressed.length > maxDecompressedPayloadBytes) {
      throw const FormatException('El proyecto excede el limite maximo de descompresion segura.');
    }
    return decompressed;
  }

  /// Codifica y comprime una herramienta individual a bytes binarios (.tnt).
  Uint8List encodeToolPreset(TunnerToolPreset tool) {
    final jsonStr = jsonEncode(tool.toJson());
    final rawBytes = utf8.encode(jsonStr);
    final compressed = _zlib.encode(rawBytes);

    final buffer = BytesBuilder(copy: false);
    buffer.add(toolMagicBytes);
    buffer.addByte(currentVersion);
    buffer.add(compressed);

    return buffer.toBytes();
  }

  /// Descomprime y valida una herramienta (.tnt) desde bytes.
  TunnerToolPreset decodeToolPreset(Uint8List bytes) {
    if (bytes.length < 5) {
      throw const FormatException('El archivo de herramienta es demasiado corto o está corrupto.');
    }

    // Verificar número mágico
    for (int i = 0; i < 4; i++) {
      if (bytes[i] != toolMagicBytes[i]) {
        throw const FormatException('Firma de archivo inválida. No es una herramienta Tunner (.tnt) reconocida.');
      }
    }

    final version = bytes[4];
    if (version > currentVersion) {
      throw FormatException('Versión de formato de herramienta no soportada ($version).');
    }

    final compressedPayload = bytes.sublist(5);
    final decompressed = _decodeBounded(compressedPayload);
    final jsonStr = utf8.decode(decompressed);
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;

    return TunnerToolPreset.fromJson(jsonMap);
  }
}
