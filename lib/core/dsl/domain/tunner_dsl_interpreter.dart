import 'dart:async';
import 'dart:math' as math;
import 'studio_os_audio_event.dart';
import 'studio_os_audio_kernel.dart';
import 'tunner_ast_node.dart';

/// Contexto mutable de ejecución durante la evaluación de un script Tunner DSL.
class TunnerDslExecutionContext {
  final StudioOsAudioKernel kernel;
  double currentBpm;
  double currentBeatOffset = 0.0;
  double currentTimeOffsetMs = 0.0;
  int executedStatements = 0;
  final List<String> warnings = [];
  final bool isDryRun;

  TunnerDslExecutionContext({
    required this.kernel,
    this.currentBpm = 120.0,
    this.isDryRun = false,
  });

  /// Offset temporal acumulado en milisegundos desde el inicio del programa DSL.
  int get currentScheduledOffsetMs => currentTimeOffsetMs.round();
}

/// Reporte inmutable del resultado de la ejecución de un script Tunner DSL.
class TunnerDslExecutionReport {
  final bool isSuccess;
  final int totalStatementsExecuted;
  final int executionTimeMicroseconds;
  final int totalScheduledDurationMs;
  final List<String> warnings;
  final List<StudioOsAudioEvent> generatedEvents;

  const TunnerDslExecutionReport({
    required this.isSuccess,
    required this.totalStatementsExecuted,
    required this.executionTimeMicroseconds,
    this.totalScheduledDurationMs = 0,
    required this.warnings,
    required this.generatedEvents,
  });

  @override
  String toString() =>
      'TunnerDslExecutionReport(success: $isSuccess, executed: $totalStatementsExecuted, time: ${executionTimeMicroseconds}us, scheduledMs: $totalScheduledDurationMs, warnings: ${warnings.length})';
}

/// Intérprete y evaluador en caliente del Árbol de Sintaxis Abstracta (AST) de Tunner DSL.
///
/// Implementa el patrón Visitor de forma completamente no bloqueante, despachando
/// las acciones hacia el micro-kernel `StudioOsAudioKernel`.
class TunnerDslInterpreter
    implements TunnerAstVisitor<Future<void>, TunnerDslExecutionContext> {
  final StudioOsAudioKernel? defaultKernel;

  TunnerDslInterpreter({this.defaultKernel});

  /// Evalúa un programa AST completo y retorna su reporte de ejecución.
  Future<TunnerDslExecutionReport> interpret(
    ProgramNode program, {
    StudioOsAudioKernel? kernel,
    bool isDryRun = false,
    double initialBpm = 120.0,
  }) async {
    final activeKernel = kernel ?? defaultKernel ?? StudioOsAudioKernel();
    final context = TunnerDslExecutionContext(
      kernel: activeKernel,
      currentBpm: initialBpm,
      isDryRun: isDryRun,
    );

    final stopwatch = Stopwatch()..start();
    final eventsBefore = activeKernel.eventHistory.length;

    try {
      await program.accept(this, context);
      stopwatch.stop();

      final eventsAfter = activeKernel.eventHistory;
      final newEvents = isDryRun
          ? const <StudioOsAudioEvent>[]
          : (eventsBefore >= eventsAfter.length && eventsAfter.isNotEmpty)
              ? eventsAfter.sublist(
                  (eventsAfter.length - context.executedStatements).clamp(0, eventsAfter.length),
                )
              : eventsAfter.sublist(
                  eventsBefore.clamp(0, eventsAfter.length),
                );

      return TunnerDslExecutionReport(
        isSuccess: true,
        totalStatementsExecuted: context.executedStatements,
        executionTimeMicroseconds: stopwatch.elapsedMicroseconds,
        totalScheduledDurationMs: context.currentScheduledOffsetMs,
        warnings: List.unmodifiable(context.warnings),
        generatedEvents: List.unmodifiable(newEvents),
      );
    } catch (e) {
      stopwatch.stop();
      context.warnings.add('Excepción durante evaluación: $e');

      return TunnerDslExecutionReport(
        isSuccess: false,
        totalStatementsExecuted: context.executedStatements,
        executionTimeMicroseconds: stopwatch.elapsedMicroseconds,
        totalScheduledDurationMs: context.currentScheduledOffsetMs,
        warnings: List.unmodifiable(context.warnings),
        generatedEvents: const [],
      );
    }
  }

  @override
  Future<void> visitProgram(
    ProgramNode node,
    TunnerDslExecutionContext context,
  ) async {
    for (final statement in node.statements) {
      await statement.accept(this, context);
    }
  }

  @override
  Future<void> visitTempo(
    TempoStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.currentBpm = node.bpm.clamp(20.0, 360.0);
    context.executedStatements++;
    await context.kernel.dispatchTempo(context.currentBpm);
  }

  @override
  Future<void> visitChannelDecl(
    ChannelDeclNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.executedStatements++;
    await context.kernel.dispatchDeclareChannel(node.channelName);
  }

  @override
  Future<void> visitConnect(
    ConnectStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.executedStatements++;
    await context.kernel.dispatchConnect(node.source, node.destination);
  }

  @override
  Future<void> visitSetParam(
    SetParamStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.executedStatements++;
    await context.kernel.dispatchSetParameter(
      node.target,
      node.parameter,
      node.value,
      unit: node.unit,
    );
  }

  @override
  Future<void> visitNote(
    NoteStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.executedStatements++;
    final midi = pitchToMidi(node.pitch);
    final freq = midiToFrequency(midi);
    final scheduledOffsetMs = context.currentScheduledOffsetMs;
    final beats = parseFraction(node.durationFraction) * 4.0;
    final durationMsExact = calculateDurationMs(node.durationFraction, context.currentBpm);
    final durationMs = durationMsExact.round();

    context.currentBeatOffset += beats;
    context.currentTimeOffsetMs += durationMsExact;
    if (context.isDryRun) return;

    await context.kernel.dispatchNote(
      node.pitch,
      freq,
      midi,
      node.durationFraction,
      scheduledOffsetMs: scheduledOffsetMs,
      durationMs: durationMs,
    );
  }

  @override
  Future<void> visitChord(
    ChordStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.executedStatements++;
    final midiNotes = <int>[];
    final frequencies = <double>[];

    for (final p in node.pitches) {
      final m = pitchToMidi(p);
      midiNotes.add(m);
      frequencies.add(midiToFrequency(m));
    }

    final scheduledOffsetMs = context.currentScheduledOffsetMs;
    final beats = parseFraction(node.durationFraction) * 4.0;
    final durationMsExact = calculateDurationMs(node.durationFraction, context.currentBpm);
    final durationMs = durationMsExact.round();

    context.currentBeatOffset += beats;
    context.currentTimeOffsetMs += durationMsExact;
    if (context.isDryRun) return;

    await context.kernel.dispatchChord(
      node.pitches,
      frequencies,
      midiNotes,
      node.durationFraction,
      scheduledOffsetMs: scheduledOffsetMs,
      durationMs: durationMs,
    );
  }

  @override
  Future<void> visitRest(
    RestStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.executedStatements++;
    final scheduledOffsetMs = context.currentScheduledOffsetMs;
    final beats = parseFraction(node.durationFraction) * 4.0;
    final durationMsExact = calculateDurationMs(node.durationFraction, context.currentBpm);
    final durationMs = durationMsExact.round();

    context.currentBeatOffset += beats;
    context.currentTimeOffsetMs += durationMsExact;
    if (context.isDryRun) return;

    await context.kernel.dispatchRest(
      node.durationFraction,
      scheduledOffsetMs: scheduledOffsetMs,
      durationMs: durationMs,
    );
  }

  @override
  Future<void> visitTransport(
    TransportStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.executedStatements++;
    if (context.isDryRun) return;
    await context.kernel.dispatchTransport(node.action);
  }

  @override
  Future<void> visitLoop(
    LoopStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    final loopCount = node.count.clamp(1, 1000);
    for (var i = 0; i < loopCount; i++) {
      for (final stmt in node.body) {
        await stmt.accept(this, context);
      }
    }
  }

  /// Convierte una cadena de nota científica o solfeo (ej. 'C4', 'A#4', 'Eb5', 'Do4', 'Sol#4') a número MIDI (0-127).
  static int pitchToMidi(String pitch) {
    if (pitch.isEmpty) return 60; // C4 default

    final trimmed = pitch.trim();
    final upper = trimmed.toUpperCase();

    const solfegeMap = {
      'SOL': 'G',
      'DO': 'C',
      'RE': 'D',
      'MI': 'E',
      'FA': 'F',
      'LA': 'A',
      'SI': 'B',
    };

    String letter = upper[0];
    int octaveIndex = 1;
    for (final entry in solfegeMap.entries) {
      if (upper.startsWith(entry.key)) {
        letter = entry.value;
        octaveIndex = entry.key.length;
        break;
      }
    }

    var accidental = 0;
    while (octaveIndex < trimmed.length) {
      final ch = trimmed[octaveIndex];
      if (ch == '#' || ch == '♯') {
        accidental++;
        octaveIndex++;
      } else if (ch == 'b' || ch == '♭' || ch == 'B') {
        accidental--;
        octaveIndex++;
      } else {
        break;
      }
    }

    var octave = 4;
    if (octaveIndex < trimmed.length) {
      octave = int.tryParse(trimmed.substring(octaveIndex)) ?? 4;
    }

    final noteMap = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };

    final semitone = (noteMap[letter] ?? 0) + accidental;
    final midi = (octave + 1) * 12 + semitone;
    return midi.clamp(0, 127);
  }

  /// Calcula la frecuencia en Hz a partir del número de nota MIDI estándar.
  /// Fórmula canónica: f = referencePitchHz * 2^((midi - 69) / 12)
  static double midiToFrequency(int midiNote, {double referencePitchHz = 440.0}) {
    final safeRef = referencePitchHz > 0.0 ? referencePitchHz : 440.0;
    return safeRef * math.pow(2.0, (midiNote - 69.0) / 12.0);
  }

  /// Convierte una fracción textual canónica (ej. '1/4', '1/8', '1/2', '1/16') a valor flotante relativo.
  static double parseFraction(String fraction) {
    final parts = fraction.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0]) ?? 1.0;
      final den = double.tryParse(parts[1]) ?? 4.0;
      if (den != 0.0) return num / den;
    }
    return double.tryParse(fraction) ?? 0.25;
  }

  /// Calcula la duración en milisegundos de una fracción rítmica en base al tempo en BPM.
  static double calculateDurationMs(String fraction, double bpm) {
    final fracVal = parseFraction(fraction);
    final beats = fracVal * 4.0;
    final msPerBeat = 60000.0 / (bpm > 0 ? bpm : 120.0);
    return beats * msPerBeat;
  }
}
