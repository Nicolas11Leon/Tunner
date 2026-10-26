import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'features/tuner_screen.dart';
import 'features/tuner_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TunerViewModel()),
      ],
      child: const TunnerApp(),
    ),
  );
}

/// Aplicación principal Tunner: Laboratorio Acústico y Partituras de Conservatorio.
class TunnerApp extends StatelessWidget {
  const TunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
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

    return MaterialApp(
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
      home: const TunerScreen(),
    );
  }
}

/// Alias para mantener retrocompatibilidad con tests existentes
typedef FluteTunerApp = TunnerApp;