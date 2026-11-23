import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import '../domain/tunner_project_package.dart';
import '../domain/tunner_tool_preset.dart';

/// Sink de descompresion acotada por chunks que aborta inmediatamente si el
/// flujo descomprimido supera [maxAllowedBytes], evitando ataques Zip-Bomb.
class _BoundedByteAccumulatorSink extends ByteConversionSinkBase {
  final int maxAllowedBytes;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _totalBytes = 0;

  _BoundedByteAccumulatorSink({required this.maxAllowedBytes});

  Uint8List takeBytes() => _builder.takeBytes();

  @override
  void add(List<int> chunk) {
    _totalBytes += chunk.length;
    if (_totalBytes > maxAllowedBytes) {
      throw const FormatException(
        'El payload excede el limite maximo de descompresion segura (Zip-Bomb bloqueado).',
      );
    }
    _builder.add(chunk);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    final sliceLength = end - start;
    if (sliceLength > 0) {
      _totalBytes += sliceLength;
      if (_totalBytes > maxAllowedBytes) {
        throw const FormatException(
          'El payload excede el limite maximo de descompresion segura (Zip-Bomb bloqueado).',
        );
      }
      _builder.add(chunk.sublist(start, end));
    }
  }

  @override
  void close() {}
}

/// Códec binario de ultra alta compresión para proyectos (.tunner) y herramientas (.tnt).
/// Emplea compresión Deflate/ZLib de nivel máximo con firma mágica de integridad
/// y descompresión streaming por chunks contra ataques Zip-Bomb.
class TunnerBinaryProjectCodec {
  /// Magic bytes para archivos de proyecto (.tunner): ASCII 'TUNP' (0x54, 0x55, 0x4E, 0x50).
  static const List<int> projectMagicBytes = [0x54, 0x55, 0x4E, 0x50];

  /// Magic bytes para archivos de herramientas (.tnt): ASCII 'TNTP' (0x54, 0x4E, 0x54, 0x50).
  static const List<int> toolMagicBytes = [0x54, 0x4E, 0x54, 0x50];

  static const int currentVersion = 1;
  static const int maxDecompressedPayloadBytes = 64 * 1024 * 1024;
  static const int _inputChunkSize = 4096;

  final int maxAllowedDecompressedBytes;
  final ZLibCodec _zlib = ZLibCodec(level: ZLibOption.maxLevel);

  TunnerBinaryProjectCodec({
    this.maxAllowedDecompressedBytes = maxDecompressedPayloadBytes,
  });

  /// Codifica y comprime un proyecto completo a bytes binarios (.tunner).
  Uint8List encodeProject(TunnerProjectPackage project) {
    return _encodeFramedJson(
      magicBytes: projectMagicBytes,
      jsonMap: project.toJson(),
    );
  }

  /// Descomprime y valida un archivo de proyecto (.tunner) desde bytes.
  TunnerProjectPackage decodeProject(Uint8List bytes) {
    final jsonMap = _decodeFramedJson(
      bytes: bytes,
      expectedMagicBytes: projectMagicBytes,
      shortFileMessage: 'El archivo de proyecto es demasiado corto o está corrupto.',
      invalidMagicMessage:
          'Firma de archivo inválida. No es un proyecto Tunner (.tunner) reconocido.',
      unsupportedVersionPrefix: 'Versión de formato no soportada',
    );
    return TunnerProjectPackage.fromJson(jsonMap);
  }

  /// Codifica y comprime una herramienta individual a bytes binarios (.tnt).
  Uint8List encodeToolPreset(TunnerToolPreset tool) {
    return _encodeFramedJson(
      magicBytes: toolMagicBytes,
      jsonMap: tool.toJson(),
    );
  }

  /// Descomprime y valida una herramienta (.tnt) desde bytes.
  TunnerToolPreset decodeToolPreset(Uint8List bytes) {
    final jsonMap = _decodeFramedJson(
      bytes: bytes,
      expectedMagicBytes: toolMagicBytes,
      shortFileMessage: 'El archivo de herramienta es demasiado corto o está corrupto.',
      invalidMagicMessage:
          'Firma de archivo inválida. No es una herramienta Tunner (.tnt) reconocida.',
      unsupportedVersionPrefix: 'Versión de formato de herramienta no soportada',
    );
    return TunnerToolPreset.fromJson(jsonMap);
  }

  Uint8List _encodeFramedJson({
    required List<int> magicBytes,
    required Map<String, dynamic> jsonMap,
  }) {
    final jsonStr = jsonEncode(jsonMap);
    final rawBytes = utf8.encode(jsonStr);
    final compressed = _zlib.encode(rawBytes);

    final buffer = BytesBuilder(copy: false);
    buffer.add(magicBytes);
    buffer.addByte(currentVersion);
    buffer.add(compressed);
    return buffer.toBytes();
  }

  Map<String, dynamic> _decodeFramedJson({
    required Uint8List bytes,
    required List<int> expectedMagicBytes,
    required String shortFileMessage,
    required String invalidMagicMessage,
    required String unsupportedVersionPrefix,
  }) {
    if (bytes.length < 5) {
      throw FormatException(shortFileMessage);
    }

    for (int i = 0; i < 4; i++) {
      if (bytes[i] != expectedMagicBytes[i]) {
        throw FormatException(invalidMagicMessage);
      }
    }

    final version = bytes[4];
    if (version > currentVersion) {
      throw FormatException('$unsupportedVersionPrefix ($version). Actualice Tunner.');
    }

    final compressedPayload = Uint8List.sublistView(bytes, 5);
    final decompressed = _decodeBounded(compressedPayload);
    final jsonStr = utf8.decode(decompressed);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  Uint8List _decodeBounded(List<int> compressedPayload) {
    final outputSink = _BoundedByteAccumulatorSink(
      maxAllowedBytes: maxAllowedDecompressedBytes,
    );
    final inputSink = _zlib.decoder.startChunkedConversion(outputSink);

    for (int offset = 0; offset < compressedPayload.length; offset += _inputChunkSize) {
      final end = math.min(offset + _inputChunkSize, compressedPayload.length);
      final isLast = end == compressedPayload.length;
      inputSink.addSlice(compressedPayload, offset, end, isLast);
    }
    inputSink.close();

    return outputSink.takeBytes();
  }
}
