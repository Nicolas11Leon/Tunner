import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/channels/data/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/domain/studio_modular_plug.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_matrix_entity.dart';
import 'package:tunner/core/channels/domain/studio_plug_type.dart';
import 'package:tunner/core/channels/presentation/studio_channel_patchbay_bar_widget.dart';
import 'package:tunner/core/channels/presentation/studio_modular_plug_widget.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_studio_workstation_view.dart';

void main() {
  group('StudioPatchbayMatrixEntity Domain & DSP Instruction Tests', () {
    test('Connects and disconnects plugs cleanly across trunk channels', () {
      var matrix = StudioPatchbayMatrixEntity.initial();

      expect(matrix.channels.length, 4);
      expect(matrix.channels.containsKey('canal_a'), isTrue);

      const plugA = StudioModularPlug(
        id: 'plug_test_out',
        label: 'TEST OUT',
        toolId: 'tool_score',
        type: StudioPlugType.audioOutput,
      );

      matrix = matrix.registerPlug(plugA);
      expect(matrix.plugs.containsKey('plug_test_out'), isTrue);
      expect(matrix.plugs['plug_test_out']!.isConnected, isFalse);

      // Connect plug to Canal A
      matrix = matrix.connectPlug('plug_test_out', 'canal_a');
      expect(matrix.plugs['plug_test_out']!.connectedChannelId, 'canal_a');
      expect(matrix.findSourcesForChannel('canal_a').length, 1);

      // Disconnect plug
      matrix = matrix.disconnectPlug('plug_test_out');
      expect(matrix.plugs['plug_test_out']!.isConnected, isFalse);
      expect(matrix.findSourcesForChannel('canal_a').isEmpty, isTrue);
    });

    test('Compiles matrix topology to DSP opcode instruction sequence', () {
      var matrix = StudioPatchbayMatrixEntity.initial();

      const plugSource = StudioModularPlug(
        id: 'src_1',
        label: 'SRC 1',
        toolId: 'synth',
        type: StudioPlugType.audioOutput,
        connectedChannelId: 'canal_a',
      );

      const plugSink = StudioModularPlug(
        id: 'sink_1',
        label: 'SINK 1',
        toolId: 'speaker',
        type: StudioPlugType.audioInput,
        connectedChannelId: 'canal_a',
      );

      matrix = matrix.registerPlug(plugSource);
      matrix = matrix.registerPlug(plugSink);

      final instructions = matrix.toDspInstructionSequence();
      expect(instructions.isNotEmpty, isTrue);

      final hasSetGain = instructions.any((i) => i.opcode == StudioDspOpcode.setBusGain);
      final hasConnectSrc = instructions.any((i) => i.opcode == StudioDspOpcode.connectSourceToBus);
      final hasConnectSink = instructions.any((i) => i.opcode == StudioDspOpcode.connectBusToSink);

      expect(hasSetGain, isTrue);
      expect(hasConnectSrc, isTrue);
      expect(hasConnectSink, isTrue);
    });
  });

  group('StudioPatchbayRoutingService Tests', () {
    test('Routes audio signal from source plug to sink listener on same channel', () {
      final service = StudioPatchbayRoutingService();

      const sourcePlug = StudioModularPlug(
        id: 'score_out_test',
        label: 'SCORE OUT',
        toolId: 'score',
        type: StudioPlugType.audioOutput,
      );

      const sinkPlug = StudioModularPlug(
        id: 'deck_in_test',
        label: 'DECK IN',
        toolId: 'dj',
        type: StudioPlugType.audioInput,
      );

      service.registerPlug(sourcePlug);
      service.registerPlug(sinkPlug);

      service.connectPlugToChannel('score_out_test', 'canal_a');
      service.connectPlugToChannel('deck_in_test', 'canal_a');

      Map<String, dynamic>? receivedPayload;
      service.registerSinkListener('deck_in_test', (src, channel, payload) {
        receivedPayload = payload;
      });

      // Dispatch signal
      service.dispatchSignalFromPlug(
        sourcePlugId: 'score_out_test',
        payload: {'bpm': 128.0, 'title': 'Test Score'},
      );

      expect(receivedPayload, isNotNull);
      expect(receivedPayload!['bpm'], 128.0);
      expect(receivedPayload!['title'], 'Test Score');

      service.unregisterSinkListener('deck_in_test');
    });

    test('Toggles mute and gain on channel buses', () {
      final service = StudioPatchbayRoutingService();
      final initialMute = service.matrix.channels['canal_a']!.isMuted;

      service.toggleChannelMute('canal_a');
      expect(service.matrix.channels['canal_a']!.isMuted, !initialMute);

      service.setChannelGain('canal_a', 1.5);
      expect(service.matrix.channels['canal_a']!.gain, 1.5);
    });
  });

  group('Studio Modular Plugs and Workstation UI Integration Tests', () {
    testWidgets('Renders patchbay bar and connects score melody to Deck A in workstation', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final vm = DjConsoleViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: DjStudioWorkstationView(
            viewModel: vm,
            initialViewMode: 'modular',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Patchbay Bar is displayed
      expect(find.byType(StudioChannelPatchbayBarWidget), findsOneWidget);
      expect(find.text('MATRIZ PATCHBAY:'), findsOneWidget);
      expect(find.descendant(of: find.byType(StudioChannelPatchbayBarWidget), matching: find.text('CH A')), findsOneWidget);
      expect(find.descendant(of: find.byType(StudioChannelPatchbayBarWidget), matching: find.text('CH B')), findsOneWidget);

      // Verify Plugs rendered on decks
      expect(find.byType(StudioModularPlugWidget), findsNWidgets(2));

      // Tap ENVIAR PARTITURA (CH A) button
      final injectBtn = find.byKey(const Key('inject_score_melody_btn'));
      expect(injectBtn, findsOneWidget);
      await tester.ensureVisible(injectBtn);
      await tester.tap(injectBtn);
      await tester.pumpAndSettle();

      // Verify Deck A title updated to the sent score
      expect(vm.deckA.trackTitle, contains('Partitura: Sonata'));
      expect(vm.deckA.bpm, 120.0);

      vm.dispose();
    });
  });
}
