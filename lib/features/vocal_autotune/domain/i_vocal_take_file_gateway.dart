import 'dart:typed_data';

/// Puerto abstracto de dominio en Dart puro para lectura de bytes WAV de tomas
/// grabadas y persistencia de tomas procesadas `*_autotuned.wav` sin acoplar
/// la capa de presentacion con `dart:io`.
abstract class IVocalTakeFileGateway {
  /// Lee los bytes del archivo de audio ubicado en [filePath], o retorna `null`
  /// si el archivo no existe o no esta disponible.
  Future<Uint8List?> readTakeBytes(String filePath);

  /// Persiste [bytes] como un archivo WAV derivado `*_autotuned.wav` a partir
  /// de [originalFilePath] y [takeId], retornando la ruta final escrita o `null`.
  Future<String?> saveAutoTunedWavBytes({
    required String originalFilePath,
    required String takeId,
    required Uint8List bytes,
  });
}

/// Implementacion No-Op en dominio puro para pruebas aisladas sin I/O en disco.
class NoOpVocalTakeFileGateway implements IVocalTakeFileGateway {
  const NoOpVocalTakeFileGateway();

  @override
  Future<Uint8List?> readTakeBytes(String filePath) async => null;

  @override
  Future<String?> saveAutoTunedWavBytes({
    required String originalFilePath,
    required String takeId,
    required Uint8List bytes,
  }) async =>
      null;
}
