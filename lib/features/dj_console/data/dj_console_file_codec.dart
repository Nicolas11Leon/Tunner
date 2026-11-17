import 'dart:convert';
import 'dart:typed_data';
import '../domain/dj_console_blueprint_entity.dart';

/// Códec seguro para serialización, importación y exportación de archivos canónicos `.djconsole`.
class DjConsoleFileCodec {
  const DjConsoleFileCodec();

  /// Codifica un plano de consola a una cadena JSON formateada y legible.
  String encodeToJsonString(DjConsoleBlueprintEntity blueprint) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(blueprint.toJson());
  }

  /// Codifica un plano de consola a bytes UTF-8 listos para ser guardados en disco.
  Uint8List encodeToBytes(DjConsoleBlueprintEntity blueprint) {
    final jsonStr = encodeToJsonString(blueprint);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  /// Decodifica una cadena JSON a una entidad [DjConsoleBlueprintEntity].
  DjConsoleBlueprintEntity decodeFromJsonString(String jsonString) {
    final decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El archivo .djconsole no contiene un objeto JSON válido');
    }

    if (decoded['format'] != null && decoded['format'] != 'tunner.djconsole') {
      throw const FormatException('El archivo no corresponde al formato canónico tunner.djconsole');
    }

    return DjConsoleBlueprintEntity.fromJson(decoded);
  }

  /// Decodifica bytes de archivo a un [DjConsoleBlueprintEntity].
  DjConsoleBlueprintEntity decodeFromBytes(Uint8List bytes) {
    final jsonStr = utf8.decode(bytes);
    return decodeFromJsonString(jsonStr);
  }
}
