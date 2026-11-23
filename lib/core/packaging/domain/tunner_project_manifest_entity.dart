import 'dart:convert';

/// Entidad inmutable que representa el manifiesto maestro de un paquete
/// canónico de proyecto `.tunner`.
///
/// Contiene metadatos descriptivos (título, autor, marcas de tiempo, tempo nominal,
/// firma métrica y frecuencia de muestreo de audio) así como un mapa de firmas
/// de integridad criptográfica SHA-256 (`fileHashes`) que asocia cada ruta
/// de archivo interna con su digest hex correspondiente.
class TunnerProjectManifestEntity {
  /// Identificador único del proyecto o UUID.
  final String id;

  /// Título formal del proyecto musical o composición.
  final String title;

  /// Nombre del autor, compositor o productor.
  final String author;

  /// Versión de la especificación del formato canónico (ej. '1.0.0').
  final String version;

  /// Fecha y hora de creación original del paquete.
  final DateTime createdAt;

  /// Fecha y hora de la última modificación guardada.
  final DateTime modifiedAt;

  /// Tempo nominal de reproducción en pulsos por minuto (BPM).
  final double bpm;

  /// Firma métrica canónica (ej. '4/4', '3/4', '6/8').
  final String timeSignature;

  /// Frecuencia de muestreo estándar de la sesión en Hertz (ej. 44100 o 48000).
  final int sampleRate;

  /// Mapa de verificación de integridad criptográfica:
  /// Asocia cada ruta relativa dentro del contenedor con su resumen SHA-256 en minúsculas.
  final Map<String, String> fileHashes;

  /// Metadatos adicionales extensibles en formato clave-valor.
  final Map<String, dynamic> metadata;

  /// Constructor canónico inmutable.
  const TunnerProjectManifestEntity({
    required this.id,
    required this.title,
    this.author = 'Tunner Producer',
    this.version = '1.0.0',
    required this.createdAt,
    required this.modifiedAt,
    this.bpm = 120.0,
    this.timeSignature = '4/4',
    this.sampleRate = 44100,
    this.fileHashes = const {},
    this.metadata = const {},
  });

  /// Crea una copia de la entidad modificando únicamente los campos especificados.
  TunnerProjectManifestEntity copyWith({
    String? id,
    String? title,
    String? author,
    String? version,
    DateTime? createdAt,
    DateTime? modifiedAt,
    double? bpm,
    String? timeSignature,
    int? sampleRate,
    Map<String, String>? fileHashes,
    Map<String, dynamic>? metadata,
  }) {
    return TunnerProjectManifestEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      sampleRate: sampleRate ?? this.sampleRate,
      fileHashes: fileHashes != null ? Map.unmodifiable(fileHashes) : this.fileHashes,
      metadata: metadata != null ? Map.unmodifiable(metadata) : this.metadata,
    );
  }

  /// Serializa la entidad a un mapa compatible con JSON estándar.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'bpm': bpm,
      'timeSignature': timeSignature,
      'sampleRate': sampleRate,
      'fileHashes': fileHashes,
      'metadata': metadata,
    };
  }

  /// Deserializa la entidad desde un mapa JSON.
  factory TunnerProjectManifestEntity.fromJson(Map<String, dynamic> json) {
    return TunnerProjectManifestEntity(
      id: json['id'] as String? ?? 'tunner_proj_001',
      title: json['title'] as String? ?? 'Untitled Project',
      author: json['author'] as String? ?? 'Tunner Producer',
      version: json['version'] as String? ?? '1.0.0',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.tryParse(json['modifiedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      bpm: (json['bpm'] as num?)?.toDouble() ?? 120.0,
      timeSignature: json['timeSignature'] as String? ?? '4/4',
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 44100,
      fileHashes: json['fileHashes'] != null
          ? Map<String, String>.from(json['fileHashes'] as Map)
          : const {},
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  /// Codifica el manifiesto directamente en una cadena formateada JSON.
  String serializeJson({bool pretty = true}) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(toJson());
    }
    return jsonEncode(toJson());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TunnerProjectManifestEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          author == other.author &&
          version == other.version &&
          bpm == other.bpm &&
          timeSignature == other.timeSignature &&
          sampleRate == other.sampleRate;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      author.hashCode ^
      version.hashCode ^
      bpm.hashCode ^
      timeSignature.hashCode ^
      sampleRate.hashCode;
}
