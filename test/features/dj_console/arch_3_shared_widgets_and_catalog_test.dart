import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/studio_composition_root.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_deck_entity.dart';
import 'package:tunner/features/dj_console/presentation/widgets/dj_hot_cue_pad_grid.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/navigation/presentation/pro_command_palette_modal.dart';
import 'package:tunner/features/navigation/presentation/studio_command_catalog_builder.dart';
import 'package:tunner/features/tuner/presentation/widgets/essential_tuner_panel.dart';

class _Arch3FakePlatformFileGateway implements IPlatformFileGateway {
  const _Arch3FakePlatformFileGateway();

  @override
  Future<String> getDocumentsDirectoryPath() async => '/tmp/tunner_arch3_docs';

  @override
  Future<String> getTemporaryDirectoryPath() async => '/tmp/tunner_arch3_temp';

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async =>
      null;

  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async =>
      '/tmp/$fileName';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCH-3 Monolithic Views Decomposition & Shared Widgets', () {
    testWidgets(
      'StudioCommandCatalogBuilder builds 33+ unique commands and dispatches navigation callbacks',
      (tester) async {
        final root = StudioCompositionRoot.create(
          platformFileGateway: const _Arch3FakePlatformFileGateway(),
        );
        final tunerVm = root.createTunerViewModel(seedDefaults: false);
        final rackVm = ModularRackViewModel();
        final vaultVm = MediaVaultViewModel();

        int? navigatedTab;
        var sidebarToggled = false;
        late List<CommandItem> commands;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                commands = StudioCommandCatalogBuilder.build(
                  context: context,
                  viewModel: tunerVm,
                  modularRackViewModel: rackVm,
                  mediaVaultViewModel: vaultVm,
                  onNavigateToTab: (tab) => navigatedTab = tab,
                  onOpenInstrumentSelector: () {},
                  onToggleSidebar: () => sidebarToggled = true,
                  onToggleDualSplit: () {},
                  onToggleTerminal: () {},
                  onOpenShortcutsGuide: () {},
                  onOpenMasterConsole: () {},
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(commands.length, greaterThanOrEqualTo(33));
        final ids = commands.map((c) => c.id).toSet();
        expect(ids.length, equals(commands.length));

        final toggleSidebarCmd =
            commands.firstWhere((c) => c.id == 'toggle_sidebar');
        toggleSidebarCmd.onSelect();
        expect(sidebarToggled, isTrue);

        final goDjCmd = commands.firstWhere((c) => c.id == 'tab_dj');
        goDjCmd.onSelect();
        expect(navigatedTab, equals(5));

        vaultVm.dispose();
        rackVm.dispose();
        tunerVm.dispose();
        root.dispose();
      },
    );

    testWidgets(
      'DjHotCuePadGrid renders 4 pads and handles tap and long-press callbacks',
      (tester) async {
        final triggered = <int>[];
        final cleared = <int>[];

        final deck = DjDeckEntity(
          deckId: 'A',
          trackTitle: 'Test Track',
          hotCues: const {0: 12000},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DjHotCuePadGrid(
                deckId: 'A',
                deck: deck,
                accentColor: Colors.cyanAccent,
                momentaryLitAction: DjAction.deckAHotCue2,
                onTriggerHotCue: triggered.add,
                onClearHotCue: cleared.add,
              ),
            ),
          ),
        );

        for (var idx = 0; idx < 4; idx++) {
          expect(find.byKey(Key('deck_A_hotcue_$idx')), findsOneWidget);
        }

        await tester.tap(find.byKey(const Key('deck_A_hotcue_1')));
        await tester.pump();
        expect(triggered, equals([1]));

        await tester.longPress(find.byKey(const Key('deck_A_hotcue_0')));
        await tester.pump();
        expect(cleared, equals([0]));
      },
    );

    testWidgets(
      'EssentialTunerPanel renders note display, mic button, and switches to Pro mode',
      (tester) async {
        final root = StudioCompositionRoot.create(
          platformFileGateway: const _Arch3FakePlatformFileGateway(),
        );
        final tunerVm = root.createTunerViewModel(seedDefaults: false);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EssentialTunerPanel(
                viewModel: tunerVm,
                palette: tunerVm.currentPalette,
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('essential_note_display')), findsOneWidget);
        expect(find.byKey(const Key('essential_mic_toggle_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('essential_switch_to_pro_card')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('essential_switch_to_pro_card')));
        await tester.pump();
        expect(tunerVm.hasTransposition, isFalse);

        tunerVm.dispose();
        root.dispose();
      },
    );
  });
}
