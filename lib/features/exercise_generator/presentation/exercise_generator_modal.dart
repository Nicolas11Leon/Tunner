import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import '../domain/algorithmic_exercise_generator.dart';

/// Modal interactivo para generación procedural de ejercicios, escalas y rutinas técnicas.
class ExerciseGeneratorModal extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const ExerciseGeneratorModal({super.key, this.onNavigateToTab});

  static Future<void> show(
    BuildContext context, {
    void Function(int tabIndex)? onNavigateToTab,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExerciseGeneratorModal(onNavigateToTab: onNavigateToTab),
    );
  }

  @override
  State<ExerciseGeneratorModal> createState() => _ExerciseGeneratorModalState();
}

class _ExerciseGeneratorModalState extends State<ExerciseGeneratorModal> {
  String _selectedBaseNote = "Do";
  String _selectedAccidental = "";
  int _selectedOctave = 4;
  ExerciseType _selectedType = ExerciseType.majorScale;
  ExerciseRhythm _selectedRhythm = ExerciseRhythm.quarter;
  int _selectedBpm = 80;

  String get _currentRootNote => "$_selectedBaseNote$_selectedAccidental$_selectedOctave";

  @override
  Widget build(BuildContext context) {
    final vm = context.read<TunerViewModel>();
    final tokens = StudioThemeScope.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        children: [
          // Barra de agarre
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: StudioIcon(
                    StudioIconId.moduleScoreEditor,
                    size: 18,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "GENERADOR DE EJERCICIOS Y ESCALAS",
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$_currentRootNote - ${_selectedType.displayName}",
                        style: TextStyle(
                          color: tokens.accentPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Selector de Tónica Raíz
                  Text(
                    "1. TONALIDAD RAÍZ",
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"].map((note) {
                      final isSel = _selectedBaseNote == note;
                      return ChoiceChip(
                        label: Text(note),
                        selected: isSel,
                        backgroundColor: tokens.elevatedSurface,
                        selectedColor: tokens.accentPrimary.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isSel ? tokens.accentPrimary : tokens.borderHairline,
                        ),
                        labelStyle: TextStyle(
                          color: isSel ? tokens.accentPrimary : tokens.textPrimary,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _selectedBaseNote = note),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _accidentalChip("♮ Natural", "", tokens),
                          _accidentalChip("♯ Sostenido", "#", tokens),
                          _accidentalChip("♭ Bemol", "b", tokens),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const Key('exercise_generator_octave_down_btn'),
                            icon: StudioIcon(
                              StudioIconId.uiAddRemove,
                              size: 18,
                              color: tokens.textPrimary,
                              tintCustomAsset: true,
                              fallbackOverride: Icons.remove_circle_outline,
                            ),
                            onPressed: _selectedOctave > 0 ? () => setState(() => _selectedOctave--) : null,
                          ),
                          Text(
                            "Oct $_selectedOctave",
                            style: TextStyle(color: tokens.accentPrimary, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            key: const Key('exercise_generator_octave_up_btn'),
                            icon: StudioIcon(
                              StudioIconId.uiAddRemove,
                              size: 18,
                              color: tokens.textPrimary,
                              tintCustomAsset: true,
                              fallbackOverride: Icons.add_circle_outline,
                            ),
                            onPressed: _selectedOctave < 8 ? () => setState(() => _selectedOctave++) : null,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Tipo de Ejercicio Técnico
                  Text(
                    "2. TIPO DE ESTUDIO / ESCALA",
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ExerciseType.values.map((type) {
                      final isSel = _selectedType == type;
                      return ChoiceChip(
                        label: Text(type.displayName),
                        selected: isSel,
                        backgroundColor: tokens.elevatedSurface,
                        selectedColor: tokens.accentSecondary.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isSel ? tokens.accentSecondary : tokens.borderHairline,
                        ),
                        labelStyle: TextStyle(
                          color: isSel ? tokens.accentPrimary : tokens.textPrimary,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => _selectedType = type),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 3. Patrón Rítmico
                  if (_selectedType != ExerciseType.longTones) ...[
                    Text(
                      "3. FIGURA RÍTMICA",
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ExerciseRhythm.whole,
                        ExerciseRhythm.half,
                        ExerciseRhythm.quarter,
                        ExerciseRhythm.eighth,
                        ExerciseRhythm.sixteenth,
                      ].map((rhythm) {
                        final isSel = _selectedRhythm == rhythm;
                        return ChoiceChip(
                          label: Text(rhythm.displayName),
                          selected: isSel,
                          backgroundColor: tokens.elevatedSurface,
                          selectedColor: tokens.accentPrimary.withValues(alpha: 0.2),
                          side: BorderSide(
                            color: isSel ? tokens.accentPrimary : tokens.borderHairline,
                          ),
                          labelStyle: TextStyle(
                            color: isSel ? tokens.accentPrimary : tokens.textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() => _selectedRhythm = rhythm),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 4. Tempo sugerido
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "TEMPO DE ESTUDIO",
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        "$_selectedBpm BPM",
                        style: TextStyle(color: tokens.accentPrimary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: _selectedBpm.toDouble(),
                    min: 50,
                    max: 160,
                    divisions: 110,
                    activeColor: tokens.accentPrimary,
                    inactiveColor: tokens.borderHairline,
                    onChanged: (val) => setState(() => _selectedBpm = val.round()),
                  ),

                  const SizedBox(height: 20),

                  // Botón Generar y Practicar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.accentPrimary,
                        foregroundColor: tokens.textOnAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: StudioIcon(
                        StudioIconId.moduleAutotune,
                        size: 18,
                        color: tokens.textOnAccent,
                        tintCustomAsset: true,
                      ),
                      label: const Text(
                        "Generar y Cargar en Atril",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        vm.generateAndLoadExercise(
                          rootNote: _currentRootNote,
                          type: _selectedType,
                          rhythm: _selectedRhythm,
                          bpm: _selectedBpm,
                        );
                        Navigator.of(context).pop();
                        widget.onNavigateToTab?.call(4);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Ejercicio generado: $_currentRootNote ${_selectedType.displayName}"),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accidentalChip(String label, String val, StudioDesignTokens tokens) {
    final isSel = _selectedAccidental == val;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      backgroundColor: tokens.elevatedSurface,
      selectedColor: tokens.accentSecondary.withValues(alpha: 0.2),
      side: BorderSide(
        color: isSel ? tokens.accentSecondary : tokens.borderHairline,
      ),
      labelStyle: TextStyle(
        color: isSel ? tokens.accentPrimary : tokens.textPrimary,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _selectedAccidental = val),
    );
  }
}
