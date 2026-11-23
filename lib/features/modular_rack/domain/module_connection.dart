import 'port_id.dart';
import 'signal_type.dart';

/// Modo de distribución de la conexión.
enum ConnectionScope {
  /// Conexión punto a punto: El puerto emisor envía únicamente a un puerto receptor específico.
  pointToPoint('point_to_point', 'Punto a Punto (Exclusivo)'),

  /// Conexión en difusión global: El puerto emisor transmite a todos los módulos compatibles.
  broadcast('broadcast', 'Difusión Global (Broadcast a Todos)');

  final String code;
  final String displayName;

  const ConnectionScope(this.code, this.displayName);
}

/// Enlace de comunicación activo entre módulos del rack.
class ModuleConnection {
  /// Identificador único de la conexión.
  final String connectionId;

  /// Puerto de salida proveedor.
  final PortId sourcePort;

  /// Puerto de entrada consumidor (nulo si la conexión es en modo Broadcast abierto).
  final PortId? destinationPort;

  /// Alcance de la conexión.
  final ConnectionScope scope;

  /// Indica si la conexión está actualmente activa y transmitiendo datos.
  final bool isEnabled;

  /// Factor de ganancia o atenuación de la señal en esta conexión [0.0, 2.0].
  final double gain;

  /// Estado de silencio (mute) de esta conexión individual.
  final bool isMuted;

  const ModuleConnection({
    required this.connectionId,
    required this.sourcePort,
    this.destinationPort,
    this.scope = ConnectionScope.pointToPoint,
    this.isEnabled = true,
    this.gain = 1.0,
    this.isMuted = false,
  });

  /// Tipo de señal que fluye por esta conexión.
  SignalType get signalType => sourcePort.signalType;

  /// Crea una conexión punto a punto verificada.
  factory ModuleConnection.pointToPoint({
    required PortId source,
    required PortId destination,
    double gain = 1.0,
    bool isMuted = false,
  }) {
    if (!source.canConnectTo(destination)) {
      throw ArgumentError('Incompatibilidad de puertos: $source no puede conectar con $destination');
    }
    return ModuleConnection(
      connectionId: '${source.ownerModuleId}.${source.id}->${destination.ownerModuleId}.${destination.id}',
      sourcePort: source,
      destinationPort: destination,
      scope: ConnectionScope.pointToPoint,
      isEnabled: true,
      gain: gain.clamp(0.0, 2.0),
      isMuted: isMuted,
    );
  }

  /// Crea una conexión de difusión broadcast abierta hacia todos los módulos.
  factory ModuleConnection.broadcast({
    required PortId source,
    double gain = 1.0,
    bool isMuted = false,
  }) {
    if (source.direction != PortDirection.output) {
      throw ArgumentError('Solo puertos de salida pueden emitir en modo broadcast: $source');
    }
    return ModuleConnection(
      connectionId: '${source.ownerModuleId}.${source.id}->BROADCAST',
      sourcePort: source,
      destinationPort: null,
      scope: ConnectionScope.broadcast,
      isEnabled: true,
      gain: gain.clamp(0.0, 2.0),
      isMuted: isMuted,
    );
  }

  ModuleConnection copyWith({
    bool? isEnabled,
    double? gain,
    bool? isMuted,
  }) {
    return ModuleConnection(
      connectionId: connectionId,
      sourcePort: sourcePort,
      destinationPort: destinationPort,
      scope: scope,
      isEnabled: isEnabled ?? this.isEnabled,
      gain: (gain ?? this.gain).clamp(0.0, 2.0),
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, dynamic> toJson() => {
        'connectionId': connectionId,
        'sourcePort': sourcePort.toJson(),
        'destinationPort': destinationPort?.toJson(),
        'scope': scope.code,
        'signalType': signalType.code,
        'isEnabled': isEnabled,
        'gain': gain,
        'isMuted': isMuted,
      };

  factory ModuleConnection.fromJson(Map<String, dynamic> json) {
    final rawScope = json['scope'] as String? ?? ConnectionScope.pointToPoint.code;
    final scope = ConnectionScope.values.firstWhere(
      (s) => s.code == rawScope || s.name == rawScope,
      orElse: () => ConnectionScope.pointToPoint,
    );
    final sourceMap = json['sourcePort'] as Map<String, dynamic>? ?? const {};
    final destMap = json['destinationPort'] as Map<String, dynamic>?;
    final rawGain = (json['gain'] as num?)?.toDouble() ?? 1.0;

    return ModuleConnection(
      connectionId: json['connectionId'] as String? ?? '',
      sourcePort: PortId.fromJson(sourceMap),
      destinationPort: destMap != null ? PortId.fromJson(destMap) : null,
      scope: scope,
      isEnabled: json['isEnabled'] as bool? ?? true,
      gain: (rawGain.isFinite ? rawGain : 1.0).clamp(0.0, 2.0),
      isMuted: json['isMuted'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModuleConnection &&
          runtimeType == other.runtimeType &&
          connectionId == other.connectionId;

  @override
  int get hashCode => connectionId.hashCode;

  @override
  String toString() => 'ModuleConnection($connectionId, scope: $scope, active: $isEnabled)';
}
