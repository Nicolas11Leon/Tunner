import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/design_system/studio_theme_provider.dart';
import 'features/navigation/presentation/main_app_shell.dart';
import 'features/tuner_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TunerViewModel(seedDefaults: true)),
        ChangeNotifierProvider(create: (_) => StudioThemeController()),
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

  @override
  void dispose() {
    _fallbackThemeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    StudioThemeController studioThemeController;
    try {
      studioThemeController = context.watch<StudioThemeController>();
    } catch (_) {
      studioThemeController = _fallbackThemeController;
    }
    final palette = viewModel.currentPalette;

    final isLight = palette.brightness == Brightness.light;

    // Sincronización de la barra de estado del sistema con el tema activo
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: palette.scaffoldBackground,
        systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      ),
    );

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