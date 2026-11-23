import '../../domain/i_studio_listenable.dart';
import 'i_studio_master_clock.dart';

/// Contrato de dominio puro para el servicio completo del Reloj Maestro de Transporte.
/// Extiende [IStudioMasterClock] con observación reactiva ([IStudioListenable]) y
/// hooks de orquestación global sin depender de Flutter UI.
abstract class IStudioMasterClockService implements IStudioMasterClock, IStudioListenable {
  StudioVoidCallback? get onPlayAll;
  set onPlayAll(StudioVoidCallback? callback);

  StudioVoidCallback? get onPauseAll;
  set onPauseAll(StudioVoidCallback? callback);

  StudioVoidCallback? get onStopAll;
  set onStopAll(StudioVoidCallback? callback);

  void Function(double bpm)? get onBpmChanged;
  set onBpmChanged(void Function(double bpm)? callback);
}
