import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../domain/song_package_entity.dart';
import '../data/song_decomposer_service.dart';

/// Diálogos modales atómicos profesionales para creación e importación de assets musicales.
class StudioAssetsModals {
  /// Despliega el diálogo modal para crear una nueva partitura MusicXML en blanco.
  static Future<void> showNewScoreDialog({
    required BuildContext context,
    required TunerViewModel viewModel,
    required void Function(int tabIndex) onNavigateToTab,
    void Function(SongPackage newScore)? onScoreCreated,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => _StudioNewScoreDialog(
        viewModel: viewModel,
        onNavigateToTab: onNavigateToTab,
        onScoreCreated: onScoreCreated,
      ),
    );
  }

  /// Despliega el diálogo modal para importar una partitura externa o del canon clásico.
  static Future<void> showImportScoreDialog({
    required BuildContext context,
    required TunerViewModel viewModel,
    required void Function(int tabIndex) onNavigateToTab,
    void Function(SongPackage importedScore)? onScoreImported,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => _StudioImportScoreDialog(
        viewModel: viewModel,
        onNavigateToTab: onNavigateToTab,
        onScoreImported: onScoreImported,
      ),
    );
  }

  /// Despliega el diálogo modal para guardar un nuevo preset de afinación personalizado.
  static Future<void> showNewTuningPresetDialog({
    required BuildContext context,
    required TunerViewModel viewModel,
    required void Function(String name, double pitchHz) onSavePreset,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => _StudioNewTuningPresetDialog(
        viewModel: viewModel,
        onSavePreset: onSavePreset,
      ),
    );
  }
}

class _StudioNewScoreDialog extends StatefulWidget {
  final TunerViewModel viewModel;
  final void Function(int tabIndex) onNavigateToTab;
  final void Function(SongPackage newScore)? onScoreCreated;

  const _StudioNewScoreDialog({
    required this.viewModel,
    required this.onNavigateToTab,
    this.onScoreCreated,
  });

  @override
  State<_StudioNewScoreDialog> createState() => _StudioNewScoreDialogState();
}

class _StudioNewScoreDialogState extends State<_StudioNewScoreDialog> {
  final TextEditingController _titleCtrl = TextEditingController(text: 'Nueva Composición');
  int _selectedBpm = 120;
  String _selectedTimeSig = '4/4';

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _createAndOpenScore() {
    final title = _titleCtrl.text.trim().isEmpty ? 'Composición sin título' : _titleCtrl.text.trim();
    final parts = _selectedTimeSig.split('/');
    final numBeats = int.tryParse(parts[0]) ?? 4;
    final beatUnit = int.tryParse(parts[1]) ?? 4;

    final initialTimeSignature = TimeSignature(numBeats, beatUnit);

    // Crea un SongPackage canónico con 4 compases iniciales de silencio válido
    final emptyMeasures = List.generate(
      4,
      (idx) => MeasureEntity(
        index: idx,
        timeSignature: initialTimeSignature,
        notes: [
          HierarchicalNote.rest(
            startTick: 0,
            durationTicks: initialTimeSignature.totalTicks,
          ),
        ],
      ),
    );

    final score = HierarchicalScore(
      title: title,
      baseBpm: _selectedBpm,
      measures: emptyMeasures,
    );

    final newPkg = SongPackage(
      id: 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      composer: 'Compositor Tunner',
      genre: MusicGenre.classical,
      difficulty: SongDifficulty.beginner,
      defaultBpm: _selectedBpm,
      score: score,
      tracks: const [],
    );

    widget.viewModel.addSongPackage(newPkg);
    widget.onScoreCreated?.call(newPkg);
    Navigator.of(context).pop();
    widget.onNavigateToTab(4); // Navega a biblioteca/partituras
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Dialog(
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.note_add_outlined, size: 18, color: tokens.accentPrimary),
                const SizedBox(width: 8),
                Text(
                  'NUEVA PARTITURA EN BLANCO',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: tokens.textMuted),
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              'Título de la Obra',
              style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.inputSurface,
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
              ),
              child: TextField(
                controller: _titleCtrl,
                style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Ej. Preludio en Do Menor',
                  hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Compás y Tempo
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compás Inicial',
                        style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: tokens.inputSurface,
                          borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTimeSig,
                            isDense: true,
                            isExpanded: true,
                            dropdownColor: tokens.panelBackground,
                            items: const [
                              DropdownMenuItem(value: '4/4', child: Text('4/4 (Común)')),
                              DropdownMenuItem(value: '3/4', child: Text('3/4 (Vals)')),
                              DropdownMenuItem(value: '6/8', child: Text('6/8 (Compuesto)')),
                              DropdownMenuItem(value: '2/4', child: Text('2/4 (Binario)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTimeSig = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tempo: $_selectedBpm BPM',
                        style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: tokens.inputSurface,
                          borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedBpm,
                            isDense: true,
                            isExpanded: true,
                            dropdownColor: tokens.panelBackground,
                            items: const [
                              DropdownMenuItem(value: 80, child: Text('80 Andante')),
                              DropdownMenuItem(value: 100, child: Text('100 Moderato')),
                              DropdownMenuItem(value: 120, child: Text('120 Allegro')),
                              DropdownMenuItem(value: 140, child: Text('140 Vivace')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedBpm = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.borderHairline),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSmall)),
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _createAndOpenScore,
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Crear Partitura', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accentPrimary,
                    foregroundColor: tokens.textOnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSmall)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioImportScoreDialog extends StatelessWidget {
  final TunerViewModel viewModel;
  final void Function(int tabIndex) onNavigateToTab;
  final void Function(SongPackage importedScore)? onScoreImported;

  const _StudioImportScoreDialog({
    required this.viewModel,
    required this.onNavigateToTab,
    this.onScoreImported,
  });

  void _importPreset(BuildContext context, SongPackage preset) {
    viewModel.addSongPackage(preset);
    onScoreImported?.call(preset);
    Navigator.of(context).pop();
    onNavigateToTab(4);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final curatedList = SongDecomposerService.getCuratedLibrary();

    return Dialog(
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.file_download_outlined, size: 18, color: tokens.accentPrimary),
                const SizedBox(width: 8),
                Text(
                  'IMPORTAR PARTITURA DEL CANON MAESTRO',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: tokens.textMuted),
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              'Obras maestras canónicas listas con notación jerárquica y stems multicanal:',
              style: TextStyle(color: tokens.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 12),

            for (final pkg in curatedList)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: tokens.elevatedSurface,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.library_music_outlined, size: 18, color: tokens.accentPrimary),
                  title: Text(pkg.title, style: TextStyle(color: tokens.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  subtitle: Text('${pkg.composer} • ${pkg.defaultBpm} BPM', style: TextStyle(color: tokens.textMuted, fontSize: 10)),
                  trailing: OutlinedButton(
                    onPressed: () => _importPreset(context, pkg),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.accentPrimary,
                      side: BorderSide(color: tokens.accentPrimary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Importar', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.borderHairline),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSmall)),
                  ),
                  child: const Text('Cerrar', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioNewTuningPresetDialog extends StatefulWidget {
  final TunerViewModel viewModel;
  final void Function(String name, double pitchHz) onSavePreset;

  const _StudioNewTuningPresetDialog({
    required this.viewModel,
    required this.onSavePreset,
  });

  @override
  State<_StudioNewTuningPresetDialog> createState() => _StudioNewTuningPresetDialogState();
}

class _StudioNewTuningPresetDialogState extends State<_StudioNewTuningPresetDialog> {
  final TextEditingController _nameCtrl = TextEditingController(text: 'Mi Calibración A4');
  double _selectedHz = 440.0;

  @override
  void initState() {
    super.initState();
    _selectedHz = widget.viewModel.referencePitch;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _savePreset() {
    final name = _nameCtrl.text.trim().isEmpty ? 'Preset A4' : _nameCtrl.text.trim();
    widget.onSavePreset(name, _selectedHz);
    widget.viewModel.setReferencePitch(_selectedHz);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Dialog(
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: tokens.accentPrimary),
                const SizedBox(width: 8),
                Text(
                  'NUEVO PRESET DE AFINACIÓN',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: tokens.textMuted),
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('Nombre del Preset', style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.inputSurface,
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
              ),
              child: TextField(
                controller: _nameCtrl,
                style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Ej. Orquestal Viena 443 Hz'),
              ),
            ),
            const SizedBox(height: 14),

            Text('Frecuencia de Concierto A4: ${_selectedHz.toInt()} Hz', style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            Slider(
              value: _selectedHz,
              min: 415.0,
              max: 466.0,
              divisions: 51,
              activeColor: tokens.accentPrimary,
              onChanged: (val) => setState(() => _selectedHz = val),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.borderHairline),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _savePreset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accentPrimary,
                    foregroundColor: tokens.textOnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text('Guardar Preset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
