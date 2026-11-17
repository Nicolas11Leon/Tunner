import 'dart:async';
import 'package:flutter/foundation.dart';
import 'studio_transport_status.dart';

/// Servicio de dominio para el Reloj Maestro de Transporte Unificado de Tunner Studio.
/// Sincroniza compás, tempo (BPM) y fase rítmica con compensación determinista
/// mediante [Stopwatch] para garantizar cero deriva temporal acumulativa.
class StudioMasterClockService extends ChangeNotifier {
  double _bpm;
  int _meterNumerator;
  int _meterDenominator;

  StudioTransportStatus _status = StudioTransportStatus.stopped;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickerTimer;

  int _currentBeat = 1;
  int _currentMeasure = 1;
  int _totalSubdivisionsElapsed = 0;

  /// Callbacks de orquestación global para sincronizar todas las herramientas de Tunner
  VoidCallback? onPlayAll;
  VoidCallback? onPauseAll;
  VoidCallback? onStopAll;
  void Function(double bpm)? onBpmChanged;

  // Registro de pulsaciones para cálculo de Tap Tempo
  final List<DateTime> _tapHistory = [];
  static const int _maxTapSamples = 5;
  static const Duration _tapTimeout = Duration(seconds: 2);

  final StreamController<int> _beatStreamController = StreamController<int>.broadcast();
  final StreamController<bool> _downbeatStreamController = StreamController<bool>.broadcast();

  StudioMasterClockService({
    double initialBpm = 120.0,
    int initialMeterNumerator = 4,
    int initialMeterDenominator = 4,
  })  : _bpm = initialBpm.clamp(20.0, 300.0),
        _meterNumerator = initialMeterNumerator.clamp(1, 16),
        _meterDenominator = initialMeterDenominator.clamp(1, 16);

  double get bpm => _bpm;
  int get meterNumerator => _meterNumerator;
  int get meterDenominator => _meterDenominator;
  StudioTransportStatus get status => _status;
  bool get isPlaying => _status == StudioTransportStatus.playing;
  bool get isPaused => _status == StudioTransportStatus.paused;
  bool get isStopped => _status == StudioTransportStatus.stopped;

  int get currentBeat => _currentBeat;
  int get currentMeasure => _currentMeasure;
  bool get isDownbeat => _currentBeat == 1;
  Duration get elapsedDuration => _stopwatch.elapsed;

  Stream<int> get onBeat => _beatStreamController.stream;
  Stream<bool> get onDownbeat => _downbeatStreamController.stream;

  /// Duración exacta de una negra (quarter note) en milisegundos:
  ///
  /// $$t_{\text{negra}} = \frac{60\,000}{\text{BPM}}$$
  double get beatIntervalMs => 60000.0 / _bpm;

  /// Ajusta el tempo del reloj maestro de 20 a 300 BPM.
  void setBpm(double newBpm) {
    final clamped = newBpm.clamp(20.0, 300.0);
    if ((clamped - _bpm).abs() < 0.01) return;
    _bpm = clamped;
    onBpmChanged?.call(clamped);
    notifyListeners();
  }

  /// Ajusta la signatura de compás (ej. 4/4, 3/4, 6/8).
  void setMeter(int numerator, int denominator) {
    _meterNumerator = numerator.clamp(1, 16);
    _meterDenominator = denominator.clamp(1, 16);
    notifyListeners();
  }

  /// Inicia el transporte del reloj maestro de estudio.
  void startTransport({double? bpm}) {
    if (bpm != null) setBpm(bpm);
    if (_status == StudioTransportStatus.playing) return;

    _status = StudioTransportStatus.playing;
    _stopwatch.start();
    _startTicker();
    onPlayAll?.call();
    notifyListeners();
  }

  /// Pausa el transporte sin resetear el compás actual.
  void pauseTransport() {
    if (_status != StudioTransportStatus.playing) return;
    _status = StudioTransportStatus.paused;
    _stopwatch.stop();
    _tickerTimer?.cancel();
    _tickerTimer = null;
    onPauseAll?.call();
    notifyListeners();
  }

  /// Detiene el transporte y reinicia los contadores de compás y compás fuerte a cero.
  void stopTransport() {
    _status = StudioTransportStatus.stopped;
    _stopwatch.stop();
    _stopwatch.reset();
    _tickerTimer?.cancel();
    _tickerTimer = null;

    _currentBeat = 1;
    _currentMeasure = 1;
    _totalSubdivisionsElapsed = 0;
    onStopAll?.call();
    notifyListeners();
  }

  void togglePlayPause() {
    if (isPlaying) {
      pauseTransport();
    } else {
      startTransport();
    }
  }

  /// Registra una pulsación táctil manual y recalcula el BPM ponderado (*Tap Tempo*).
  void registerTap() {
    final now = DateTime.now();

    // Si ha pasado mucho tiempo desde el último tap, reiniciar historial
    if (_tapHistory.isNotEmpty && now.difference(_tapHistory.last) > _tapTimeout) {
      _tapHistory.clear();
    }

    _tapHistory.add(now);
    if (_tapHistory.length > _maxTapSamples) {
      _tapHistory.removeAt(0);
    }

    if (_tapHistory.length >= 2) {
      double totalDeltaMs = 0.0;
      for (int i = 1; i < _tapHistory.length; i++) {
        totalDeltaMs += _tapHistory[i].difference(_tapHistory[i - 1]).inMilliseconds;
      }
      final avgDeltaMs = totalDeltaMs / (_tapHistory.length - 1);
      if (avgDeltaMs > 100.0 && avgDeltaMs < 3000.0) {
        final calculatedBpm = 60000.0 / avgDeltaMs;
        setBpm(calculatedBpm);
      }
    }
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    // Ticker de alta resolución cada 25 ms para muestreo determinista
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      if (_status != StudioTransportStatus.playing) return;

      final elapsedMs = _stopwatch.elapsedMilliseconds.toDouble();
      final totalBeats = (elapsedMs / beatIntervalMs).floor();

      if (totalBeats > _totalSubdivisionsElapsed) {
        _totalSubdivisionsElapsed = totalBeats;

        final beatInBar = (totalBeats % _meterNumerator) + 1;
        final measure = (totalBeats ~/ _meterNumerator) + 1;

        _currentBeat = beatInBar;
        _currentMeasure = measure;

        _beatStreamController.add(_currentBeat);
        if (_currentBeat == 1) {
          _downbeatStreamController.add(true);
        }

        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _stopwatch.stop();
    _beatStreamController.close();
    _downbeatStreamController.close();
    super.dispose();
  }
}
