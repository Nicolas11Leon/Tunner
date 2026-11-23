import 'package:flutter/material.dart';

import 'studio_design_tokens.dart';

/// Feature-agnostic controller holding the active [StudioDesignTokens].
/// Allows hot-swapping visual skins without touching any functional ViewModel.
class StudioThemeController extends ChangeNotifier {
  StudioDesignTokens _tokens;

  StudioThemeController({
    StudioDesignTokens initialTokens = StudioDesignTokens.studioOledMonochrome,
  }) : _tokens = initialTokens;

  StudioDesignTokens get tokens => _tokens;

  void setTokens(StudioDesignTokens next) {
    if (identical(next, _tokens) || next == _tokens) {
      return;
    }
    _tokens = next;
    notifyListeners();
  }

  void selectById(String id) {
    final match = StudioDesignTokens.presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => StudioDesignTokens.studioOledMonochrome,
    );
    setTokens(match);
  }
}

/// Inherited scope providing [StudioDesignTokens] and optional
/// [StudioThemeController] down the widget tree.
class StudioThemeScope extends InheritedNotifier<StudioThemeController> {
  const StudioThemeScope({
    super.key,
    required StudioThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static StudioDesignTokens of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<StudioThemeScope>();
    return scope?.notifier?.tokens ?? StudioDesignTokens.studioOledMonochrome;
  }

  static StudioDesignTokens tokensOf(BuildContext context) => of(context);

  static StudioThemeController? controllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StudioThemeScope>()
        ?.notifier;
  }
}
