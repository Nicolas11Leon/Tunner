import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/instrument/presentation/fretboard_tactile_widget.dart';
import 'package:tunner/features/instrument/presentation/instrument_emulation_surface_widget.dart';

void main() {
  test('US-6.4: InstrumentProfileEntity.standardInstruments expone >= 40 instrumentos incluyendo Hornbostel-Sachs', () {
    expect(InstrumentProfileEntity.standardInstruments.length, greaterThanOrEqualTo(40));
    final ids = InstrumentProfileEntity.standardInstruments.map((e) => e.id).toSet();
    expect(ids, containsAll(<String>['kora', 'sitar', 'shakuhachi', 'charango', 'cuatro']));
  });

  testWidgets('US-6.4: FretboardTactileWidget dispara f = f_open * 2^(fret/12) en trastes 1..totalFrets', (tester) async {
    double? triggeredFreq;
    const openE2 = 82.41;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FretboardTactileWidget(
            instrument: UniversalInstrumentDefinition.classicalGuitar,
            onNoteTriggered: (f) => triggeredFreq = f,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('fret_cell_0_12')));
    await tester.pump();

    expect(triggeredFreq, isNotNull);
    expect(triggeredFreq!, closeTo(openE2 * math.pow(2.0, 12 / 12.0), 0.1));
  });

  testWidgets('US-6.4: InstrumentEmulationSurfaceWidget asigna frecuencias diatonicas distintas por llave/piston', (tester) async {
    final triggered = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: InstrumentEmulationSurfaceWidget(
              instrument: UniversalInstrumentDefinition.fluteConcert,
              onFrequencyTriggered: triggered.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('acoustic_surface_btn_0')));
    await tester.tap(find.byKey(const Key('acoustic_surface_btn_1')));
    await tester.tap(find.byKey(const Key('acoustic_surface_btn_2')));
    await tester.pump();

    expect(triggered.length, 3);
    expect(triggered[0] != triggered[1], isTrue);
    expect(triggered[1] != triggered[2], isTrue);
  });
}
