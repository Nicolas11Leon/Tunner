import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: viewModel.currentPalette.cardBackground,
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

  final Color _colorA = const Color(0xFF00E5FF); // Cyan
  final Color _colorB = const Color(0xFFFFD700); // Oro

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
    try {
      return takes.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.viewModel.currentPalette;
    final session = widget.viewModel.multiTrackSession;
    final takes = session.takes;

    final takeA = _getTake(_selectedTakeAId) ?? session.takeA;
    final takeB = _getTake(_selectedTakeBId) ?? session.takeB;

    final SpectralComparisonResult comparison = (takeA != null && takeB != null)
        ? _comparatorService.compareTakes(takeA, takeB)
        : SpectralComparisonResult.empty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                color: palette.staffLinesColor.withValues(alpha: 0.3),
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
                  Icon(Icons.compare_arrows, color: palette.secondaryAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "COMPARADOR ESPECTRAL DE TOMAS",
                    style: TextStyle(
                      color: palette.secondaryAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                key: const Key('close_spectral_comparator_btn'),
                icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Análisis diferencial de entonación (cents) y centroide tímbrico entre ensayos de conservatorio",
            style: TextStyle(color: palette.textMutedColor, fontSize: 11),
          ),
          const SizedBox(height: 12),

          // Selector dual de Tomas (A y B)
          if (takes.length >= 2) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.scaffoldBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  // Selector Toma A
                  Expanded(
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: _colorA, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: takeA?.id,
                              dropdownColor: palette.cardBackground,
                              style: TextStyle(color: _colorA, fontWeight: FontWeight.bold, fontSize: 12),
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
                    child: Text("VS", style: TextStyle(color: palette.textMutedColor, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                  // Selector Toma B
                  Expanded(
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: _colorB, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: takeB?.id,
                              dropdownColor: palette.cardBackground,
                              style: TextStyle(color: _colorB, fontWeight: FontWeight.bold, fontSize: 12),
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
                  color: comparison.pitchStabilityDelta >= 0 ? palette.correctPitchColor : palette.errorPitchColor,
                  palette: palette,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: "AFINACIÓN PURA (±5c)",
                  value: "${comparison.inTunePercentageB.toStringAsFixed(0)}%",
                  subtitle: "Toma A: ${comparison.inTunePercentageA.toStringAsFixed(0)}%",
                  color: palette.primaryAccent,
                  palette: palette,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: "DELTA BRILLO (Hz)",
                  value: "${comparison.centroidDeltaHz >= 0 ? '+' : ''}${comparison.centroidDeltaHz.toStringAsFixed(0)} Hz",
                  subtitle: comparison.centroidDeltaHz > 0 ? "Mayor Proyección" : "Más Redondo",
                  color: palette.secondaryAccent,
                  palette: palette,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Diagnóstico pedagógico
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.scaffoldBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.secondaryAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.insights, size: 16, color: palette.secondaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comparison.pedagogicalSummary,
                    style: TextStyle(color: palette.textColor, fontSize: 11, fontWeight: FontWeight.w500),
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
                color: palette.staffBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: SpectralComparatorPainter(
                    comparison: comparison,
                    palette: palette,
                    colorTakeA: _colorA,
                    colorTakeB: _colorB,
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
                  Container(width: 10, height: 3, color: _colorA),
                  const SizedBox(width: 4),
                  Text("Toma A", style: TextStyle(color: _colorA, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Container(width: 10, height: 3, color: _colorB),
                  const SizedBox(width: 4),
                  Text("Toma B", style: TextStyle(color: _colorB, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              // Controles de Audición
              Row(
                children: [
                  OutlinedButton.icon(
                    key: const Key('audition_take_a_btn'),
                    icon: Icon(
                      (_auditioningTakeId == takeA?.id && widget.viewModel.isPlayingAudio)
                          ? Icons.pause_circle_filled
                          : Icons.volume_up,
                      size: 14,
                      color: _colorA,
                    ),
                    label: Text(
                      (_auditioningTakeId == takeA?.id && widget.viewModel.isPlayingAudio)
                          ? "Pausar A"
                          : "Oír A",
                      style: TextStyle(color: _colorA, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _colorA.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: takeA != null ? () => _auditionTake(takeA) : null,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const Key('audition_take_b_btn'),
                    icon: Icon(
                      (_auditioningTakeId == takeB?.id && widget.viewModel.isPlayingAudio)
                          ? Icons.pause_circle_filled
                          : Icons.volume_up,
                      size: 14,
                      color: _colorB,
                    ),
                    label: Text(
                      (_auditioningTakeId == takeB?.id && widget.viewModel.isPlayingAudio)
                          ? "Pausar B"
                          : "Oír B",
                      style: TextStyle(color: _colorB, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _colorB.withValues(alpha: 0.5)),
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
  }

  void _auditionTake(PracticeTakeEntity take) {
    setState(() => _auditioningTakeId = take.id);
    if (take.filePath.isNotEmpty) {
      widget.viewModel.playTakeAudio(take);
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required TunnerThemePalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: palette.textMutedColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text(subtitle, style: TextStyle(color: palette.textMutedColor, fontSize: 9), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
