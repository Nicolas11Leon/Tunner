import 'signal_type.dart';

/// Dirección del puerto respecto al módulo de estudio.
enum PortDirection {
  /// Puerto receptor que consume datos.
  input('in', 'Entrada'),

  /// Puerto emisor que produce datos hacia otros módulos o al bus global.
  output('out', 'Salida');

  final String code;
  final String displayName;

  const PortDirection(this.code, this.displayName);
}

/// Identificador inmutable de un puerto de señal en un módulo del rack.
class PortId {
  /// ID alfanumérico único del puerto (ej: 'mic.raw_audio', 'pitch.detected_note', 'score.notes_in').
  final String id;

  /// Nombre amigable para mostrar en la interfaz táctil.
  final String displayName;

  /// Tipo de señal que acepta o emite el puerto.
  final SignalType signalType;

  /// Dirección del puerto (Entrada o Salida).
  final PortDirection direction;

  /// ID del módulo al que pertenece el puerto (ej: 'module_tuner', 'module_score').
  final String ownerModuleId;

  const PortId({
    required this.id,
    required this.displayName,
    required this.signalType,
    required this.direction,
    required this.ownerModuleId,
  });

  /// Determina si este puerto emisor puede conectarse físicamente con un puerto receptor.
  bool canConnectTo(PortId other) {
    if (direction == other.direction) return false;
    if (ownerModuleId == other.ownerModuleId) return false;
    return signalType == other.signalType;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'signalType': signalType.code,
        'direction': direction.code,
        'ownerModuleId': ownerModuleId,
      };

  factory PortId.fromJson(Map<String, dynamic> json) {
    final rawSignal = json['signalType'] as String? ?? SignalType.audioPcm.code;
    final rawDir = json['direction'] as String? ?? PortDirection.input.code;
    final signalType = SignalType.values.firstWhere(
      (s) => s.code == rawSignal || s.name == rawSignal,
      orElse: () => SignalType.audioPcm,
    );
    final direction = PortDirection.values.firstWhere(
      (d) => d.code == rawDir || d.name == rawDir,
      orElse: () => PortDirection.input,
    );
    return PortId(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      signalType: signalType,
      direction: direction,
      ownerModuleId: json['ownerModuleId'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortId &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ownerModuleId == other.ownerModuleId;

  @override
  int get hashCode => id.hashCode ^ ownerModuleId.hashCode;

  @override
  String toString() => 'PortId($id, $direction, type: $signalType, module: $ownerModuleId)';
}
