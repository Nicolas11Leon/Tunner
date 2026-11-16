import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';
import '../atoms/studio_hairline.dart';
import '../atoms/studio_toolbar.dart';

/// Organismo de UI: Armazón de Estación de Trabajo Pro-Studio (StudioWorkbenchShell).
///
/// Implementa la estructura ergonómica y modular estándar de Adobe Creative Cloud
/// (Audition / Premiere Pro):
/// - Barra de herramientas superior compacta (38px).
/// - Área de trabajo principal enmarcada por bordes hairline de 1px.
/// - Barra de estado y transporte inferior (Status / Transport Dock).
class StudioWorkbenchShell extends StatelessWidget {
  final Widget? headerLeading;
  final Widget? headerTitle;
  final List<Widget> headerActions;
  final Widget body;
  final Widget? bottomStatusBar;
  final EdgeInsetsGeometry padding;

  const StudioWorkbenchShell({
    super.key,
    this.headerLeading,
    this.headerTitle,
    this.headerActions = const [],
    required this.body,
    this.bottomStatusBar,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de herramientas superior unificada
            StudioToolbar(
              children: [
                if (headerLeading != null) ...[
                  headerLeading!,
                  const SizedBox(width: 8),
                ],
                if (headerTitle != null) ...[
                  headerTitle!,
                  const SizedBox(width: 12),
                ],
                ...headerActions,
              ],
            ),
            const StudioHairline(orientation: Axis.horizontal),

            // Espacio de trabajo central (Viewport)
            Expanded(
              child: Container(
                color: tokens.canvasBackground,
                padding: padding,
                child: body,
              ),
            ),

            // Barra de estado inferior opcional
            if (bottomStatusBar != null) ...[
              const StudioHairline(orientation: Axis.horizontal),
              Container(
                height: 26.0,
                color: tokens.panelHeaderBackground,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                alignment: Alignment.centerLeft,
                child: bottomStatusBar!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
