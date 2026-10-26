import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../tuner_viewmodel.dart';
import 'theme_editor_dialog.dart';

/// Modal integral de personalización estética y de estudio acústico.
/// Permite conmutar entre las 7 estéticas curadas, gestionar temas personalizados,
/// crearlos interactivamente con ThemeEditorDialog, e importar/exportar en JSON.
class ThemeCustomizationModal extends StatelessWidget {
  final TunerViewModel viewModel;

  const ThemeCustomizationModal({
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
      builder: (_) => ThemeCustomizationModal(viewModel: viewModel),
    );
  }

  void _showExportJsonDialog(BuildContext context, TunnerThemePalette palette) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(palette.toJson());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.surfaceBorderColor),
        ),
        title: Row(
          children: [
            Icon(Icons.code, color: palette.primaryAccent),
            const SizedBox(width: 8),
            Text(
              "Exportar Tema (JSON)",
              style: TextStyle(color: palette.textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Copia esta configuración JSON para respaldar tu estética o compartirla con otros músicos:",
              style: TextStyle(color: palette.textMutedColor, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.staffBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.surfaceBorderColor),
              ),
              child: SelectableText(
                jsonStr,
                style: TextStyle(
                  color: palette.primaryAccent,
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cerrar", style: TextStyle(color: palette.textMutedColor)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primaryAccent,
              foregroundColor: palette.onPrimaryColor,
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text("Copiar al Portapapeles"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: palette.cardBackground,
                  content: Text(
                    "¡Configuración de '${palette.displayName}' copiada!",
                    style: TextStyle(color: palette.primaryAccent),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showImportJsonDialog(BuildContext context, TunnerThemePalette palette) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.surfaceBorderColor),
        ),
        title: Row(
          children: [
            Icon(Icons.file_download_outlined, color: palette.primaryAccent),
            const SizedBox(width: 8),
            Text(
              "Importar Tema desde JSON",
              style: TextStyle(color: palette.textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pega aquí el texto JSON de cualquier paleta para cargarla instantáneamente:",
              style: TextStyle(color: palette.textMutedColor, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 6,
              style: TextStyle(color: palette.textColor, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '{\n  "displayName": "Mi Estética",\n  "primaryAccent": ...\n}',
                hintStyle: TextStyle(color: palette.textMutedColor.withValues(alpha: 0.5)),
                filled: true,
                fillColor: palette.staffBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: palette.surfaceBorderColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: palette.textMutedColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primaryAccent,
              foregroundColor: palette.onPrimaryColor,
            ),
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                final success = viewModel.importPaletteFromJson(text);
                Navigator.pop(ctx);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: palette.cardBackground,
                      content: Text(
                        "¡Tema importado y aplicado con éxito!",
                        style: TextStyle(color: palette.correctPitchColor),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: palette.cardBackground,
                      content: Text(
                        "Error: el formato JSON proporcionado no es válido.",
                        style: TextStyle(color: palette.errorPitchColor),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text("Importar y Aplicar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final palette = viewModel.currentPalette;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Container(
              color: palette.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  // Tirador superior de arrastre
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.surfaceBorderColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Barra de Título
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune, color: palette.primaryAccent, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "PERSONALIZACIÓN DE ESTUDIO",
                            style: TextStyle(
                              color: palette.primaryAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Text(
                    "Selecciona estéticas curadas, crea tu propia paleta o importa configuraciones en JSON",
                    style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                  ),
                  const SizedBox(height: 16),

                  // Botones rápidos de Crear e Importar Tema
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.primaryAccent,
                            side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text("Crear Tema", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            ThemeEditorDialog.show(
                              context: context,
                              onSave: (newTheme) {
                                viewModel.addCustomPalette(newTheme);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: "Importar Tema (JSON)",
                        icon: Icon(Icons.file_download_outlined, color: palette.primaryAccent, size: 20),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: palette.surfaceBorderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showImportJsonDialog(context, palette),
                      ),
                      const SizedBox(width: 4),
                      IconButton.outlined(
                        tooltip: "Exportar Tema Activo (JSON)",
                        icon: Icon(Icons.share_outlined, color: palette.secondaryAccent, size: 20),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: palette.surfaceBorderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showExportJsonDialog(context, palette),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1. Selector de Estéticas y Temas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Estéticas Disponibles (${viewModel.availablePalettes.length})",
                        style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (palette.isCustom)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.primaryAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            "Tema Activo: Personalizado",
                            style: TextStyle(color: palette.primaryAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Lista de Tarjetas de Temas
                  ...viewModel.availablePalettes.map((p) {
                    final isSelected = viewModel.currentPalette.id == p.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: p.scaffoldBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? p.primaryAccent : p.surfaceBorderColor,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: p.primaryAccent.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => viewModel.setPalette(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              // Cápsula de Swatches de Color
                              Container(
                                width: 50,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24, width: 0.8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Row(
                                  children: [
                                    Expanded(child: Container(color: p.cardBackground)),
                                    Expanded(child: Container(color: p.staffBackground)),
                                    Expanded(child: Container(color: p.primaryAccent)),
                                    Expanded(child: Container(color: p.secondaryAccent)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Nombre y Badge
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          p.displayName,
                                          style: TextStyle(
                                            color: p.textColor,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (p.isCustom) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: p.primaryAccent.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "CUSTOM",
                                              style: TextStyle(color: p.primaryAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.brightness == Brightness.dark ? "Modo Oscuro / Acústico" : "Modo Claro / Luz Solar",
                                      style: TextStyle(color: p.textMutedColor, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              // Acciones de edición si es custom
                              if (p.isCustom) ...[
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, size: 18, color: p.primaryAccent),
                                  tooltip: "Editar Tema",
                                  onPressed: () {
                                    ThemeEditorDialog.show(
                                      context: context,
                                      initialPalette: p,
                                      onSave: (updated) => viewModel.updateCustomPalette(updated),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: p.errorPitchColor),
                                  tooltip: "Eliminar Tema",
                                  onPressed: () => viewModel.deleteCustomPalette(p.id),
                                ),
                              ],
                              if (isSelected)
                                Icon(Icons.check_circle, color: p.primaryAccent, size: 20)
                              else
                                Icon(Icons.radio_button_unchecked, color: p.textMutedColor, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),

                  // 2. Selector de Métrica de Compás Libre
                  Text(
                    "Métrica de Compás",
                    style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TimeSignature.standardSignatures.map((sig) {
                      final isSelected = viewModel.currentMeasureTimeSignature == sig;
                      return ActionChip(
                        avatar: Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: isSelected ? palette.primaryAccent : palette.textMutedColor,
                        ),
                        label: Text(sig.toString()),
                        backgroundColor: isSelected
                            ? palette.surfaceHighlightColor
                            : palette.staffBackground,
                        labelStyle: TextStyle(
                          color: isSelected ? palette.primaryAccent : palette.textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? palette.primaryAccent : palette.surfaceBorderColor,
                        ),
                        onPressed: () => viewModel.setCustomTimeSignature(sig),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
