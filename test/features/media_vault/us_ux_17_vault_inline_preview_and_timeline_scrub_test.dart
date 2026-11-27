import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/features/media_vault/data/universal_media_io_service.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_workspace_modal.dart';

void main() {
  group('US-UX-17: Pre-escucha inline y scrubbing de timeline', () {
    testWidgets(
      'Prueba 1: Cada activo muestra su boton de pre-escucha y alterna previewingAssetId',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final vm = MediaVaultViewModel(
          ioService: const UniversalMediaIoService(),
        );
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          StudioThemeScope(
            controller: StudioThemeController(),
            child: MaterialApp(
              home: MediaVaultWorkspaceModal(viewModel: vm),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(vm.allAssets, isNotEmpty);
        expect(vm.previewingAssetId, isNull);

        for (final asset in vm.allAssets) {
          expect(
            find.byKey(Key('vault_asset_preview_btn_${asset.id}')),
            findsOneWidget,
          );
        }

        final firstAsset = vm.allAssets.first;
        final firstBtnFinder = find.byKey(
          Key('vault_asset_preview_btn_${firstAsset.id}'),
        );

        expect(
          find.descendant(
            of: firstBtnFinder,
            matching: find.byIcon(Icons.play_circle_outline_rounded),
          ),
          findsOneWidget,
        );

        // Primer tap: inicia pre-escucha del activo
        await tester.tap(firstBtnFinder);
        await tester.pumpAndSettle();
        expect(vm.previewingAssetId, firstAsset.id);
        expect(
          find.descendant(
            of: firstBtnFinder,
            matching: find.byIcon(Icons.stop_circle_outlined),
          ),
          findsOneWidget,
        );

        // Segundo tap: detiene pre-escucha y vuelve a null
        await tester.tap(firstBtnFinder);
        await tester.pumpAndSettle();
        expect(vm.previewingAssetId, isNull);
        expect(
          find.descendant(
            of: firstBtnFinder,
            matching: find.byIcon(Icons.play_circle_outline_rounded),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Prueba 2: Tocar y arrastrar sobre la regla actualiza playheadMs instantaneamente',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final vm = MediaVaultViewModel(
          ioService: const UniversalMediaIoService(),
        );
        addTearDown(vm.dispose);

        await tester.pumpWidget(
          StudioThemeScope(
            controller: StudioThemeController(),
            child: MaterialApp(
              home: MediaVaultWorkspaceModal(viewModel: vm),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rulerFinder = find.byKey(const Key('vault_timeline_scrub_ruler'));
        expect(rulerFinder, findsOneWidget);

        for (final label in <String>['0s', '5s', '10s', '15s', '20s', '25s', '30s']) {
          expect(
            find.descendant(of: rulerFinder, matching: find.text(label)),
            findsOneWidget,
          );
        }

        expect(vm.playheadMs, 0);

        // Tap en el centro de la regla (~15000 ms)
        await tester.tap(rulerFinder);
        await tester.pumpAndSettle();
        final afterTapMs = vm.playheadMs;
        expect(afterTapMs, greaterThan(0));

        // Arrastre horizontal hacia la derecha incrementa el playheadMs
        await tester.drag(rulerFinder, const Offset(150, 0));
        await tester.pumpAndSettle();
        expect(vm.playheadMs, greaterThan(afterTapMs));

        // Limites de clamp en seekPlayheadMs
        vm.seekPlayheadMs(-500);
        expect(vm.playheadMs, 0);
        vm.seekPlayheadMs(999999);
        expect(vm.playheadMs, 600000);
      },
    );
  });
}
