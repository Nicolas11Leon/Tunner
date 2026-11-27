import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_routing_service.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_studio_workstation_view.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_workspace_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-UX-16: Bóveda en Cabecera, Presets Rápidos de Stems y Snap de Crossfader', () {
    late StudioPatchbayRoutingService routingService;

    setUp(() {
      routingService = StudioPatchbayRoutingService();
      routingService.resetToDefaults();
    });

    tearDown(() {
      routingService.resetToDefaults();
    });

    testWidgets(
      '1. Pulsar snap A, B y Centro del crossfader posiciona exactamente en -1.0, 1.0 y 0.0',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final viewModel = DjConsoleViewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: DjStudioWorkstationView(
              viewModel: viewModel,
              initialViewMode: 'modular',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final snapA = find.byKey(const Key('dj_crossfader_snap_a'));
        final snapCenter = find.byKey(const Key('dj_crossfader_snap_center'));
        final snapB = find.byKey(const Key('dj_crossfader_snap_b'));

        expect(snapA, findsOneWidget);
        expect(snapCenter, findsOneWidget);
        expect(snapB, findsOneWidget);

        await tester.ensureVisible(snapA);
        await tester.tap(snapA);
        await tester.pumpAndSettle();
        expect(viewModel.crossfader.position, -1.0);

        await tester.ensureVisible(snapB);
        await tester.tap(snapB);
        await tester.pumpAndSettle();
        expect(viewModel.crossfader.position, 1.0);

        await tester.ensureVisible(snapCenter);
        await tester.tap(snapCenter);
        await tester.pumpAndSettle();
        expect(viewModel.crossfader.position, 0.0);
      },
    );

    testWidgets(
      '2. Presets rápidos de Stems (Acapella, Instrumental, Todos) actualizan Deck A',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final viewModel = DjConsoleViewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: DjStudioWorkstationView(
              viewModel: viewModel,
              initialViewMode: 'modular',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final acapellaA = find.byKey(const Key('dj_stem_preset_acapella_A'));
        final instrumentalA = find.byKey(const Key('dj_stem_preset_instrumental_A'));
        final allA = find.byKey(const Key('dj_stem_preset_all_A'));

        expect(acapellaA, findsOneWidget);
        expect(instrumentalA, findsOneWidget);
        expect(allA, findsOneWidget);

        await tester.ensureVisible(acapellaA);
        await tester.tap(acapellaA);
        await tester.pumpAndSettle();

        expect(viewModel.deckA.stems.isVocalMuted, isFalse);
        expect(viewModel.deckA.stems.isDrumsMuted, isTrue);
        expect(viewModel.deckA.stems.isBassMuted, isTrue);
        expect(viewModel.deckA.stems.isMelodyMuted, isTrue);

        await tester.ensureVisible(instrumentalA);
        await tester.tap(instrumentalA);
        await tester.pumpAndSettle();

        expect(viewModel.deckA.stems.isVocalMuted, isTrue);
        expect(viewModel.deckA.stems.isDrumsMuted, isFalse);
        expect(viewModel.deckA.stems.isBassMuted, isFalse);
        expect(viewModel.deckA.stems.isMelodyMuted, isFalse);

        await tester.ensureVisible(allA);
        await tester.tap(allA);
        await tester.pumpAndSettle();

        expect(viewModel.deckA.stems.isVocalMuted, isFalse);
        expect(viewModel.deckA.stems.isDrumsMuted, isFalse);
        expect(viewModel.deckA.stems.isBassMuted, isFalse);
        expect(viewModel.deckA.stems.isMelodyMuted, isFalse);
      },
    );

    testWidgets(
      '3. Botón en cabecera abre MediaVaultWorkspaceModal directamente',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final viewModel = DjConsoleViewModel();
        final vaultViewModel = MediaVaultViewModel();
        addTearDown(() {
          viewModel.dispose();
          vaultViewModel.dispose();
        });

        await tester.pumpWidget(
          ChangeNotifierProvider<MediaVaultViewModel>.value(
            value: vaultViewModel,
            child: MaterialApp(
              home: DjStudioWorkstationView(
                viewModel: viewModel,
                initialViewMode: 'modular',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final openVaultBtn = find.byKey(const Key('dj_open_media_vault_header_btn'));
        expect(openVaultBtn, findsOneWidget);
        expect(find.text('BÓVEDA / TIMELINE'), findsOneWidget);

        await tester.ensureVisible(openVaultBtn);
        await tester.tap(openVaultBtn);
        await tester.pumpAndSettle();

        expect(find.byType(MediaVaultWorkspaceModal), findsOneWidget);
        expect(find.byKey(const Key('media_vault_workspace_modal')), findsOneWidget);
        final modalWidget = tester.widget<MediaVaultWorkspaceModal>(
          find.byType(MediaVaultWorkspaceModal),
        );
        expect(modalWidget.viewModel, same(vaultViewModel));
      },
    );
  });
}
