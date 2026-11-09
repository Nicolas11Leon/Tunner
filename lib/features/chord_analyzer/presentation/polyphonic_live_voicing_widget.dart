import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../navigation/presentation/contextual_help_sheet.dart';
import '../../tuner_viewmodel.dart';
import '../domain/chord_entity.dart';
import '../domain/polyphonic_pitch_entity.dart';

/// Widget de presentación reactivo para la visualización en tiempo real de
/// descomposición polifónica de acordes, armónicos superiores (H1 a H8)
/// e intervalos constitutivos para estudio y conservatorio.
class PolyphonicLiveVoicingWidget extends StatefulWidget {
  final ChordEntity? recognizedChord;
  final PolyphonicMultiToneAnalysisResult analysisResult;
  final TunnerThemePalette palette;
  final VoidCallback? onToggleLockRoot;

  const PolyphonicLiveVoicingWidget({
    super.key,
    this.recognizedChord,
    required this.analysisResult,
    required this.palette,
    this.onToggleLockRoot,
  });

  @override
  State<PolyphonicLiveVoicingWidget> createState() => _PolyphonicLiveVoicingWidgetState();
}

class _PolyphonicLiveVoicingWidgetState extends State<PolyphonicLiveVoicingWidget> {
  bool _showHarmonicsBreakdown = true;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final chord = widget.recognizedChord;
    final voices = widget.analysisResult.voices;
    final hasVoices = voices.isNotEmpty;

    return Container(
      key: const Key('polyphonic_live_voicing_container'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.staffLinesColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de cabecera con identificación y ayuda contextual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: palette.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.piano, color: palette.primaryAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'VISUALIZADOR POLIFÓNICO',
                                style: TextStyle(
                                  color: palette.textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ContextualHelpBadge(
                                toolId: 'chord_analyzer',
                                palette: palette,
                                size: 16,
                              ),
                            ],
                          ),
                          Text(
                            'Descomposición de Voces & Armónicos H1-H8',
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Selector de vista
              IconButton(
                key: const Key('btn_toggle_harmonics_view'),
                icon: Icon(
                  _showHarmonicsBreakdown ? Icons.equalizer : Icons.view_column,
                  color: palette.primaryAccent,
                  size: 20,
                ),
                tooltip: _showHarmonicsBreakdown ? 'Ver Voces' : 'Ver Armónicos H1-H8',
                onPressed: () {
                  setState(() {
                    _showHarmonicsBreakdown = !_showHarmonicsBreakdown;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Banner del acorde detectado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.scaffoldBackground.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (chord != null && chord.isRecognized ? palette.primaryAccent : Colors.white24).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACORDE RECONOCIDO',
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chord != null && chord.isRecognized
                          ? chord.symbol
                          : (hasVoices ? 'Acorde en Análisis...' : 'Esperando señal polifónica...'),
                      key: const Key('chord_name_display'),
                      style: TextStyle(
                        color: chord != null && chord.isRecognized ? palette.primaryAccent : palette.textMutedColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (chord != null && chord.isRecognized)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.correctPitchColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.correctPitchColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, color: palette.correctPitchColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${(chord.confidence * 100).toStringAsFixed(0)}% Confianza',
                          style: TextStyle(
                            color: palette.correctPitchColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Contenido principal condicional: Desglose de Voces o Espectro de Armónicos
          if (_showHarmonicsBreakdown)
            _buildHarmonicSeriesBreakdown(palette, voices)
          else
            _buildVoicesRow(palette, voices),

          const SizedBox(height: 10),

          // Barra inferior de interoperabilidad con SignalBus
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SIGNALBUS: PUERTO POLIFÓNICO CONECTADO',
                    style: TextStyle(
                      color: palette.textMutedColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                '${voices.length} ${voices.length == 1 ? 'voz' : 'voces'}',
                style: TextStyle(
                  color: palette.primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoicesRow(TunnerThemePalette palette, List<DetectedPolyphonicVoice> voices) {
    if (voices.isEmpty) {
      return Container(
        height: 70,
        alignment: Alignment.center,
        child: Text(
          'Toca un acorde en tu piano o guitarra para visualizar sus notas...',
          style: TextStyle(color: palette.textMutedColor, fontSize: 12),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: voices.map((voice) {
          final isRoot = voice.harmonicRole.toLowerCase().contains('fundamental') ||
              voice.harmonicRole.toLowerCase().contains('root');
          final badgeColor = isRoot ? palette.primaryAccent : const Color(0xFF38BDF8);

          return Container(
            key: Key('voice_badge_${voice.fullNoteNameInternational}'),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  voice.fullNoteNameInternational,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${voice.frequencyHz.toStringAsFixed(1)} Hz',
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  voice.harmonicRole.toUpperCase(),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHarmonicSeriesBreakdown(TunnerThemePalette palette, List<DetectedPolyphonicVoice> voices) {
    // Si hay voces, tomamos la más grave como fundamental f0; si no, 440 Hz
    final f0 = voices.isNotEmpty
        ? voices.map((v) => v.frequencyHz).reduce((a, b) => a < b ? a : b)
        : 440.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERIE ARMÓNICA TEÓRICA (H1 A H8) RESPECTO A LA VOZ GRAVE (${f0.toStringAsFixed(1)} Hz):',
          style: TextStyle(
            color: palette.textMutedColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(8, (i) {
            final harmonicIndex = i + 1;
            final harmonicFreq = f0 * harmonicIndex;
            // Verificar si alguna voz detectada coincide aproximadamente con este armónico
            final matchesVoice = voices.any((v) => (v.frequencyHz - harmonicFreq).abs() < 15.0);

            final barColor = matchesVoice ? palette.primaryAccent : palette.staffLinesColor.withValues(alpha: 0.35);

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: matchesVoice ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: barColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      'H$harmonicIndex',
                      style: TextStyle(
                        color: matchesVoice ? palette.primaryAccent : palette.textMutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: (12 + (8 - i) * 3).toDouble(),
                      width: 6,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      harmonicFreq < 1000
                          ? harmonicFreq.toStringAsFixed(0)
                          : '${(harmonicFreq / 1000).toStringAsFixed(1)}k',
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Modal interactivo de presentación para el Visualizador Polifónico y Armónicos H1-H8.
class PolyphonicLiveVoicingModal extends StatelessWidget {
  final TunerViewModel viewModel;

  const PolyphonicLiveVoicingModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ListenableBuilder(
        listenable: viewModel,
        builder: (ctx, _) => PolyphonicLiveVoicingModal(viewModel: viewModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = viewModel.currentPalette;
    final chord = viewModel.recognizedChord.isRecognized ? viewModel.recognizedChord : null;
    final analysis = viewModel.polyphonicAnalysisResult;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: palette.staffLinesColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PolyphonicLiveVoicingWidget(
                recognizedChord: chord,
                analysisResult: analysis,
                palette: palette,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
