import 'dart:typed_data';
import '../../../audio/domain/i_studio_audio_device_matrix_service.dart';
import '../../../dsl/domain/i_synth_voice_pool_port.dart';
import '../../../dsl/domain/studio_os_audio_kernel.dart';
import '../../../dsl/domain/tunner_dsl_interpreter.dart';
import '../../../dsl/domain/tunner_dsl_parser.dart';
import '../../../dsl/domain/tunner_dsl_template_catalog.dart';
import '../../../file_system/domain/studio_file_system_node.dart';
import '../../../file_system/domain/studio_file_system_repository.dart';
import '../../domain/i_terminal_command_handler.dart';
import '../../domain/i_terminal_feature_ports.dart';
import '../../domain/tunner_os_command_entity.dart';

/// Manejador modular de comandos de sistema de archivos, proyecto, pedagogia, evaluacion vocal y DSL.
class FsWorkspaceCommandHandler implements ITerminalCommandHandler {
  final StudioFileSystemRepository? Function() _getFileSystemRepository;
  final ITerminalProjectPort? Function() _getProjectPort;
  final IStudioAudioDeviceMatrixService? Function() _getMatrixService;
  final ISynthVoicePoolPort? Function() _getSynthVoicePool;
  final ITerminalEarTrainingPort? Function() _getEarTrainingEngine;
  final ITerminalVocalPedagogyPort? Function() _getVocalEvaluator;
  final List<double> Function()? Function() _getOnReadCapturedFrequencies;
  final List<double> Function()? Function() _getOnReadCapturedAmplitudes;
  final StudioOsAudioKernel? Function() _getAudioKernel;
  final TunnerDslParser Function() _getDslParser;
  final TunnerDslInterpreter Function() _getDslInterpreter;

  const FsWorkspaceCommandHandler({
    required StudioFileSystemRepository? Function() getFileSystemRepository,
    required ITerminalProjectPort? Function() getProjectPort,
    required IStudioAudioDeviceMatrixService? Function() getMatrixService,
    required ISynthVoicePoolPort? Function() getSynthVoicePool,
    required ITerminalEarTrainingPort? Function() getEarTrainingEngine,
    required ITerminalVocalPedagogyPort? Function() getVocalEvaluator,
    required List<double> Function()? Function() getOnReadCapturedFrequencies,
    required List<double> Function()? Function() getOnReadCapturedAmplitudes,
    required StudioOsAudioKernel? Function() getAudioKernel,
    required TunnerDslParser Function() getDslParser,
    required TunnerDslInterpreter Function() getDslInterpreter,
  })  : _getFileSystemRepository = getFileSystemRepository,
        _getProjectPort = getProjectPort,
        _getMatrixService = getMatrixService,
        _getSynthVoicePool = getSynthVoicePool,
        _getEarTrainingEngine = getEarTrainingEngine,
        _getVocalEvaluator = getVocalEvaluator,
        _getOnReadCapturedFrequencies = getOnReadCapturedFrequencies,
        _getOnReadCapturedAmplitudes = getOnReadCapturedAmplitudes,
        _getAudioKernel = getAudioKernel,
        _getDslParser = getDslParser,
        _getDslInterpreter = getDslInterpreter;

  @override
  Set<String> get supportedDomains => const {
        'fs',
        'project',
        'train',
        'vocal',
        'dsl',
        'eval',
      };

  @override
  Future<TunnerOsCommandResult> execute(
    String domain,
    List<String> args,
    String rawCommandLine,
  ) async {
    switch (domain) {
      case 'fs':
        return _handleFs(args);
      case 'project':
        return _handleProject(args);
      case 'train':
        return _handleTrain(args);
      case 'vocal':
        return _handleVocal(args);
      case 'dsl':
      case 'eval':
        return _handleDsl(rawCommandLine);
      default:
        return TunnerOsCommandResult.error("[ERROR] Dominio de espacio de trabajo no soportado: '$domain'.");
    }
  }

  Future<TunnerOsCommandResult> _handleFs(List<String> args) async {
    if (args.isEmpty || args[0] == 'ls') {
      final fileSystemRepository = _getFileSystemRepository();
      if (fileSystemRepository == null) {
        return TunnerOsCommandResult.error(
          '[ERROR] Repositorio de sistema de archivos no conectado al kernel.',
        );
      }
      final root = await fileSystemRepository.loadRootWorkspace();
      final buf = StringBuffer('ARCHIVOS DEL PROYECTO ACTUAL:\n');
      if (root.children.isEmpty) {
        buf.writeln('  (espacio de trabajo vacio)');
      } else {
        void printNode(StudioFileSystemNode node, String prefix) {
          if (node is StudioFileEntity) {
            buf.writeln('  $prefix• ${node.name} [${node.fileType.name.toUpperCase()}] (${node.sizeBytes} B)');
          } else if (node is StudioFolderEntity) {
            buf.writeln('  $prefix[DIR] ${node.name}/');
            for (final child in node.children) {
              printNode(child, '$prefix  ');
            }
          }
        }

        for (final child in root.children) {
          printNode(child, '');
        }
      }
      return TunnerOsCommandResult.success(buf.toString().trim());
    }

    return TunnerOsCommandResult.error('Sintaxis: fs ls');
  }

  Future<TunnerOsCommandResult> _handleProject(List<String> args) async {
    final projectPort = _getProjectPort();
    final matrixService = _getMatrixService();
    final synthVoicePool = _getSynthVoicePool();
    final fileSystemRepository = _getFileSystemRepository();

    final sub = args.isEmpty ? 'info' : args[0].toLowerCase();
    switch (sub) {
      case 'info':
        final title = projectPort?.activeTitle ?? 'Untitled Project';
        final composer = projectPort?.activeComposer ?? 'Tunner Artist';
        final bpmVal = projectPort?.bpm ?? 120;
        final matrixInfo = matrixService != null
            ? 'Conectada (${matrixService.matrix.channelRoutings.length} canales activos)'
            : 'Desconectada';
        final synthInfo = synthVoicePool != null
            ? '${synthVoicePool.dslWaveformName} (Voces activas: ${synthVoicePool.activeVoiceCount})'
            : 'No inicializado';
        return TunnerOsCommandResult.success('''
PROYECTO ACTIVO EN TUNNER STUDIO:
- Titulo: $title
- Compositor / Autor: $composer
- Tempo Nominal: $bpmVal BPM
- Matriz de Hardware: $matrixInfo
- Sintetizador Polifonico: $synthInfo
- Contenedor Canonico: .tunner v1.0.0 (DEFLATE ZIP con SHA-256)
'''.trim());

      case 'export':
        if (projectPort == null) {
          return TunnerOsCommandResult.error(
            'No se puede exportar: Puerto de proyecto no enlazado al kernel.',
          );
        }
        final customTitle = args.length > 1 ? args.sublist(1).join(' ').replaceAll('"', '') : null;
        try {
          final bytes = projectPort.exportCurrentProjectToTunner(projectTitle: customTitle);
          final resolvedTitle = customTitle ?? projectPort.activeTitle;
          final safeSlug = resolvedTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final exportPath = 'exports/$safeSlug.tunner';
          String diskStatus = 'Memoria (sin FileSystem conectado)';
          if (fileSystemRepository != null) {
            await fileSystemRepository.saveFile(
              relativePath: exportPath,
              bytes: Uint8List.fromList(bytes),
            );
            diskStatus = exportPath;
          }
          return TunnerOsCommandResult.success('''
[OK] Proyecto exportado exitosamente a formato canonico .tunner:
- Titulo: $resolvedTitle
- Peso del archivo: ${bytes.lengthInBytes} bytes
- Destino: $diskStatus
- Integridad: Hashes SHA-256 generados y sellados en manifest.json
'''.trim());
        } catch (e) {
          return TunnerOsCommandResult.error('Fallo al exportar el proyecto .tunner: $e');
        }

      default:
        return TunnerOsCommandResult.error(
          "Subcomando project desconocido: '$sub'. Opciones validas: info, export",
        );
    }
  }

  TunnerOsCommandResult _handleTrain(List<String> args) {
    final earTrainingEngine = _getEarTrainingEngine();
    if (earTrainingEngine == null) {
      return TunnerOsCommandResult.error('Motor de entrenamiento auditivo no inicializado.');
    }

    final now = DateTime.now();

    if (args.isEmpty || args[0].toLowerCase() == 'status') {
      final all = earTrainingEngine.getAllItems(now);
      final due = earTrainingEngine.getDueItems(now);
      final avgRetention = earTrainingEngine.overallRetentionAverage(now) * 100.0;
      final mastered = all.where((i) => i.repetitions >= 3).length;

      return TunnerOsCommandResult.success('''
[ESTADO DE ENTRENAMIENTO AUDITIVO - REPETICION ESPACIADA EBBINGHAUS]
- Total de Ejercicios en Catalogo: ${all.length}
- Ejercicios Pendientes de Repaso: ${due.length}
- Retencion Cognitiva Promedio: ${avgRetention.toStringAsFixed(1)}%
- Intervalos Dominados (>= 3 repasos): $mastered / ${all.length}
'''.trim());
    }

    final subCmd = args[0].toLowerCase();
    switch (subCmd) {
      case 'review':
      case 'due':
        final due = earTrainingEngine.getDueItems(now);
        if (due.isEmpty) {
          return TunnerOsCommandResult.success(
            '[OK] No hay ejercicios pendientes de repaso. Retencion auditiva por encima del 90%.',
          );
        }
        final buffer = StringBuffer('EJERCICIOS PENDIENTES DE REPASO:\n-------------------------------\n');
        for (final item in due) {
          final ret = item.retentionPercent.toStringAsFixed(1);
          buffer.writeln(
            '- ${item.id} | ${item.name} (${item.semitones} st) | Retencion: $ret% | Estabilidad: ${item.stabilityDays.toStringAsFixed(2)}d',
          );
        }
        return TunnerOsCommandResult.success(buffer.toString().trim());

      case 'list':
        final all = earTrainingEngine.getAllItems(now);
        final buffer = StringBuffer('CATALOGO DE ENTRENAMIENTO AUDITIVO:\n----------------------------------\n');
        for (final item in all) {
          final ret = item.retentionPercent.toStringAsFixed(1);
          buffer.writeln(
            '- ${item.id.padRight(28)}: ${item.name.padRight(32)} [$ret% ret | ${item.stabilityDays.toStringAsFixed(1)}d stab | ${item.repetitions} reps]',
          );
        }
        return TunnerOsCommandResult.success(buffer.toString().trim());

      case 'answer':
      case 'submit':
        if (args.length < 3) {
          return TunnerOsCommandResult.error(
            'Sintaxis: train answer <id_ejercicio> <cents_error> [tiempo_seg] [correcto: 1|0]',
          );
        }
        final itemId = args[1];
        final cents = double.tryParse(args[2]);
        if (cents == null) {
          return TunnerOsCommandResult.error('El error en cents debe ser un numero decimal.');
        }

        final time = args.length >= 4 ? (double.tryParse(args[3]) ?? 2.0) : 2.0;
        final isCorrect = args.length >= 5
            ? (args[4] == '1' || args[4].toLowerCase() == 'true')
            : cents.abs() <= 50.0;

        try {
          final result = earTrainingEngine.submitAnswer(
            itemId,
            isCorrect: isCorrect,
            centsError: cents,
            responseTimeSeconds: time,
            timestamp: now,
          );
          return TunnerOsCommandResult.success('''
[EVALUACION PEDAGOGICA EBBINGHAUS]
- Ejercicio: ${result.updatedItem.name} (${result.updatedItem.id})
- Calificacion de Calidad: ${result.qualityGrade}/5
- Error Acustico: ${result.centsError.toStringAsFixed(1)} cents
- Tiempo de Respuesta: ${result.responseTimeSeconds.toStringAsFixed(2)} s
- Nueva Estabilidad: ${result.updatedItem.stabilityDays.toStringAsFixed(2)} dias
- Proximo Repaso: ${result.updatedItem.nextReviewDate.toIso8601String().substring(0, 16)}
- Diagnostico: ${result.cognitiveFeedback}
'''.trim());
        } catch (e) {
          return TunnerOsCommandResult.error('Error al evaluar ejercicio: ${e.toString()}');
        }

      case 'reset':
        earTrainingEngine.reset();
        return TunnerOsCommandResult.success('[OK] Catalogo de entrenamiento auditivo reiniciado al estado base.');

      default:
        return TunnerOsCommandResult.error(
          'Subcomando no valido: $subCmd. Opciones: status, review, list, answer, reset',
        );
    }
  }

  Future<TunnerOsCommandResult> _handleVocal(List<String> args) async {
    final vocalEvaluator = _getVocalEvaluator();
    if (vocalEvaluator == null) {
      return TunnerOsCommandResult.error('[ERROR] Evaluador de estabilidad vocal no inicializado.');
    }

    final onReadCapturedFrequencies = _getOnReadCapturedFrequencies();
    final onReadCapturedAmplitudes = _getOnReadCapturedAmplitudes();
    final fileSystemRepository = _getFileSystemRepository();

    if (args.isEmpty || args[0].toLowerCase() == 'eval') {
      final targetHz = args.length >= 2 ? (double.tryParse(args[1]) ?? 440.0) : 440.0;
      if (targetHz <= 0.0) {
        return TunnerOsCommandResult.error('La frecuencia target debe ser positiva.');
      }

      final capturedFreqs = onReadCapturedFrequencies?.call() ?? const <double>[];
      final capturedAmps = onReadCapturedAmplitudes?.call() ?? const <double>[];
      if (capturedFreqs.isEmpty) {
        return TunnerOsCommandResult.error(
          '[ERROR] No hay captura vocal real disponible. Activa el microfono o proporciona muestras reales antes de ejecutar vocal eval.',
        );
      }

      final freqs = List<double>.from(capturedFreqs);
      final amps = capturedAmps.length == capturedFreqs.length
          ? List<double>.from(capturedAmps)
          : List<double>.filled(freqs.length, 0.85);

      final eval = vocalEvaluator.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: targetHz,
      );

      return TunnerOsCommandResult.success('''
[INFORME DE EVALUACION VOCAL Y ESTABILIDAD ACUSTICA]
- ID Evaluacion: ${eval.evaluationId}
- Frecuencia Target: ${eval.targetFrequencyHz.toStringAsFixed(1)} Hz | Media: ${eval.measuredMeanFrequencyHz.toStringAsFixed(1)} Hz
- Desviacion Tonal: ${eval.centsDeviation.toStringAsFixed(1)} cents
- Jitter Relativo: ${eval.jitterPercent.toStringAsFixed(2)}% (Fisiologico <= 1.00%)
- Shimmer de Amplitud: ${eval.shimmerPercent.toStringAsFixed(2)}% (Fisiologico <= 3.50%)
- Tasa de Vibrato: ${eval.vibratoRateHz.toStringAsFixed(2)} Hz | Profundidad: ${eval.vibratoDepthCents.toStringAsFixed(1)} cents
- Calificacion Global: ${eval.overallScore.toStringAsFixed(1)} / 100
- Dictamen: ${eval.classificationLabel}
- Sello SHA-256: ${eval.payloadHashSha256}
'''.trim());
    }

    final subCmd = args[0].toLowerCase();
    if (subCmd == 'cert' || subCmd == 'certificate') {
      if (args.length < 2) {
        return TunnerOsCommandResult.error('Sintaxis: vocal cert <nombre_estudiante> [target_hz]');
      }

      final studentName = args[1].replaceAll('"', '');
      final targetHz = args.length >= 3 ? (double.tryParse(args[2]) ?? 440.0) : 440.0;

      final capturedFreqs = onReadCapturedFrequencies?.call() ?? const <double>[];
      final capturedAmps = onReadCapturedAmplitudes?.call() ?? const <double>[];
      if (capturedFreqs.isEmpty) {
        return TunnerOsCommandResult.error(
          '[ERROR] No hay captura vocal real disponible. No se puede emitir un certificado PDF sin muestras reales.',
        );
      }

      final freqs = List<double>.from(capturedFreqs);
      final amps = capturedAmps.length == capturedFreqs.length
          ? List<double>.from(capturedAmps)
          : List<double>.filled(freqs.length, 0.90);

      final eval = vocalEvaluator.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: targetHz,
      );

      final pdfBytes = vocalEvaluator.generateCertificatePdf(
        studentName: studentName,
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: targetHz,
      );

      final safeStudent = studentName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final certPath = 'certificates/${safeStudent}_vocal_cert.pdf';
      String savedCertStatus = 'Memoria';
      if (fileSystemRepository != null) {
        await fileSystemRepository.saveFile(
          relativePath: certPath,
          bytes: Uint8List.fromList(pdfBytes),
        );
        savedCertStatus = certPath;
      }

      return TunnerOsCommandResult.success('''
[CERTIFICADO OFICIAL DE CONSERVATORIO GENERADO EXITOSAMENTE]
- Formato: Binario Vectorial PDF-1.4 (ISO 32000-1)
- Tamano del Documento: ${pdfBytes.length} bytes
- Archivo: $savedCertStatus
- Candidato: $studentName
- Calificacion: ${eval.overallScore.toStringAsFixed(1)} / 100 (${eval.classificationLabel})
- Sello Digital SHA-256 (Inmutable):
  ${eval.payloadHashSha256}
'''.trim());
    }

    return TunnerOsCommandResult.error(
      'Subcomando vocal no valido: $subCmd. Opciones: eval [target_hz], cert <nombre> [target_hz]',
    );
  }

  Future<TunnerOsCommandResult> _handleDsl(String rawCommandLine) async {
    final firstSpace = rawCommandLine.indexOf(' ');
    if (firstSpace == -1 || firstSpace == rawCommandLine.length - 1) {
      final singleWord = rawCommandLine.trim().toLowerCase();
      if (singleWord == 'dsl' || singleWord == 'eval') {
        return TunnerOsCommandResult.error(
          'Sintaxis: dsl <script> o eval <script> (o dsl list | dsl load <plantilla>). Ejemplo: dsl tempo 128; note C4 1/4;',
        );
      }
    }
    final script = rawCommandLine.substring(firstSpace + 1).trim();
    if (script.isEmpty) {
      return TunnerOsCommandResult.error('El script DSL no puede estar vacio.');
    }

    final lowerScript = script.toLowerCase();

    if (lowerScript == 'list' || lowerScript == 'templates') {
      final buffer = StringBuffer();
      buffer.writeln('[BIBLIOTECA CANONICA DE PLANTILLAS TUNNER DSL]');
      buffer.writeln('--------------------------------------------------');
      for (final t in TunnerDslTemplateCatalog.allTemplates) {
        buffer.writeln('ID         : ${t.id}');
        buffer.writeln('Titulo     : ${t.title}');
        buffer.writeln('Categoria  : ${t.category}');
        buffer.writeln('Tempo      : ${t.defaultBpm.toInt()} BPM');
        buffer.writeln('Activo     : ${t.assetPath}');
        buffer.writeln('Descripcion: ${t.description}');
        buffer.writeln('Comando    : dsl load ${t.id}');
        buffer.writeln();
      }
      buffer.write("Escribe 'dsl load <id>' para compilar y ejecutar una plantilla.");
      return TunnerOsCommandResult.success(buffer.toString().trim());
    }

    if (lowerScript.startsWith('load ') || lowerScript == 'load') {
      final parts = script.split(RegExp(r'\s+'));
      if (parts.length < 2 || parts[1].trim().isEmpty) {
        final available = TunnerDslTemplateCatalog.allTemplates.map((t) => t.id).join(', ');
        return TunnerOsCommandResult.error(
          'Sintaxis: dsl load <plantilla_id>. Plantillas disponibles: $available',
        );
      }
      final templateId = parts[1].trim();
      final template = TunnerDslTemplateCatalog.findById(templateId);
      if (template == null) {
        final available = TunnerDslTemplateCatalog.allTemplates.map((t) => t.id).join(', ');
        return TunnerOsCommandResult.error(
          "Plantilla '$templateId' no encontrada en el catalogo canónico. Disponibles: $available",
        );
      }
      return _executeDslScript(
        template.sourceCode,
        headerPrefix: '[PLANTILLA CARGADA: ${template.title}]',
      );
    }

    return _executeDslScript(script);
  }

  Future<TunnerOsCommandResult> _executeDslScript(
    String script, {
    String? headerPrefix,
  }) async {
    final parseResult = _getDslParser().parse(script);
    if (!parseResult.isSuccess || parseResult.program == null) {
      final errors = parseResult.diagnostics
          .map((d) => '[L${d.line}:C${d.column}] ${d.message}')
          .join('\n');
      return TunnerOsCommandResult.error(
        'Error de sintaxis en script Tunner DSL:\n$errors',
      );
    }

    final report = await _getDslInterpreter().interpret(
      parseResult.program!,
      kernel: _getAudioKernel(),
    );

    if (!report.isSuccess) {
      final warnings = report.warnings.join('\n');
      return TunnerOsCommandResult.error(
        'Fallo de evaluacion en Tunner DSL:\n$warnings',
      );
    }

    final eventSummary = report.generatedEvents.map((e) => '  - ${e.toString()}').join('\n');
    final header = headerPrefix != null ? '$headerPrefix\n' : '';
    return TunnerOsCommandResult.success('''
$header[TUNNER DSL EXECUTION REPORT]
- Sentencias procesadas: ${report.totalStatementsExecuted}
- Tiempo de evaluacion: ${report.executionTimeMicroseconds} us
- Eventos de audio despachados: ${report.generatedEvents.length}
${eventSummary.isNotEmpty ? 'Eventos despachados:\n$eventSummary' : ''}
'''.trim());
  }
}
