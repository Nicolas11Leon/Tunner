import 'module_connection.dart';
import 'port_id.dart';
import 'signal_type.dart';

/// Arbitro central de politicas de seguridad acustica y permisos de conexion entre puertos.
/// Garantiza la integridad del SignalBus, previene bucles de retroalimentacion (acoples)
/// y asegura el modo de silencio durante calibraciones espectrales de referencia.
class PortPermissionBroker {
  const PortPermissionBroker();

  /// Valida si dos puertos logicos pueden conectarse respetando las reglas de senal y direccion.
  bool canAuthorizeConnection(PortId source, PortId destination) {
    // 1. La fuente debe ser salida y el destino debe ser entrada
    if (source.direction != PortDirection.output || destination.direction != PortDirection.input) {
      return false;
    }

    // 2. No se permiten auto-conexiones dentro del mismo modulo
    if (source.ownerModuleId == destination.ownerModuleId) {
      return false;
    }

    // 3. Los tipos de senal deben ser equivalentes
    if (source.signalType != destination.signalType) {
      return false;
    }

    return true;
  }

  /// Evalua si se concede el permiso para activar el monitoreo vocal/acustico en tiempo real.
  /// Para proteger el oido del estudiante y evitar realimentacion acustica destructiva (acople),
  /// el monitoreo en vivo requiere obligatoriamente transductores desacoplados (auriculares o interfaz externa).
  bool canAuthorizeLiveMonitoring({required bool isHeadphonesOrInterfaceConnected}) {
    return isHeadphonesOrInterfaceConnected;
  }

  /// Evalua si un modulo generador de audio tiene permiso de emitir sonido hacia el DAC.
  /// Durante la calibracion del piso de ruido en el laboratorio acustico, la emision esta prohibida.
  bool canAuthorizeAudioEmission({required bool isCalibrationActive}) {
    if (isCalibrationActive) return false;
    return true;
  }

  /// Retorna un mensaje explicativo y riguroso cuando se deniega el permiso de monitoreo.
  String getSafetyWarningReason({
    required bool isHeadphonesConnected,
    required bool isLiveMonitoringRequested,
  }) {
    if (isLiveMonitoringRequested && !isHeadphonesConnected) {
      return 'Monitoreo en vivo deshabilitado por seguridad acustica. Conecta auriculares para evitar acoples por altavoces.';
    }
    return '';
  }

  /// Filtra y sanitiza una lista de conexiones aplicando las politicas de seguridad en tiempo real.
  List<ModuleConnection> sanitizeConnections(
    List<ModuleConnection> connections, {
    required bool isHeadphonesConnected,
    required bool isCalibrationActive,
  }) {
    final sanitized = <ModuleConnection>[];

    for (final conn in connections) {
      // 1. Si la calibracion esta activa y la conexion transporta audio hacia salida, se desactiva
      if (isCalibrationActive && conn.signalType == SignalType.audioPcm) {
        continue;
      }

      // 2. Si es una conexion de retorno de microfono a altavoz sin auriculares, se bloquea
      if (!isHeadphonesConnected &&
          conn.sourcePort.id.contains('mic') &&
          (conn.destinationPort?.id.contains('speaker') ?? false)) {
        continue;
      }

      // 3. Verificacion de compatibilidad si es punto a punto
      if (conn.destinationPort != null &&
          !canAuthorizeConnection(conn.sourcePort, conn.destinationPort!)) {
        continue;
      }

      sanitized.add(conn);
    }

    return sanitized;
  }
}
