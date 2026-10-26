import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';

/// Diálogo interactivo del Estudio de Temas para que los usuarios creen o editen
/// sus propias paletas estéticas con previsualización en tiempo real.
class ThemeEditorDialog extends StatefulWidget {
  final TunnerThemePalette? initialPalette;
  final Function(TunnerThemePalette palette) onSave;

  const ThemeEditorDialog({
    super.key,
    this.initialPalette,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    TunnerThemePalette? initialPalette,
    required Function(TunnerThemePalette palette) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ThemeEditorDialog(
        initialPalette: initialPalette,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ThemeEditorDialog> createState() => _ThemeEditorDialogState();
}

class _ThemeEditorDialogState extends State<ThemeEditorDialog> {
  late TextEditingController _nameController;
  String _selectedBase = "dark"; // "dark", "oled", "wood", "light"
  late Color _primaryAccent;
  late Color _secondaryAccent;

  // Paleta de acentos armónicos de alta vibración y legibilidad
  static const List<Color> curatedPrimaryAccents = [
    Color(0xFF00E676), // Esmeralda
    Color(0xFF00F0FF), // Cian Eléctrico
    Color(0xFFFFB300), // Ámbar Solar
    Color(0xFFF43F5E), // Rosa Rubí
    Color(0xFFA855F7), // Púrpura Real
    Color(0xFF38BDF8), // Zafiro
    Color(0xFF10B981), // Menta Acústica
    Color(0xFFFF6F00), // Naranja Puesta de Sol
    Color(0xFFE040FB), // Magenta Neón
  ];

  static const List<Color> curatedSecondaryAccents = [
    Color(0xFFFFD54F), // Oro Cálido
    Color(0xFFFF007F), // Magenta Eléctrico
    Color(0xFF38BDF8), // Azul Cielo
    Color(0xFFFBBF24), // Ámbar Noble
    Color(0xFF6EE7B7), // Aguamarina
    Color(0xFFFB7185), // Coral
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialPalette;
    _nameController = TextEditingController(
      text: init?.displayName ?? "Mi Estudio Acústico",
    );

    if (init != null) {
      if (init.scaffoldBackground == Colors.black) {
        _selectedBase = "oled";
      } else if (init.brightness == Brightness.light) {
        _selectedBase = "light";
      } else if (init.scaffoldBackground == const Color(0xFF181310) ||
          init.displayName.toLowerCase().contains("madera") ||
          init.displayName.toLowerCase().contains("wood")) {
        _selectedBase = "wood";
      } else {
        _selectedBase = "dark";
      }
      _primaryAccent = init.primaryAccent;
      _secondaryAccent = init.secondaryAccent;
    } else {
      _selectedBase = "dark";
      _primaryAccent = curatedPrimaryAccents.first;
      _secondaryAccent = curatedSecondaryAccents.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  TunnerThemePalette _buildPreviewPalette() {
    final name = _nameController.text.trim().isEmpty
        ? "Estudio Personalizado"
        : _nameController.text.trim();

    return TunnerThemePalette.createCustom(
      name: name,
      baseStyle: _selectedBase,
      primaryAccent: _primaryAccent,
      secondaryAccent: _secondaryAccent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreviewPalette();

    return AlertDialog(
      backgroundColor: preview.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: preview.surfaceBorderColor, width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: _primaryAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                widget.initialPalette != null ? "EDITAR ESTÉTICA" : "CREAR ESTÉTICA",
                style: TextStyle(
                  color: _primaryAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, color: preview.textMutedColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de Nombre
              Text(
                "Nombre del Tema",
                style: TextStyle(color: preview.textColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: preview.textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Ej. Obsidian Violeta, Madera Real...",
                  hintStyle: TextStyle(color: preview.textMutedColor),
                  filled: true,
                  fillColor: preview.staffBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: preview.surfaceBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: preview.surfaceBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _primaryAccent, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Selector de Tono Base
              Text(
                "Tono Base y Fondo",
                style: TextStyle(color: preview.textColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBaseChip("dark", "🌑 Oscuro Grafito", preview),
                  _buildBaseChip("oled", "⬛ OLED Puro", preview),
                  _buildBaseChip("wood", "🪵 Madera", preview),
                  _buildBaseChip("light", "☀️ Claro", preview),
                ],
              ),
              const SizedBox(height: 14),

              // Acento Primario (Identidad & Afinación)
              Text(
                "Color Acento Primario",
                style: TextStyle(color: preview.textColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: curatedPrimaryAccents.map((c) {
                  final isSelected = _primaryAccent.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _primaryAccent = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? preview.textColor : Colors.transparent,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: c.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: preview.brightness == Brightness.dark ? Colors.black : Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Acento Secundario (Tempo Mark & Metrónomo)
              Text(
                "Color Acento Secundario",
                style: TextStyle(color: preview.textColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: curatedSecondaryAccents.map((c) {
                  final isSelected = _secondaryAccent.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _secondaryAccent = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? preview.textColor : Colors.transparent,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 14, color: Colors.black87)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Tarjeta de Previsualización en Vivo
              Text(
                "Previsualización en Vivo",
                style: TextStyle(color: preview.textColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: preview.staffBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: preview.surfaceBorderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text("𝄞", style: TextStyle(color: preview.musicalSymbolsColor, fontSize: 24)),
                            const SizedBox(width: 6),
                            Text(
                              "4/4",
                              style: TextStyle(color: preview.musicalSymbolsColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: preview.surfaceHighlightColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _primaryAccent.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                "La4 440 Hz",
                                style: TextStyle(color: _primaryAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "ALLEGRO",
                          style: TextStyle(color: _secondaryAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CustomPaint(
                      size: const Size(double.infinity, 16),
                      painter: _MiniStaffPreviewPainter(
                        lineColor: preview.staffLinesColor,
                        playheadColor: preview.playheadColor,
                        noteColor: preview.musicalSymbolsColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: preview.textMutedColor)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryAccent,
            foregroundColor: preview.brightness == Brightness.dark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: const Icon(Icons.check, size: 16),
          label: const Text("Guardar y Aplicar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          onPressed: () {
            final savedPalette = _buildPreviewPalette();
            widget.onSave(savedPalette);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildBaseChip(String key, String label, TunnerThemePalette preview) {
    final isSelected = _selectedBase == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _primaryAccent.withValues(alpha: 0.25),
      backgroundColor: preview.staffBackground,
      labelStyle: TextStyle(
        color: isSelected ? _primaryAccent : preview.textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      side: BorderSide(
        color: isSelected ? _primaryAccent : preview.surfaceBorderColor,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedBase = key);
      },
    );
  }
}

class _MiniStaffPreviewPainter extends CustomPainter {
  final Color lineColor;
  final Color playheadColor;
  final Color noteColor;

  _MiniStaffPreviewPainter({
    required this.lineColor,
    required this.playheadColor,
    required this.noteColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    final spacing = size.height / 4;
    for (int i = 0; i < 5; i++) {
      final y = i * spacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }

    final notePaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.4, size.height * 0.5), width: 9, height: 7),
      notePaint,
    );

    final cursorPaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(size.width * 0.4, 0),
      Offset(size.width * 0.4, size.height),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniStaffPreviewPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.playheadColor != playheadColor ||
        oldDelegate.noteColor != noteColor;
  }
}
