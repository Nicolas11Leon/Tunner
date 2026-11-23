import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../../core/file_system/domain/i_studio_workspace_file_system.dart';
import '../../tuner_viewmodel.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../tuner/domain/tuning_preset_entity.dart';
import '../domain/song_package_entity.dart';
import '../domain/song_decomposer_service.dart';

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
    void Function(TuningPresetEntity preset)? onSavePreset,
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

  /// Despliega el diálogo modal para guardar el proyecto actual con un nuevo nombre.
  static Future<void> showSaveAsDialog({
    required BuildContext context,
    required TunerViewModel viewModel,
    IStudioWorkspaceFileSystem? fileSystemService,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => _StudioSaveAsDialog(
        viewModel: viewModel,
        fileSystemService: fileSystemService,
      ),
    );
  }

  /// Despliega el diálogo modal para exportar partitura y audio en múltiples formatos canónicos.
  static Future<void> showExportDialog({
    required BuildContext context,
    required TunerViewModel viewModel,
    IStudioWorkspaceFileSystem? fileSystemService,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => _StudioExportDialog(
        viewModel: viewModel,
        fileSystemService: fileSystemService,
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

    final pkg = widget.viewModel.createWorkspaceScore(
      title: title,
      bpm: _selectedBpm,
      timeSignature: initialTimeSignature,
      initialMeasures: 4,
    );

    widget.onScoreCreated?.call(pkg);
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tokens.inputSurface,
                          borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              onPressed: () => setState(() => _selectedBpm = (_selectedBpm - 1).clamp(20, 300)),
                            ),
                            Expanded(
                              child: Slider(
                                value: _selectedBpm.toDouble().clamp(20.0, 300.0),
                                min: 20.0,
                                max: 300.0,
                                divisions: 280,
                                activeColor: tokens.accentPrimary,
                                onChanged: (val) => setState(() => _selectedBpm = val.round().clamp(20, 300)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              onPressed: () => setState(() => _selectedBpm = (_selectedBpm + 1).clamp(20, 300)),
                            ),
                          ],
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

  Future<void> _pickFileFromDisk(BuildContext context) async {
    final result = await viewModel.importScoreFromFilePicker();
    if (result != null && context.mounted) {
      onScoreImported?.call(result.package);
      Navigator.of(context).pop();
      onNavigateToTab(4);
    }
  }

  void _importPreset(BuildContext context, SongPackage preset) {
    final imported = viewModel.importPresetToWorkspace(preset);
    onScoreImported?.call(imported);
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
                  'IMPORTAR PARTITURA / ARCHIVO',
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

            // Ingesta Directa desde Archivo Local en Disco
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(color: tokens.accentPrimary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_open_outlined, color: tokens.accentPrimary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Examinar Archivo en Disco',
                          style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'MusicXML (.xml, .mxl), MIDI (.mid), ABC, PDF o WAV',
                          style: TextStyle(color: tokens.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickFileFromDisk(context),
                    icon: const Icon(Icons.upload_file, size: 14),
                    label: const Text('Examinar...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accentPrimary,
                      foregroundColor: tokens.textOnAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
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
  final void Function(TuningPresetEntity preset)? onSavePreset;

  const _StudioNewTuningPresetDialog({
    required this.viewModel,
    this.onSavePreset,
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
    final name = _nameCtrl.text.trim().isEmpty ? 'Calibración A4' : _nameCtrl.text.trim();
    final preset = TuningPresetEntity(
      id: 'preset_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      referencePitchHz: _selectedHz,
      temperamentId: widget.viewModel.selectedTemperament.id,
      rootKey: widget.viewModel.temperamentRootKey,
      createdAt: DateTime.now(),
    );
    widget.viewModel.saveCustomTuningPreset(preset);
    widget.viewModel.applyTuningPreset(preset);
    widget.onSavePreset?.call(preset);
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

class _StudioSaveAsDialog extends StatefulWidget {
  final TunerViewModel viewModel;
  final IStudioWorkspaceFileSystem? fileSystemService;

  const _StudioSaveAsDialog({
    required this.viewModel,
    this.fileSystemService,
  });

  @override
  State<_StudioSaveAsDialog> createState() => _StudioSaveAsDialogState();
}

class _StudioSaveAsDialogState extends State<_StudioSaveAsDialog> {
  late final TextEditingController _titleCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentTitle = widget.viewModel.activePackage.title;
    _titleCtrl = TextEditingController(text: '$currentTitle - Copia');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAs() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final bytes = widget.viewModel.exportCurrentProjectToTunner(projectTitle: title);
      if (widget.fileSystemService != null) {
        final safeName = title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
        await widget.fileSystemService!.fileSystemRepository.saveFile(
          relativePath: 'Partituras & Notación/$safeName.tunner',
          bytes: bytes,
        );
        await widget.fileSystemService!.refreshFromDisk();
      }
      await widget.viewModel.savePersistedState();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proyecto guardado como "$title" exitosamente.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.save_as_outlined, size: 18, color: tokens.accentPrimary),
                const SizedBox(width: 8),
                Text(
                  'GUARDAR PROYECTO COMO...',
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
            Text(
              'Nombre del Nuevo Archivo / Proyecto',
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
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Introduce el nuevo nombre...',
                ),
                onSubmitted: (_) => _handleSaveAs(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.borderHairline),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSaveAs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accentPrimary,
                    foregroundColor: tokens.textOnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    _isSaving ? 'Guardando...' : 'Guardar Copia',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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

class _StudioExportDialog extends StatefulWidget {
  final TunerViewModel viewModel;
  final IStudioWorkspaceFileSystem? fileSystemService;

  const _StudioExportDialog({
    required this.viewModel,
    this.fileSystemService,
  });

  @override
  State<_StudioExportDialog> createState() => _StudioExportDialogState();
}

class _StudioExportDialogState extends State<_StudioExportDialog> {
  bool _isExporting = false;

  Future<void> _exportAs(String formatId) async {
    setState(() => _isExporting = true);
    try {
      final title = widget.viewModel.activePackage.title;
      final safeName = title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      String targetPath = '';
      int byteCount = 0;

      switch (formatId) {
        case 'musicxml':
          final xml = widget.viewModel.exportActiveScoreToMusicXml();
          final bytes = Uint8List.fromList(utf8.encode(xml));
          targetPath = 'Partituras & Notación/$safeName.musicxml';
          byteCount = bytes.lengthInBytes;
          if (widget.fileSystemService != null) {
            await widget.fileSystemService!.fileSystemRepository.saveFile(
              relativePath: targetPath,
              bytes: bytes,
            );
            await widget.fileSystemService!.refreshFromDisk();
          }
          break;
        case 'midi':
          final bytes = widget.viewModel.exportActiveScoreToMidi();
          targetPath = 'Partituras & Notación/$safeName.mid';
          byteCount = bytes.lengthInBytes;
          if (widget.fileSystemService != null) {
            await widget.fileSystemService!.fileSystemRepository.saveFile(
              relativePath: targetPath,
              bytes: bytes,
            );
            await widget.fileSystemService!.refreshFromDisk();
          }
          break;
        case 'pdf':
          final bytes = widget.viewModel.exportActiveScoreToPdf();
          targetPath = 'Partituras & Notación/$safeName.pdf';
          byteCount = bytes.lengthInBytes;
          if (widget.fileSystemService != null) {
            await widget.fileSystemService!.fileSystemRepository.saveFile(
              relativePath: targetPath,
              bytes: bytes,
            );
            await widget.fileSystemService!.refreshFromDisk();
          }
          break;
        case 'tunner':
          final bytes = widget.viewModel.exportCurrentProjectToTunner();
          targetPath = 'Partituras & Notación/$safeName.tunner';
          byteCount = bytes.lengthInBytes;
          if (widget.fileSystemService != null) {
            await widget.fileSystemService!.fileSystemRepository.saveFile(
              relativePath: targetPath,
              bytes: bytes,
            );
            await widget.fileSystemService!.refreshFromDisk();
          }
          break;
        case 'stems':
          final result = await widget.viewModel.exportStemsAndMidi();
          targetPath = 'Tomas de Audio & WAV/';
          for (final f in result.files) {
            byteCount += f.sizeBytes;
            if (widget.fileSystemService != null) {
              await widget.fileSystemService!.fileSystemRepository.saveFile(
                relativePath: '$targetPath${f.fileName}',
                bytes: f.bytes,
              );
            }
          }
          if (widget.fileSystemService != null) {
            await widget.fileSystemService!.refreshFromDisk();
          }
          break;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exportación completada exitosamente ($targetPath • $byteCount bytes).'),
            duration: const Duration(seconds: 4),
            action: widget.fileSystemService != null
                ? SnackBarAction(
                    label: 'Abrir Carpeta',
                    onPressed: () => widget.fileSystemService!.openInSystemExplorer(targetPath),
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.ios_share_outlined, size: 18, color: tokens.accentPrimary),
                const SizedBox(width: 8),
                Text(
                  'EXPORTAR PROYECTO Y NOTACIÓN',
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
            const SizedBox(height: 8),
            Text(
              'Selecciona el formato canónico deseado para guardar en el explorador de archivos:',
              style: TextStyle(color: tokens.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 16),
            _buildExportOption(
              tokens: tokens,
              title: 'MusicXML (.musicxml)',
              subtitle: 'Notación digital estándar abierta W3C compatible con Dorico, Sibelius y MuseScore',
              icon: Icons.description_outlined,
              formatId: 'musicxml',
            ),
            _buildExportOption(
              tokens: tokens,
              title: 'MIDI Estándar (.mid)',
              subtitle: 'Secuencia canónica de notas, eventos de tempo y cambios de métrica',
              icon: Icons.piano_outlined,
              formatId: 'midi',
            ),
            _buildExportOption(
              tokens: tokens,
              title: 'Documento PDF (.pdf)',
              subtitle: 'Partitura vectorial maquetada con tipografía SMuFL lista para impresión',
              icon: Icons.picture_as_pdf_outlined,
              formatId: 'pdf',
            ),
            _buildExportOption(
              tokens: tokens,
              title: 'Paquete de Proyecto (.tunner)',
              subtitle: 'Archivo binario comprimido con estado íntegro, pistas y metadatos del estudio',
              icon: Icons.inventory_2_outlined,
              formatId: 'tunner',
            ),
            _buildExportOption(
              tokens: tokens,
              title: 'Pistas Separadas & Stems (.wav / .mid)',
              subtitle: 'Exportación multi-pista con mezcla maestro, minus-one y pistas de práctica',
              icon: Icons.multitrack_audio_outlined,
              formatId: 'stems',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.borderHairline),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildExportOption({
    required StudioDesignTokens tokens,
    required String title,
    required String subtitle,
    required IconData icon,
    required String formatId,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tokens.inputSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: tokens.accentPrimary),
        title: Text(title, style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: tokens.textSecondary, fontSize: 10)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: tokens.textMuted),
        onTap: _isExporting ? null : () => _exportAs(formatId),
      ),
    );
  }
}
