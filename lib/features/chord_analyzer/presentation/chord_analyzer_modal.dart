import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';
import 'chord_radar_widget.dart';
import 'multi_tone_voicing_widget.dart';
import 'polyphonic_live_voicing_widget.dart';

/// Modal interactivo para el Reconocimiento Polifónico de Acordes y Análisis Armónico.
class ChordAnalyzerModal extends StatelessWidget {
  final TunerViewModel viewModel;

  const ChordAnalyzerModal({
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
        builder: (ctx, _) => ChordAnalyzerModal(viewModel: viewModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = viewModel.currentPalette;
    final chord = viewModel.recognizedChord;
    final chroma = viewModel.activeChromaVector;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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

          // Encabezado del modal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, color: palette.primaryAccent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reconocimiento Polifónico',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Chroma Vectors & Pitch Class Profile',
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botón para abrir el visualizador polifónico en vivo con armónicos H1-H8
                IconButton(
                  key: const Key('btn_open_live_harmonics_modal'),
                  icon: Icon(Icons.equalizer, color: palette.primaryAccent),
                  tooltip: 'Visualizador de Armónicos H1-H8',
                  onPressed: () => PolyphonicLiveVoicingModal.show(context, viewModel),
                ),
                // Switch de activación
                IconButton(
                  key: const Key('toggle_chord_recognition_btn'),
                  icon: Icon(
                    viewModel.isChordRecognitionActive
                        ? Icons.power_settings_new
                        : Icons.power_off_outlined,
                    color: viewModel.isChordRecognitionActive
                        ? palette.primaryAccent
                        : palette.textMutedColor,
                  ),
                  tooltip: viewModel.isChordRecognitionActive
                      ? 'Desactivar Reconocimiento'
                      : 'Activar Reconocimiento',
                  onPressed: () => viewModel.toggleChordRecognition(),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textMutedColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Contenido principal scrollable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. Tarjeta Monumental del Acorde Activo
                _buildActiveChordCard(context, palette, chord),

                const SizedBox(height: 18),

                // 2. Descomposición Multitonal en Vivo (Voces, Octavas y Cents)
                MultiToneVoicingWidget(
                  analysisResult: viewModel.polyphonicAnalysisResult,
                  palette: palette,
                ),

                const SizedBox(height: 18),

                // 3. Radar Cromático de 12 Semitonos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: palette.staffLinesColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Radar Cromático (Pitch Classes)',
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: palette.secondaryAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '12 Semitonos',
                              style: TextStyle(
                                color: palette.secondaryAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: ChordRadarWidget(
                          chromaVector: chroma,
                          recognizedChord: chord,
                          palette: palette,
                          size: 240,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Historial de Progresiones Armónicas Recientes
                _buildChordHistorySection(context, palette),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChordCard(
    BuildContext context,
    TunnerThemePalette palette,
    dynamic chord,
  ) {
    final bool isRecognized = chord.isRecognized;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecognized
              ? palette.primaryAccent.withValues(alpha: 0.6)
              : palette.staffLinesColor.withValues(alpha: 0.25),
          width: isRecognized ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Acorde Detectado',
                style: TextStyle(
                  color: palette.textMutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isRecognized)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: palette.primaryAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${(chord.confidence * 100).toStringAsFixed(0)}% Certeza',
                    style: TextStyle(
                      color: palette.primaryAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Text(
                  viewModel.isChordRecognitionActive
                      ? 'Escuchando en vivo...'
                      : 'Reconocimiento en pausa',
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (isRecognized) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  chord.symbol,
                  key: const Key('active_chord_symbol_text'),
                  style: TextStyle(
                    color: palette.textColor,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    chord.displayName,
                    key: const Key('active_chord_name_text'),
                    style: TextStyle(
                      color: palette.secondaryAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Fórmula: ${chord.formula}',
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 6,
                  children: List<Widget>.generate(
                    chord.notes.length,
                    (i) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.staffLinesColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        chord.notes[i],
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '--',
                    key: const Key('active_chord_symbol_placeholder'),
                    style: TextStyle(
                      color: palette.textMutedColor.withValues(alpha: 0.5),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Toca un acorde en tu instrumento (guitarra, piano o ensamble)',
                    style: TextStyle(
                      color: palette.textMutedColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChordHistorySection(
    BuildContext context,
    TunnerThemePalette palette,
  ) {
    final history = viewModel.chordHistory;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.staffLinesColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresión Armónica Reciente',
                style: TextStyle(
                  color: palette.textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (history.isNotEmpty)
                GestureDetector(
                  key: const Key('clear_chord_history_btn'),
                  onTap: () => viewModel.clearChordHistory(),
                  child: Text(
                    'Limpiar',
                    style: TextStyle(
                      color: palette.secondaryAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            Text(
              'Aún no se han registrado progresiones.',
              style: TextStyle(
                color: palette.textMutedColor,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: history.length,
                separatorBuilder: (_, _) => Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: palette.staffLinesColor.withValues(alpha: 0.4),
                ),
                itemBuilder: (ctx, i) {
                  final item = history[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.staffLinesColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: palette.primaryAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.symbol,
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
