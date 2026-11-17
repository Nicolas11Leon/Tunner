import 'studio_plug_type.dart';

/// Entidad inmutable que representa un Plug o Jack virtual interactivo en una herramienta.
class StudioModularPlug {
  final String id;
  final String label;
  final String toolId;
  final StudioPlugType type;
  final String? connectedChannelId; // p. ej. 'canal_a', 'canal_b', 'canal_c', 'canal_d'
  final bool isCarryingSignal;

  const StudioModularPlug({
    required this.id,
    required this.label,
    required this.toolId,
    required this.type,
    this.connectedChannelId,
    this.isCarryingSignal = false,
  });

  bool get isConnected => connectedChannelId != null && connectedChannelId!.isNotEmpty;
  bool get isInput => type.isInput;
  bool get isOutput => type.isOutput;

  StudioModularPlug copyWith({
    String? id,
    String? label,
    String? toolId,
    StudioPlugType? type,
    String? connectedChannelId,
    bool clearConnection = false,
    bool? isCarryingSignal,
  }) {
    return StudioModularPlug(
      id: id ?? this.id,
      label: label ?? this.label,
      toolId: toolId ?? this.toolId,
      type: type ?? this.type,
      connectedChannelId: clearConnection ? null : (connectedChannelId ?? this.connectedChannelId),
      isCarryingSignal: isCarryingSignal ?? this.isCarryingSignal,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudioModularPlug &&
        other.id == id &&
        other.label == label &&
        other.toolId == toolId &&
        other.type == type &&
        other.connectedChannelId == connectedChannelId &&
        other.isCarryingSignal == isCarryingSignal;
  }

  @override
  int get hashCode => Object.hash(id, label, toolId, type, connectedChannelId, isCarryingSignal);
}
