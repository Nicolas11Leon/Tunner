import 'package:flutter/material.dart';
import '../domain/instrument_customization_profile.dart';
import '../domain/per_note_detuning_profile.dart';
import '../../tuner/domain/temperament_engine.dart';

/// Modal completo de personalización física, tímbrica y microtonal por instrumento.
class InstrumentCustomizationModal extends StatefulWidget {
  final InstrumentCustomizationProfile initialProfile;
  final ValueChanged<InstrumentCustomizationProfile> onProfileUpdated;

  const InstrumentCustomizationModal({
    super.key,
    required this.initialProfile,
    required this.onProfileUpdated,
  });

  static void show(
    BuildContext context, {
    required InstrumentCustomizationProfile currentProfile,
    required ValueChanged<InstrumentCustomizationProfile> onUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => InstrumentCustomizationModal(
        initialProfile: currentProfile,
        onProfileUpdated: onUpdated,
      ),
    );
  }

  @override
  State<InstrumentCustomizationModal> createState() => _InstrumentCustomizationModalState();
}

class _InstrumentCustomizationModalState extends State<InstrumentCustomizationModal>
    with SingleTickerProviderStateMixin {
  late InstrumentCustomizationProfile _profile;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateProfile(InstrumentCustomizationProfile newProfile) {
    setState(() => _profile = newProfile);
    widget.onProfileUpdated(newProfile);
  }

  @override
  Widget build(BuildContext context) {
    final instrument = _profile.instrument;
    final primaryColor = instrument.visualProfile.primaryAccentColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tirador superior
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(instrument.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PERSONALIZACIÓN DE ${instrument.displayName.toUpperCase()}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const Text(
                            'Tono, timbre, temperamento y desafinación microtonal',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pestañas de navegación
          TabBar(
            controller: _tabController,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.graphic_eq, size: 16), text: 'Timbre & ADSR'),
              Tab(icon: Icon(Icons.tune, size: 16), text: 'A4 & Temperamento'),
              Tab(icon: Icon(Icons.blur_linear, size: 16), text: 'Desafinación Microtonal'),
            ],
          ),
          const SizedBox(height: 12),

          // Vistas de pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimbreTab(primaryColor),
                _buildTuningTab(primaryColor),
                _buildMicrotonalTab(primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PESTAÑA 1: TIMBRE Y ADSR ---
  Widget _buildTimbreTab(Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSliderRow(
            title: 'Velocidad de Ataque ADSR',
            value: _profile.attackMultiplier,
            min: 0.2,
            max: 3.0,
            displayValue: '${_profile.attackMultiplier.toStringAsFixed(2)}x',
            accentColor: accentColor,
            onChanged: (val) => _updateProfile(_profile.copyWith(attackMultiplier: val)),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            title: 'Nivel de Sostenimiento (Sustain)',
            value: _profile.sustainMultiplier,
            min: 0.2,
            max: 2.0,
            displayValue: '${_profile.sustainMultiplier.toStringAsFixed(2)}x',
            accentColor: accentColor,
            onChanged: (val) => _updateProfile(_profile.copyWith(sustainMultiplier: val)),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            title: 'Brillo Armónico (Sobretonos H2..H8)',
            value: _profile.harmonicBrightness,
            min: 0.2,
            max: 2.5,
            displayValue: '${_profile.harmonicBrightness.toStringAsFixed(2)}x',
            accentColor: accentColor,
            onChanged: (val) => _updateProfile(_profile.copyWith(harmonicBrightness: val)),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            title: 'Resonancia Acústica de Caja / Cuerpo',
            value: _profile.resonanceFactor,
            min: 0.0,
            max: 1.0,
            displayValue: '${(_profile.resonanceFactor * 100).toInt()}%',
            accentColor: accentColor,
            onChanged: (val) => _updateProfile(_profile.copyWith(resonanceFactor: val)),
          ),
        ],
      ),
    );
  }

  // --- PESTAÑA 2: A4 Y TEMPERAMENTOS HISTÓRICOS ---
  Widget _buildTuningTab(Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de Tono de Concierto A4
          Text('TONO DE REFERENCIA A4: ${_profile.referencePitchA4.toStringAsFixed(1)} Hz',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Slider(
            value: _profile.referencePitchA4,
            min: 415.0,
            max: 466.0,
            divisions: 51,
            activeColor: accentColor,
            inactiveColor: Colors.white12,
            onChanged: (val) => _updateProfile(_profile.copyWith(referencePitchA4: val)),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [415.0, 432.0, 440.0, 442.0, 444.0].map((pitch) {
              final isSel = (_profile.referencePitchA4 - pitch).abs() < 0.1;
              return ActionChip(
                label: Text('${pitch.toInt()} Hz'),
                labelStyle: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                backgroundColor: isSel ? accentColor : Colors.white12,
                onPressed: () => _updateProfile(_profile.copyWith(referencePitchA4: pitch)),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          const Text('SISTEMA DE TEMPERAMENTO MUSICAL',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...TemperamentEngine.allTemperaments.map((temp) {
            final isSelected = _profile.temperament.id == temp.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? accentColor : Colors.white12),
              ),
              child: ListTile(
                dense: true,
                title: Text(temp.name, style: TextStyle(color: isSelected ? accentColor : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: Text('${temp.historicalEra} • ${temp.description}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                trailing: isSelected ? Icon(Icons.check, color: accentColor, size: 18) : null,
                onTap: () => _updateProfile(_profile.copyWith(temperament: temp)),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- PESTAÑA 3: DESAFINACIÓN MICROTONAL POR TECLA / CUERDA ---
  Widget _buildMicrotonalTab(Color accentColor) {
    final detuning = _profile.detuningProfile;
    final strings = _profile.instrument.acousticRange.standardTuningNoteNames;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PRESETS DE DESAFINACIÓN & EFECTOS',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: PerNoteDetuningProfile.presets.map((preset) {
              final isSel = detuning.id == preset.id;
              return FilterChip(
                label: Text(preset.name),
                selected: isSel,
                selectedColor: accentColor,
                backgroundColor: Colors.white12,
                labelStyle: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                onSelected: (_) => _updateProfile(_profile.copyWith(detuningProfile: preset)),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          if (strings.isNotEmpty) ...[
            Text('DESAFINACIÓN INDIVIDUAL POR CUERDA (±50 CENTS)',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List.generate(strings.length, (idx) {
              final stringName = strings[idx];
              final currentOffset = detuning.getCentsOffsetForString(idx);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        'Cuerda ${idx + 1} ($stringName):',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: currentOffset,
                        min: -50.0,
                        max: 50.0,
                        divisions: 100,
                        activeColor: currentOffset.abs() > 0.1 ? accentColor : Colors.white24,
                        inactiveColor: Colors.white12,
                        onChanged: (val) {
                          final updated = detuning.withStringOffset(idx, val);
                          _updateProfile(_profile.copyWith(detuningProfile: updated));
                        },
                      ),
                    ),
                    SizedBox(
                      width: 55,
                      child: Text(
                        '${currentOffset > 0 ? "+" : ""}${currentOffset.toStringAsFixed(1)} ¢',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: currentOffset.abs() > 0.1 ? accentColor : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            const Text('DESAFINACIÓN CROMÁTICA TECLA A TECLA',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'En instrumentos sin cuerdas, la desafinación se aplica cromáticamente con los presets (ej. Maqam -50¢ o Railsback).',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required Color accentColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(displayValue, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: accentColor,
          inactiveColor: Colors.white12,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
