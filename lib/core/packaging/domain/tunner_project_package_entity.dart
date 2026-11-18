import 'dart:typed_data';
import 'tunner_project_manifest_entity.dart';

/// Agregado raíz inmutable que encapsula el contenido completo decodificado
/// de un proyecto musical `.tunner` en memoria.
///
/// Agrupa de manera desacoplada:
/// - El manifiesto descriptivo con control de integridad criptográfica (`manifest`).
/// - La matriz de hardware de audio y mastering (`routingMatrixJson`).
/// - La notación musical vectorial jerárquica (`scoreJson`).
/// - La configuración tímbrica y envolventes ADSR del sintetizador (`synthPresetJson`).
/// - El estado de la estación de mezcla DJ (`djSessionJson`).
/// - Colección de pistas de audio / stems PCM binarios (`audioFiles`).
class TunnerProjectPackageEntity {
  /// Manifiesto con metadatos del proyecto y hashes de archivos.
  final TunnerProjectManifestEntity manifest;

  /// Mapa serializado de la entidad `AudioDeviceMatrixEntity`.
  final Map<String, dynamic>? routingMatrixJson;

  /// Mapa serializado de la partitura musical activa (`ScoreEntity` o `HierarchicalScore`).
  final Map<String, dynamic>? scoreJson;

  /// Mapa serializado de la configuración del sintetizador polifónico (forma de onda, ADSR).
  final Map<String, dynamic>? synthPresetJson;

  /// Mapa serializado de la cabina de DJ (pistas en decks, tempos, hot cues).
  final Map<String, dynamic>? djSessionJson;

  /// Mapa de archivos de audio binarios PCM (ruta interna relativa -> bytes del archivo WAV).
  final Map<String, Uint8List> audioFiles;

  /// Constructor inmutable con validación de inmutabilidad interna.
  TunnerProjectPackageEntity({
    required this.manifest,
    this.routingMatrixJson,
    this.scoreJson,
    this.synthPresetJson,
    this.djSessionJson,
    Map<String, Uint8List>? audioFiles,
  }) : audioFiles = audioFiles != null ? Map.unmodifiable(audioFiles) : const {};

  /// Crea una copia de la entidad modificando selectivamente los campos indicados.
  TunnerProjectPackageEntity copyWith({
    TunnerProjectManifestEntity? manifest,
    Map<String, dynamic>? routingMatrixJson,
    Map<String, dynamic>? scoreJson,
    Map<String, dynamic>? synthPresetJson,
    Map<String, dynamic>? djSessionJson,
    Map<String, Uint8List>? audioFiles,
  }) {
    return TunnerProjectPackageEntity(
      manifest: manifest ?? this.manifest,
      routingMatrixJson: routingMatrixJson ?? this.routingMatrixJson,
      scoreJson: scoreJson ?? this.scoreJson,
      synthPresetJson: synthPresetJson ?? this.synthPresetJson,
      djSessionJson: djSessionJson ?? this.djSessionJson,
      audioFiles: audioFiles ?? this.audioFiles,
    );
  }

  /// Retorna si el paquete contiene una partitura musical estructurada.
  bool get hasScore => scoreJson != null && scoreJson!.isNotEmpty;

  /// Retorna si el paquete contiene configuración de matriz de audio de estudio.
  bool get hasRoutingMatrix => routingMatrixJson != null && routingMatrixJson!.isNotEmpty;

  /// Retorna si el paquete contiene presets del sintetizador polifónico.
  bool get hasSynthPreset => synthPresetJson != null && synthPresetJson!.isNotEmpty;

  /// Retorna si el paquete contiene sesión activa de estación DJ.
  bool get hasDjSession => djSessionJson != null && djSessionJson!.isNotEmpty;

  /// Retorna si el paquete incluye stems o archivos de audio grabados.
  bool get hasAudioFiles => audioFiles.isNotEmpty;

  /// Tamaño total en bytes de los archivos de audio adjuntos en memoria.
  int get totalAudioBytes {
    var total = 0;
    for (final bytes in audioFiles.values) {
      total += bytes.lengthInBytes;
    }
    return total;
  }
}
