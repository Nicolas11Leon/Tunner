/// Supresor de Eco Acústico y Filtrado de Sangrado (Acoustic Echo Suppressor - AES).
///
/// Protege al detector de tono y a los evaluadores de práctica contra el acoplamiento
/// acústico entre los altavoces del dispositivo (clic del metrónomo) y el micrófono.
/// 100% puro Dart, determinista y testeable sin dependencias de plataforma.
class AcousticEchoSuppressor {
  final int blankingDurationMs;
  int _lastClickTimestampMs = 0;
  double _lastLegitimatePitch = 0.0;
  int _lastLegitimatePitchTimestampMs = 0;

  AcousticEchoSuppressor({
    this.blankingDurationMs = 70,
  });

  /// Registra el instante exacto en que se emitió un pulso o clic sonoro de metrónomo.
  void notifyClickEmitted({int? timestampMs}) {
    _lastClickTimestampMs = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
  }

  /// Evalúa si una frecuencia detectada corresponde a un eco o sangrado acústico del metrónomo.
  ///
  /// * Si la frecuencia arriba dentro de la ventana de inmunidad ([blankingDurationMs]) y
  ///   no forma parte de una nota continua sostenida por el instrumentista, retorna `true` (suprimir).
  /// * Si el instrumentista ya venía tocando una nota continua antes del clic, retorna `false` (permitir).
  bool shouldSuppressPitch(double detectedPitchHz, {int? timestampMs}) {
    if (detectedPitchHz <= 0.0) return false;

    final now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final elapsedSinceClick = now - _lastClickTimestampMs;

    // Verificar si nos encontramos dentro de la ventana de amortiguamiento acústico del clic
    if (_lastClickTimestampMs > 0 && elapsedSinceClick >= 0 && elapsedSinceClick <= blankingDurationMs) {
      // Comprobar si el usuario sostenía una nota legítima antes del clic
      final wasSustainingBeforeClick = _lastLegitimatePitch > 20.0 &&
          (now - _lastLegitimatePitchTimestampMs) <= 120;

      if (wasSustainingBeforeClick) {
        // Tolerancia de 1 semitono (~5.9% de variación en frecuencia: ratio 2^(1/12) ≈ 1.05946)
        final ratio = detectedPitchHz / _lastLegitimatePitch;
        if (ratio >= 0.94 && ratio <= 1.06) {
          // El músico continúa sosteniendo su nota legítima a través del clic
          _lastLegitimatePitch = detectedPitchHz;
          _lastLegitimatePitchTimestampMs = now;
          return false;
        }
      }

      // Frecuencia espuria introducida por el transitorio del altavoz: SUPRIMIR
      return true;
    }

    // Fuera de la ventana de clic: registrar como nota legítima
    _lastLegitimatePitch = detectedPitchHz;
    _lastLegitimatePitchTimestampMs = now;
    return false;
  }

  /// Limpia el estado interno de marcas temporales y notas sostenidas.
  void reset() {
    _lastClickTimestampMs = 0;
    _lastLegitimatePitch = 0.0;
    _lastLegitimatePitchTimestampMs = 0;
  }
}
