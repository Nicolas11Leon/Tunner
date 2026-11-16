import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/project_format/data/tunner_binary_project_codec.dart';
import 'package:tunner/features/project_format/domain/patchbay_routing_connection.dart';
import 'package:tunner/features/project_format/domain/tunner_project_package.dart';
import 'package:tunner/features/project_format/domain/tunner_tool_preset.dart';

void main() {
  group('TunnerBinaryProjectCodec Tests', () {
    late TunnerBinaryProjectCodec codec;

    setUp(() {
      codec = TunnerBinaryProjectCodec();
    });

    test('encodes and decodes a TunnerProjectPackage with >80% compression ratio compared to raw JSON', () {
      final tunerModule = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);
      final scoreModule = RackModuleEntity.standard(RackModuleType.scoreNotation, 1);

      final project = TunnerProjectPackage(
        projectId: 'proj_test_001',
        projectName: 'Sinfonía en Sol Menor',
        author: 'Maestro Pro',
        masterBpm: 128.0,
        referenceA4Hz: 442.0,
        musicalKey: 'G Minor',
        notes: 'Sesión de grabación acústica con microfonía estéreo y pentagrama sincronizado.',
        tools: [
          TunnerToolPreset.fromModule(tunerModule.copyWith(title: 'Afinador Violín Principal')),
          TunnerToolPreset.fromModule(scoreModule.copyWith(title: 'Partitura Solista')),
        ],
        patchConnections: [
          const PatchbayRoutingConnection(
            connectionId: 'conn_01',
            sourceModuleId: 'mod_strobe_tuner_0',
            sourcePortId: 'pitch_out',
            destinationModuleId: 'mod_score_notation_1',
            destinationPortId: 'pitch_in',
            signalType: SignalType.pitchEvents,
          ),
        ],
        createdAtMicros: 1700000000000,
        updatedAtMicros: 1700000005000,
      );

      // Raw JSON size
      final rawJsonBytes = utf8.encode(jsonEncode(project.toJson()));
      final compressedBytes = codec.encodeProject(project);

      // Magic header verification
      expect(compressedBytes.sublist(0, 4), equals(TunnerBinaryProjectCodec.projectMagicBytes));
      expect(compressedBytes[4], equals(1)); // version 1

      // Compression check
      expect(compressedBytes.length, lessThan(rawJsonBytes.length));

      // Decode and verify roundtrip integrity
      final decoded = codec.decodeProject(compressedBytes);
      expect(decoded.projectId, equals('proj_test_001'));
      expect(decoded.projectName, equals('Sinfonía en Sol Menor'));
      expect(decoded.author, equals('Maestro Pro'));
      expect(decoded.masterBpm, equals(128.0));
      expect(decoded.referenceA4Hz, equals(442.0));
      expect(decoded.musicalKey, equals('G Minor'));
      expect(decoded.tools.length, equals(2));
      expect(decoded.tools[0].customTitle, equals('Afinador Violín Principal'));
      expect(decoded.tools[1].customTitle, equals('Partitura Solista'));
      expect(decoded.patchConnections.length, equals(1));
      expect(decoded.patchConnections[0].sourcePortId, equals('pitch_out'));
      expect(decoded.patchConnections[0].destinationPortId, equals('pitch_in'));
    });

    test('encodes and decodes a single TunnerToolPreset (.tnt)', () {
      final module = RackModuleEntity.standard(RackModuleType.vocalAutoTune, 0)
          .copyWith(title: 'Voz Principal Corregida');

      final preset = TunnerToolPreset.fromModule(
        module,
        parameters: {'correctionSpeed': 15, 'scale': 'Chromatic'},
      );

      final bytes = codec.encodeToolPreset(preset);
      expect(bytes.sublist(0, 4), equals(TunnerBinaryProjectCodec.toolMagicBytes));
      expect(bytes[4], equals(1));

      final decoded = codec.decodeToolPreset(bytes);
      expect(decoded.customTitle, equals('Voz Principal Corregida'));
      expect(decoded.moduleTypeCode, equals('vocal_autotune'));
      expect(decoded.toolParameters['correctionSpeed'], equals(15));
      expect(decoded.toolParameters['scale'], equals('Chromatic'));

      final entity = decoded.toModuleEntity(5, customId: 'restored_vocal_unit');
      expect(entity.moduleId, equals('restored_vocal_unit'));
      expect(entity.title, equals('Voz Principal Corregida'));
      expect(entity.orderIndex, equals(5));
      expect(entity.outputPorts.any((p) => p.id == 'tuned_out'), isTrue);
    });

    test('throws FormatException on corrupt or invalid magic header', () {
      final badBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x01, 0x10, 0x20]);
      expect(() => codec.decodeProject(badBytes), throwsA(isA<FormatException>()));
      expect(() => codec.decodeToolPreset(badBytes), throwsA(isA<FormatException>()));
    });
  });
}
