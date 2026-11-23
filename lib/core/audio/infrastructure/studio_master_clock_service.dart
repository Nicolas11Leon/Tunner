import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/i_studio_master_clock_service.dart';
import '../domain/studio_transport_status.dart';

/// Servicio de infraestructura para el Reloj Maestro de Transporte Unificado de Tunner Studio.
/// Sincroniza compás, tempo (BPM) y fase rítmica con acumulador de fase anclado
/// sobre [Stopwatch] para garantizar cero deriva y transiciones fluidas al cambiar BPM en vivo.
class StudioMasterClockService extends ChangeNotifier implements IStudioMasterClockService {
  double _bpm;
  int _meterNumerator;
  int _meterDenominator;

  StudioTransportStatus _status = StudioTransportStatus.stopped;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickerTimer;
  bool _isDisposed = false;

  // Acumulador de fase para cambios de BPM sin saltos ni congelamientos
  double _accumulatedBeats = 0.0;
  int _anchorElapsedMicros = 0;
  int _lastEmittedBeatIndex = -1;

  int _currentBeat = 1;
  int _currentMeasure = 1;

  /// Callbacks de orquestación global para sincronizar todas las herramientas de Tunner
  VoidCallback? onPlayAll;
  VoidCallback? onPauseAll;
  VoidCallback? onStopAll;
  void Function(double bpm)? onBpmChanged;

  // Registro de pulsaciones para cálculo de Tap Tempo (soporta hasta 20 BPM = 3000ms)
  final List<DateTime> _tapHistory = [];
  static const int _maxTapSamples = 5;
  static const Duration _tapTimeout = Duration(milliseconds: 3200);

  final StreamController<int> _beatStreamController = StreamController<int>.broadcast();
  final StreamController<bool> _downbeatStreamController = StreamController<bool>.broadcast();

  StudioMasterClockService({
    double initialBpm = 120.0,
    int initialMeterNumerator = 4,
    int initialMeterDenominator = 4,
  })  : _bpm = initialBpm.clamp(20.0, 300.0),
        _meterNumerator = initialMeterNumerator.clamp(1, 16),
        _meterDenominator = initialMeterDenominator.clamp(1, 16);

  @override
  double get bpm => _bpm;
  @override
  int get meterNumerator => _meterNumerator;
  @override
  int get meterDenominator => _meterDenominator;
  @override
  StudioTransportStatus get status => _status;
  @override
  bool get isPlaying => _status == StudioTransportStatus.playing;
  @override
  bool get isPaused => _status == StudioTransportStatus.paused;
  @override
  bool get isStopped => _status == StudioTransportStatus.stopped;

  @override
  int get currentBeat => _currentBeat;
  @override
  int get currentMeasure => _currentMeasure;
  @override
  bool get isDownbeat => _currentBeat == 1;
  @override
  Duration get elapsedDuration => _stopwatch.elapsed;

  @override
  Stream<int> get onBeat => _beatStreamController.stream;
  @override
  Stream<bool> get onDownbeat => _downbeatStreamController.stream;

  /// Duración exacta de una negra (quarter note) en milisegundos:
  ///
  /// $$t_{\text{negra}} = \frac{60\,000}{\text{BPM}}$$
  @override
  double get beatIntervalMs => 60000.0 / _bpm;

  void _consolidatePhaseAnchor() {
    final nowMicros = _stopwatch.elapsedMicroseconds;
    final deltaMicros = nowMicros - _anchorElapsedMicros;
    if (deltaMicros > 0) {
      final microsPerBeat = 60000000.0 / _bpm;
      _accumulatedBeats += deltaMicros / microsPerBeat;
      _anchorElapsedMicros = nowMicros;
    }
  }

  double _currentTotalBeats() {
    final nowMicros = _stopwatch.elapsedMicroseconds;
    final deltaMicros = nowMicros - _anchorElapsedMicros;
    final microsPerBeat = 60000000.0 / _bpm;
    return _accumulatedBeats + (deltaMicros / microsPerBeat);
  }

  /// Ajusta el tempo del reloj maestro de 20 a 300 BPM preservando la fase rítmica actual.
  @override
  void setBpm(double newBpm) {
    final clamped = newBpm.clamp(20.0, 300.0);
    if ((clamped - _bpm).abs() < 0.01) return;
    _consolidatePhaseAnchor();
    _bpm = clamped;
    onBpmChanged?.call(clamped);
    if (!_isDisposed) notifyListeners();
  }

  /// Ajusta la signatura de compás (ej. 4/4, 3/4, 6/8).
  @override
  void setMeter(int numerator, int denominator) {
    _meterNumerator = numerator.clamp(1, 16);
    _meterDenominator = denominator.clamp(1, 16);
    if (!_isDisposed) notifyListeners();
  }

  /// Inicia el transporte del reloj maestro de estudio.
  @override
  void startTransport({double? bpm}) {
    if (bpm != null) setBpm(bpm);
    if (_status == StudioTransportStatus.playing) return;

    _status = StudioTransportStatus.playing;
    _anchorElapsedMicros = _stopwatch.elapsedMicroseconds;
    _stopwatch.start();
    _startTicker();
    onPlayAll?.call();
    if (!_isDisposed) notifyListeners();
  }

  /// Pausa el transporte sin resetear el compás ni la fase acumulada.
  @override
  void pauseTransport() {
    if (_status != StudioTransportStatus.playing) return;
    _consolidatePhaseAnchor();
    _status = StudioTransportStatus.paused;
    _stopwatch.stop();
    _tickerTimer?.cancel();
    _tickerTimer = null;
    onPauseAll?.call();
    if (!_isDisposed) notifyListeners();
  }

  /// Detiene el transporte y reinicia los contadores de compás y fase a cero.
  @override
  void stopTransport() {
    _status = StudioTransportStatus.stopped;
    _stopwatch.stop();
    _stopwatch.reset();
    _tickerTimer?.cancel();
    _tickerTimer = null;

    _accumulatedBeats = 0.0;
    _anchorElapsedMicros = 0;
    _lastEmittedBeatIndex = -1;
    _currentBeat = 1;
    _currentMeasure = 1;
    onStopAll?.call();
    if (!_isDisposed) notifyListeners();
  }

  @override
  void togglePlayPause() {
    if (isPlaying) {
      pauseTransport();
    } else {
      startTransport();
    }
  }

  /// Registra una pulsación táctil manual y recalcula el BPM ponderado (*Tap Tempo*).
  @override
  void registerTap() {
    final now = DateTime.now();

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
      if (avgDeltaMs >= 200.0 && avgDeltaMs <= 3000.0) {
        final calculatedBpm = 60000.0 / avgDeltaMs;
        setBpm(calculatedBpm);
      }
    }
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    void scheduleNextBeat() {
      if (_isDisposed || _status != StudioTransportStatus.playing) return;

      final totalBeats = _currentTotalBeats().floor();
      if (totalBeats > _lastEmittedBeatIndex) {
        _lastEmittedBeatIndex = totalBeats;

        final beatInBar = (totalBeats % _meterNumerator) + 1;
        final measure = (totalBeats ~/ _meterNumerator) + 1;

        _currentBeat = beatInBar;
        _currentMeasure = measure;

        if (!_beatStreamController.isClosed) {
          _beatStreamController.add(_currentBeat);
        }
        if (_currentBeat == 1 && !_downbeatStreamController.isClosed) {
          _downbeatStreamController.add(true);
        }

        if (!_isDisposed) notifyListeners();
      }

      final double fractionalBeat = _currentTotalBeats();
      final double remainingBeats = (totalBeats + 1.0) - fractionalBeat;
      final int waitMicros = (remainingBeats * (60000000.0 / _bpm)).round().clamp(1000, 3000000);
      _tickerTimer = Timer(Duration(microseconds: waitMicros), scheduleNextBeat);
    }

    scheduleNextBeat();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _stopwatch.stop();
    _beatStreamController.close();
    _downbeatStreamController.close();
    super.dispose();
  }
}
