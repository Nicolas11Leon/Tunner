import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/channels/data/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/domain/studio_channel_bus.dart';
import 'package:tunner/core/channels/domain/studio_modular_plug.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_matrix_entity.dart';
import 'package:tunner/core/channels/domain/studio_plug_type.dart';
import 'package:tunner/core/channels/presentation/studio_channel_modals.dart';
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

    test('Creates, renames, and removes custom named channels in matrix', () {
      var matrix = StudioPatchbayMatrixEntity.initial();

      final customBus = StudioChannelBus.createCustom(
        id: 'canal_guitar',
        name: 'Guitarra Acústica',
        shortCode: 'GUIT',
        colorHex: 0xFFFF6D00,
      );

      matrix = matrix.addChannel(customBus);
      expect(matrix.channels.containsKey('canal_guitar'), isTrue);
      expect(matrix.channels['canal_guitar']!.name, 'Guitarra Acústica');

      // Rename
      matrix = matrix.renameChannel('canal_guitar', 'Guitarra Eléctrica Lead');
      expect(matrix.channels['canal_guitar']!.name, 'Guitarra Eléctrica Lead');

      // Connect a plug
      const plug = StudioModularPlug(
        id: 'plug_gtr',
        label: 'IN GTR',
        toolId: 'tuner',
        type: StudioPlugType.audioInput,
      );
      matrix = matrix.registerPlug(plug);
      matrix = matrix.connectPlug('plug_gtr', 'canal_guitar');
      expect(matrix.plugs['plug_gtr']!.connectedChannelId, 'canal_guitar');

      // Remove channel should disconnect plug
      matrix = matrix.removeChannel('canal_guitar');
      expect(matrix.channels.containsKey('canal_guitar'), isFalse);
      expect(matrix.plugs['plug_gtr']!.isConnected, isFalse);
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
    late StudioPatchbayRoutingService service;

    setUp(() {
      service = StudioPatchbayRoutingService();
      service.resetToDefaults();
    });

    test('Routes audio signal from source plug to sink listener on same channel', () {
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

    test('Creates custom channels and supports bidirectional parameter synchronization', () {
      final customBus = service.createCustomChannel(
        name: 'Voz Principal',
        colorHex: 0xFF10B981,
      );

      expect(service.channels.any((c) => c.name == 'Voz Principal'), isTrue);

      const sinkPlug = StudioModularPlug(
        id: 'voc_sink',
        label: 'VOC IN',
        toolId: 'vocoder',
        type: StudioPlugType.audioInput,
      );
      service.registerPlug(sinkPlug);

      Map<String, dynamic>? receivedParams;
      service.registerSinkListener('voc_sink', (src, channel, payload) {
        receivedParams = payload;
      });

      // Connecting plug immediately receives existing channel parameters
      service.connectPlugToChannel('voc_sink', customBus.id);
      expect(receivedParams, isNotNull);

      // Publishing new parameters updates channel and propagates to sink
      service.publishChannelParameters(
        customBus.id,
        title: 'Toma 1 Acapella',
        bpm: 130.0,
        key: '5A',
        isPlaying: true,
      );

      expect(receivedParams!['title'], 'Toma 1 Acapella');
      expect(receivedParams!['bpm'], 130.0);
      expect(receivedParams!['key'], '5A');
      expect(receivedParams!['isPlaying'], isTrue);

      // Renaming channel updates metadata
      service.renameChannel(customBus.id, 'Voz Líder Procesada');
      final updated = service.channels.firstWhere((c) => c.id == customBus.id);
      expect(updated.name, 'Voz Líder Procesada');

      service.unregisterSinkListener('voc_sink');
    });

    test('Toggles mute and gain on channel buses', () {
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

    testWidgets('Opens modal to create a new custom channel from patchbay bar', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = StudioPatchbayRoutingService();
      service.resetToDefaults();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioChannelPatchbayBarWidget(routingService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap [NUEVO CANAL] button
      final newChannelBtn = find.byKey(const Key('create_custom_channel_btn'));
      expect(newChannelBtn, findsOneWidget);
      await tester.tap(newChannelBtn);
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.byType(StudioCreateChannelModal), findsOneWidget);
      expect(find.text('CREAR NUEVO CANAL'), findsOneWidget);

      // Enter channel name
      await tester.enterText(find.byType(TextField), 'Sintetizador Modular');
      await tester.pumpAndSettle();

      // Tap 'Crear Canal'
      await tester.tap(find.text('Crear Canal'));
      await tester.pumpAndSettle();

      // Verify new channel pill appears in bar
      expect(service.channels.any((c) => c.name == 'Sintetizador Modular'), isTrue);
      expect(find.text('Sintetizador Modular'), findsOneWidget);
    });
  });
}
