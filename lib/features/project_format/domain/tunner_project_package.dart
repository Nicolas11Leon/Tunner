import 'package:meta/meta.dart';
import 'patchbay_routing_connection.dart';
import 'tunner_tool_preset.dart';

/// Paquete completo e inmutable que representa un Proyecto de Tunner Studio (.tunner).
@immutable
class TunnerProjectPackage {
  /// Versión del formato de proyecto de Tunner.
  final int formatVersion;

  /// ID único del proyecto.
  final String projectId;

  /// Nombre del proyecto asignado por el usuario.
  final String projectName;

  /// Autor o creador del proyecto.
  final String author;

  /// Tempo maestro de la sesión en Beats Per Minute (BPM).
  final double masterBpm;

  /// Frecuencia de referencia acústica A4 en Hertz (ej: 440.0 o 432.0).
  final double referenceA4Hz;

  /// Clave o escala musical del proyecto (opcional).
  final String musicalKey;

  /// Notas o descripción de la sesión.
  final String notes;

  /// Lista ordenada de herramientas/módulos que componen el rack.
  final List<TunnerToolPreset> tools;

  /// Grafo de cableado y enrutamiento entre puertos de herramientas.
  final List<PatchbayRoutingConnection> patchConnections;

  /// Timestamp de creación del proyecto en microsegundos.
  final int createdAtMicros;

  /// Timestamp de última modificación en microsegundos.
  final int updatedAtMicros;

  const TunnerProjectPackage({
    this.formatVersion = 1,
    required this.projectId,
    required this.projectName,
    this.author = 'Tunner Artist',
    this.masterBpm = 120.0,
    this.referenceA4Hz = 440.0,
    this.musicalKey = 'C Major',
    this.notes = '',
    required this.tools,
    this.patchConnections = const [],
    required this.createdAtMicros,
    required this.updatedAtMicros,
  });

  TunnerProjectPackage copyWith({
    String? projectName,
    String? author,
    double? masterBpm,
    double? referenceA4Hz,
    String? musicalKey,
    String? notes,
    List<TunnerToolPreset>? tools,
    List<PatchbayRoutingConnection>? patchConnections,
    int? updatedAtMicros,
  }) {
    return TunnerProjectPackage(
      formatVersion: formatVersion,
      projectId: projectId,
      projectName: projectName ?? this.projectName,
      author: author ?? this.author,
      masterBpm: masterBpm ?? this.masterBpm,
      referenceA4Hz: referenceA4Hz ?? this.referenceA4Hz,
      musicalKey: musicalKey ?? this.musicalKey,
      notes: notes ?? this.notes,
      tools: tools ?? this.tools,
      patchConnections: patchConnections ?? this.patchConnections,
      createdAtMicros: createdAtMicros,
      updatedAtMicros: updatedAtMicros ?? DateTime.now().microsecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'projectId': projectId,
    'projectName': projectName,
    'author': author,
    'masterBpm': masterBpm,
    'referenceA4Hz': referenceA4Hz,
    'musicalKey': musicalKey,
    'notes': notes,
    'tools': tools.map((t) => t.toJson()).toList(),
    'patchConnections': patchConnections.map((c) => c.toJson()).toList(),
    'createdAtMicros': createdAtMicros,
    'updatedAtMicros': updatedAtMicros,
  };

  factory TunnerProjectPackage.fromJson(Map<String, dynamic> json) {
    final rawTools = json['tools'] as List<dynamic>? ?? [];
    final rawConns = json['patchConnections'] as List<dynamic>? ?? [];

    return TunnerProjectPackage(
      formatVersion: json['formatVersion'] as int? ?? 1,
      projectId: json['projectId'] as String,
      projectName: json['projectName'] as String,
      author: json['author'] as String? ?? 'Tunner Artist',
      masterBpm: (json['masterBpm'] as num?)?.toDouble() ?? 120.0,
      referenceA4Hz: (json['referenceA4Hz'] as num?)?.toDouble() ?? 440.0,
      musicalKey: json['musicalKey'] as String? ?? 'C Major',
      notes: json['notes'] as String? ?? '',
      tools: rawTools.map((t) => TunnerToolPreset.fromJson(t as Map<String, dynamic>)).toList(),
      patchConnections: rawConns.map((c) => PatchbayRoutingConnection.fromJson(c as Map<String, dynamic>)).toList(),
      createdAtMicros: json['createdAtMicros'] as int? ?? 0,
      updatedAtMicros: json['updatedAtMicros'] as int? ?? 0,
    );
  }
}
