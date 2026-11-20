import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../molecules/studio_theme_manager_modal.dart';
import '../studio_design_tokens.dart';
import '../studio_theme_provider.dart';
import '../../../features/tuner_viewmodel.dart';

/// Feature-agnostic skin selector allowing instant switching between
/// Tunner Studio palettes without affecting any functional state.
class StudioThemeSwitcher extends StatelessWidget {
  const StudioThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final controller = StudioThemeScope.controllerOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: tokens.inputSurface,
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            border: Border.all(
              color: tokens.borderHairline,
              width: tokens.borderWidth,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('studio_theme_switcher_dropdown'),
              value: StudioDesignTokens.presets.any((p) => p.id == tokens.id) ? tokens.id : null,
              hint: Text(
                tokens.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              isDense: true,
              dropdownColor: tokens.panelHeaderBackground,
              icon: Icon(
                Icons.palette_outlined,
                size: 13,
                color: tokens.textSecondary,
              ),
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              items: StudioDesignTokens.presets
                  .map(
                    (preset) => DropdownMenuItem<String>(
                      value: preset.id,
                      child: Text(preset.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (id) {
                if (id != null) {
                  controller.selectById(id);
                  try {
                    final vm = Provider.of<TunerViewModel>(context, listen: false);
                    vm.setPaletteById(id);
                  } catch (_) {}
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const Key('btn_open_theme_manager'),
          tooltip: 'Gestionar Skins y Estéticas (.tntheme)',
          icon: Icon(Icons.tune, size: 14, color: tokens.accentPrimary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () => StudioThemeManagerModal.show(context),
        ),
      ],
    );
  }
}
