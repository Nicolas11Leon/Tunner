import 'package:flutter/material.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../tuner_viewmodel.dart';
import '../data/song_decomposer_service.dart';

/// Modal interactivo de estudio para la creación, importación y descomposición pedagógica
/// de canciones en pistas aisladas (stems).
class SongDecomposerModal extends StatefulWidget {
  final TunerViewModel viewModel;

  const SongDecomposerModal({
    super.key,
    required this.viewModel,
  });

  static void show(BuildContext context, TunerViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: viewModel.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SongDecomposerModal(viewModel: viewModel),
    );
  }

  @override
  State<SongDecomposerModal> createState() => _SongDecomposerModalState();
}

class _SongDecomposerModalState extends State<SongDecomposerModal> {
  int _selectedTab = 0; // 0: Editor & Entrada Rápida, 1: Plantillas Maestras

  late final TextEditingController _titleController;
  late final TextEditingController _composerController;
  late final TextEditingController _notationController;

  int _bpm = 112;
  TimeSignature _timeSignature = TimeSignature.commonTime44;

  bool _includeLead = true;
  bool _includePiano = true;
  bool _includeBass = true;
  bool _includeRhythm = true;

  int _selectedOctave = 4;
  String _selectedAccidental = '';
  int _selectedDuration = 4; // 16: Redonda, 8: Blanca, 4: Negra, 2: Corchea

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: "Mi Composición Descompuesta");
    _composerController = TextEditingController(text: "Estudiante Tunner");
    _notationController = TextEditingController(
      text: "Do4:4 Re4:4 Mi4:4 Fa4:4 | Sol4:4 Sol4:4 Fa4:4 Mi4:4 | Re4:4 Re4:4 Do4:8",
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _notationController.dispose();
    super.dispose();
  }

  void _applyTemplate(SongDecompositionTemplate template) {
    setState(() {
      _titleController.text = template.title;
      _composerController.text = template.composer;
      _bpm = template.bpm;
      _timeSignature = template.timeSignature;
      _notationController.text = template.melodyNotation;
      _selectedTab = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Plantilla '${template.title}' cargada en el editor."),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _appendNote(String baseName) {
    String noteToken;
    if (baseName == 'R') {
      noteToken = "_:$_selectedDuration";
    } else {
      noteToken = "$baseName$_selectedAccidental$_selectedOctave:$_selectedDuration";
    }

    final current = _notationController.text.trim();
    if (current.isEmpty) {
      _notationController.text = noteToken;
    } else {
      _notationController.text = "$current $noteToken";
    }
    setState(() {});
  }

  void _appendBar() {
    final current = _notationController.text.trim();
    if (current.isNotEmpty && !current.endsWith('|')) {
      _notationController.text = "$current | ";
      setState(() {});
    }
  }

  void _backspaceNote() {
    final text = _notationController.text.trim();
    if (text.isEmpty) return;

    final parts = text.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      parts.removeLast();
      _notationController.text = parts.join(' ');
      setState(() {});
    }
  }

  void _executeDecomposition() {
    final parsedMeasures = SongDecomposerService.parseMelodyText(
      _notationController.text,
      _timeSignature,
    );

    final decomposedPackage = SongDecomposerService.decomposeCustomScore(
      title: _titleController.text.trim().isEmpty ? "Obra Descompuesta" : _titleController.text.trim(),
      composer: _composerController.text.trim().isEmpty ? "Músico Local" : _composerController.text.trim(),
      bpm: _bpm,
      timeSignature: _timeSignature,
      measures: parsedMeasures,
      includeLead: _includeLead,
      includePiano: _includePiano,
      includeBass: _includeBass,
      includeRhythm: _includeRhythm,
    );

    widget.viewModel.addSongPackage(decomposedPackage);
    widget.viewModel.loadSongPackage(decomposedPackage);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: widget.viewModel.currentPalette.primaryAccent,
        content: Text(
          "¡Obra '${decomposedPackage.title}' descompuesta con éxito en ${decomposedPackage.tracks.length} capas!",
          style: TextStyle(
            color: widget.viewModel.currentPalette.brightness == Brightness.dark ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.viewModel.currentPalette;
    final isDark = palette.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final parsedPreview = SongDecomposerService.parseMelodyText(_notationController.text, _timeSignature);
    final totalNotes = parsedPreview.fold<int>(0, (acc, m) => acc + m.notes.where((n) => !n.isRest).length);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle & Header
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: palette.surfaceBorderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.primaryAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: palette.primaryAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Estudio de Descomposición",
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Crea o importa melodías y aísla pistas pedagógicas",
                      style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: palette.textMutedColor),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector de modo / tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: palette.scaffoldBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.surfaceBorderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? palette.primaryAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Editor & Entrada Rápida",
                        style: TextStyle(
                          color: _selectedTab == 0
                              ? (isDark ? Colors.black : Colors.white)
                              : palette.textMutedColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? palette.primaryAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Plantillas de Estudio",
                        style: TextStyle(
                          color: _selectedTab == 1
                              ? (isDark ? Colors.black : Colors.white)
                              : palette.textMutedColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Contenido principal scrolleable
          Expanded(
            child: SingleChildScrollView(
              child: _selectedTab == 0
                  ? _buildEditorTab(palette, isDark, parsedPreview, totalNotes)
                  : _buildTemplatesTab(palette, isDark),
            ),
          ),

          const SizedBox(height: 12),

          // Botón de descomposición
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _executeDecomposition,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryAccent,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.splitscreen_rounded),
              label: Text(
                "Descomponer y Cargar al Estudio (${parsedPreview.length} compases)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorTab(
    dynamic palette,
    bool isDark,
    List<MeasureEntity> parsedPreview,
    int totalNotes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila de Título y Compositor
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildTextField(
                controller: _titleController,
                label: "Título de la Obra",
                hint: "Ej. Canon Didáctico",
                palette: palette,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _composerController,
                label: "Compositor",
                hint: "Tu nombre / Autor",
                palette: palette,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Fila de Métricas: BPM y Compás
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.surfaceBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Tempo (BPM)", style: TextStyle(color: palette.textMutedColor, fontSize: 11)),
                        Text("$_bpm BPM", style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: palette.primaryAccent,
                        thumbColor: palette.primaryAccent,
                        inactiveTrackColor: palette.surfaceBorderColor,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: _bpm.toDouble(),
                        min: 40,
                        max: 220,
                        divisions: 90,
                        onChanged: (val) => setState(() => _bpm = val.round()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.surfaceBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Métrica", style: TextStyle(color: palette.textMutedColor, fontSize: 11)),
                    const SizedBox(height: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<TimeSignature>(
                        value: _timeSignature,
                        isDense: true,
                        dropdownColor: palette.cardBackground,
                        icon: Icon(Icons.arrow_drop_down, color: palette.primaryAccent),
                        items: const [
                          DropdownMenuItem(
                            value: TimeSignature.commonTime44,
                            child: Text("4/4 (Común)", style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: TimeSignature.waltzTime34,
                            child: Text("3/4 (Vals)", style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: TimeSignature(2, 4),
                            child: Text("2/4 (Binario)", style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: TimeSignature(6, 8),
                            child: Text("6/8 (Compuesto)", style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        onChanged: (newVal) {
                          if (newVal != null) setState(() => _timeSignature = newVal);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Campo de Notación Textual
        Text(
          "Notación Melódica (Sintaxis Libre)",
          style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          "Formato: Nota + Octava:Duración (ej. Do4:4 Re4:4 | Sol4:8) o letras (C4 D4 E4)",
          style: TextStyle(color: palette.textMutedColor, fontSize: 10),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _notationController,
          maxLines: 2,
          style: TextStyle(color: palette.textColor, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.scaffoldBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.surfaceBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.surfaceBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.primaryAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),

        // Teclado interactivo de notas y modificadores
        _buildQuickNoteKeypad(palette),
        const SizedBox(height: 14),

        // Opciones de descomposición de capas (Stems)
        Text(
          "Capas a Generar en la Descomposición",
          style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildLayerFilterChip("🎵 Voz/Lead", _includeLead, (v) => setState(() => _includeLead = v), palette),
            _buildLayerFilterChip("🎹 Armonía/Piano", _includePiano, (v) => setState(() => _includePiano = v), palette),
            _buildLayerFilterChip("🎻 Bajo/Cello", _includeBass, (v) => setState(() => _includeBass = v), palette),
            _buildLayerFilterChip("🥁 Ritmo/Perc", _includeRhythm, (v) => setState(() => _includeRhythm = v), palette),
          ],
        ),
        const SizedBox(height: 14),

        // Tarjeta de Previsualización en Vivo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.primaryAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric("Compases", "${parsedPreview.length}", palette),
              _buildStatMetric("Notas Melódicas", "$totalNotes", palette),
              _buildStatMetric("Capas Activas", "${[_includeLead, _includePiano, _includeBass, _includeRhythm].where((b) => b).length}", palette),
              _buildStatMetric("Ticks/Compás", "${_timeSignature.totalTicks}", palette),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplatesTab(dynamic palette, bool isDark) {
    final templates = SongDecomposerService.getDecompositionTemplates();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Selecciona una obra curada para cargarla instantáneamente con todas sus capas:",
          style: TextStyle(color: palette.textMutedColor, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...templates.map((tpl) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: palette.scaffoldBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: palette.surfaceBorderColor),
            ),
            elevation: 0,
            child: InkWell(
              onTap: () => _applyTemplate(tpl),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.music_note, color: palette.primaryAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tpl.title,
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${tpl.composer} • ${tpl.bpm} BPM • ${tpl.timeSignature.numerator}/${tpl.timeSignature.denominator}",
                            style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _applyTemplate(tpl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primaryAccent,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                      ),
                      child: const Text("Cargar", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQuickNoteKeypad(dynamic palette) {
    final notes = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si', 'R'];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.surfaceBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selectores de Octava, Alteración y Duración
          Row(
            children: [
              // Octava
              Text("Octava:", style: TextStyle(color: palette.textMutedColor, fontSize: 11)),
              const SizedBox(width: 4),
              for (final oct in [3, 4, 5])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text("$oct", style: const TextStyle(fontSize: 10)),
                    selected: _selectedOctave == oct,
                    onSelected: (_) => setState(() => _selectedOctave = oct),
                    selectedColor: palette.primaryAccent,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              const Spacer(),
              // Alteración
              for (final acc in ['', '#', 'b'])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    label: Text(acc.isEmpty ? "Natural" : acc, style: const TextStyle(fontSize: 10)),
                    selected: _selectedAccidental == acc,
                    onSelected: (_) => setState(() => _selectedAccidental = acc),
                    selectedColor: palette.primaryAccent,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Duraciones (Figuras)
          Row(
            children: [
              Text("Figura:", style: TextStyle(color: palette.textMutedColor, fontSize: 11)),
              const SizedBox(width: 4),
              _buildDurationChip("Negra (1/4)", 4, palette),
              const SizedBox(width: 4),
              _buildDurationChip("Blanca (1/2)", 8, palette),
              const SizedBox(width: 4),
              _buildDurationChip("Corchea (1/8)", 2, palette),
              const SizedBox(width: 4),
              _buildDurationChip("Redonda (1)", 16, palette),
            ],
          ),
          const SizedBox(height: 8),

          // Teclado de notas
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in notes)
                ElevatedButton(
                  onPressed: () => _appendNote(n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: n == 'R'
                        ? palette.surfaceBorderColor
                        : palette.cardBackground,
                    foregroundColor: palette.textColor,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                    side: BorderSide(color: palette.surfaceBorderColor),
                  ),
                  child: Text(
                    n == 'R' ? 'Silencio' : n,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: n == 'R' ? palette.textMutedColor : palette.textColor,
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _appendBar,
                icon: const Icon(Icons.line_weight, size: 14),
                label: const Text("| Compás", style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.cardBackground,
                  foregroundColor: palette.primaryAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: palette.surfaceBorderColor),
                  elevation: 0,
                ),
              ),
              IconButton(
                icon: Icon(Icons.backspace_outlined, size: 16, color: palette.textMutedColor),
                onPressed: _backspaceNote,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(String label, int ticks, dynamic palette) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: _selectedDuration == ticks,
      onSelected: (_) => setState(() => _selectedDuration = ticks),
      selectedColor: palette.primaryAccent,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildLayerFilterChip(String label, bool value, ValueChanged<bool> onChanged, dynamic palette) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: value,
      onSelected: onChanged,
      selectedColor: palette.primaryAccent.withValues(alpha: 0.25),
      checkmarkColor: palette.primaryAccent,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: value ? palette.primaryAccent : palette.surfaceBorderColor),
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, dynamic palette) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: palette.primaryAccent, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required dynamic palette,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.textMutedColor, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: TextStyle(color: palette.textColor, fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: palette.textMutedColor.withValues(alpha: 0.6), fontSize: 12),
            filled: true,
            fillColor: palette.scaffoldBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.surfaceBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.surfaceBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.primaryAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }
}
