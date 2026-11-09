import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../navigation/presentation/contextual_help_sheet.dart';
import '../../tuner_viewmodel.dart';
import '../domain/blind_ear_trainer_engine.dart';
import '../domain/ear_training_exercise.dart';

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
  EarTrainingQuestion? _question;
  EarTrainingAnswerResult? _lastResult;
  DateTime? _questionStartTime;
  Timer? _note2Timer;
  Timer? _stopTimer;

  @override
  void initState() {
    super.initState();
    _engine = BlindEarTrainerEngine();
    _generateNextQuestion();
  }

  @override
  void dispose() {
    _note2Timer?.cancel();
    _stopTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _generateNextQuestion() {
    setState(() {
      _question = _engine.generateNextQuestion();
      _lastResult = null;
      _questionStartTime = DateTime.now();
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
    );

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
    final palette = widget.viewModel.currentPalette;
    final q = _question;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: palette.scaffoldBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: palette.staffLinesColor.withValues(alpha: 0.3),
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
                color: palette.staffLinesColor.withValues(alpha: 0.4),
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
                      color: palette.primaryAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('👂', style: TextStyle(fontSize: 22)),
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
                                color: palette.textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ContextualHelpBadge(
                              toolId: 'ear_trainer',
                              palette: palette,
                              size: 16,
                            ),
                          ],
                        ),
                        Text(
                          'Discriminación de Intervalos sin Apoyo Visual',
                          style: TextStyle(
                            color: palette.textColor.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botón Cerrar
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textColor.withValues(alpha: 0.7)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Colors.white10),

            // Panel de estadísticas de racha y puntuación
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _buildStatBadge(
                    'RACHA',
                    '${_engine.currentStreak} 🔥',
                    palette.primaryAccent,
                    palette,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    'PUNTAJE',
                    '${_engine.totalScore}',
                    const Color(0xFF10B981),
                    palette,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    'PRECISIÓN',
                    '${_engine.accuracyPercentage.toStringAsFixed(0)}%',
                    const Color(0xFF38BDF8),
                    palette,
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
                            ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isBlindModeActive ? const Color(0xFF6366F1) : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isBlindModeActive ? Icons.visibility_off : Icons.visibility,
                            color: _isBlindModeActive ? const Color(0xFF818CF8) : Colors.white60,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isBlindModeActive ? 'Modo a Ciegas' : 'Modo Visible',
                            style: TextStyle(
                              color: _isBlindModeActive ? const Color(0xFF818CF8) : Colors.white70,
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
                        color: palette.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isPlayingAudio
                              ? palette.primaryAccent
                              : palette.staffLinesColor.withValues(alpha: 0.3),
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
                                    ? palette.primaryAccent
                                    : palette.primaryAccent.withValues(alpha: 0.15),
                                border: Border.all(color: palette.primaryAccent, width: 2),
                                boxShadow: _isPlayingAudio
                                    ? [
                                        BoxShadow(
                                          color: palette.primaryAccent.withValues(alpha: 0.5),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                _isPlayingAudio ? Icons.volume_up : Icons.play_arrow,
                                color: _isPlayingAudio ? Colors.black : palette.primaryAccent,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _isPlayingAudio ? 'Escuchando intervalo...' : 'Toca o presiona [Espacio] para re-escuchar',
                            style: TextStyle(
                              color: palette.textColor.withValues(alpha: 0.8),
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
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '🔒 PANTALLA A CIEGAS: CONFÍA EN TU PERCEPCIÓN AUDITIVA',
                                style: TextStyle(
                                  color: Color(0xFFFBBF24),
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
                                    color: palette.textColor.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  (q?.isAscending ?? true) ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 14,
                                  color: palette.primaryAccent,
                                ),
                                Text(
                                  (q?.isAscending ?? true) ? 'Ascendente' : 'Descendente',
                                  style: TextStyle(
                                    color: palette.primaryAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

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

                          Color buttonBg = palette.cardBackground;
                          Color borderColor = palette.staffLinesColor.withValues(alpha: 0.4);

                          if (isAnswered) {
                            if (isTarget) {
                              buttonBg = const Color(0xFF10B981).withValues(alpha: 0.2);
                              borderColor = const Color(0xFF10B981);
                            } else if (isSelected) {
                              buttonBg = const Color(0xFFEF4444).withValues(alpha: 0.2);
                              borderColor = const Color(0xFFEF4444);
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
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: palette.textColor,
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
                                            color: palette.textColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          option.displayName,
                                          style: TextStyle(
                                            color: palette.textColor.withValues(alpha: 0.7),
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
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _lastResult!.isCorrect
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _lastResult!.isCorrect ? Icons.check_circle : Icons.cancel,
                                  color: _lastResult!.isCorrect
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _lastResult!.isCorrect ? '¡CORRECTO!' : 'RESPUESTA INCORRECTA',
                                  style: TextStyle(
                                    color: _lastResult!.isCorrect
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Grado ${_lastResult!.grade.letter}',
                                    style: const TextStyle(
                                      color: Colors.white,
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
                                color: palette.textColor.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              key: const Key('btn_next_question'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.primaryAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _generateNextQuestion,
                              icon: const Icon(Icons.arrow_forward, size: 18),
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
    TunnerThemePalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textColor.withValues(alpha: 0.5),
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
