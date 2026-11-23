import 'package:flutter/material.dart';

import '../../../../core/design_system/atoms/studio_icon.dart';
import '../../../../core/design_system/domain/studio_icon_catalog.dart';
import '../../../../core/design_system/studio_theme_provider.dart';
import '../../../instrument/domain/instrument_profile_entity.dart';
import '../../../instrument/presentation/widgets/smart_instrument_badge.dart';
import '../tuner_viewmodel.dart';

/// Modal de Selector de Instrumento, Reconocimiento Inteligente y Transposición
/// extraído de [TunerScreen]. Estilizado con [StudioThemeScope] y [StudioIcon].
class TunerInstrumentModal extends StatelessWidget {
  final TunerViewModel viewModel;

  const TunerInstrumentModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    final tokens = StudioThemeScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TunerInstrumentModal(viewModel: viewModel),
    );
  }

  StudioIconId _iconForFamily(InstrumentFamily family) {
    if (family == InstrumentFamily.brass) {
      return StudioIconId.audioVolumeOn;
    }
    if (family == InstrumentFamily.strings) {
      return StudioIconId.moduleScoreSheet;
    }
    return StudioIconId.fileMusicXmlMidi;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final palette = viewModel.currentPalette;

    return StatefulBuilder(
      builder: (modalContext, setModalState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      StudioIcon(
                        StudioIconId.modulePianoRoll,
                        color: tokens.accentSecondary,
                        size: 22,
                        tintCustomAsset: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SELECTOR DE INSTRUMENTO',
                        style: TextStyle(
                          color: tokens.accentSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('close_instrument_modal_btn'),
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      color: tokens.textMuted,
                      size: 20,
                      tintCustomAsset: true,
                    ),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Transposición armónica automática de partitura y afinador según la clave del instrumento',
                style: TextStyle(color: tokens.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.inputSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: viewModel.isSmartInstrumentTuningActive
                        ? tokens.accentPrimary.withValues(alpha: 0.4)
                        : tokens.borderSubtle,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        StudioIcon(
                          StudioIconId.uiAutomations,
                          size: 18,
                          color: viewModel.isSmartInstrumentTuningActive
                              ? tokens.accentPrimary
                              : tokens.textMuted,
                          tintCustomAsset: true,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Afinación Inteligente con Reconocimiento',
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Detecta timbre y adapta afinador, filtro acústico y SoundFont',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          key: const Key('toggle_smart_instrument_switch'),
                          value: viewModel.isSmartInstrumentTuningActive,
                          activeThumbColor: tokens.accentPrimary,
                          onChanged: (_) {
                            viewModel.toggleSmartInstrumentTuning();
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    if (viewModel.isSmartInstrumentTuningActive) ...[
                      Divider(color: tokens.borderSubtle, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: SmartInstrumentBadge(
                              isSmartTuningActive: viewModel.isSmartInstrumentTuningActive,
                              autoSwitchEnabled: viewModel.autoSwitchInstrumentEnabled,
                              match: viewModel.lastDetectedMatch,
                              activeInstrument: viewModel.activeInstrument,
                              palette: palette,
                              onToggleSmartTuning: () {
                                viewModel.toggleSmartInstrumentTuning();
                                setModalState(() {});
                              },
                              onToggleAutoSwitch: () {
                                viewModel.toggleAutoSwitchInstrument();
                                setModalState(() {});
                              },
                              onApplyMatch: (match) {
                                viewModel.applyDetectedInstrumentMatch(match);
                                setModalState(() {});
                              },
                              onDismissMatch: () {
                                viewModel.dismissSmartInstrumentMatch();
                                setModalState(() {});
                              },
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Auto-adaptar',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                              Checkbox(
                                key: const Key('auto_switch_instrument_checkbox'),
                                value: viewModel.autoSwitchInstrumentEnabled,
                                activeColor: tokens.accentPrimary,
                                onChanged: (_) {
                                  viewModel.toggleAutoSwitchInstrument();
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(modalContext).size.height * 0.55,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: InstrumentProfileEntity.standardInstruments.length,
                    itemBuilder: (context, index) {
                    final inst = InstrumentProfileEntity.standardInstruments[index];
                    final isSelected = viewModel.activeInstrument.id == inst.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isSelected
                            ? tokens.accentPrimary.withValues(alpha: 0.14)
                            : tokens.elevatedSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? tokens.accentPrimary : tokens.borderSubtle,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            viewModel.setInstrumentProfile(inst);
                            Navigator.pop(modalContext);
                          },
                          leading: CircleAvatar(
                            backgroundColor:
                                isSelected ? tokens.accentPrimary : tokens.panelBackground,
                            child: StudioIcon(
                              _iconForFamily(inst.family),
                              color: isSelected ? tokens.textOnAccent : tokens.accentPrimary,
                              size: 18,
                              tintCustomAsset: true,
                            ),
                          ),
                          title: Text(
                            inst.name,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${inst.family.displayName} • ${inst.key.displayName} • ${inst.clef.displayName} (${inst.transpositionSemitones >= 0 ? '+' : ''}${inst.transpositionSemitones} st)',
                            style: TextStyle(color: tokens.textMuted, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (inst.isTransposing)
                                IconButton(
                                  key: Key('transpose_score_btn_${inst.id}'),
                                  icon: StudioIcon(
                                    StudioIconId.uiAutomations,
                                    size: 18,
                                    color: tokens.accentSecondary,
                                    tintCustomAsset: true,
                                    fallbackOverride: Icons.transform,
                                  ),
                                  tooltip: 'Transponer partitura a ${inst.name}',
                                  onPressed: () {
                                    viewModel.transposeActiveScoreForInstrument(inst);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Partitura transpuesta para ${inst.name}'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              if (isSelected)
                                StudioIcon(
                                  StudioIconId.uiCloseConfirm,
                                  size: 18,
                                  color: tokens.accentPrimary,
                                  tintCustomAsset: true,
                                  fallbackOverride: Icons.check_circle,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
