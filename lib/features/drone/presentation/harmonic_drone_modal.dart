import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final palette = viewModel.currentPalette;
    final config = viewModel.droneConfig;
    final isPlaying = viewModel.isDronePlaying;

    final freqs = viewModel.droneConfig.octave >= 1
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
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
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
              color: palette.staffLinesColor.withValues(alpha: 0.4),
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
                    color: palette.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.waves, color: palette.primaryAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estudio de Dron Armónico',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tono pedal continuo para entrenamiento de intonación',
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('close_drone_modal_btn'),
                  icon: Icon(Icons.close, color: palette.textMutedColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 0.5),

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
                        ? palette.primaryAccent.withValues(alpha: 0.12)
                        : palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPlaying
                          ? palette.primaryAccent
                          : palette.staffLinesColor.withValues(alpha: 0.25),
                      width: isPlaying ? 1.6 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                config.rootDisplayName,
                                key: const Key('active_drone_note_label'),
                                style: TextStyle(
                                  color: isPlaying ? palette.primaryAccent : palette.textColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${config.timbre.displayName} • ${fundHz.toStringAsFixed(1)} Hz'
                                '${config.includeFifth ? ' + 5ta (${fifthHz.toStringAsFixed(1)} Hz)' : ''}',
                                style: TextStyle(
                                  color: palette.textMutedColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            key: const Key('toggle_drone_playback_btn'),
                            onPressed: () => viewModel.toggleDrone(),
                            icon: Icon(
                              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                              size: 24,
                            ),
                            label: Text(isPlaying ? 'DETENER' : 'ACTIVAR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPlaying ? Colors.redAccent : palette.primaryAccent,
                              foregroundColor: Colors.black,
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
                    color: palette.textColor,
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
                              ? palette.secondaryAccent
                              : palette.cardBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? palette.secondaryAccent
                                : palette.staffLinesColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          noteName,
                          style: TextStyle(
                            color: isSelected ? Colors.black : palette.textColor,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Selector de Octava
                Text(
                  'Octava de Registro',
                  style: TextStyle(
                    color: palette.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [2, 3, 4].map((oct) {
                    final isSelected = config.octave == oct;
                    final label = oct == 2
                        ? 'Octava 2 (Grave)'
                        : oct == 3
                            ? 'Octava 3 (Medio)'
                            : 'Octava 4 (Agudo)';
                    return Expanded(
                      child: GestureDetector(
                        key: Key('drone_octave_$oct'),
                        onTap: () {
                          viewModel.setDroneConfig(config.copyWith(octave: oct));
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? palette.primaryAccent : palette.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? palette.primaryAccent
                                  : palette.staffLinesColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.black : palette.textColor,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Capas Armónicas
                Text(
                  'Capas Armónicas Secundarias',
                  style: TextStyle(
                    color: palette.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('drone_toggle_fifth_switch'),
                        value: config.includeFifth,
                        title: Text(
                          'Quinta Armónica Superior (${config.fifthDisplayName})',
                          style: TextStyle(color: palette.textColor, fontSize: 13),
                        ),
                        subtitle: Text(
                          'Intervalo puro 3:2 o temperado para consonancia acústica',
                          style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                        ),
                        activeThumbColor: palette.primaryAccent,
                        onChanged: (val) {
                          viewModel.setDroneConfig(config.copyWith(includeFifth: val));
                        },
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      SwitchListTile(
                        key: const Key('drone_toggle_octave_switch'),
                        value: config.includeOctave,
                        title: Text(
                          'Octava Superior (${config.octaveDisplayName})',
                          style: TextStyle(color: palette.textColor, fontSize: 13),
                        ),
                        subtitle: Text(
                          'Refuerzo de presencia y brillo armónico',
                          style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                        ),
                        activeThumbColor: palette.primaryAccent,
                        onChanged: (val) {
                          viewModel.setDroneConfig(config.copyWith(includeOctave: val));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Selector de Timbre
                Text(
                  'Timbre Acústico Sintetizado',
                  style: TextStyle(
                    color: palette.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...DroneTimbre.values.map((timbre) {
                  final isSelected = config.timbre == timbre;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? palette.primaryAccent.withValues(alpha: 0.12)
                          : palette.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? palette.primaryAccent
                            : palette.staffLinesColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: ListTile(
                      key: Key('drone_timbre_${timbre.name}'),
                      title: Text(
                        timbre.displayName,
                        style: TextStyle(
                          color: isSelected ? palette.primaryAccent : palette.textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        timbre.description,
                        style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: palette.primaryAccent, size: 20)
                          : null,
                      onTap: () {
                        viewModel.setDroneConfig(config.copyWith(timbre: timbre));
                      },
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Sliders de Volumen y Balance
                Text(
                  'Volumen General (${(config.volume * 100).round()}%)',
                  style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Slider(
                  key: const Key('drone_volume_slider'),
                  value: config.volume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: palette.primaryAccent,
                  inactiveColor: palette.staffLinesColor.withValues(alpha: 0.3),
                  onChanged: (val) {
                    viewModel.setDroneConfig(config.copyWith(volume: val));
                  },
                ),

                Text(
                  'Balance Armónico (${(config.harmonicBalance * 100).round()}%)',
                  style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Slider(
                  key: const Key('drone_balance_slider'),
                  value: config.harmonicBalance,
                  min: 0.0,
                  max: 1.0,
                  activeColor: palette.secondaryAccent,
                  inactiveColor: palette.staffLinesColor.withValues(alpha: 0.3),
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
