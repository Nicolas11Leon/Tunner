import 'package:flutter/material.dart';
import '../../tuner_viewmodel.dart';
import '../domain/stem_export_entity.dart';

/// Modal interactivo para la configuración y exportación de Stems de Audio WAV (16-bit PCM 44.1 kHz)
/// y secuencias Standard MIDI File (SMF) directamente desde el espacio de Composición.
class AudioMidiExportModal extends StatefulWidget {
  final TunerViewModel viewModel;

  const AudioMidiExportModal({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioMidiExportModal(viewModel: viewModel),
    );
  }

  @override
  State<AudioMidiExportModal> createState() => _AudioMidiExportModalState();
}

class _AudioMidiExportModalState extends State<AudioMidiExportModal> {
  bool _includeMaster = true;
  bool _includeStems = true;
  bool _includeMidi = true;
  bool _includeRecordedTake = false;
  int _sampleRate = 44100;
  ExportBundleResult? _bundleResult;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _bundleResult = widget.viewModel.lastExportBundle;
    _includeRecordedTake = widget.viewModel.activeRecording != null;
  }

  Future<void> _handleExport() async {
    setState(() {
      _isProcessing = true;
    });

    final config = StemExportConfig(
      sampleRate: _sampleRate,
      includeMasterMixdown: _includeMaster,
      includeIndividualStems: _includeStems,
      includeMidiFile: _includeMidi,
      includeMelodyTrack: true,
      includeMetronomeTrack: true,
      includeAccompanimentTrack: true,
      includeRecordedTake: _includeRecordedTake,
    );

    try {
      final result = await widget.viewModel.exportStemsAndMidi(config: config);
      if (mounted) {
        setState(() {
          _bundleResult = result;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Exportación completada: ${result.files.length} archivos generados (${result.formattedTotalSize}).",
            ),
            backgroundColor: widget.viewModel.currentPalette.primaryAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error durante la síntesis y exportación: $e"),
            backgroundColor: widget.viewModel.currentPalette.errorPitchColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.viewModel.currentPalette;

    return Container(
      key: const Key('export_audio_midi_modal'),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra superior de arrastre
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
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
                  child: Icon(Icons.album, color: palette.primaryAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Exportación de Stems & MIDI",
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${widget.viewModel.activePackage.title} (${widget.viewModel.bpm} BPM)",
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textMutedColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Opciones de exportación
            Text(
              "FORMATOS Y PISTAS A INCLUIR",
              style: TextStyle(
                color: palette.primaryAccent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: palette.staffBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const Key('export_switch_master'),
                    title: Text(
                      "Master Mixdown WAV",
                      style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Mezcla estéreo balanceada según volúmenes de consola",
                      style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                    ),
                    value: _includeMaster,
                    activeTrackColor: palette.primaryAccent,
                    onChanged: (val) => setState(() => _includeMaster = val),
                  ),
                  Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),
                  SwitchListTile.adaptive(
                    key: const Key('export_switch_stems'),
                    title: Text(
                      "Stems Separados WAV",
                      style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Pistas aisladas de melodía, acompañamiento y metrónomo",
                      style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                    ),
                    value: _includeStems,
                    activeTrackColor: palette.primaryAccent,
                    onChanged: (val) => setState(() => _includeStems = val),
                  ),
                  Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),
                  SwitchListTile.adaptive(
                    key: const Key('export_switch_midi'),
                    title: Text(
                      "Archivo MIDI Canónico (.mid)",
                      style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Secuencia Standard MIDI SMF con métrica y tempo 480 PPQN",
                      style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                    ),
                    value: _includeMidi,
                    activeTrackColor: palette.primaryAccent,
                    onChanged: (val) => setState(() => _includeMidi = val),
                  ),
                  if (widget.viewModel.activeRecording != null) ...[
                    Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),
                    SwitchListTile.adaptive(
                      key: const Key('export_switch_take'),
                      title: Text(
                        "Toma de Práctica Grabada",
                        style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "Audio registrado por micrófono en sesión",
                        style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                      ),
                      value: _includeRecordedTake,
                      activeTrackColor: palette.secondaryAccent,
                      onChanged: (val) => setState(() => _includeRecordedTake = val),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tasa de Muestreo
            Row(
              children: [
                Text(
                  "Frecuencia de Muestreo:",
                  style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                ChoiceChip(
                  label: const Text("44.1 kHz"),
                  selected: _sampleRate == 44100,
                  onSelected: (_) => setState(() => _sampleRate = 44100),
                  selectedColor: palette.primaryAccent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _sampleRate == 44100 ? palette.primaryAccent : palette.textMutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("48.0 kHz"),
                  selected: _sampleRate == 48000,
                  onSelected: (_) => setState(() => _sampleRate = 48000),
                  selectedColor: palette.primaryAccent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _sampleRate == 48000 ? palette.primaryAccent : palette.textMutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Botón de Generación y Guardado
            ElevatedButton.icon(
              key: const Key('export_generate_btn'),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.save_alt, size: 18, color: Colors.black),
              label: Text(
                _isProcessing ? "Sintetizando Audio y MIDI..." : "Sintetizar y Guardar Stems",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isProcessing ? null : _handleExport,
            ),

            // Resumen de Archivos Generados
            if (_bundleResult != null && _bundleResult!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                "ARCHIVOS EXPORTADOS EN DISCO LOCAL",
                style: TextStyle(
                  color: palette.secondaryAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: palette.staffBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bundleResult!.files.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: palette.staffLinesColor.withValues(alpha: 0.15),
                  ),
                  itemBuilder: (context, index) {
                    final f = _bundleResult!.files[index];
                    final isWav = f.mimeType == "audio/wav";
                    return ListTile(
                      key: Key('export_stem_item_$index'),
                      dense: true,
                      leading: Icon(
                        isWav ? Icons.graphic_eq : Icons.music_note,
                        color: isWav ? palette.primaryAccent : palette.secondaryAccent,
                        size: 20,
                      ),
                      title: Text(
                        f.fileName,
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        f.description,
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.cardBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          f.formattedSize,
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
