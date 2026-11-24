import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../../core/file_system/domain/i_platform_file_gateway.dart';
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

class _StudioImportScoreDialog extends StatefulWidget {
  final TunerViewModel viewModel;
  final void Function(int tabIndex) onNavigateToTab;
  final void Function(SongPackage importedScore)? onScoreImported;

  const _StudioImportScoreDialog({
    required this.viewModel,
    required this.onNavigateToTab,
    this.onScoreImported,
  });

  @override
  State<_StudioImportScoreDialog> createState() =>
      _StudioImportScoreDialogState();
}

class _StudioImportScoreDialogState extends State<_StudioImportScoreDialog> {
  static const Set<String> _audioExtensions = <String>{
    'mp3',
    'wav',
    'flac',
    'ogg',
    'm4a',
    'aac',
    'opus',
  };
  static const Set<String> _scoreExtensions = <String>{
    'musicxml',
    'xml',
    'mxl',
    'mid',
    'midi',
    'abc',
    'pdf',
  };
  static const Set<String> _allSupportedExtensions = <String>{
    ..._audioExtensions,
    ..._scoreExtensions,
  };

  int _selectedTab = 0; // 0: Explorador Local Didáctico, 1: Biblioteca Canónica
  String _categoryFilter = 'all'; // 'all', 'audio', 'score'
  String _searchQuery = '';
  bool _isLoadingDir = false;
  bool _isImporting = false;
  String? _statusMessage;
  bool _isStatusError = false;

  List<StudioQuickDirectory> _quickDirs = const <StudioQuickDirectory>[];
  String _currentDirPath = '';
  List<StudioDiskEntry> _entries = const <StudioDiskEntry>[];

  @override
  void initState() {
    super.initState();
    _initBrowser();
  }

  Future<void> _initBrowser() async {
    final gateway = widget.viewModel.platformFileGateway;
    if (gateway is! IStudioDiskBrowserGateway) return;

    setState(() => _isLoadingDir = true);
    final browser = gateway as IStudioDiskBrowserGateway;
    final dirs = await browser.getQuickDirectories();
    if (!mounted) return;

    final startPath = dirs.isNotEmpty ? dirs.first.path : '';
    setState(() {
      _quickDirs = dirs;
      _currentDirPath = startPath;
    });
    if (startPath.isNotEmpty) {
      await _loadDirectory(startPath);
    } else {
      setState(() => _isLoadingDir = false);
    }
  }

  Future<void> _loadDirectory(String dirPath) async {
    final gateway = widget.viewModel.platformFileGateway;
    if (gateway is! IStudioDiskBrowserGateway) return;

    setState(() {
      _isLoadingDir = true;
      _currentDirPath = dirPath;
      _statusMessage = null;
      _isStatusError = false;
    });

    final browser = gateway as IStudioDiskBrowserGateway;
    final allowed = switch (_categoryFilter) {
      'audio' => _audioExtensions,
      'score' => _scoreExtensions,
      _ => _allSupportedExtensions,
    };
    final items = await browser.listDirectoryEntries(
      dirPath,
      allowedExtensions: allowed,
    );
    if (!mounted) return;
    setState(() {
      _entries = items;
      _isLoadingDir = false;
    });
  }

  void _navigateUp() {
    if (_currentDirPath.isEmpty) return;
    final normalized = _currentDirPath.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    if (lastSlash <= 0) return;
    final parent = normalized.substring(0, lastSlash);
    if (parent.isNotEmpty) {
      _loadDirectory(parent);
    }
  }

  Future<void> _importDiskEntry(StudioDiskEntry entry) async {
    final gateway = widget.viewModel.platformFileGateway;
    if (gateway is! IStudioDiskBrowserGateway) return;

    setState(() {
      _isImporting = true;
      _statusMessage = 'Importando "${entry.name}"...';
      _isStatusError = false;
    });

    final browser = gateway as IStudioDiskBrowserGateway;
    final bytes = await browser.readFileBytes(entry.path);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _isImporting = false;
        _statusMessage = 'No se pudo leer el archivo "${entry.name}".';
        _isStatusError = true;
      });
      return;
    }

    final result = await widget.viewModel.importScoreFromBytes(bytes, entry.name);
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isImporting = false;
        _statusMessage =
            'No se pudo decodificar "${entry.name}". Verifica que sea MP3, WAV, FLAC, OGG, MusicXML, MIDI, ABC o PDF válido.';
        _isStatusError = true;
      });
      return;
    }

    widget.onScoreImported?.call(result.package);
    Navigator.of(context).pop();
    widget.onNavigateToTab(4);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Archivo "${entry.name}" importado al estudio (${result.package.totalMeasures} compases).',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickFileFromDisk(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isImporting = true;
      _statusMessage = 'Abriendo selector del sistema...';
      _isStatusError = false;
    });
    final result = await widget.viewModel.importScoreFromFilePicker();
    if (!mounted) return;
    if (result != null) {
      widget.onScoreImported?.call(result.package);
      navigator.pop();
      widget.onNavigateToTab(4);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Archivo "${result.package.title}" importado correctamente.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _isImporting = false;
        _statusMessage =
            'No se importó ningún archivo. Puedes usar el explorador integrado arriba.';
        _isStatusError = false;
      });
    }
  }

  void _importPreset(BuildContext context, SongPackage preset) {
    final imported = widget.viewModel.importPresetToWorkspace(preset);
    widget.onScoreImported?.call(imported);
    Navigator.of(context).pop();
    widget.onNavigateToTab(4);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  IconData _iconForQuickDir(String key) {
    switch (key) {
      case 'music':
        return Icons.library_music_outlined;
      case 'downloads':
        return Icons.download_outlined;
      case 'docs':
        return Icons.description_outlined;
      case 'desktop':
        return Icons.desktop_windows_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  String _didacticHintForExt(String ext) {
    if (_audioExtensions.contains(ext)) {
      return 'Audio ${ext.toUpperCase()} -> Transcribe melodía y separa en Stems';
    }
    switch (ext) {
      case 'mid':
      case 'midi':
        return 'Secuencia MIDI -> Abre pistas en pentagrama editable';
      case 'musicxml':
      case 'xml':
      case 'mxl':
        return 'Partitura MusicXML -> Notación SMuFL completa';
      case 'pdf':
        return 'Partitura PDF -> Reconocimiento OMR vectorial';
      case 'abc':
        return 'Notación ABC -> Conversión automática a compases';
      default:
        return 'Archivo compatible';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final curatedList = SongDecomposerService.getCuratedLibrary();
    final hasDiskBrowser =
        widget.viewModel.platformFileGateway is IStudioDiskBrowserGateway;
    final filteredEntries = _entries.where((e) {
      if (_searchQuery.trim().isEmpty) return true;
      return e.name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera didáctica
              Row(
                children: [
                  Icon(Icons.folder_open_rounded, size: 20, color: tokens.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXPLORADOR E IMPORTADOR DEL ESTUDIO',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        Text(
                          'Acepta Audio (MP3, WAV, FLAC, OGG, M4A) y Partituras (MusicXML, MIDI, ABC, PDF)',
                          style: TextStyle(color: tokens.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const Key('import_dialog_os_picker_btn'),
                    onPressed: _isImporting ? null : () => _pickFileFromDisk(context),
                    icon: const Icon(Icons.upload_file, size: 14),
                    label: const Text('Selector del Sistema...', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.elevatedSurface,
                      foregroundColor: tokens.textPrimary,
                      side: BorderSide(color: tokens.borderHairline),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: tokens.textMuted),
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tabs claras: Mi Computador vs Biblioteca del Conservatorio
              Row(
                children: [
                  ChoiceChip(
                    key: const Key('import_tab_disk_btn'),
                    avatar: Icon(
                      Icons.computer,
                      size: 14,
                      color: _selectedTab == 0 ? tokens.textOnAccent : tokens.textSecondary,
                    ),
                    label: const Text('Explorar Mi Computador', style: TextStyle(fontSize: 11)),
                    selected: _selectedTab == 0,
                    selectedColor: tokens.accentPrimary,
                    labelStyle: TextStyle(
                      color: _selectedTab == 0 ? tokens.textOnAccent : tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => setState(() => _selectedTab = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('import_tab_library_btn'),
                    avatar: Icon(
                      Icons.library_music_outlined,
                      size: 14,
                      color: _selectedTab == 1 ? tokens.textOnAccent : tokens.textSecondary,
                    ),
                    label: Text(
                      'Obras de Ejemplo (${curatedList.length})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _selectedTab == 1,
                    selectedColor: tokens.accentPrimary,
                    labelStyle: TextStyle(
                      color: _selectedTab == 1 ? tokens.textOnAccent : tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => setState(() => _selectedTab = 1),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_statusMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: (_isStatusError ? tokens.accentDanger : tokens.accentPrimary)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(
                      color: _isStatusError ? tokens.accentDanger : tokens.accentPrimary,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isImporting) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Contenido del tab activo
              Expanded(
                child: _selectedTab == 1
                    ? ListView(
                        children: [
                          for (final pkg in curatedList)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: tokens.elevatedSurface,
                                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                                border: Border.all(
                                  color: tokens.borderHairline,
                                  width: tokens.borderWidth,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.library_music_outlined,
                                  size: 18,
                                  color: tokens.accentPrimary,
                                ),
                                title: Text(
                                  pkg.title,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${pkg.composer} • ${pkg.defaultBpm} BPM • ${pkg.tracks.length} pistas',
                                  style: TextStyle(color: tokens.textMuted, fontSize: 10.5),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _importPreset(context, pkg),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tokens.accentPrimary,
                                    foregroundColor: tokens.textOnAccent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text('Cargar', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            ),
                        ],
                      )
                    : !hasDiskBrowser
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.upload_file, size: 36, color: tokens.accentPrimary),
                                const SizedBox(height: 8),
                                Text(
                                  'Pulsa "Selector del Sistema..." arriba para elegir tu MP3, WAV o Partitura.',
                                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Accesos rápidos a carpetas del usuario
                              if (_quickDirs.isNotEmpty)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final qd in _quickDirs)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: ActionChip(
                                            avatar: Icon(
                                              _iconForQuickDir(qd.iconKey),
                                              size: 14,
                                              color: _currentDirPath == qd.path
                                                  ? tokens.accentPrimary
                                                  : tokens.textSecondary,
                                            ),
                                            label: Text(
                                              qd.label,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: _currentDirPath == qd.path
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: tokens.textPrimary,
                                              ),
                                            ),
                                            backgroundColor: _currentDirPath == qd.path
                                                ? tokens.accentPrimary.withValues(alpha: 0.16)
                                                : tokens.elevatedSurface,
                                            side: BorderSide(
                                              color: _currentDirPath == qd.path
                                                  ? tokens.accentPrimary
                                                  : tokens.borderHairline,
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => _loadDirectory(qd.path),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),

                              // Barra de ruta actual + filtro por tipo + búsqueda
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Subir a la carpeta padre',
                                    icon: Icon(Icons.arrow_upward, size: 16, color: tokens.textPrimary),
                                    onPressed: _navigateUp,
                                    style: IconButton.styleFrom(
                                      backgroundColor: tokens.elevatedSurface,
                                      padding: const EdgeInsets.all(6),
                                      minimumSize: const Size(28, 28),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: tokens.inputSurface,
                                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                                        border: Border.all(color: tokens.borderHairline),
                                      ),
                                      child: Text(
                                        _currentDirPath.isEmpty ? 'Selecciona una carpeta' : _currentDirPath,
                                        style: TextStyle(
                                          color: tokens.textSecondary,
                                          fontSize: 10.5,
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 170,
                                    height: 30,
                                    child: TextField(
                                      onChanged: (val) => setState(() => _searchQuery = val),
                                      style: TextStyle(color: tokens.textPrimary, fontSize: 11),
                                      decoration: InputDecoration(
                                        hintText: 'Buscar archivo...',
                                        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 10.5),
                                        prefixIcon: Icon(Icons.search, size: 14, color: tokens.textMuted),
                                        contentPadding: EdgeInsets.zero,
                                        filled: true,
                                        fillColor: tokens.inputSurface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(tokens.radiusSmall),
                                          borderSide: BorderSide(color: tokens.borderHairline),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Filtros por categoría didáctica
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final (id, label) in [
                                    ('all', 'Todos los compatibles'),
                                    ('audio', 'Audio (MP3 / WAV / FLAC / OGG)'),
                                    ('score', 'Partituras (XML / MIDI / PDF / ABC)'),
                                  ])
                                    FilterChip(
                                      label: Text(label, style: const TextStyle(fontSize: 10)),
                                      selected: _categoryFilter == id,
                                      selectedColor: tokens.accentSecondary.withValues(alpha: 0.22),
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) {
                                        setState(() => _categoryFilter = id);
                                        if (_currentDirPath.isNotEmpty) {
                                          _loadDirectory(_currentDirPath);
                                        }
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Lista de carpetas y archivos compatibles
                              Expanded(
                                child: _isLoadingDir
                                    ? const Center(child: CircularProgressIndicator())
                                    : filteredEntries.isEmpty
                                        ? Center(
                                            child: Text(
                                              'No hay archivos de audio o partituras en esta carpeta.\nPrueba en "Música" o "Descargas", o usa "Selector del Sistema...".',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                                            ),
                                          )
                                        : ListView.separated(
                                            itemCount: filteredEntries.length,
                                            separatorBuilder: (_, _) => const SizedBox(height: 4),
                                            itemBuilder: (ctx, index) {
                                              final entry = filteredEntries[index];
                                              if (entry.isDirectory) {
                                                return InkWell(
                                                  onTap: () => _loadDirectory(entry.path),
                                                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: tokens.elevatedSurface,
                                                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                                                      border: Border.all(color: tokens.borderHairline),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.folder, size: 17, color: tokens.accentSecondary),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            entry.name,
                                                            style: TextStyle(
                                                              color: tokens.textPrimary,
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                        Icon(Icons.chevron_right, size: 16, color: tokens.textMuted),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }

                                              final isAudio = _audioExtensions.contains(entry.extensionName);
                                              final badgeColor = isAudio
                                                  ? tokens.accentPrimary
                                                  : tokens.accentSecondary;

                                              return Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 7,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: tokens.inputSurface,
                                                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                                                  border: Border.all(color: tokens.borderHairline),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 44,
                                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: badgeColor.withValues(alpha: 0.16),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: badgeColor),
                                                      ),
                                                      child: Text(
                                                        entry.extensionName.toUpperCase(),
                                                        style: TextStyle(
                                                          color: badgeColor,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w800,
                                                          fontFamily: 'monospace',
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            entry.name,
                                                            style: TextStyle(
                                                              color: tokens.textPrimary,
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          Text(
                                                            '${_formatSize(entry.sizeBytes)} • ${_didacticHintForExt(entry.extensionName)}',
                                                            style: TextStyle(
                                                              color: tokens.textMuted,
                                                              fontSize: 9.5,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ElevatedButton(
                                                      onPressed: _isImporting
                                                          ? null
                                                          : () => _importDiskEntry(entry),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: badgeColor,
                                                        foregroundColor: tokens.textOnAccent,
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                        minimumSize: Size.zero,
                                                      ),
                                                      child: Text(
                                                        isAudio ? 'Transcribir' : 'Abrir',
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                              ),
                            ],
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      ),
                    ),
                    child: const Text('Cerrar', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
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
