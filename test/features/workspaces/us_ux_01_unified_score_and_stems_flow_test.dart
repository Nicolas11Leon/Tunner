import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/presentation/composition_notation_workspace_view.dart';

void main() {
  group('US-UX-01: Unified Score Picker & Inline Stems / Minus-One Bar', () {
    Widget buildWorkspaceHost({
      required TunerViewModel viewModel,
      required VoidCallback onOpenLibraryModal,
    }) {
      return StudioThemeScope(
        controller: StudioThemeController(),
        child: MaterialApp(
          home: Scaffold(
            body: CompositionNotationWorkspaceView(
              viewModel: viewModel,
              palette: TunnerThemePalette.obsidianStudio,
              onOpenLibraryModal: onOpenLibraryModal,
              onOpenMixerModal: () {},
            ),
          ),
        ),
      );
    }

    SongPackage buildFourStemPackage({
      required String id,
      required String title,
      String composer = 'Estudio Tunner',
      int bpm = 110,
    }) {
      return SongPackage(
        id: id,
        title: title,
        composer: composer,
        genre: MusicGenre.contemporary,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: bpm,
        tracks: const [
          AudioTrack(
            id: 'lead',
            title: 'Lead',
            instrumentIcon: 'mic',
            volume: 0.9,
          ),
          AudioTrack(
            id: 'harmony',
            title: 'Armonía',
            instrumentIcon: 'piano',
            volume: 0.8,
          ),
          AudioTrack(
            id: 'bass',
            title: 'Bajo',
            instrumentIcon: 'music_note',
            volume: 0.85,
          ),
          AudioTrack(
            id: 'rhythm',
            title: 'Ritmo',
            instrumentIcon: 'timer',
            volume: 0.75,
          ),
        ],
        score: HierarchicalScore(
          title: title,
          baseBpm: bpm,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(
                  startTick: 0,
                  durationTicks: 4,
                  noteName: 'Do4',
                ),
                HierarchicalNote.note(
                  startTick: 4,
                  durationTicks: 4,
                  noteName: 'Mi4',
                ),
              ],
            ),
          ],
        ),
      );
    }

    testWidgets(
      'Tapping song picker opens repertoire sheet with workspaceScores/curatedLibrary, switches work, and triggers disk import',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final vm = TunerViewModel();
        final customPkg = buildFourStemPackage(
          id: 'ux01_project_song',
          title: 'Balada de Prueba UX-01',
          composer: 'Compositor Proyecto',
          bpm: 96,
        );
        final importedFromPreset = vm.importPresetToWorkspace(customPkg);

        // Select another song from curatedLibrary first so activePackage != importedFromPreset
        final initialTarget = vm.curatedLibrary.firstWhere(
          (p) => p.id != importedFromPreset.id,
        );
        vm.loadSongPackage(initialTarget);

        int openLibraryCount = 0;

        await tester.pumpWidget(
          buildWorkspaceHost(
            viewModel: vm,
            onOpenLibraryModal: () => openLibraryCount++,
          ),
        );
        await tester.pumpAndSettle();

        // Open song picker sheet from header
        expect(find.byKey(const Key('score_workspace_song_picker_btn')), findsOneWidget);
        await tester.tap(find.byKey(const Key('score_workspace_song_picker_btn')));
        await tester.pumpAndSettle();

        // Sheet displays title, disk import button, and available works without duplicate IDs
        expect(find.text('Repertorio & Obras del Proyecto'), findsOneWidget);
        expect(find.byKey(const Key('song_picker_import_from_disk_btn')), findsOneWidget);
        expect(
          find.text('Importar Audio (MP3/WAV) o Partitura del Computador...'),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('song_picker_item_${importedFromPreset.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('song_picker_item_${initialTarget.id}')),
          findsOneWidget,
        );

        // Select the project song in 1 tap
        await tester.tap(find.byKey(Key('song_picker_item_${importedFromPreset.id}')));
        await tester.pumpAndSettle();

        expect(vm.activePackage.id, equals(importedFromPreset.id));
        expect(find.text('Balada de Prueba UX-01'), findsOneWidget);
        expect(openLibraryCount, equals(0));

        // Re-open song picker and tap disk import button
        await tester.tap(find.byKey(const Key('score_workspace_song_picker_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('song_picker_import_from_disk_btn')));
        await tester.pumpAndSettle();

        expect(openLibraryCount, equals(1));
        expect(find.byKey(const Key('song_picker_import_from_disk_btn')), findsNothing);
      },
    );

    testWidgets(
      'Inline stems and Minus-One bar toggles individual stem mute and Minus-One mode without nested modals',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final vm = TunerViewModel();
        final fourStemPkg = buildFourStemPackage(
          id: 'ux01_4_stems',
          title: 'Cuarteto 4 Stems',
        );
        vm.addSongPackage(fourStemPkg);

        await tester.pumpWidget(
          buildWorkspaceHost(
            viewModel: vm,
            onOpenLibraryModal: () {},
          ),
        );
        await tester.pumpAndSettle();

        // Inline bar and all 4 stem chips + Minus-One chip are visible
        expect(find.byKey(const Key('inline_stems_minus_one_bar')), findsOneWidget);
        expect(find.byKey(const Key('inline_minus_one_toggle_chip')), findsOneWidget);
        expect(find.byKey(const Key('inline_stem_toggle_lead')), findsOneWidget);
        expect(find.byKey(const Key('inline_stem_toggle_harmony')), findsOneWidget);
        expect(find.byKey(const Key('inline_stem_toggle_bass')), findsOneWidget);
        expect(find.byKey(const Key('inline_stem_toggle_rhythm')), findsOneWidget);

        expect(find.text('Minus-One'), findsOneWidget);
        expect(find.text('Lead'), findsOneWidget);
        expect(find.text('Armonía'), findsOneWidget);
        expect(find.text('Bajo'), findsOneWidget);
        expect(find.text('Ritmo'), findsOneWidget);

        // Initially all stems unmuted and Minus-One inactive
        expect(vm.isMinusOneActive, isFalse);
        expect(
          vm.mixerConsole.stems.firstWhere((t) => t.id == 'bass').isMuted,
          isFalse,
        );

        // Tap stem chip to mute Bajo inline
        await tester.tap(find.byKey(const Key('inline_stem_toggle_bass')));
        await tester.pump();
        expect(
          vm.mixerConsole.stems.firstWhere((t) => t.id == 'bass').isMuted,
          isTrue,
        );

        // Tap again to unmute Bajo inline
        await tester.tap(find.byKey(const Key('inline_stem_toggle_bass')));
        await tester.pump();
        expect(
          vm.mixerConsole.stems.firstWhere((t) => t.id == 'bass').isMuted,
          isFalse,
        );

        // Toggle Minus-One inline
        await tester.tap(find.byKey(const Key('inline_minus_one_toggle_chip')));
        await tester.pump();
        expect(vm.isMinusOneActive, isTrue);
        expect(
          vm.mixerConsole.stems.firstWhere((t) => t.id == 'lead').isMuted,
          isTrue,
        );

        // Toggle Minus-One off inline
        await tester.tap(find.byKey(const Key('inline_minus_one_toggle_chip')));
        await tester.pump();
        expect(vm.isMinusOneActive, isFalse);
        expect(
          vm.mixerConsole.stems.firstWhere((t) => t.id == 'lead').isMuted,
          isFalse,
        );
      },
    );
  });
}
