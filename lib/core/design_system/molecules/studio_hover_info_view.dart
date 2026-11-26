import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Modelo inmutable de metainformación contextual acústica y pedagógica
/// al estilo Ableton Live 12 Info View.
class StudioHoverInfoItem {
  final String title;
  final String description;
  final String? shortcut;
  final String? acousticFormula;
  final String category;

  const StudioHoverInfoItem({
    required this.title,
    required this.description,
    this.shortcut,
    this.acousticFormula,
    this.category = 'ESTUDIO',
  });

  static const StudioHoverInfoItem defaultInfo = StudioHoverInfoItem(
    title: 'Inspector & Info View Activo',
    description:
        'Pase el cursor sobre cualquier control del shell o seleccione un parámetro para ver su función acústica, fórmula DSP y atajo de teclado.',
    shortcut: 'Ctrl+I',
    acousticFormula: 'f = A4 * 2^((n - 69) / 12)',
    category: 'ESTUDIO',
  );
}

/// Controlador reactivo de ayuda contextual instantánea por hover.
///
/// Funciona como singleton global (`StudioHoverInfoController.instance`) o como
/// instancia inyectable para pruebas aisladas.
class StudioHoverInfoController extends ChangeNotifier {
  static final StudioHoverInfoController instance = StudioHoverInfoController();

  StudioHoverInfoItem _currentInfo = StudioHoverInfoItem.defaultInfo;

  StudioHoverInfoController({StudioHoverInfoItem? initialInfo}) {
    if (initialInfo != null) {
      _currentInfo = initialInfo;
    }
  }

  StudioHoverInfoItem get currentInfo => _currentInfo;

  void setHoverInfo(StudioHoverInfoItem info) {
    if (_currentInfo == info) return;
    _currentInfo = info;
    notifyListeners();
  }

  void resetToDefault() {
    setHoverInfo(StudioHoverInfoItem.defaultInfo);
  }
}

/// Widget envolvente que publica automáticamente un [StudioHoverInfoItem]
/// cuando el cursor entra en su región interactiva.
class StudioHoverInfoTarget extends StatelessWidget {
  final StudioHoverInfoItem item;
  final Widget child;
  final StudioHoverInfoController? controller;
  final bool resetOnExit;

  const StudioHoverInfoTarget({
    super.key,
    required this.item,
    required this.child,
    this.controller,
    this.resetOnExit = false,
  });

  @override
  Widget build(BuildContext context) {
    final targetController = controller ?? StudioHoverInfoController.instance;
    return MouseRegion(
      opaque: false,
      onEnter: (_) => targetController.setHoverInfo(item),
      onExit: resetOnExit ? (_) => targetController.resetToDefault() : null,
      child: child,
    );
  }
}

/// Panel de Ayuda Ambiental Instantánea al estilo Ableton Live 12 Info View.
///
/// Se ancla en el pie del Inspector Contextual Derecho para mostrar en tiempo real
/// qué hace cada control, su atajo de teclado y su fundamento matemático/DSP.
class StudioHoverInfoViewPanel extends StatelessWidget {
  final StudioHoverInfoController? controller;

  const StudioHoverInfoViewPanel({
    super.key = const Key('studio_hover_info_view_panel'),
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final activeController = controller ?? StudioHoverInfoController.instance;

    return ListenableBuilder(
      listenable: activeController,
      builder: (context, _) {
        final info = activeController.currentInfo;
        return Container(
          decoration: BoxDecoration(
            color: tokens.panelHeaderBackground,
            border: Border(
              top: BorderSide(
                color: tokens.borderHairline,
                width: tokens.borderWidth,
              ),
            ),
          ),
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabecera compacta
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13.0,
                    color: tokens.accentPrimary,
                  ),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: Text(
                      'INFO VIEW (ABLETON STYLE)',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (info.shortcut != null && info.shortcut!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5.0,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(
                          color: tokens.accentPrimary.withValues(alpha: 0.4),
                          width: tokens.borderWidth,
                        ),
                      ),
                      child: Text(
                        info.shortcut!,
                        style: TextStyle(
                          color: tokens.accentPrimary,
                          fontSize: 9.0,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6.0),
              // Título en negrita
              Text(
                info.title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4.0),
              // Descripción pedagógica
              Text(
                info.description,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
              // Caja monoespaciada con fórmula acústica si no es nula
              if (info.acousticFormula != null &&
                  info.acousticFormula!.isNotEmpty) ...[
                const SizedBox(height: 6.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.inputSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(
                      color: tokens.borderHairline,
                      width: tokens.borderWidth,
                    ),
                  ),
                  child: Text(
                    info.acousticFormula!,
                    style: TextStyle(
                      color: tokens.accentPrimary,
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
