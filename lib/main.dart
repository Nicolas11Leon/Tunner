import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/studio_composition_root.dart';
import 'core/design_system/studio_theme_provider.dart';
import 'core/logging/infrastructure/studio_debug_logger.dart';
import 'core/theme/tunner_theme.dart';
import 'features/navigation/presentation/main_app_shell.dart';
import 'features/tuner_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final compositionRoot = StudioCompositionRoot.create();

  runApp(
    MultiProvider(
      providers: [
        Provider<StudioCompositionRoot>.value(value: compositionRoot),
        ChangeNotifierProvider(
          create: (_) => compositionRoot.createTunerViewModel(seedDefaults: true),
        ),
        ChangeNotifierProvider.value(value: compositionRoot.themeController),
      ],
      child: TunnerApp(compositionRoot: compositionRoot),
    ),
  );
}

/// Aplicación principal Tunner: Laboratorio Acústico y Partituras de Conservatorio.
class TunnerApp extends StatefulWidget {
  final StudioCompositionRoot? compositionRoot;

  const TunnerApp({super.key, this.compositionRoot});

  @override
  State<TunnerApp> createState() => _TunnerAppState();
}

class _TunnerAppState extends State<TunnerApp> {
  final StudioThemeController _fallbackThemeController =
      StudioThemeController();
  StudioThemeController? _observedThemeController;
  String? _lastAppliedPaletteId;
  String? _lastSyncedStudioThemeId;

  void _attachThemeControllerSync(StudioThemeController controller) {
    if (identical(_observedThemeController, controller)) return;
    _observedThemeController?.removeListener(_handleStudioThemeControllerChanged);
    _observedThemeController = controller;
    _observedThemeController?.addListener(_handleStudioThemeControllerChanged);
  }

  void _handleStudioThemeControllerChanged() {
    if (!mounted) return;
    final controller = _observedThemeController;
    if (controller == null) return;
    final currentId = controller.tokens.id;
    if (currentId == _lastSyncedStudioThemeId) return;
    _lastSyncedStudioThemeId = currentId;
    try {
      context.read<TunerViewModel>().setActiveStudioThemeId(currentId);
    } catch (_) {
      // Tolerante en árboles de prueba sin TunerViewModel montado.
    }
  }

  @override
  void dispose() {
    _observedThemeController?.removeListener(_handleStudioThemeControllerChanged);
    _fallbackThemeController.dispose();
    widget.compositionRoot?.dispose();
    super.dispose();
  }

  void _syncSystemUiStyleIfChanged(TunnerThemePalette palette) {
    if (_lastAppliedPaletteId == palette.id) return;
    _lastAppliedPaletteId = palette.id;

    final isLight = palette.brightness == Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: palette.scaffoldBackground,
        systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Selector granular: evita reconstruir MaterialApp en cada frame de pitch (60 FPS)
    final palette = context.select<TunerViewModel, TunnerThemePalette>(
      (vm) => vm.currentPalette,
    );
    StudioThemeController studioThemeController;
    try {
      studioThemeController = context.watch<StudioThemeController>();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'TunnerApp',
        'StudioThemeController no encontrado en arbol; usando fallback: $e',
        error: e,
        stackTrace: st,
      );
      studioThemeController = _fallbackThemeController;
    }

    _attachThemeControllerSync(studioThemeController);
    _syncSystemUiStyleIfChanged(palette);

    return StudioThemeScope(
      controller: studioThemeController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tunner: Studio Pitch & Sheet Music Lab',
        theme: ThemeData(
          useMaterial3: true,
          brightness: palette.brightness,
          scaffoldBackgroundColor: palette.scaffoldBackground,
          cardColor: palette.cardBackground,
          colorScheme: ColorScheme.fromSeed(
            seedColor: palette.primaryAccent,
            brightness: palette.brightness,
            surface: palette.cardBackground,
          ),
        ),
        home: const MainAppShell(),
      ),
    );
  }
}

/// Alias para mantener retrocompatibilidad con tests existentes
typedef FluteTunerApp = TunnerApp;
