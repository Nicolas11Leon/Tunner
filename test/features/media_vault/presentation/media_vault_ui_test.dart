import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/media_vault/data/universal_media_io_service.dart';
import 'package:tunner/features/media_vault/domain/media_asset_entity.dart';
import 'package:tunner/features/media_vault/domain/media_synergy_target.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_workspace_modal.dart';

void main() {
  group('MediaVaultWorkspaceModal UI & Drag-and-Drop Tests', () {
    testWidgets('renders vault, filters assets, and supports drag-and-drop to timeline lane',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      MediaSynergyTarget? dispatchedTarget;
      MediaAssetEntity? dispatchedAsset;

      final vm = MediaVaultViewModel(
        ioService: const UniversalMediaIoService(),
        onDispatchToTool: (asset, target) {
          dispatchedAsset = asset;
          dispatchedTarget = target;
        },
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaVaultWorkspaceModal(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('media_vault_workspace_modal')), findsOneWidget);
      expect(find.byKey(const Key('vault_asset_card_seed_house_groove')), findsOneWidget);

      // Filter by search query
      await tester.enterText(
        find.byKey(const Key('media_vault_search_field')),
        'Skyline',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_asset_card_seed_vocal_stem')), findsOneWidget);
      expect(find.byKey(const Key('vault_asset_card_seed_house_groove')), findsNothing);

      // Clear search
      await tester.enterText(
        find.byKey(const Key('media_vault_search_field')),
        '',
      );
      await tester.pumpAndSettle();

      // Drag asset from vault onto Timeline Deck A lane
      final assetFinder = find.byKey(const Key('vault_asset_card_seed_house_groove'));
      final laneFinder = find.byKey(const Key('timeline_drop_lane_track_deck_a'));
      await tester.drag(
        assetFinder,
        tester.getCenter(laneFinder) - tester.getCenter(assetFinder),
      );
      await tester.pumpAndSettle();

      expect(vm.timeline.tracks.first.clips.length, 1);
      expect(find.byKey(const Key('timeline_clip_clip_1_seed_house_groove')), findsOneWidget);

      // Drag asset onto DJ Deck A Synergy Drop Zone
      final synergyFinder = find.byKey(const Key('synergy_drop_target_djDeckA'));
      await tester.drag(
        assetFinder,
        tester.getCenter(synergyFinder) - tester.getCenter(assetFinder),
      );
      await tester.pumpAndSettle();

      expect(dispatchedTarget, MediaSynergyTarget.djDeckA);
      expect(dispatchedAsset?.id, 'seed_house_groove');

      // Export Tunner JSON bundle via menu
      await tester.tap(find.byKey(const Key('media_vault_export_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proyecto Tunner (.tunner.json)'));
      await tester.pumpAndSettle();

      expect(vm.lastExportResult?.success, isTrue);
      expect(vm.lastExportResult?.fileName, endsWith('.tunner.json'));
    });
  });
}
