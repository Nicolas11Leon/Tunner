import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../tuner_viewmodel.dart';
import '../domain/algorithmic_exercise_generator.dart';

/// Modal interactivo para generación procedural de ejercicios, escalas y rutinas técnicas.
class ExerciseGeneratorModal extends StatefulWidget {
  const ExerciseGeneratorModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ExerciseGeneratorModal(),
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
    final palette = context.select<TunerViewModel, dynamic>((v) => v.currentPalette);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
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
                color: palette.textMutedColor.withValues(alpha: 0.4),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "GENERADOR DE EJERCICIOS Y ESCALAS",
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$_currentRootNote - ${_selectedType.displayName}",
                      style: TextStyle(
                        color: palette.primaryAccent,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

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
                      color: palette.textMutedColor,
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
                        selectedColor: palette.primaryAccent.withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                          color: isSel ? palette.primaryAccent : palette.textColor,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _selectedBaseNote = note),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          _accidentalChip("♮ Natural", "", palette),
                          _accidentalChip("♯ Sostenido", "#", palette),
                          _accidentalChip("♭ Bemol", "b", palette),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        color: palette.textColor,
                        onPressed: _selectedOctave > 2 ? () => setState(() => _selectedOctave--) : null,
                      ),
                      Text("Oct $_selectedOctave",
                          style: TextStyle(color: palette.primaryAccent, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        color: palette.textColor,
                        onPressed: _selectedOctave < 6 ? () => setState(() => _selectedOctave++) : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Tipo de Ejercicio Técnico
                  Text(
                    "2. TIPO DE ESTUDIO / ESCALA",
                    style: TextStyle(
                      color: palette.textMutedColor,
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
                        selectedColor: palette.secondaryAccent.withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                          color: isSel ? palette.secondaryAccent : palette.textColor,
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
                        color: palette.textMutedColor,
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
                        ExerciseRhythm.quarter,
                        ExerciseRhythm.eighth,
                        ExerciseRhythm.sixteenth,
                      ].map((rhythm) {
                        final isSel = _selectedRhythm == rhythm;
                        return ChoiceChip(
                          label: Text(rhythm.displayName),
                          selected: isSel,
                          selectedColor: palette.primaryAccent.withValues(alpha: 0.3),
                          labelStyle: TextStyle(
                            color: isSel ? palette.primaryAccent : palette.textColor,
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
                          color: palette.textMutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text("$_selectedBpm BPM",
                          style: TextStyle(color: palette.primaryAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _selectedBpm.toDouble(),
                    min: 50,
                    max: 160,
                    divisions: 110,
                    activeColor: palette.primaryAccent,
                    inactiveColor: palette.staffLinesColor.withValues(alpha: 0.3),
                    onChanged: (val) => setState(() => _selectedBpm = val.round()),
                  ),

                  const SizedBox(height: 20),

                  // Botón Generar y Practicar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primaryAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 20),
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

  Widget _accidentalChip(String label, String val, dynamic palette) {
    final isSel = _selectedAccidental == val;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: palette.secondaryAccent.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSel ? palette.secondaryAccent : palette.textColor,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _selectedAccidental = val),
    );
  }
}
