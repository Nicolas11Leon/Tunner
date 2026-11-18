import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_event.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_kernel.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_interpreter.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_parser.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_template_catalog.dart';

void main() {
  group('TunnerDslTemplateCatalog Unit Tests', () {
    late TunnerDslParser parser;
    late TunnerDslInterpreter interpreter;
    late StudioOsAudioKernel audioKernel;

    setUp(() {
      parser = TunnerDslParser();
      audioKernel = StudioOsAudioKernel(maxHistoryLength: 500);
      interpreter = TunnerDslInterpreter(defaultKernel: audioKernel);
    });

    tearDown(() {
      audioKernel.dispose();
    });

    test('catalog contains all 3 canonical templates with complete metadata', () {
      final templates = TunnerDslTemplateCatalog.allTemplates;
      expect(templates.length, 3);

      final ids = templates.map((t) => t.id).toList();
      expect(ids, containsAll(['ambient_chords', 'acid_bassline', 'vocal_warmup_routine']));

      for (final template in templates) {
        expect(template.id, isNotEmpty);
        expect(template.title, isNotEmpty);
        expect(template.category, isNotEmpty);
        expect(template.defaultBpm, greaterThan(0));
        expect(template.description, isNotEmpty);
        expect(template.assetPath, isNotEmpty);
        expect(template.sourceCode, isNotEmpty);
      }
    });

    test('findById resolves case-insensitively and handles .tun extension', () {
      expect(TunnerDslTemplateCatalog.findById('ambient_chords'), isNotNull);
      expect(TunnerDslTemplateCatalog.findById('AMBIENT_CHORDS'), isNotNull);
      expect(TunnerDslTemplateCatalog.findById('ambient_chords.tun'), isNotNull);
      expect(TunnerDslTemplateCatalog.findById('acid_bassline'), isNotNull);
      expect(TunnerDslTemplateCatalog.findById('vocal_warmup_routine.tun'), isNotNull);
      expect(TunnerDslTemplateCatalog.findById('unknown_template'), isNull);
    });

    test('all catalog templates parse cleanly with 0 syntax errors or diagnostics', () {
      for (final template in TunnerDslTemplateCatalog.allTemplates) {
        final parseResult = parser.parse(template.sourceCode);
        expect(
          parseResult.isSuccess,
          isTrue,
          reason: 'Template ${template.id} syntax error: ${parseResult.diagnostics.map((d) => d.message).join(', ')}',
        );
        expect(parseResult.program, isNotNull);
        expect(parseResult.program!.statements, isNotEmpty);
      }
    });

    test('ambient_chords template evaluates and dispatches acoustic events', () async {
      final template = TunnerDslTemplateCatalog.ambientChords;
      final parseResult = parser.parse(template.sourceCode);
      expect(parseResult.isSuccess, isTrue);

      final report = await interpreter.interpret(parseResult.program!, kernel: audioKernel);
      expect(report.isSuccess, isTrue);
      expect(report.warnings, isEmpty);

      // Verifica tempo
      final tempoEvent = report.generatedEvents.whereType<StudioOsTempoEvent>().first;
      expect(tempoEvent.bpm, 72.0);

      // Verifica canal 'ambient' y conexion
      final channelEvent = report.generatedEvents.whereType<StudioOsChannelDeclaredEvent>().first;
      expect(channelEvent.channelName, 'ambient');

      // Verifica acordes despachados
      final chordEvents = report.generatedEvents.whereType<StudioOsChordEvent>().toList();
      expect(chordEvents.length, 4);
      expect(chordEvents.first.pitches, ['D3', 'F3', 'A3', 'C4', 'E4']);

      // Verifica play final
      final transportEvent = report.generatedEvents.whereType<StudioOsTransportEvent>().last;
      expect(transportEvent.action, 'play');
    });

    test('acid_bassline template evaluates 135 BPM loop and rapid synth parameters', () async {
      final template = TunnerDslTemplateCatalog.acidBassline;
      final parseResult = parser.parse(template.sourceCode);
      expect(parseResult.isSuccess, isTrue);

      final report = await interpreter.interpret(parseResult.program!, kernel: audioKernel);
      expect(report.isSuccess, isTrue);

      final tempoEvent = report.generatedEvents.whereType<StudioOsTempoEvent>().first;
      expect(tempoEvent.bpm, 135.0);

      // Verifica notas generadas por el bucle (2 iteraciones de 8 notas = 16 notas)
      final noteEvents = report.generatedEvents.whereType<StudioOsNoteEvent>().toList();
      expect(noteEvents.length, 16);
      expect(noteEvents.first.pitch, 'C2');
      expect(noteEvents[2].pitch, 'Eb2');
    });

    test('vocal_warmup_routine template executes diatonic transposed scales', () async {
      final template = TunnerDslTemplateCatalog.vocalWarmupRoutine;
      final parseResult = parser.parse(template.sourceCode);
      expect(parseResult.isSuccess, isTrue);

      final report = await interpreter.interpret(parseResult.program!, kernel: audioKernel);
      expect(report.isSuccess, isTrue);

      final tempoEvent = report.generatedEvents.whereType<StudioOsTempoEvent>().first;
      expect(tempoEvent.bpm, 96.0);

      final noteEvents = report.generatedEvents.whereType<StudioOsNoteEvent>().toList();
      expect(noteEvents.length, greaterThanOrEqualTo(20));

      final restEvents = report.generatedEvents.whereType<StudioOsRestEvent>().toList();
      expect(restEvents.length, 2);
    });

    test('physical asset files in assets/dsl/ exist and match catalog source code', () {
      for (final template in TunnerDslTemplateCatalog.allTemplates) {
        final file = File(template.assetPath);
        expect(file.existsSync(), isTrue, reason: 'Physical asset file does not exist: ${template.assetPath}');
        final contents = file.readAsStringSync();
        expect(contents.trim(), template.sourceCode.trim());
      }
    });
  });
}
