import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/tuner/presentation/tuner_viewmodel.dart';

class _ControllableMetronomeService extends IMetronomeService {
  bool isStarted = false;
  int lastTicksPerMeasure = 16;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {
    isStarted = true;
    lastTicksPerMeasure = ticksPerMeasure;
  }

  @override
  Future<void> stop() async {
    isStarted = false;
  }

  void emitSubTick(int subTick) {
    onSubTick?.call(subTick);
  }

  void emitFullMeasure([int ticksPerMeasure = 16]) {
    for (int t = 0; t < ticksPerMeasure; t++) {
      emitSubTick(t);
    }
  }
}

void main() {
  group('US-UX-11: Ejecución Real del Bucle A-B en Transporte y Sincronía de Paleta', () {
    test(
      'Prueba 1: Con una obra de 4 compases y bucle A-B en [1, 2], tras count-in arranca en 1, avanza a 2 y hace wrap de vuelta a 1',
      () async {
        final fakeMetronome = _ControllableMetronomeService();
        final viewModel = TunerViewModel(metronomeService: fakeMetronome);

        // Cargamos una obra de 4 compases en 4/4 (16 sub-ticks por compás, 4 pulsos de count-in en ticks 0, 4, 8, 12)
        viewModel.createWorkspaceScore(
          title: 'Estudio Bucle A-B',
          bpm: 120,
          timeSignature: TimeSignature.commonTime44,
          initialMeasures: 4,
        );
        expect(viewModel.totalMeasures, equals(4));

        // Configuramos bucle A-B en índices 1 y 2 (compases 2 y 3)
        viewModel.scorePlaybackCoordinator.setMeasureLoopRange(1, 2);
        expect(viewModel.scorePlaybackCoordinator.isMeasureLoopActive, isTrue);

        // Iniciamos el transporte con count-in
        await viewModel.startSongWithCountIn();
        expect(viewModel.isCountingIn, isTrue);

        // Emitimos los 4 pulsos del count-in (en 4/4 ocurren en los sub-ticks 0, 4, 8 y 12)
        for (int t = 0; t <= 12; t++) {
          fakeMetronome.emitSubTick(t);
        }

        // Tras los 4 pulsos de count-in, el transporte debe arrancar en el compás 1 (loopStartMeasureIndex)
        expect(viewModel.isCountingIn, isFalse);
        expect(viewModel.currentMeasureIndex, equals(1));

        // Recorremos el compás 1 completo (ticks 0..15)
        fakeMetronome.emitFullMeasure(16);
        expect(viewModel.currentMeasureIndex, equals(1));

        // Al llegar al sub-tick 0 del siguiente compás, avanza al compás 2 (loopEndMeasureIndex)
        fakeMetronome.emitSubTick(0);
        expect(viewModel.currentMeasureIndex, equals(2));

        // Completamos el resto del compás 2 (ticks 1..15)
        for (int t = 1; t < 16; t++) {
          fakeMetronome.emitSubTick(t);
        }
        expect(viewModel.currentMeasureIndex, equals(2));

        // Al terminar el compás 2 y recibir subTick == 0, hace wrap de vuelta al compás 1 en lugar de avanzar al compás 3
        fakeMetronome.emitSubTick(0);
        expect(viewModel.currentMeasureIndex, equals(1));

        viewModel.dispose();
      },
    );

    test(
      'Prueba 2: setActiveStudioThemeId sincroniza automáticamente currentPalette entre skin claro (conservatory ivory) y oscuro (OLED monochrome)',
      () {
        final viewModel = TunerViewModel();

        // Por defecto inicia en paleta oscura
        expect(viewModel.currentPalette.brightness, equals(Brightness.dark));

        // Al elegir un skin claro ('skin_conservatory_ivory'), currentPalette cambia a paleta clara
        viewModel.setActiveStudioThemeId('skin_conservatory_ivory');
        expect(viewModel.activeStudioThemeId, equals('skin_conservatory_ivory'));
        expect(viewModel.currentPalette.brightness, equals(Brightness.light));
        expect(viewModel.currentPalette.isDark, isFalse);
        expect(viewModel.themeMode, equals(TunnerThemeMode.nordicFrost));

        // Al elegir un skin OLED/oscuro ('studio_oled_monochrome'), restaura la paleta oscura
        viewModel.setActiveStudioThemeId('studio_oled_monochrome');
        expect(viewModel.activeStudioThemeId, equals('studio_oled_monochrome'));
        expect(viewModel.currentPalette.brightness, equals(Brightness.dark));
        expect(viewModel.currentPalette.isDark, isTrue);
        expect(viewModel.themeMode, equals(TunnerThemeMode.obsidianStudio));

        viewModel.dispose();
      },
    );
  });
}
