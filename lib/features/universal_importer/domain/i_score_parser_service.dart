import 'dart:typed_data';
import 'parsed_score_result_entity.dart';

/// Contrato abstracto del dominio para decodificadores de partituras y secuencias musicales.
abstract class IScoreParserService {
  /// Determina si este decodificador soporta el archivo provisto según nombre o firma binaria.
  bool canParse(String fileName, Uint8List bytes);

  /// Decodifica los bytes del archivo y construye un [ParsedScoreResult] normalizado.
  Future<ParsedScoreResult> parseScoreData({
    required Uint8List bytes,
    required String fileName,
  });
}
