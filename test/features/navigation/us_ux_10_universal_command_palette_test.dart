import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/features/audio_synthesizer/data/audio_synthesizer_service.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/navigation/presentation/home_dashboard_screen.dart';
import 'package:tunner/features/navigation/presentation/pro_command_palette_modal.dart';
import 'package:tunner/features/navigation/presentation/studio_command_catalog_builder.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;
  late ModularRackViewModel modularRackViewModel;
  late MediaVaultViewModel mediaVaultViewModel;
  late MemoryStudioAudioEngine memoryEngine;

  setUp(() {
    memoryEngine = MemoryStudioAudioEngine();
    viewModel = TunerViewModel(
      pitchService: _FakePitchService(),
      audioSynthesizerService: AudioSynthesizerService(audioEngine: memoryEngine),
      seedDefaults: true,
    );
    modularRackViewModel = ModularRackViewModel();
    mediaVaultViewModel = MediaVaultViewModel();
  });

  tearDown(() {
    mediaVaultViewModel.dispose();
    modularRackViewModel.dispose();
    viewModel.dispose();
  });

  group('US-UX-10: Universal Command Palette (Autodesk Fusion 360 / VS Code style)', () {
    testWidgets(
      'Prueba 1: StudioCommandCatalogBuilder.build incluye open_harmonic_tutor, set_a4_432/440/442 y partituras dinámicas de workspaceScores',
      (tester) async {
        expect(viewModel.workspaceScores, isNotEmpty);

        int? navigatedTab;
        late List<CommandItem> commands;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  commands = StudioCommandCatalogBuilder.build(
                    context: context,
                    viewModel: viewModel,
                    modularRackViewModel: modularRackViewModel,
                    mediaVaultViewModel: mediaVaultViewModel,
                    onNavigateToTab: (tab) => navigatedTab = tab,
                    onOpenInstrumentSelector: () {},
                    onToggleSidebar: () {},
                    onToggleDualSplit: () {},
                    onToggleTerminal: () {},
                    onOpenShortcutsGuide: () {},
                    onOpenMasterConsole: () {},
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        final commandIds = commands.map((c) => c.id).toSet();
        expect(commandIds, contains('open_harmonic_tutor'));
        expect(commandIds, contains('set_a4_432'));
        expect(commandIds, contains('set_a4_440'));
        expect(commandIds, contains('set_a4_442'));

        final tutorCmd = commands.firstWhere((c) => c.id == 'open_harmonic_tutor');
        expect(tutorCmd.title, equals('Abrir Tutor Armónico (Entonación Justa & Batimentos)'));
        expect(tutorCmd.category, equals('Pedagogía & Conservatorio'));

        final a432Cmd = commands.firstWhere((c) => c.id == 'set_a4_432');
        expect(a432Cmd.title, equals('Calibrar Referencia A4 = 432 Hz'));
        expect(a432Cmd.category, equals('Afinación & DSP'));
        a432Cmd.onSelect();
        expect(viewModel.referencePitch, equals(432.0));

        final a440Cmd = commands.firstWhere((c) => c.id == 'set_a4_440');
        expect(a440Cmd.title, equals('Calibrar Referencia A4 = 440 Hz (Estándar ISO 16)'));
        expect(a440Cmd.category, equals('Afinación & DSP'));
        a440Cmd.onSelect();
        expect(viewModel.referencePitch, equals(440.0));

        final a442Cmd = commands.firstWhere((c) => c.id == 'set_a4_442');
        expect(a442Cmd.title, equals('Calibrar Referencia A4 = 442 Hz (Orquesta Sinfónica)'));
        expect(a442Cmd.category, equals('Afinación & DSP'));
        a442Cmd.onSelect();
        expect(viewModel.referencePitch, equals(442.0));

        // Verificar indexación dinámica de workspaceScores
        for (int i = 0; i < viewModel.workspaceScores.length; i++) {
          final score = viewModel.workspaceScores[i];
          final scoreCmd = commands.firstWhere((c) => c.id == 'open_project_score_$i');
          expect(scoreCmd.title, equals('Partitura del Proyecto: ${score.title}'));
          expect(scoreCmd.category, equals('Archivos & Partituras'));
        }

        // Ejecutar la primera partitura del proyecto y verificar carga + navegación al tab 4
        final firstScoreCmd = commands.firstWhere((c) => c.id == 'open_project_score_0');
        firstScoreCmd.onSelect();
        expect(viewModel.activePackage.id, equals(viewModel.workspaceScores[0].id));
        expect(navigatedTab, equals(4));

        // Ejecutar open_harmonic_tutor abre HarmonicTutorModal
        tutorCmd.onSelect();
        await tester.pumpAndSettle();
        expect(find.byType(HarmonicTutorModal), findsOneWidget);
      },
    );

    testWidgets(
      'Prueba 2: ProCommandPaletteModal renderiza píldoras de filtro por categoría, filtra por Afinación & DSP y ejecuta set_a4_442',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        expect(viewModel.referencePitch, equals(440.0));

        await tester.pumpWidget(
          ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: MaterialApp(
              home: HomeDashboardScreen(
                onNavigateToTab: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Abrir Command Palette Universal desde el trigger CTRL+K en HomeDashboardScreen
        final universalTrigger = find.byKey(const Key('home_universal_command_palette_trigger'));
        expect(universalTrigger, findsOneWidget);
        await tester.tap(universalTrigger);
        await tester.pumpAndSettle();

        expect(find.byType(ProCommandPaletteModal), findsOneWidget);
        expect(find.byKey(const Key('command_palette_shortcut_hint_badge')), findsOneWidget);
        expect(find.text('CTRL+K / CTRL+P'), findsOneWidget);

        // Verificar barra y píldoras de filtro por categoría
        expect(find.byKey(const Key('command_palette_category_filter_bar')), findsOneWidget);
        expect(find.byKey(const Key('cmd_filter_all')), findsOneWidget);
        expect(find.byKey(const Key('cmd_filter_navigation')), findsOneWidget);
        expect(find.byKey(const Key('cmd_filter_dsp')), findsOneWidget);
        expect(find.byKey(const Key('cmd_filter_scores')), findsOneWidget);
        expect(find.byKey(const Key('cmd_filter_pedagogy')), findsOneWidget);

        // Pulsar filtro de Pedagogía y verificar que aparece open_harmonic_tutor y no tab_home
        await tester.tap(find.byKey(const Key('cmd_filter_pedagogy')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('command_item_open_harmonic_tutor')), findsOneWidget);
        expect(find.byKey(const Key('command_item_tab_home')), findsNothing);

        // Pulsar filtro de Afinación & DSP y verificar filtrado
        await tester.tap(find.byKey(const Key('cmd_filter_dsp')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('command_item_open_harmonic_tutor')), findsNothing);

        // Combinar con búsqueda por texto "442" para seleccionar set_a4_442
        await tester.enterText(find.byKey(const Key('command_palette_search_input')), '442');
        await tester.pumpAndSettle();

        final a442Item = find.byKey(const Key('command_item_set_a4_442'));
        expect(a442Item, findsOneWidget);

        await tester.tap(a442Item);
        await tester.pumpAndSettle();

        expect(viewModel.referencePitch, equals(442.0));
      },
    );
  });
}
