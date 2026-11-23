import 'dart:async';
import 'dart:math' as math;
import 'studio_os_audio_event.dart';
import 'studio_os_audio_kernel.dart';
import 'tunner_ast_node.dart';
import 'tunner_dsl_diagnostic.dart';

/// Excepcion controlada emitida cuando un script DSL excede los limites de
/// seguridad de ejecucion (`maxStatements` o `maxLoopDepth`).
class TunnerDslSecurityLimitException implements Exception {
  final String code;
  final String message;

  const TunnerDslSecurityLimitException({
    required this.code,
    required this.message,
  });

  TunnerDslDiagnostic toDiagnostic({int line = 1, int column = 1}) {
    return TunnerDslDiagnostic.error(
      '[$code] $message',
      line: line,
      column: column,
    );
  }

  @override
  String toString() => 'TunnerDslSecurityLimitException($code): $message';
}

/// Contexto mutable de ejecución durante la evaluación de un script Tunner DSL.
class TunnerDslExecutionContext {
  final StudioOsAudioKernel kernel;
  double currentBpm;
  double currentBeatOffset = 0.0;
  double currentTimeOffsetMs = 0.0;
  int executedStatements = 0;
  int currentLoopDepth = 0;
  final int maxStatements;
  final int maxLoopDepth;
  final List<String> warnings = [];
  final List<TunnerDslDiagnostic> diagnostics = [];
  final bool isDryRun;

  TunnerDslExecutionContext({
    required this.kernel,
    this.currentBpm = 120.0,
    this.isDryRun = false,
    this.maxStatements = TunnerDslInterpreter.defaultMaxStatements,
    this.maxLoopDepth = TunnerDslInterpreter.defaultMaxLoopDepth,
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
  final List<TunnerDslDiagnostic> diagnostics;
  final List<StudioOsAudioEvent> generatedEvents;

  const TunnerDslExecutionReport({
    required this.isSuccess,
    required this.totalStatementsExecuted,
    required this.executionTimeMicroseconds,
    this.totalScheduledDurationMs = 0,
    required this.warnings,
    this.diagnostics = const [],
    required this.generatedEvents,
  });

  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'totalStatementsExecuted': totalStatementsExecuted,
      'executionTimeMicroseconds': executionTimeMicroseconds,
      'totalScheduledDurationMs': totalScheduledDurationMs,
      'warnings': List<String>.from(warnings),
      'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
      'generatedEventsCount': generatedEvents.length,
    };
  }

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
  static const int defaultMaxStatements = 10000;
  static const int defaultMaxLoopDepth = 8;

  final StudioOsAudioKernel? defaultKernel;
  final int maxStatements;
  final int maxLoopDepth;

  TunnerDslInterpreter({
    this.defaultKernel,
    this.maxStatements = defaultMaxStatements,
    this.maxLoopDepth = defaultMaxLoopDepth,
  });

  /// Evalúa un programa AST completo y retorna su reporte de ejecución.
  Future<TunnerDslExecutionReport> interpret(
    ProgramNode program, {
    StudioOsAudioKernel? kernel,
    bool isDryRun = false,
    double initialBpm = 120.0,
    int? maxStatements,
    int? maxLoopDepth,
  }) async {
    final activeKernel = kernel ?? defaultKernel ?? StudioOsAudioKernel();
    final context = TunnerDslExecutionContext(
      kernel: activeKernel,
      currentBpm: initialBpm,
      isDryRun: isDryRun,
      maxStatements: maxStatements ?? this.maxStatements,
      maxLoopDepth: maxLoopDepth ?? this.maxLoopDepth,
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
        diagnostics: List.unmodifiable(context.diagnostics),
        generatedEvents: List.unmodifiable(newEvents),
      );
    } on TunnerDslSecurityLimitException catch (e) {
      stopwatch.stop();
      context.warnings.add(e.message);
      context.diagnostics.add(e.toDiagnostic());

      return TunnerDslExecutionReport(
        isSuccess: false,
        totalStatementsExecuted: context.executedStatements,
        executionTimeMicroseconds: stopwatch.elapsedMicroseconds,
        totalScheduledDurationMs: context.currentScheduledOffsetMs,
        warnings: List.unmodifiable(context.warnings),
        diagnostics: List.unmodifiable(context.diagnostics),
        generatedEvents: const [],
      );
    } catch (e) {
      stopwatch.stop();
      context.warnings.add('Excepción durante evaluación: $e');
      context.diagnostics.add(
        TunnerDslDiagnostic.error('Excepcion durante evaluacion: $e', line: 1, column: 1),
      );

      return TunnerDslExecutionReport(
        isSuccess: false,
        totalStatementsExecuted: context.executedStatements,
        executionTimeMicroseconds: stopwatch.elapsedMicroseconds,
        totalScheduledDurationMs: context.currentScheduledOffsetMs,
        warnings: List.unmodifiable(context.warnings),
        diagnostics: List.unmodifiable(context.diagnostics),
        generatedEvents: const [],
      );
    }
  }

  void _consumeStatementBudget(TunnerDslExecutionContext context) {
    if (context.executedStatements >= context.maxStatements) {
      throw TunnerDslSecurityLimitException(
        code: 'MAX_STATEMENTS_EXCEEDED',
        message: 'Limite global de seguridad excedido: maximo ${context.maxStatements} sentencias permitidas.',
      );
    }
    context.executedStatements++;
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
    _consumeStatementBudget(context);
    context.currentBpm = node.bpm.clamp(20.0, 360.0);
    await context.kernel.dispatchTempo(context.currentBpm);
  }

  @override
  Future<void> visitChannelDecl(
    ChannelDeclNode node,
    TunnerDslExecutionContext context,
  ) async {
    _consumeStatementBudget(context);
    await context.kernel.dispatchDeclareChannel(node.channelName);
  }

  @override
  Future<void> visitConnect(
    ConnectStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    _consumeStatementBudget(context);
    await context.kernel.dispatchConnect(node.source, node.destination);
  }

  @override
  Future<void> visitSetParam(
    SetParamStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    _consumeStatementBudget(context);
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
    _consumeStatementBudget(context);
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
    _consumeStatementBudget(context);
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
    _consumeStatementBudget(context);
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
    _consumeStatementBudget(context);
    if (context.isDryRun) return;
    await context.kernel.dispatchTransport(node.action);
  }

  @override
  Future<void> visitLoop(
    LoopStatementNode node,
    TunnerDslExecutionContext context,
  ) async {
    context.currentLoopDepth++;
    if (context.currentLoopDepth > context.maxLoopDepth) {
      context.currentLoopDepth--;
      throw TunnerDslSecurityLimitException(
        code: 'MAX_LOOP_DEPTH_EXCEEDED',
        message: 'Limite de anidamiento de bucles excedido: maximo ${context.maxLoopDepth} niveles permitidos.',
      );
    }

    try {
      final loopCount = node.count.clamp(1, 1000);
      for (var i = 0; i < loopCount; i++) {
        for (final stmt in node.body) {
          await stmt.accept(this, context);
        }
      }
    } finally {
      context.currentLoopDepth--;
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
