import 'studio_transport_status.dart';

/// Contrato de dominio puro para el Reloj Maestro de Transporte Unificado de Tunner Studio.
abstract class IStudioMasterClock {
  double get bpm;
  int get meterNumerator;
  int get meterDenominator;
  StudioTransportStatus get status;
  bool get isPlaying;
  bool get isPaused;
  bool get isStopped;

  int get currentBeat;
  int get currentMeasure;
  bool get isDownbeat;
  Duration get elapsedDuration;

  Stream<int> get onBeat;
  Stream<bool> get onDownbeat;
  double get beatIntervalMs;

  void setBpm(double newBpm);
  void setMeter(int numerator, int denominator);
  void startTransport({double? bpm});
  void pauseTransport();
  void stopTransport();
  void togglePlayPause();
  void registerTap();
  void dispose();
}
