import 'dart:async';
import 'tunner_os_command_entity.dart';

/// Contrato de dominio para manejadores modulares de comandos de Tunner OS (Command Pattern).
/// Permite registrar y despachar comandos en $O(1)$ sin acoplar el kernel central a nuevas features.
abstract class ITerminalCommandHandler {
  /// Dominios/prefijos de comando atendidos por este manejador (en minúsculas).
  Set<String> get supportedDomains;

  /// Ejecuta el comando recibido y retorna el resultado estructurado.
  FutureOr<TunnerOsCommandResult> execute(
    String domain,
    List<String> args,
    String rawCommandLine,
  );
}
