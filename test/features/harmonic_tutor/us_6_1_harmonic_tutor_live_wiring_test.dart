import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import 'package:tunner/features/navigation/presentation/tool_search_modal.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _SpyDroneSynthesizer extends NoOpAudioSynthesizerService {
  int startDroneCalls = 0;
  int stopDroneCalls = 0;
  Uint8List? lastWavBytes;

  @override
  Future<void> startDroneLoop(Uint8List wavBytes, {double volume = 0.7}) async {
    startDroneCalls++;
    lastWavBytes = wavBytes;
  }

  @override
  Future<void> stopDroneLoop() async {
    stopDroneCalls++;
  }
}

void main() {
  testWidgets('US-6.1: ToolSearchModal conecta HarmonicTutorModal a audioSynthesizer y telemetryListenable sin botones de simulacion', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize);

    final synth = _SpyDroneSynthesizer();
    final tunerVm = TunerViewModel(
      seedDefaults: false,
      audioSynthesizerService: synth,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToolSearchModal(viewModel: tunerVm),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Buscar y abrir Tutor de Entonacion Armonica
    await tester.enterText(find.byType(TextField), 'justa');
    await tester.pump(const Duration(milliseconds: 100));
    final tutorTile = find.textContaining('Justa').first;
    await tester.tap(tutorTile);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HarmonicTutorModal), findsOneWidget);
    expect(find.text('SIMULACIÓN DE PRÁCTICA AUDITIVA'), findsNothing);
    final micBtn = find.byKey(const Key('harmonic_tutor_mic_toggle_btn'));
    expect(micBtn, findsOneWidget);
    expect(find.text('Activar Mic'), findsOneWidget);

    // Pulsar boton de microfono actualiza reactivamente la etiqueta a Detener Mic y de vuelta a Activar Mic
    await tester.ensureVisible(micBtn);
    await tester.tap(micBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Detener Mic'), findsOneWidget);

    await tester.tap(micBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Activar Mic'), findsOneWidget);

    // Activar dron guia dispara audioSynthesizer.startDroneLoop con WAV real
    final droneBtn = find.byKey(const Key('toggle_harmonic_drone_btn'));
    await tester.ensureVisible(droneBtn);
    await tester.tap(droneBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(synth.startDroneCalls, 1);
    expect(synth.lastWavBytes, isNotNull);
    expect(synth.lastWavBytes!.length, greaterThan(44));

    // Telemetria de TunerViewModel actualiza el analisis en HarmonicTutorViewModel
    tunerVm.emitTelemetryForTesting(frequency: 327.0375);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Consonancia Pura (Lock)'), findsOneWidget);

    // Desactivar dron dispara stopDroneLoop
    await tester.tap(droneBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(synth.stopDroneCalls, 1);

    tunerVm.dispose();
  });
}
