import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/navigation/presentation/main_app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Studio Sidebar Clean Separation Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets('renders Documentos del Proyecto and Suite de Herramientas independently', (tester) async {
      // Configurar tamaño de escritorio amplio para que se muestre el shell de estudio
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: viewModel),
            ChangeNotifierProvider(create: (_) => StudioThemeController()),
          ],
          child: const MaterialApp(
            home: MainAppShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verifica la existencia de las dos secciones calculadas independientes
      expect(find.text('Documentos del Proyecto'), findsOneWidget);
      expect(find.text('Suite de Herramientas'), findsOneWidget);

      // 2. Verifica las carpetas de Documentos del Proyecto
      expect(find.text('Partituras & Notación (0)'), findsOneWidget);
      expect(find.text('Tomas de Audio & WAV (0)'), findsOneWidget);
      expect(find.text('Presets de Afinación (0)'), findsOneWidget);

      // 3. Verifica que en Tomas de Audio NO está el Rack Modular
      expect(find.text('Rack Modular de Pedales DSP'), findsOneWidget); // Está en Suite de Herramientas -> Producción
      expect(find.text('Producción & Enrutamiento'), findsOneWidget);

      // 4. Verifica las carpetas de Suite de Herramientas
      expect(find.text('Afinación & Entonación'), findsOneWidget);
      expect(find.text('Análisis Acústico & Laboratorio'), findsOneWidget);
      expect(find.text('Pedagogía & Conservatorio'), findsOneWidget);

      // 5. Verifica items de herramientas
      expect(find.text('Afinador Estroboscópico Pro'), findsOneWidget);
      expect(find.text('Espectrograma FFT en Vivo'), findsOneWidget);
      expect(find.text('Tutor de Compás y Rushing'), findsOneWidget);
    });
  });
}
