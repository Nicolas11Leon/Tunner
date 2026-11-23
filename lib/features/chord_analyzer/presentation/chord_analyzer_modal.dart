import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
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
    final tokens = StudioThemeScope.of(context);
    final legacyPalette = viewModel.currentPalette;
    final chord = viewModel.recognizedChord;
    final chroma = viewModel.activeChromaVector;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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

          // Encabezado del modal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                StudioIcon(
                  StudioIconId.moduleChordAnalyzer,
                  color: tokens.accentPrimary,
                  size: 22,
                  tintCustomAsset: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reconocimiento Polifónico',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Chroma Vectors & Pitch Class Profile',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botón para abrir el visualizador polifónico en vivo con armónicos H1-H8
                IconButton(
                  key: const Key('btn_open_live_harmonics_modal'),
                  icon: StudioIcon(
                    StudioIconId.moduleSpectrogram,
                    size: 18,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                  tooltip: 'Visualizador de Armónicos H1-H8',
                  onPressed: () => PolyphonicLiveVoicingModal.show(context, viewModel),
                ),
                // Switch de activación
                IconButton(
                  key: const Key('toggle_chord_recognition_btn'),
                  icon: StudioIcon(
                    StudioIconId.uiPower,
                    size: 18,
                    color: viewModel.isChordRecognitionActive
                        ? tokens.accentSuccess
                        : tokens.textMuted,
                    tintCustomAsset: true,
                  ),
                  tooltip: viewModel.isChordRecognitionActive
                      ? 'Desactivar Reconocimiento'
                      : 'Activar Reconocimiento',
                  onPressed: () => viewModel.toggleChordRecognition(),
                ),
                IconButton(
                  key: const Key('chord_toggle_mic_btn'),
                  icon: StudioIcon(
                    viewModel.isRecording
                        ? StudioIconId.audioMicOn
                        : StudioIconId.audioMicOff,
                    size: 18,
                    color: viewModel.isRecording
                        ? tokens.accentPrimary
                        : tokens.textMuted,
                    tintCustomAsset: true,
                  ),
                  tooltip: viewModel.isRecording ? 'Apagar Micrófono' : 'Activar Micrófono',
                  onPressed: () => viewModel.toggleRecording(),
                ),
                IconButton(
                  icon: StudioIcon(
                    StudioIconId.uiCloseConfirm,
                    size: 18,
                    color: tokens.textSecondary,
                    tintCustomAsset: true,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: tokens.borderSubtle),

          // Contenido principal scrollable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. Tarjeta Monumental del Acorde Activo
                _buildActiveChordCard(context, tokens),

                const SizedBox(height: 18),

                // 2. Descomposición Multitonal en Vivo (Voces, Octavas y Cents)
                MultiToneVoicingWidget(
                  analysisResult: viewModel.polyphonicAnalysisResult,
                  palette: legacyPalette,
                ),

                const SizedBox(height: 18),

                // 3. Radar Cromático de 12 Semitonos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.panelBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tokens.borderHairline,
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
                              color: tokens.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: tokens.elevatedSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: tokens.borderHairline),
                            ),
                            child: Text(
                              '12 Semitonos',
                              style: TextStyle(
                                color: tokens.accentSecondary,
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
                          palette: legacyPalette,
                          size: 240,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Historial de Progresiones Armónicas Recientes
                _buildChordHistorySection(context, tokens),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChordCard(
    BuildContext context,
    StudioDesignTokens tokens,
  ) {
    final chord = viewModel.recognizedChord;
    final bool isRecognized = chord.isRecognized;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecognized
              ? tokens.accentPrimary.withValues(alpha: 0.6)
              : tokens.borderHairline,
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
                  color: tokens.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isRecognized)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tokens.accentPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${(chord.confidence * 100).toStringAsFixed(0)}% Certeza',
                    style: TextStyle(
                      color: tokens.accentPrimary,
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
                    color: tokens.textMuted,
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
                    color: tokens.textPrimary,
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
                      color: tokens.accentSecondary,
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
                    color: tokens.textMuted,
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
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: Text(
                        chord.notes[i],
                        style: TextStyle(
                          color: tokens.textPrimary,
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
                      color: tokens.textMuted.withValues(alpha: 0.5),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Toca un acorde en tu instrumento (guitarra, piano o ensamble)',
                    style: TextStyle(
                      color: tokens.textMuted,
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
    StudioDesignTokens tokens,
  ) {
    final history = viewModel.chordHistory;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.borderHairline,
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
                  color: tokens.textPrimary,
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
                      color: tokens.accentSecondary,
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
                color: tokens.textMuted,
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
                separatorBuilder: (_, _) => StudioIcon(
                  StudioIconId.transportForward,
                  size: 10,
                  color: tokens.textMuted,
                  tintCustomAsset: true,
                  fallbackOverride: Icons.arrow_forward_ios,
                ),
                itemBuilder: (ctx, i) {
                  final item = history[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tokens.borderHairline,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.symbol,
                        style: TextStyle(
                          color: tokens.accentPrimary,
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
