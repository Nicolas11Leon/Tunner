import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/studio_composition_root.dart';
import 'core/design_system/studio_theme_provider.dart';
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
      child: const TunnerApp(),
    ),
  );
}

/// Aplicación principal Tunner: Laboratorio Acústico y Partituras de Conservatorio.
class TunnerApp extends StatefulWidget {
  const TunnerApp({super.key});

  @override
  State<TunnerApp> createState() => _TunnerAppState();
}

class _TunnerAppState extends State<TunnerApp> {
  final StudioThemeController _fallbackThemeController =
      StudioThemeController();
  String? _lastAppliedPaletteId;

  @override
  void dispose() {
    _fallbackThemeController.dispose();
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
    } catch (_) {
      studioThemeController = _fallbackThemeController;
    }

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
