import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/studio_theme_catalog_service.dart';
import '../domain/studio_theme_skin_entity.dart';
import '../studio_design_tokens.dart';
import '../studio_theme_provider.dart';

/// Modal interactivo para explorar, previsualizar, aplicar, importar y exportar
/// estéticas completas de estudio en formato descargable (.tntheme).
class StudioThemeManagerModal extends StatelessWidget {
  final StudioThemeCatalogService catalogService;

  const StudioThemeManagerModal({
    super.key,
    required this.catalogService,
  });

  static Future<void> show(
    BuildContext context, {
    StudioThemeCatalogService? catalogService,
  }) {
    final controller = StudioThemeScope.controllerOf(context);
    final service = catalogService ?? StudioThemeCatalogService(controller: controller);

    return showDialog<void>(
      context: context,
      builder: (ctx) => StudioThemeManagerModal(catalogService: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return ListenableBuilder(
      listenable: catalogService,
      builder: (context, _) {
        final skins = catalogService.availableSkins;
        final activeSkin = catalogService.activeSkin;

        return Dialog(
          backgroundColor: tokens.canvasBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMedium * 2),
            side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera del Gestor de Estéticas
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          border: Border.all(color: tokens.accentPrimary, width: tokens.borderWidth),
                        ),
                        child: Icon(Icons.palette, color: tokens.accentPrimary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CATÁLOGO DE ESTÉTICAS (.TNTHEME)',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Skins profesionales inspiradas en consolas analógicas y DAWs de clase mundial',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: tokens.textSecondary, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: tokens.borderHairline),
                  const SizedBox(height: 12),

                  // Lista scrolleable de Estéticas
                  Expanded(
                    child: ListView.separated(
                      itemCount: skins.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final skin = skins[index];
                        final isSelected = activeSkin.id == skin.id;

                        return _buildSkinCard(context, skin, isSelected, tokens);
                      },
                    ),
                  ),

                  const SizedBox(height: 14),
                  Divider(height: 1, color: tokens.borderHairline),
                  const SizedBox(height: 12),

                  // Barra inferior de importación y exportación de archivos .tntheme
                  Row(
                    children: [
                      // Botón Importar .tntheme
                      OutlinedButton.icon(
                        key: const Key('btn_import_theme'),
                        icon: const Icon(Icons.file_download_outlined, size: 14),
                        label: const Text('Importar .tntheme', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.textPrimary,
                          side: BorderSide(color: tokens.borderHairline),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _showImportDialog(context, tokens),
                      ),
                      const SizedBox(width: 8),

                      // Botón Exportar Activa .tntheme
                      OutlinedButton.icon(
                        key: const Key('btn_export_theme'),
                        icon: const Icon(Icons.file_upload_outlined, size: 14),
                        label: const Text('Exportar Activa', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.accentPrimary,
                          side: BorderSide(color: tokens.accentPrimary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          final json = catalogService.exportThemeToJson(activeSkin.id);
                          Clipboard.setData(ClipboardData(text: json));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Estética "${activeSkin.name}" copiada al portapapeles en formato .tntheme JSON.'),
                              backgroundColor: tokens.accentSuccess,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                      const Spacer(),

                      // Botón Cerrar
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.elevatedSurface,
                          foregroundColor: tokens.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkinCard(
    BuildContext context,
    StudioThemeSkinEntity skin,
    bool isSelected,
    StudioDesignTokens tokens,
  ) {
    final canvasColor = Color(skin.canvasBackgroundHex);
    final panelColor = Color(skin.panelBackgroundHex);
    final accentColor = Color(skin.accentPrimaryHex);
    final textColor = Color(skin.textPrimaryHex);

    return InkWell(
      onTap: () => catalogService.selectSkin(skin.id),
      borderRadius: BorderRadius.circular(tokens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? tokens.hoverSurface : tokens.panelBackground,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(
            color: isSelected ? tokens.accentPrimary : tokens.borderHairline,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Muestra visual de paleta en círculos
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: canvasColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _colorDot(canvasColor, 'Canvas'),
                  const SizedBox(width: 4),
                  _colorDot(panelColor, 'Panel'),
                  const SizedBox(width: 4),
                  _colorDot(accentColor, 'Acento'),
                  const SizedBox(width: 4),
                  _colorDot(textColor, 'Texto'),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Nombre y detalles de la estética
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        skin.name,
                        style: TextStyle(
                          color: isSelected ? tokens.accentPrimary : tokens.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: tokens.accentPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'ACTIVA',
                            style: TextStyle(
                              color: tokens.accentPrimary,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    skin.description,
                    style: TextStyle(color: tokens.textSecondary, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Por: ${skin.author}',
                    style: TextStyle(color: tokens.textMuted, fontSize: 8.5, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Botón Seleccionar
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? tokens.accentPrimary : tokens.inputSurface,
                foregroundColor: isSelected ? tokens.textOnAccent : tokens.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
              ),
              onPressed: () => catalogService.selectSkin(skin.id),
              child: Text(
                isSelected ? 'Seleccionada' : 'Aplicar',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context, StudioDesignTokens tokens) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: tokens.canvasBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          side: BorderSide(color: tokens.borderHairline),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IMPORTAR ESTÉTICA (.TNTHEME)',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pega el contenido JSON del archivo .tntheme descargado:',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '{\n  "format": "tunner_theme_package",\n  "name": "Mi Skin", ...\n}',
                    filled: true,
                    fillColor: tokens.inputSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: tokens.accentPrimary, foregroundColor: tokens.textOnAccent),
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          try {
                            final imported = catalogService.importThemeFromJson(text);
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Estética "${imported.name}" importada y aplicada.'),
                                backgroundColor: tokens.accentSuccess,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al importar tema: $e'),
                                backgroundColor: tokens.accentDanger,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Importar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
