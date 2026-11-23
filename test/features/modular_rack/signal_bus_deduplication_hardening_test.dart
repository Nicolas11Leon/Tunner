import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/channels/data/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/domain/studio_modular_plug.dart';
import 'package:tunner/core/channels/domain/studio_plug_type.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';

void main() {
  group('SignalBus and Patchbay Deduplication Hardening Tests', () {
    late SignalBus bus;

    setUp(() {
      bus = SignalBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('SignalBus emit delivers event to destination without duplicates', () async {
      const outPort = PortId(
        ownerModuleId: 'synth_1',
        id: 'out_audio',
        displayName: 'Audio Out',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
      );

      const inPort = PortId(
        ownerModuleId: 'fx_1',
        id: 'in_audio',
        displayName: 'Audio In',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
      );

      final connection = ModuleConnection.pointToPoint(
        source: outPort,
        destination: inPort,
      );

      bus.addConnection(connection);

      final receivedEvents = <dynamic>[];
      final subscription = bus.subscribe<Map<String, dynamic>>(inPort).listen((event) {
        receivedEvents.add(event);
      });

      bus.emit(outPort, {'sample': 0.75});
      await Future.delayed(const Duration(milliseconds: 20));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first['sample'], equals(0.75));

      await subscription.cancel();
    });

    test('SignalBus respects connection isMuted state and blocks dispatch', () async {
      const outPort = PortId(
        ownerModuleId: 'synth_2',
        id: 'out_audio',
        displayName: 'Audio Out 2',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
      );

      const inPort = PortId(
        ownerModuleId: 'fx_2',
        id: 'in_audio',
        displayName: 'Audio In 2',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
      );

      final mutedConn = ModuleConnection.pointToPoint(
        source: outPort,
        destination: inPort,
        isMuted: true,
      );

      bus.addConnection(mutedConn);

      final received = <dynamic>[];
      final subscription = bus.subscribe<String>(inPort).listen((data) {
        received.add(data);
      });

      bus.emit(outPort, 'signal_pulse');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(received, isEmpty);
      await subscription.cancel();
    });

    test('StudioPatchbayRoutingService zeroes pcmBuffer when channel is muted', () {
      final patchbay = StudioPatchbayRoutingService.isolated();

      const sourcePlug = StudioModularPlug(
        id: 'source_plug_1',
        label: 'Synthesizer Out',
        toolId: 'synth_tool',
        type: StudioPlugType.audioOutput,
      );

      const sinkPlug = StudioModularPlug(
        id: 'sink_plug_1',
        label: 'Mixer In',
        toolId: 'mixer_tool',
        type: StudioPlugType.audioInput,
      );

      patchbay.registerPlug(sourcePlug);
      patchbay.registerPlug(sinkPlug);

      final ch = patchbay.channels.first;
      patchbay.connectPlugToChannel(sourcePlug.id, ch.id);
      patchbay.connectPlugToChannel(sinkPlug.id, ch.id);

      // Mute the channel
      patchbay.toggleChannelMute(ch.id);

      Map<String, dynamic>? deliveredPayload;
      patchbay.registerSinkListener(sinkPlug.id, (sourceId, channelId, payload) {
        deliveredPayload = payload;
      });

      final rawPcm = Float32List.fromList([0.5, -0.5, 0.8]);
      patchbay.dispatchSignalFromPlug(
        sourcePlugId: sourcePlug.id,
        payload: {
          'title': 'Test Song',
          'pcmBuffer': rawPcm,
        },
      );

      expect(deliveredPayload, isNotNull);
      expect(deliveredPayload!['channelIsMuted'], isTrue);
      final deliveredPcm = deliveredPayload!['pcmBuffer'] as Float32List?;
      expect(deliveredPcm, isNotNull);
      for (final s in deliveredPcm!) {
        expect(s, equals(0.0));
      }
    });
  });
}
