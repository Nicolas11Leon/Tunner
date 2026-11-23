import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import '../domain/drone_timbre.dart';
import '../domain/harmonic_drone_config.dart';
import '../domain/harmonic_drone_synthesizer.dart';

/// Modal interactivo para configurar y controlar el Estudio de Dron Armónico continuo.
class HarmonicDroneModal extends StatelessWidget {
  const HarmonicDroneModal({super.key});

  /// Abre el modal de forma responsiva en la parte inferior de la pantalla.
  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const HarmonicDroneModal(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final tokens = StudioThemeScope.of(context);
    final config = viewModel.droneConfig;
    final isPlaying = viewModel.isDronePlaying;

    final freqs = viewModel.droneConfig.octave >= 0
        ? const HarmonicDroneSynthesizer().calculateFrequencies(
            config: config,
            a4Ref: viewModel.referencePitch,
            temperament: viewModel.selectedTemperament,
            temperamentRootKey: viewModel.temperamentRootKey,
          )
        : {'fundamental': 0.0, 'fifth': 0.0, 'octave': 0.0};

    final fundHz = freqs['fundamental'] ?? 0.0;
    final fifthHz = freqs['fifth'] ?? 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: tokens.canvasBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tokens.borderHairline),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de agarre
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.borderHairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    StudioIconId.moduleDrone,
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
                      Text(
                        'Estudio de Dron Armónico',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tono pedal continuo para entrenamiento de intonación',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('close_drone_modal_btn'),
                  icon: StudioIcon(
                    StudioIconId.uiCloseConfirm,
                    size: 18,
                    color: tokens.textSecondary,
                    tintCustomAsset: true,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 24, thickness: 0.5, color: tokens.borderSubtle),

          // Cuerpo con scroll
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // Tarjeta de estado de reproducción y frecuencias
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? tokens.elevatedSurface
                        : tokens.panelBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPlaying
                          ? tokens.accentPrimary
                          : tokens.borderHairline,
                      width: isPlaying ? 1.6 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.rootDisplayName,
                                  key: const Key('active_drone_note_label'),
                                  style: TextStyle(
                                    color: isPlaying ? tokens.accentPrimary : tokens.textPrimary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${config.timbre.displayName} • ${fundHz.toStringAsFixed(1)} Hz'
                                  '${config.includeFifth ? ' + 5ta (${fifthHz.toStringAsFixed(1)} Hz)' : ''}',
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            key: const Key('toggle_drone_playback_btn'),
                            onPressed: () => viewModel.toggleDrone(),
                            icon: StudioIcon(
                              isPlaying ? StudioIconId.transportStop : StudioIconId.transportPlay,
                              size: 18,
                              color: isPlaying ? Colors.white : tokens.textOnAccent,
                              tintCustomAsset: true,
                            ),
                            label: Text(isPlaying ? 'DETENER' : 'ACTIVAR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPlaying ? tokens.accentDanger : tokens.accentPrimary,
                              foregroundColor: isPlaying ? Colors.white : tokens.textOnAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Selector de Nota Raíz Fundamental
                Text(
                  'Nota Fundamental',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(12, (index) {
                    final noteName = HarmonicDroneConfig.chromaticNoteNames[index];
                    final isSelected = config.rootNoteIndex == index;
                    return InkWell(
                      key: Key('drone_root_note_$index'),
                      onTap: () {
                        viewModel.setDroneConfig(config.copyWith(rootNoteIndex: index));
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.accentPrimary
                              : tokens.panelBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? tokens.accentPrimary
                                : tokens.borderHairline,
                          ),
                        ),
                        child: Text(
                          noteName,
                          style: TextStyle(
                            color: isSelected ? tokens.textOnAccent : tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Selector de Octava (A0 a C8)
                Text(
                  'Octava de Registro (0 a 8)',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(9, (oct) {
                      final isSelected = config.octave == oct;
                      final label = 'Oct $oct';
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          key: Key('drone_octave_$oct'),
                          onTap: () {
                            viewModel.setDroneConfig(config.copyWith(octave: oct));
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? tokens.accentPrimary : tokens.panelBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? tokens.accentPrimary
                                    : tokens.borderHairline,
                              ),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? tokens.textOnAccent : tokens.textPrimary,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // Capas Armónicas
                Text(
                  'Capas Armónicas Secundarias',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: tokens.panelBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quinta Armónica Superior (${config.fifthDisplayName})',
                                    style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                  ),
                                  Text(
                                    'Intervalo puro 3:2 o temperado para consonancia acústica',
                                    style: TextStyle(color: tokens.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              key: const Key('drone_toggle_fifth_switch'),
                              value: config.includeFifth,
                              activeThumbColor: tokens.accentPrimary,
                              onChanged: (val) {
                                viewModel.setDroneConfig(config.copyWith(includeFifth: val));
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 0.5, color: tokens.borderSubtle),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Octava Superior (${config.octaveDisplayName})',
                                    style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                  ),
                                  Text(
                                    'Refuerzo de presencia y brillo armónico',
                                    style: TextStyle(color: tokens.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              key: const Key('drone_toggle_octave_switch'),
                              value: config.includeOctave,
                              activeThumbColor: tokens.accentPrimary,
                              onChanged: (val) {
                                viewModel.setDroneConfig(config.copyWith(includeOctave: val));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Selector de Timbre
                Text(
                  'Timbre Acústico Sintetizado',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...DroneTimbre.values.map((timbre) {
                  final isSelected = config.timbre == timbre;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? tokens.elevatedSurface
                          : tokens.panelBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? tokens.accentPrimary
                              : tokens.borderHairline,
                        ),
                      ),
                      child: ListTile(
                        key: Key('drone_timbre_${timbre.name}'),
                        title: Text(
                          timbre.displayName,
                          style: TextStyle(
                            color: isSelected ? tokens.accentPrimary : tokens.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          timbre.description,
                          style: TextStyle(color: tokens.textMuted, fontSize: 10),
                        ),
                        trailing: isSelected
                            ? StudioIcon(
                                StudioIconId.uiCloseConfirm,
                                color: tokens.accentSuccess,
                                size: 18,
                                tintCustomAsset: true,
                                fallbackOverride: Icons.check_circle,
                              )
                            : null,
                        onTap: () {
                          viewModel.setDroneConfig(config.copyWith(timbre: timbre));
                        },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Sliders de Volumen y Balance
                Text(
                  'Volumen General (${(config.volume * 100).round()}%)',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Slider(
                  key: const Key('drone_volume_slider'),
                  value: config.volume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: tokens.accentPrimary,
                  inactiveColor: tokens.borderHairline,
                  onChanged: (val) {
                    viewModel.setDroneConfig(config.copyWith(volume: val));
                  },
                ),

                Text(
                  'Balance Armónico (${(config.harmonicBalance * 100).round()}%)',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Slider(
                  key: const Key('drone_balance_slider'),
                  value: config.harmonicBalance,
                  min: 0.0,
                  max: 1.0,
                  activeColor: tokens.accentSecondary,
                  inactiveColor: tokens.borderHairline,
                  onChanged: (val) {
                    viewModel.setDroneConfig(config.copyWith(harmonicBalance: val));
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
