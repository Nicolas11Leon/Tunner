import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import '../domain/multitrack_session_entity.dart';
import '../domain/spectral_comparator_service.dart';
import 'spectral_comparator_painter.dart';

/// Modal interactivo de conservatorio para la comparación espectral y de afinación entre tomas.
class SpectralComparatorModal extends StatefulWidget {
  final TunerViewModel viewModel;

  const SpectralComparatorModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    final tokens = StudioThemeScope.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SpectralComparatorModal(viewModel: viewModel),
    );
  }

  @override
  State<SpectralComparatorModal> createState() => _SpectralComparatorModalState();
}

class _SpectralComparatorModalState extends State<SpectralComparatorModal> {
  static const _comparatorService = SpectralComparatorService();
  String? _selectedTakeAId;
  String? _selectedTakeBId;
  String? _auditioningTakeId;

  @override
  void initState() {
    super.initState();
    final session = widget.viewModel.multiTrackSession;
    _selectedTakeAId = session.selectedTakeAId ?? session.takeA?.id;
    _selectedTakeBId = session.selectedTakeBId ?? session.takeB?.id;
  }

  PracticeTakeEntity? _getTake(String? id) {
    if (id == null) return null;
    final takes = widget.viewModel.multiTrackSession.takes;
    return takes.where((t) => t.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final colorA = tokens.accentPrimary;
    final colorB = tokens.accentWarning;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final session = widget.viewModel.multiTrackSession;
        final takes = session.takes;

        final takeA = _getTake(_selectedTakeAId) ?? session.takeA;
        final takeB = _getTake(_selectedTakeBId) ?? session.takeB;

        final SpectralComparisonResult comparison = (takeA != null && takeB != null)
            ? _comparatorService.compareTakes(takeA, takeB)
            : SpectralComparisonResult.empty;

        final maxComparisonMs = (takeA != null && takeB != null)
            ? math.max(takeA.duration.inMilliseconds, takeB.duration.inMilliseconds)
            : 0;
        final totalDurationMs = maxComparisonMs > 0
            ? maxComparisonMs
            : widget.viewModel.playbackDuration.inMilliseconds;
        final currentPlaybackPositionNormalized = totalDurationMs > 0
            ? (widget.viewModel.playbackPosition.inMilliseconds / totalDurationMs).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: tokens.panelBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: tokens.borderHairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior con manija y cierre
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      StudioIcon(
                        StudioIconId.moduleSpectrogram,
                        color: tokens.accentPrimary,
                        size: 20,
                        tintCustomAsset: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "COMPARADOR ESPECTRAL DE TOMAS",
                        style: TextStyle(
                          color: tokens.accentPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('close_spectral_comparator_btn'),
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      color: tokens.textSecondary,
                      size: 18,
                      tintCustomAsset: true,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Análisis diferencial de entonación (cents) y centroide tímbrico entre ensayos de conservatorio",
                style: TextStyle(color: tokens.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),

              // Selector dual de Tomas (A y B)
              if (takes.length >= 2) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.canvasBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Row(
                    children: [
                      // Selector Toma A
                      Expanded(
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: colorA, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: takeA?.id,
                                  dropdownColor: tokens.panelBackground,
                                  style: TextStyle(color: colorA, fontWeight: FontWeight.bold, fontSize: 12),
                                  items: takes.map((t) {
                                    return DropdownMenuItem(
                                      value: t.id,
                                      child: Text(t.name, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (newId) {
                                    if (newId != null) {
                                      setState(() => _selectedTakeAId = newId);
                                      widget.viewModel.selectComparisonTakes(takeAId: newId);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text("VS", style: TextStyle(color: tokens.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                      // Selector Toma B
                      Expanded(
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: colorB, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: takeB?.id,
                                  dropdownColor: tokens.panelBackground,
                                  style: TextStyle(color: colorB, fontWeight: FontWeight.bold, fontSize: 12),
                                  items: takes.map((t) {
                                    return DropdownMenuItem(
                                      value: t.id,
                                      child: Text(t.name, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (newId) {
                                    if (newId != null) {
                                      setState(() => _selectedTakeBId = newId);
                                      widget.viewModel.selectComparisonTakes(takeBId: newId);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Tarjetas de Métricas de Conservatorio
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: "DELTA AFINACIÓN",
                      value: "${comparison.pitchStabilityDelta >= 0 ? '+' : ''}${comparison.pitchStabilityDelta.toStringAsFixed(1)} c",
                      subtitle: comparison.pitchStabilityDelta >= 0 ? "Mejora de Estabilidad" : "Regresión",
                      color: comparison.pitchStabilityDelta >= 0 ? tokens.accentSuccess : tokens.accentDanger,
                      tokens: tokens,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      title: "AFINACIÓN PURA (±5c)",
                      value: "${comparison.inTunePercentageB.toStringAsFixed(0)}%",
                      subtitle: "Toma A: ${comparison.inTunePercentageA.toStringAsFixed(0)}%",
                      color: tokens.accentPrimary,
                      tokens: tokens,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      title: "DELTA BRILLO (Hz)",
                      value: "${comparison.centroidDeltaHz >= 0 ? '+' : ''}${comparison.centroidDeltaHz.toStringAsFixed(0)} Hz",
                      subtitle: comparison.centroidDeltaHz > 0 ? "Mayor Proyección" : "Más Redondo",
                      color: tokens.accentSecondary,
                      tokens: tokens,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Diagnóstico pedagógico
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.canvasBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Row(
                  children: [
                    StudioIcon(
                      StudioIconId.moduleSpectrogram,
                      size: 16,
                      color: tokens.accentSecondary,
                      tintCustomAsset: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        comparison.pedagogicalSummary,
                        style: TextStyle(color: tokens.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Lienzo Gráfico Comparador Vectorial
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: tokens.canvasBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: SpectralComparatorPainter(
                        comparison: comparison,
                        tokens: tokens,
                        colorTakeA: colorA,
                        colorTakeB: colorB,
                        currentPlaybackPositionNormalized: currentPlaybackPositionNormalized,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Barra de Leyenda y Audición Conmutada A/B
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Leyenda
                  Row(
                    children: [
                      Container(width: 10, height: 3, color: colorA),
                      const SizedBox(width: 4),
                      Text("Toma A", style: TextStyle(color: colorA, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Container(width: 10, height: 3, color: colorB),
                      const SizedBox(width: 4),
                      Text("Toma B", style: TextStyle(color: colorB, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // Controles de Audición
                  Row(
                    children: [
                      OutlinedButton.icon(
                        key: const Key('audition_take_a_btn'),
                        icon: StudioIcon(
                          (_auditioningTakeId == takeA?.id && widget.viewModel.isPlayingAudio)
                              ? StudioIconId.transportPause
                              : StudioIconId.audioVolumeOn,
                          size: 14,
                          color: colorA,
                          tintCustomAsset: true,
                        ),
                        label: Text(
                          (_auditioningTakeId == takeA?.id && widget.viewModel.isPlayingAudio)
                              ? "Pausar A"
                              : "Oír A",
                          style: TextStyle(color: colorA, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorA.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        onPressed: takeA != null ? () => _auditionTake(takeA) : null,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('audition_take_b_btn'),
                        icon: StudioIcon(
                          (_auditioningTakeId == takeB?.id && widget.viewModel.isPlayingAudio)
                              ? StudioIconId.transportPause
                              : StudioIconId.audioVolumeOn,
                          size: 14,
                          color: colorB,
                          tintCustomAsset: true,
                        ),
                        label: Text(
                          (_auditioningTakeId == takeB?.id && widget.viewModel.isPlayingAudio)
                              ? "Pausar B"
                              : "Oír B",
                          style: TextStyle(color: colorB, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorB.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        onPressed: takeB != null ? () => _auditionTake(takeB) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _auditionTake(PracticeTakeEntity take) {
    if (_auditioningTakeId == take.id && widget.viewModel.isPlayingAudio) {
      widget.viewModel.stopActiveRecordingPlayback();
      setState(() => _auditioningTakeId = null);
      return;
    }
    setState(() => _auditioningTakeId = take.id);
    widget.viewModel.playTakeAudio(take);
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required StudioDesignTokens tokens,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.canvasBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: tokens.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text(subtitle, style: TextStyle(color: tokens.textMuted, fontSize: 9), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
