import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';

/// Modal de edición interactiva de partituras SMuFL y exportación canónica MusicXML/MIDI.
class ScoreEditorModal extends StatefulWidget {
  const ScoreEditorModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ScoreEditorModal(),
    );
  }

  @override
  State<ScoreEditorModal> createState() => _ScoreEditorModalState();
}

class _ScoreEditorModalState extends State<ScoreEditorModal> {
  int _selectedMeasureIndex = 0;
  int _selectedStartTick = 0;
  int _selectedDurationTicks = 4; // Negra por defecto
  String _selectedBaseNote = "Do";
  String _selectedAccidental = ""; // "", "#", "b"
  int _selectedOctave = 4;
  bool _isRestMode = false;

  String get _currentFormattedNoteName {
    if (_isRestMode) return "--";
    return "$_selectedBaseNote$_selectedAccidental$_selectedOctave";
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;
    final totalMeasures = vm.activePackage.totalMeasures;
    final safeMeasureIndex = _selectedMeasureIndex.clamp(0, totalMeasures - 1);
    final activeMeasure = vm.activePackage.score.measures[safeMeasureIndex];
    final totalTicks = activeMeasure.timeSignature.totalTicks;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: palette.textMutedColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_note, color: palette.primaryAccent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ESTUDIO DE EDICIÓN SMuFL",
                        style: TextStyle(
                          color: palette.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        "${vm.activePackage.title} (${activeMeasure.timeSignature})",
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botones Deshacer y Rehacer
                IconButton(
                  icon: Icon(Icons.undo,
                      color: vm.canUndoScoreEdit ? palette.primaryAccent : palette.textMutedColor.withValues(alpha: 0.3)),
                  tooltip: "Deshacer (Undo)",
                  onPressed: vm.canUndoScoreEdit ? () => vm.undoScoreEdit() : null,
                ),
                IconButton(
                  icon: Icon(Icons.redo,
                      color: vm.canRedoScoreEdit ? palette.secondaryAccent : palette.textMutedColor.withValues(alpha: 0.3)),
                  tooltip: "Rehacer (Redo)",
                  onPressed: vm.canRedoScoreEdit ? () => vm.redoScoreEdit() : null,
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Selector de Compás
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: palette.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 16),
                            color: safeMeasureIndex > 0 ? palette.primaryAccent : palette.textMutedColor.withValues(alpha: 0.3),
                            onPressed: safeMeasureIndex > 0
                                ? () => setState(() => _selectedMeasureIndex = safeMeasureIndex - 1)
                                : null,
                          ),
                          Expanded(
                            child: Text(
                              "Compás ${safeMeasureIndex + 1} de $totalMeasures",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            color: safeMeasureIndex < totalMeasures - 1
                                ? palette.primaryAccent
                                : palette.textMutedColor.withValues(alpha: 0.3),
                            onPressed: safeMeasureIndex < totalMeasures - 1
                                ? () => setState(() => _selectedMeasureIndex = safeMeasureIndex + 1)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: palette.textColor, size: 20),
                            onSelected: (val) {
                              if (val == 'add') {
                                vm.addScoreMeasure();
                                setState(() => _selectedMeasureIndex = totalMeasures);
                              } else if (val == 'remove') {
                                vm.removeScoreMeasure(safeMeasureIndex);
                                setState(() => _selectedMeasureIndex = (safeMeasureIndex - 1).clamp(0, totalMeasures));
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'add',
                                child: Text('Añadir Compás al Final'),
                              ),
                              if (totalMeasures > 1)
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Eliminar Compás Actual'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. Paleta de Duraciones Rítmicas
                    Text(
                      "FIGURA RÍTMICA",
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _durationChip(label: "Redonda", ticks: 16, palette: palette),
                        _durationChip(label: "Blanca", ticks: 8, palette: palette),
                        _durationChip(label: "Negra", ticks: 4, palette: palette),
                        _durationChip(label: "Corchea", ticks: 2, palette: palette),
                        _durationChip(label: "Semicorchea", ticks: 1, palette: palette),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 3. Posición Temporal (Tick de Inicio)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "PULSO DE INICIO (TICK)",
                          style: TextStyle(
                            color: palette.textMutedColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          "Tick $_selectedStartTick / $totalTicks",
                          style: TextStyle(
                            color: palette.primaryAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: palette.primaryAccent,
                        inactiveTrackColor: palette.staffLinesColor.withValues(alpha: 0.3),
                        thumbColor: palette.primaryAccent,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _selectedStartTick.clamp(0, totalTicks - 1).toDouble(),
                        min: 0,
                        max: (totalTicks - 1).toDouble(),
                        divisions: totalTicks - 1,
                        onChanged: (val) => setState(() => _selectedStartTick = val.round()),
                      ),
                    ),

                    // 4. Selector de Nota, Alteración y Octava
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "ALTURA Y TONO",
                          style: TextStyle(
                            color: palette.textMutedColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _isRestMode,
                              activeColor: palette.secondaryAccent,
                              onChanged: (val) => setState(() => _isRestMode = val ?? false),
                            ),
                            Text("Silencio", style: TextStyle(color: palette.textColor, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),

                    if (!_isRestMode) ...[
                      // Teclado diatónico
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
                      const SizedBox(height: 8),

                      // Alteraciones y Octava
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children: [
                                _accidentalChip(label: "♮ Natural", val: "", palette: palette),
                                _accidentalChip(label: "♯ Sostenido", val: "#", palette: palette),
                                _accidentalChip(label: "♭ Bemol", val: "b", palette: palette),
                              ],
                            ),
                          ),
                          // Octava
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 18),
                                color: palette.textColor,
                                onPressed: _selectedOctave > 2
                                    ? () => setState(() => _selectedOctave--)
                                    : null,
                              ),
                              Text("Oct $_selectedOctave",
                                  style: TextStyle(color: palette.primaryAccent, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                color: palette.textColor,
                                onPressed: _selectedOctave < 7
                                    ? () => setState(() => _selectedOctave++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Botones de Inserción y Eliminación
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primaryAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              "Insertar $_currentFormattedNoteName",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () {
                              vm.insertOrUpdateScoreNote(
                                measureIndex: safeMeasureIndex,
                                startTick: _selectedStartTick,
                                durationTicks: _selectedDurationTicks,
                                noteName: _currentFormattedNoteName,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Nota $_currentFormattedNoteName insertada en compás ${safeMeasureIndex + 1}"),
                                  duration: const Duration(milliseconds: 1000),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.errorPitchColor,
                              side: BorderSide(color: palette.errorPitchColor.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text("Borrar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              vm.deleteScoreNote(
                                measureIndex: safeMeasureIndex,
                                startTick: _selectedStartTick,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 5. Sección de Exportación Canónica Universal
                    Text(
                      "EXPORTACIÓN UNIVERSAL",
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textColor,
                              side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.code, size: 18),
                            label: const Text("MusicXML", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              final xml = vm.exportActiveScoreToMusicXml();
                              Clipboard.setData(ClipboardData(text: xml));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Partitura copiada en formato MusicXML estándar"),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textColor,
                              side: BorderSide(color: palette.secondaryAccent.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.piano, size: 18),
                            label: const Text("MIDI (SMF)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              final midiBytes = vm.exportActiveScoreToMidi();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Archivo MIDI exportado (${midiBytes.length} bytes generados)"),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationChip({required String label, required int ticks, required TunnerThemePalette palette}) {
    final isSel = _selectedDurationTicks == ticks;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: palette.primaryAccent.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSel ? palette.primaryAccent : palette.textColor,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedDurationTicks = ticks),
    );
  }

  Widget _accidentalChip({required String label, required String val, required TunnerThemePalette palette}) {
    final isSel = _selectedAccidental == val;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: palette.secondaryAccent.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSel ? palette.secondaryAccent : palette.textColor,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedAccidental = val),
    );
  }
}
