import 'package:meta/meta.dart';
import '../../modular_rack/domain/signal_type.dart';

/// Representación serializable e inmutable de una conexión de cableado entre puertos en el Patchbay.
@immutable
class PatchbayRoutingConnection {
  /// ID único de la conexión (ej: 'conn_audio_in_01').
  final String connectionId;

  /// ID del módulo de origen.
  final String sourceModuleId;

  /// ID del puerto de salida de origen.
  final String sourcePortId;

  /// ID del módulo de destino (nulo si es una transmisión en broadcast).
  final String? destinationModuleId;

  /// ID del puerto de entrada de destino (nulo si es una transmisión en broadcast).
  final String? destinationPortId;

  /// Tipo de señal que fluye por esta conexión.
  final SignalType signalType;

  /// Indica si la conexión es punto a punto o multidifusión general (broadcast).
  final bool isBroadcast;

  const PatchbayRoutingConnection({
    required this.connectionId,
    required this.sourceModuleId,
    required this.sourcePortId,
    this.destinationModuleId,
    this.destinationPortId,
    required this.signalType,
    this.isBroadcast = false,
  });

  Map<String, dynamic> toJson() => {
    'connectionId': connectionId,
    'sourceModuleId': sourceModuleId,
    'sourcePortId': sourcePortId,
    'destinationModuleId': destinationModuleId,
    'destinationPortId': destinationPortId,
    'signalType': signalType.name,
    'isBroadcast': isBroadcast,
  };

  factory PatchbayRoutingConnection.fromJson(Map<String, dynamic> json) {
    return PatchbayRoutingConnection(
      connectionId: json['connectionId'] as String,
      sourceModuleId: json['sourceModuleId'] as String,
      sourcePortId: json['sourcePortId'] as String,
      destinationModuleId: json['destinationModuleId'] as String?,
      destinationPortId: json['destinationPortId'] as String?,
      signalType: SignalType.values.firstWhere(
        (s) => s.name == json['signalType'],
        orElse: () => SignalType.audioPcm,
      ),
      isBroadcast: json['isBroadcast'] as bool? ?? false,
    );
  }
}
