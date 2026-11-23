import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../navigation/presentation/contextual_help_sheet.dart';
import '../../tuner_viewmodel.dart';
import '../domain/blind_ear_trainer_engine.dart';
import '../domain/ear_training_exercise.dart';
import '../domain/musical_interval.dart';

/// Modal interactivo de Conservatorio para el Entrenamiento Auditivo de Intervalos a Ciegas.
///
/// Implementa atajos de teclado primarios:
/// - `1`, `2`, `3`, `4`: Selección rápida de opciones de intervalo.
/// - `Espacio`: Reproducir / Repetir el estímulo auditivo.
/// - `Enter`: Avanzar al siguiente ejercicio tras responder.
/// - `Escape`: Cerrar el modal.
class BlindEarTrainerModal extends StatefulWidget {
  final TunerViewModel viewModel;

  const BlindEarTrainerModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlindEarTrainerModal(viewModel: viewModel),
    );
  }

  @override
  State<BlindEarTrainerModal> createState() => _BlindEarTrainerModalState();
}

class _BlindEarTrainerModalState extends State<BlindEarTrainerModal> {
  late final BlindEarTrainerEngine _engine;
  final FocusNode _focusNode = FocusNode();

  bool _isBlindModeActive = true;
  bool _isPlayingAudio = false;
  bool _isSungResponseMode = false;
  EarTrainingQuestion? _question;
  EarTrainingAnswerResult? _lastResult;
  DateTime? _questionStartTime;
  Timer? _note2Timer;
  Timer? _stopTimer;
  final List<double> _consecutiveSungSamples = [];
  double _lastDetectedSungFrequency = 0.0;

  @override
  void initState() {
    super.initState();
    _engine = BlindEarTrainerEngine();
    widget.viewModel.telemetryListenable.addListener(_onLiveTelemetry);
    _generateNextQuestion();
  }

  @override
  void dispose() {
    widget.viewModel.telemetryListenable.removeListener(_onLiveTelemetry);
    _note2Timer?.cancel();
    _stopTimer?.cancel();
    widget.viewModel.stopReferenceTone();
    _focusNode.dispose();
    super.dispose();
  }

  void _onLiveTelemetry() {
    if (!mounted || !_isSungResponseMode || _lastResult != null || _isPlayingAudio) {
      return;
    }
    final freq = widget.viewModel.telemetryListenable.value.frequency;
    if (freq <= 20.0) {
      _consecutiveSungSamples.clear();
      return;
    }

    _lastDetectedSungFrequency = freq;

    if (_consecutiveSungSamples.isNotEmpty) {
      final prevFreq = _consecutiveSungSamples.last;
      final deltaCents = MusicalInterval.calculateCentsDeviation(freq, prevFreq).abs();
      if (deltaCents >= 50.0) {
        _consecutiveSungSamples.clear();
      }
    }

    _consecutiveSungSamples.add(freq);
    setState(() {});

    if (_consecutiveSungSamples.length >= 3) {
      final avgFreq = _consecutiveSungSamples.reduce((a, b) => a + b) /
          _consecutiveSungSamples.length;
      _consecutiveSungSamples.clear();
      _submitSungTone(avgFreq);
    }
  }

  void _toggleSungResponseMode() {
    setState(() {
      _isSungResponseMode = !_isSungResponseMode;
      _consecutiveSungSamples.clear();
      _lastDetectedSungFrequency = 0.0;
    });
    if (_isSungResponseMode && !widget.viewModel.isRecording) {
      widget.viewModel.toggleRecording();
    }
  }

  void _submitSungTone(double freq) {
    if (_lastResult != null) return;
    final q = _question;
    if (q == null || freq <= 20.0) return;
    _consecutiveSungSamples.clear();
    final elapsedMs = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds
        : 1800;
    final result = _engine.submitSungFrequency(
      freq,
      responseTimeMs: elapsedMs,
    );
    widget.viewModel.recordEarTrainingAnswer(q.targetInterval, result);
    setState(() {
      _lastResult = result;
    });
  }

  void _generateNextQuestion() {
    setState(() {
      _question = _engine.generateNextQuestion();
      _lastResult = null;
      _questionStartTime = DateTime.now();
      _consecutiveSungSamples.clear();
      _lastDetectedSungFrequency = 0.0;
    });
    _playIntervalStimulus();
  }

  void _playIntervalStimulus() {
    final q = _question;
    if (q == null) return;

    _note2Timer?.cancel();
    _stopTimer?.cancel();

    setState(() {
      _isPlayingAudio = true;
    });

    // Reproducir nota base
    widget.viewModel.startReferencePitchTone(q.baseFrequencyHz);

    // Tras 650 ms, reproducir nota objetivo
    _note2Timer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      widget.viewModel.startReferencePitchTone(q.targetFrequencyHz);

      // Silenciar tras 750 ms
      _stopTimer = Timer(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        widget.viewModel.stopReferenceTone();
        setState(() {
          _isPlayingAudio = false;
        });
      });
    });
  }

  void _selectOption(int optionIndex) {
    if (_lastResult != null) return; // Ya respondido
    final q = _question;
    if (q == null || optionIndex < 0 || optionIndex >= q.options.length) return;

    final selectedInterval = q.options[optionIndex];
    final elapsedMs = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds
        : 1500;

    final result = _engine.submitIntervalChoice(
      selectedInterval,
      responseTimeMs: elapsedMs,
      centsDeviation: 0.0,
      hasAcousticCents: false,
    );
    widget.viewModel.recordEarTrainingAnswer(q.targetInterval, result);

    setState(() {
      _lastResult = result;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _selectOption(0);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _selectOption(1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _selectOption(2);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      _selectOption(3);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.space) {
      _playIntervalStimulus();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_lastResult != null) {
        _generateNextQuestion();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final legacyPalette = widget.viewModel.currentPalette;
    final q = _question;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: tokens.canvasBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: tokens.borderHairline,
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            // Barra de arrastre superior
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Cabecera con título, métricas y botón de ayuda contextual
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: StudioIcon(
                      StudioIconId.audioHeadphones,
                      color: tokens.accentPrimary,
                      size: 20,
                      tintCustomAsset: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ENTRENADOR A CIEGAS',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ContextualHelpBadge(
                              toolId: 'ear_trainer',
                              palette: legacyPalette,
                              size: 16,
                            ),
                          ],
                        ),
                        Text(
                          'Discriminación de Intervalos sin Apoyo Visual',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botón Cerrar
                  IconButton(
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      size: 18,
                      color: tokens.textSecondary,
                      tintCustomAsset: true,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: tokens.borderSubtle),

            // Panel de estadísticas de racha y puntuación
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _buildStatBadge(
                    'RACHA',
                    '${_engine.currentStreak}',
                    tokens.accentPrimary,
                    tokens,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    'PUNTAJE',
                    '${_engine.totalScore}',
                    tokens.accentSuccess,
                    tokens,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    'PRECISIÓN',
                    '${_engine.accuracyPercentage.toStringAsFixed(0)}%',
                    tokens.accentSecondary,
                    tokens,
                  ),
                  const Spacer(),
                  // Interruptor Modo a Ciegas
                  InkWell(
                    key: const Key('btn_toggle_blind_mode'),
                    onTap: () {
                      setState(() {
                        _isBlindModeActive = !_isBlindModeActive;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isBlindModeActive
                            ? tokens.elevatedSurface
                            : tokens.panelBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isBlindModeActive
                              ? tokens.accentPrimary
                              : tokens.borderHairline,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StudioIcon(
                            StudioIconId.uiLock,
                            color: _isBlindModeActive
                                ? tokens.accentPrimary
                                : tokens.textMuted,
                            size: 14,
                            tintCustomAsset: true,
                            fallbackOverride: _isBlindModeActive
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isBlindModeActive ? 'Modo a Ciegas' : 'Modo Visible',
                            style: TextStyle(
                              color: _isBlindModeActive
                                  ? tokens.accentPrimary
                                  : tokens.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenedor principal scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Área acústica del estímulo
                    Container(
                      key: const Key('ear_trainer_stimulus_box'),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: tokens.panelBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isPlayingAudio
                              ? tokens.accentPrimary
                              : tokens.borderHairline,
                          width: _isPlayingAudio ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Botón circular central para reproducir
                          GestureDetector(
                            key: const Key('btn_replay_stimulus'),
                            onTap: _playIntervalStimulus,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isPlayingAudio
                                    ? tokens.accentPrimary
                                    : tokens.elevatedSurface,
                                border: Border.all(color: tokens.accentPrimary, width: 2),
                                boxShadow: _isPlayingAudio
                                    ? [
                                        BoxShadow(
                                          color: tokens.accentPrimary.withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: StudioIcon(
                                  _isPlayingAudio
                                      ? StudioIconId.audioVolumeOn
                                      : StudioIconId.transportPlay,
                                  color: _isPlayingAudio
                                      ? tokens.textOnAccent
                                      : tokens.accentPrimary,
                                  size: 32,
                                  tintCustomAsset: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _isPlayingAudio ? 'Escuchando intervalo...' : 'Toca o presiona [Espacio] para re-escuchar',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Modo a Ciegas vs Detalle revelado
                          if (_isBlindModeActive && _lastResult == null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.inputSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tokens.borderHairline),
                              ),
                              child: Text(
                                'MODO A CIEGAS: PERCEPCIÓN AUDITIVA PURA',
                                style: TextStyle(
                                  color: tokens.accentWarning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Nota Base: ${q?.baseNoteName ?? ''}',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                StudioIcon(
                                  (q?.isAscending ?? true)
                                      ? StudioIconId.transportForward
                                      : StudioIconId.transportRewind,
                                  size: 14,
                                  color: tokens.accentPrimary,
                                  tintCustomAsset: true,
                                  fallbackOverride: (q?.isAscending ?? true)
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (q?.isAscending ?? true) ? 'Ascendente' : 'Descendente',
                                  style: TextStyle(
                                    color: tokens.accentPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Modo Responder Cantando / Tocando (Microfono)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('btn_sung_response_mode'),
                            onPressed: _toggleSungResponseMode,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _isSungResponseMode
                                    ? tokens.accentPrimary
                                    : tokens.borderHairline,
                              ),
                            ),
                            icon: StudioIcon(
                              _isSungResponseMode
                                  ? StudioIconId.audioMicOn
                                  : StudioIconId.audioMicOff,
                              size: 16,
                              color: _isSungResponseMode
                                  ? tokens.accentPrimary
                                  : tokens.textMuted,
                              tintCustomAsset: true,
                            ),
                            label: Text(
                              _isSungResponseMode
                                  ? 'Modo Microfono Activo (${widget.viewModel.frequency > 20 ? "${widget.viewModel.frequency.toStringAsFixed(1)} Hz" : "escuchando..."})'
                                  : 'Responder Cantando / Tocando (Micrófono)',
                              style: TextStyle(
                                color: _isSungResponseMode
                                    ? tokens.accentPrimary
                                    : tokens.textPrimary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        if (_isSungResponseMode && _lastResult == null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            key: const Key('btn_submit_sung_tone'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.accentPrimary,
                              foregroundColor: tokens.textOnAccent,
                            ),
                            onPressed: (widget.viewModel.frequency > 20.0 ||
                                    _lastDetectedSungFrequency > 20.0)
                                ? () => _submitSungTone(
                                      widget.viewModel.frequency > 20.0
                                          ? widget.viewModel.frequency
                                          : _lastDetectedSungFrequency,
                                    )
                                : null,
                            child: const Text('Evaluar', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Opciones de respuesta (Grid de 4 botones con atajos 1, 2, 3, 4)
                    if (q != null)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: q.options.length,
                        itemBuilder: (ctx, index) {
                          final option = q.options[index];
                          final isAnswered = _lastResult != null;
                          final isTarget = option == q.targetInterval;
                          final isSelected = _lastResult?.selectedInterval == option;

                          Color buttonBg = tokens.panelBackground;
                          Color borderColor = tokens.borderHairline;

                          if (isAnswered) {
                            if (isTarget) {
                              buttonBg = tokens.accentSuccess.withValues(alpha: 0.16);
                              borderColor = tokens.accentSuccess;
                            } else if (isSelected) {
                              buttonBg = tokens.accentDanger.withValues(alpha: 0.16);
                              borderColor = tokens.accentDanger;
                            }
                          }

                          return InkWell(
                            key: Key('btn_interval_option_$index'),
                            onTap: isAnswered ? null : () => _selectOption(index),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: buttonBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor, width: isTarget && isAnswered ? 2.0 : 1.0),
                              ),
                              child: Row(
                                children: [
                                  // Badge del atajo de teclado [1]..[4]
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tokens.elevatedSurface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: tokens.borderHairline),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          option.shortName,
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          option.displayName,
                                          style: TextStyle(
                                            color: tokens.textSecondary,
                                            fontSize: 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 16),

                    // Resultado y botón siguiente
                    if (_lastResult != null) ...[
                      Container(
                        key: const Key('ear_trainer_result_banner'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lastResult!.isCorrect
                              ? tokens.accentSuccess.withValues(alpha: 0.14)
                              : tokens.accentDanger.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _lastResult!.isCorrect
                                ? tokens.accentSuccess
                                : tokens.accentDanger,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                StudioIcon(
                                  StudioIconId.uiCloseConfirm,
                                  color: _lastResult!.isCorrect
                                      ? tokens.accentSuccess
                                      : tokens.accentDanger,
                                  size: 18,
                                  tintCustomAsset: true,
                                  fallbackOverride: _lastResult!.isCorrect
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _lastResult!.isCorrect ? '¡CORRECTO!' : 'RESPUESTA INCORRECTA',
                                  style: TextStyle(
                                    color: _lastResult!.isCorrect
                                        ? tokens.accentSuccess
                                        : tokens.accentDanger,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.inputSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: tokens.borderHairline),
                                  ),
                                  child: Text(
                                    'Grado ${_lastResult!.grade.letter}',
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _lastResult!.feedbackMessage,
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              key: const Key('btn_next_question'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.accentPrimary,
                                foregroundColor: tokens.textOnAccent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _generateNextQuestion,
                              icon: StudioIcon(
                                StudioIconId.transportForward,
                                size: 16,
                                color: tokens.textOnAccent,
                                tintCustomAsset: true,
                              ),
                              label: const Text(
                                'SIGUIENTE EJERCICIO [ENTER]',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(
    String label,
    String value,
    Color accentColor,
    StudioDesignTokens tokens,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
