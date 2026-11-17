/// Entidad pura e inmutable de la capa de dominio para modelar presets de afinación acústica
/// de conservatorio y laboratorio de física del sonido.
///
/// Cumple estrictamente con la regla de Clean Architecture: Cero dependencias de Flutter UI
/// o paquetes de infraestructura externa.
class TuningPresetEntity {
  final String id;
  final String name;
  final double referencePitchHz;
  final String temperamentId;
  final int rootKey;
  final String description;
  final DateTime createdAt;

  const TuningPresetEntity({
    required this.id,
    required this.name,
    required this.referencePitchHz,
    this.temperamentId = 'equal',
    this.rootKey = 0,
    this.description = '',
    required this.createdAt,
  });

  /// Crea una copia inmutable actualizando selectivamente los campos especificados.
  TuningPresetEntity copyWith({
    String? id,
    String? name,
    double? referencePitchHz,
    String? temperamentId,
    int? rootKey,
    String? description,
    DateTime? createdAt,
  }) {
    return TuningPresetEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      referencePitchHz: referencePitchHz ?? this.referencePitchHz,
      temperamentId: temperamentId ?? this.temperamentId,
      rootKey: rootKey ?? this.rootKey,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serialización a mapa estructurado para persistencia local offline.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'referencePitchHz': referencePitchHz,
      'temperamentId': temperamentId,
      'rootKey': rootKey,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Deserialización segura desde mapa estructurado con valores de respaldo canónicos.
  factory TuningPresetEntity.fromMap(Map<String, dynamic> map) {
    return TuningPresetEntity(
      id: map['id'] as String? ?? 'preset_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Preset de Afinación',
      referencePitchHz: (map['referencePitchHz'] as num?)?.toDouble() ?? 440.0,
      temperamentId: map['temperamentId'] as String? ?? 'equal',
      rootKey: (map['rootKey'] as num?)?.toInt() ?? 0,
      description: map['description'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TuningPresetEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          referencePitchHz == other.referencePitchHz &&
          temperamentId == other.temperamentId &&
          rootKey == other.rootKey;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      referencePitchHz.hashCode ^
      temperamentId.hashCode ^
      rootKey.hashCode;

  @override
  String toString() =>
      'TuningPresetEntity(id: $id, name: $name, referencePitchHz: $referencePitchHz Hz, temperament: $temperamentId)';
}
