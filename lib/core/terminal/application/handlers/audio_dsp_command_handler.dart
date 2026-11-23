import '../../../audio/domain/ffi/i_native_dsp_bridge.dart';
import '../../../audio/domain/i_studio_audio_engine.dart';
import '../../../audio/domain/i_studio_audio_input_engine.dart';
import '../../../audio/domain/reverb/schroeder_reverb_engine.dart';
import '../../../audio/domain/spatial/binaural_panner_engine.dart';
import '../../../audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../../../audio/infrastructure/studio_master_clock_service.dart';
import '../../../audio/infrastructure/studio_master_dsp_chain.dart';
import '../../domain/i_terminal_command_handler.dart';
import '../../domain/tunner_os_command_entity.dart';

/// Manejador modular de comandos de audio, hardware E/S, cadena DSP, reloj y espacializacion.
class AudioDspCommandHandler implements ITerminalCommandHandler {
  final IStudioAudioEngine? Function() _getOutputEngine;
  final IStudioAudioInputEngine? Function() _getInputEngine;
  final StudioAudioDeviceMatrixService? Function() _getMatrixService;
  final StudioMasterClockService? Function() _getClockService;
  final SchroederReverbEngine? Function() _getReverbEngine;
  final BinauralPannerEngine? Function() _getSpatialEngine;
  final INativeDspBridge? Function() _getNativeDspBridge;
  final StudioMasterDspChain? Function() _getMasterDspChain;

  const AudioDspCommandHandler({
    required IStudioAudioEngine? Function() getOutputEngine,
    required IStudioAudioInputEngine? Function() getInputEngine,
    required StudioAudioDeviceMatrixService? Function() getMatrixService,
    required StudioMasterClockService? Function() getClockService,
    required SchroederReverbEngine? Function() getReverbEngine,
    required BinauralPannerEngine? Function() getSpatialEngine,
    required INativeDspBridge? Function() getNativeDspBridge,
    required StudioMasterDspChain? Function() getMasterDspChain,
  })  : _getOutputEngine = getOutputEngine,
        _getInputEngine = getInputEngine,
        _getMatrixService = getMatrixService,
        _getClockService = getClockService,
        _getReverbEngine = getReverbEngine,
        _getSpatialEngine = getSpatialEngine,
        _getNativeDspBridge = getNativeDspBridge,
        _getMasterDspChain = getMasterDspChain;

  @override
  Set<String> get supportedDomains => const {
        'io',
        'dsp',
        'master',
        'eq',
        'comp',
        'route',
        'clock',
        'reverb',
        'spatial',
      };

  @override
  Future<TunnerOsCommandResult> execute(
    String domain,
    List<String> args,
    String rawCommandLine,
  ) async {
    switch (domain) {
      case 'io':
        return _handleIo(args);
      case 'dsp':
        return _handleDsp(args);
      case 'master':
        return _handleMaster(args);
      case 'eq':
        return _handleEq(args);
      case 'comp':
        return _handleComp(args);
      case 'route':
        return _handleRoute(args);
      case 'clock':
        return _handleClock(args);
      case 'reverb':
        return _handleReverb(args);
      case 'spatial':
        return _handleSpatial(args);
      default:
        return TunnerOsCommandResult.error("[ERROR] Dominio de audio no soportado: '$domain'.");
    }
  }

  Future<TunnerOsCommandResult> _handleIo(List<String> args) async {
    if (args.isEmpty) {
      return TunnerOsCommandResult.error('Sintaxis: io [list|set-input <id>]');
    }

    final inputEngine = _getInputEngine();
    final subCmd = args[0].toLowerCase();
    if (subCmd == 'list') {
      if (inputEngine == null) {
        return TunnerOsCommandResult.error(
          '[ERROR] Motor de entrada de audio no conectado al kernel. No es posible enumerar interfaces fisicas.',
        );
      }
      final devices = await inputEngine.listInputDevices();
      if (devices.isEmpty) {
        return TunnerOsCommandResult.success(
          '[WARN] No se detectaron interfaces de audio de entrada disponibles.',
        );
      }
      final buf = StringBuffer('INTERFACES DE AUDIO DETECTADAS:\n');
      for (int i = 0; i < devices.length; i++) {
        final d = devices[i];
        buf.writeln('  [${i + 1}] ID: ${d.id} | ${d.label} ${d.isDefault ? '(ACTIVO)' : ''}');
      }
      return TunnerOsCommandResult.success(buf.toString().trim());
    } else if (subCmd == 'set-input') {
      if (args.length < 2) {
        return TunnerOsCommandResult.error('Especifica el ID del dispositivo.');
      }
      if (inputEngine == null) {
        return TunnerOsCommandResult.error(
          '[ERROR] Motor de entrada de audio no conectado al kernel. No es posible cambiar la interfaz de entrada.',
        );
      }
      final devId = args[1];
      await inputEngine.setInputDevice(devId);
      return TunnerOsCommandResult.success('[OK] Interfaz de entrada cambiada a: $devId');
    }

    return TunnerOsCommandResult.error("Subcomando io desconocido: '$subCmd'");
  }

  TunnerOsCommandResult _handleDsp(List<String> args) {
    final nativeDspBridge = _getNativeDspBridge();
    final masterDspChain = _getMasterDspChain();

    if (args.isNotEmpty && args[0].toLowerCase() == 'bench') {
      int iters = 100;
      int block = 2048;
      if (args.length >= 2) {
        iters = int.tryParse(args[1]) ?? 100;
      }
      if (args.length >= 3) {
        block = int.tryParse(args[2]) ?? 2048;
      }

      final chain = masterDspChain ?? StudioMasterDspChain(bridge: nativeDspBridge);
      final res = chain.runBenchmark(iterations: iters, blockSize: block);

      final report = '''
BENCHMARK DEL MOTOR DSP (TUNNER STUDIO):
-------------------------------------------
Motor Activo          : ${res.engineName}
Aceleración Nativa    : ${res.isNative ? "SI (C99 SIMD x4)" : "NO (Pure Dart SIMD Fallback)"}
Configuración         : ${res.iterations} iteraciones x ${res.blockSize} muestras
Muestras Procesadas   : ${res.iterations * res.blockSize * 2} muestras
Tiempo Transcurrido   : ${res.elapsedMicroseconds} us
Tasa de Rendimiento   : ${res.throughputMegaSamplesPerSec.toStringAsFixed(2)} MSamples/s
Latencia por Bloque   : ${(res.elapsedMicroseconds / res.iterations).toStringAsFixed(2)} us/bloque
''';
      return TunnerOsCommandResult.success(report.trim());
    }

    final matrixService = _getMatrixService();
    final outputEngine = _getOutputEngine() ?? matrixService?.outputEngine;
    final inputEngine = _getInputEngine() ?? matrixService?.inputEngine;
    final matrix = matrixService?.matrix;

    final String audioEngineState;
    if (outputEngine != null && inputEngine != null) {
      audioEngineState = 'EN LINEA (FULL-DUPLEX)';
    } else if (outputEngine != null) {
      audioEngineState = 'EN LINEA (SOLO SALIDA)';
    } else if (inputEngine != null) {
      audioEngineState = 'EN LINEA (SOLO ENTRADA)';
    } else {
      audioEngineState = 'NO CONECTADO';
    }

    final sampleRateText = matrix != null
        ? '${(matrix.sampleRate / 1000.0).toStringAsFixed(1)} kHz (${matrix.sampleRate} Hz)'
        : 'No disponible (matriz no conectada)';
    final bufferText = matrix != null
        ? '${matrix.bufferSize} muestras (${matrix.estimatedBufferLatencyMs.toStringAsFixed(1)} ms latencia)'
        : 'No disponible (matriz no conectada)';
    final activeInputText = matrix != null ? matrix.activeInputDevice.label : 'No conectado';
    final activeOutputText = matrix != null ? matrix.activeOutputDevice.label : 'No conectado';
    final channelsText = matrix != null && matrix.channelRoutings.isNotEmpty
        ? matrix.channelRoutings.keys.join(', ')
        : 'Ninguno';
    final eqStateText = matrix != null
        ? (matrix.isEqBypassed
            ? 'BYPASS'
            : 'ACTIVO (Low ${matrix.eqLowDb.toStringAsFixed(1)} dB | Mid ${matrix.eqMidDb.toStringAsFixed(1)} dB | High ${matrix.eqHighDb.toStringAsFixed(1)} dB)')
        : 'No disponible';
    final compStateText = matrix != null
        ? (matrix.isCompBypassed
            ? 'BYPASS'
            : 'ACTIVO (Thresh ${matrix.compThresholdDb.toStringAsFixed(1)} dB | Ratio ${matrix.compRatio.toStringAsFixed(1)}:1)')
        : 'No disponible';

    final nativeEngine = nativeDspBridge != null ? nativeDspBridge.engineName : 'No Inicializado';
    final isNative = nativeDspBridge?.isNativeAvailable ?? false;

    final report = '''
ESTADO DEL MOTOR DSP CORE (TUNNER STUDIO):
-------------------------------------------
Motor de Audio        : $audioEngineState
Frecuencia Base       : $sampleRateText
Tamaño de Buffer      : $bufferText
Entrada Activa        : $activeInputText
Salida Activa         : $activeOutputText
Acelerador Nativo FFI : $nativeEngine (Nativo Activo: ${isNative ? "SI" : "NO - Fallback Activo"})
Canales de Salida     : $channelsText
EQ Maestro            : $eqStateText
Compresor Maestro     : $compStateText
''';
    return TunnerOsCommandResult.success(report.trim());
  }

  TunnerOsCommandResult _handleMaster(List<String> args) {
    final matrixService = _getMatrixService();
    if (matrixService == null) {
      return TunnerOsCommandResult.error('Matriz de hardware no conectada al kernel.');
    }
    if (args.isEmpty) {
      final m = matrixService.matrix;
      return TunnerOsCommandResult.success(
        'ESTADO MASTER: Gain: ${m.masterGainDb.toStringAsFixed(1)} dB | '
        'Mute: ${m.isMuted} | Dim: ${m.isDimmed} | Mono: ${m.isMono} | Rec: ${m.isMasterRecording}',
      );
    }
    final action = args[0].toLowerCase();
    switch (action) {
      case 'gain':
        if (args.length < 2) return TunnerOsCommandResult.error('Sintaxis: master gain <db>');
        final db = double.tryParse(args[1]);
        if (db == null) return TunnerOsCommandResult.error('Valor de dB inválido: ${args[1]}');
        matrixService.setMasterGainDb(db);
        return TunnerOsCommandResult.success(
          '[OK] Ganancia maestra establecida en ${db.toStringAsFixed(1)} dB',
        );

      case 'mute':
        matrixService.toggleMute();
        return TunnerOsCommandResult.success(
          "[OK] MUTE: ${matrixService.matrix.isMuted ? 'ACTIVADO' : 'DESACTIVADO'}",
        );

      case 'dim':
        matrixService.toggleDim();
        return TunnerOsCommandResult.success(
          "[OK] DIM (-20dB): ${matrixService.matrix.isDimmed ? 'ACTIVADO' : 'DESACTIVADO'}",
        );

      case 'mono':
        matrixService.toggleMono();
        return TunnerOsCommandResult.success(
          "[OK] MONO: ${matrixService.matrix.isMono ? 'ACTIVADO' : 'DESACTIVADO'}",
        );

      case 'rec':
        final path = 'recordings/master_mix_${DateTime.now().millisecondsSinceEpoch}.wav';
        matrixService.startMasterRecording(path);
        return TunnerOsCommandResult.success('[OK] Grabación maestra iniciada en: $path');

      case 'stop-rec':
        matrixService.stopMasterRecording();
        return TunnerOsCommandResult.success('[OK] Grabación maestra finalizada y guardada en disco.');

      default:
        return TunnerOsCommandResult.error(
          'Acción master desconocida. Opciones: gain, mute, dim, mono, rec, stop-rec',
        );
    }
  }

  TunnerOsCommandResult _handleEq(List<String> args) {
    final matrixService = _getMatrixService();
    if (matrixService == null) {
      return TunnerOsCommandResult.error('Matriz de hardware no conectada al kernel.');
    }
    if (args.isEmpty) {
      final m = matrixService.matrix;
      return TunnerOsCommandResult.success(
        'EQ MASTER: Low: ${m.eqLowDb} dB | Mid: ${m.eqMidDb} dB | High: ${m.eqHighDb} dB | Bypass: ${m.isEqBypassed}',
      );
    }
    final band = args[0].toLowerCase();
    if (band == 'bypass') {
      matrixService.toggleEqBypass();
      return TunnerOsCommandResult.success(
        "[OK] EQ Bypass: ${matrixService.matrix.isEqBypassed ? 'ACTIVADO' : 'DESACTIVADO'}",
      );
    }
    if (args.length < 2) return TunnerOsCommandResult.error('Sintaxis: eq [low|mid|high] <db>');
    final db = double.tryParse(args[1]);
    if (db == null) return TunnerOsCommandResult.error('Valor de dB inválido: ${args[1]}');

    switch (band) {
      case 'low':
        matrixService.setEqLow(db);
        return TunnerOsCommandResult.success('[OK] EQ Low Shelf (100 Hz): ${db.toStringAsFixed(1)} dB');
      case 'mid':
        matrixService.setEqMid(db);
        return TunnerOsCommandResult.success('[OK] EQ Mid Peaking (1 kHz): ${db.toStringAsFixed(1)} dB');
      case 'high':
        matrixService.setEqHigh(db);
        return TunnerOsCommandResult.success('[OK] EQ High Shelf (8 kHz): ${db.toStringAsFixed(1)} dB');
      default:
        return TunnerOsCommandResult.error('Banda desconocida: $band. Opciones: low, mid, high, bypass');
    }
  }

  TunnerOsCommandResult _handleComp(List<String> args) {
    final matrixService = _getMatrixService();
    if (matrixService == null) {
      return TunnerOsCommandResult.error('Matriz de hardware no conectada al kernel.');
    }
    if (args.isEmpty) {
      final m = matrixService.matrix;
      return TunnerOsCommandResult.success(
        'COMP MASTER: Thresh: ${m.compThresholdDb} dB | Ratio: ${m.compRatio}:1 | Bypass: ${m.isCompBypassed}',
      );
    }
    final param = args[0].toLowerCase();
    switch (param) {
      case 'thresh':
      case 'threshold':
        if (args.length < 2) return TunnerOsCommandResult.error('Sintaxis: comp thresh <db>');
        final db = double.tryParse(args[1]);
        if (db == null) return TunnerOsCommandResult.error('Valor de umbral inválido: ${args[1]}');
        matrixService.setCompThreshold(db);
        return TunnerOsCommandResult.success('[OK] Compresor Umbral: ${db.toStringAsFixed(1)} dB');

      case 'ratio':
        if (args.length < 2) return TunnerOsCommandResult.error('Sintaxis: comp ratio <valor>');
        final ratio = double.tryParse(args[1]);
        if (ratio == null) return TunnerOsCommandResult.error('Valor de ratio inválido: ${args[1]}');
        matrixService.setCompRatio(ratio);
        return TunnerOsCommandResult.success('[OK] Compresor Ratio: ${ratio.toStringAsFixed(1)}:1');

      case 'bypass':
        matrixService.toggleCompBypass();
        return TunnerOsCommandResult.success(
          "[OK] Compresor Bypass: ${matrixService.matrix.isCompBypassed ? 'ACTIVADO' : 'DESACTIVADO'}",
        );

      default:
        return TunnerOsCommandResult.error('Parámetro desconocido: $param. Opciones: thresh, ratio, bypass');
    }
  }

  TunnerOsCommandResult _handleRoute(List<String> args) {
    final matrixService = _getMatrixService();
    if (matrixService == null) {
      return TunnerOsCommandResult.error('Matriz de hardware no conectada al kernel.');
    }
    if (args.length < 2) {
      return TunnerOsCommandResult.error('Sintaxis: route <canal> <master|cue|mute>');
    }
    final channel = args[0];
    final destination = args[1].toLowerCase();
    if (!['master', 'cue', 'mute'].contains(destination)) {
      return TunnerOsCommandResult.error('Destino inválido: $destination. Opciones: master, cue, mute');
    }
    matrixService.setChannelRouting(channel, destination);
    return TunnerOsCommandResult.success("[OK] Canal '$channel' enrutado a bus '$destination'");
  }

  TunnerOsCommandResult _handleClock(List<String> args) {
    final clockService = _getClockService();
    if (clockService == null) {
      return TunnerOsCommandResult.error('Reloj maestro no conectado al kernel.');
    }
    if (args.isEmpty) {
      return TunnerOsCommandResult.success(
        'RELOJ MAESTRO: ${clockService.bpm.toStringAsFixed(1)} BPM | '
        'Compás: ${clockService.currentMeasure}:${clockService.currentBeat} | '
        'Estado: ${clockService.status.name.toUpperCase()}',
      );
    }
    final action = args[0].toLowerCase();
    switch (action) {
      case 'play':
      case 'start':
        clockService.startTransport();
        return TunnerOsCommandResult.success('[OK] Transporte global: PLAY ALL');

      case 'pause':
        clockService.pauseTransport();
        return TunnerOsCommandResult.success('[OK] Transporte global: PAUSE ALL');

      case 'stop':
        clockService.stopTransport();
        return TunnerOsCommandResult.success('[OK] Transporte global: STOP ALL');

      case 'bpm':
      case 'tempo':
        if (args.length < 2) return TunnerOsCommandResult.error('Sintaxis: clock bpm <valor>');
        final bpmVal = double.tryParse(args[1]);
        if (bpmVal == null) return TunnerOsCommandResult.error('Valor de BPM inválido: ${args[1]}');
        clockService.setBpm(bpmVal);
        return TunnerOsCommandResult.success(
          '[OK] Tempo del reloj maestro: ${bpmVal.toStringAsFixed(1)} BPM',
        );

      case 'tap':
        clockService.registerTap();
        return TunnerOsCommandResult.success(
          '[OK] Tap Tempo registrado -> ${clockService.bpm.toStringAsFixed(1)} BPM',
        );

      default:
        return TunnerOsCommandResult.error(
          'Acción de reloj desconocida. Opciones: play, pause, stop, bpm, tap',
        );
    }
  }

  TunnerOsCommandResult _handleReverb(List<String> args) {
    final reverbEngine = _getReverbEngine();
    if (reverbEngine == null) {
      return TunnerOsCommandResult.error('Reverberador no disponible en el kernel.');
    }
    if (args.isEmpty || args[0] == 'status') {
      return TunnerOsCommandResult.success('''
[ESTADO REVERBERADOR SCHROEDER-MOORER]
- Room Size: ${(reverbEngine.roomSize * 100).toStringAsFixed(1)}%
- Damping: ${(reverbEngine.damping * 100).toStringAsFixed(1)}%
- Wet Mix: ${(reverbEngine.wetMix * 100).toStringAsFixed(1)}%
- Dry Mix: ${(reverbEngine.dryMix * 100).toStringAsFixed(1)}%
- Width: ${(reverbEngine.width * 100).toStringAsFixed(1)}%
'''.trim());
    }

    final param = args[0].toLowerCase();
    if (args.length < 2) {
      return TunnerOsCommandResult.error('Sintaxis: reverb [room|damp|wet|dry|width] <valor 0.0-1.0>');
    }
    final val = double.tryParse(args[1]);
    if (val == null) {
      return TunnerOsCommandResult.error('El valor de reverberacion debe ser un numero decimal.');
    }

    switch (param) {
      case 'room':
      case 'roomsize':
        reverbEngine.roomSize = val;
        return TunnerOsCommandResult.success('[OK] Reverb Room Size fijado en: ${reverbEngine.roomSize}');
      case 'damp':
      case 'damping':
        reverbEngine.damping = val;
        return TunnerOsCommandResult.success('[OK] Reverb Damping fijado en: ${reverbEngine.damping}');
      case 'wet':
        reverbEngine.wetMix = val;
        return TunnerOsCommandResult.success('[OK] Reverb Wet Mix fijado en: ${reverbEngine.wetMix}');
      case 'dry':
        reverbEngine.dryMix = val;
        return TunnerOsCommandResult.success('[OK] Reverb Dry Mix fijado en: ${reverbEngine.dryMix}');
      case 'width':
        reverbEngine.width = val;
        return TunnerOsCommandResult.success('[OK] Reverb Width fijado en: ${reverbEngine.width}');
      default:
        return TunnerOsCommandResult.error(
          'Parametro de reverberacion no valido: $param. Opciones: room, damp, wet, dry, width, status',
        );
    }
  }

  TunnerOsCommandResult _handleSpatial(List<String> args) {
    final spatialEngine = _getSpatialEngine();
    if (spatialEngine == null) {
      return TunnerOsCommandResult.error('Motor de espacializacion binaural 3D no inicializado.');
    }

    if (args.isEmpty || args[0].toLowerCase() == 'status') {
      final coords = spatialEngine.coordinates;
      return TunnerOsCommandResult.success('''
[MATRIZ DE ESPACIALIZACION BINAURAL 3D - HRTF WOODWORTH]
- Azimut: ${coords.azimuthDegrees.toStringAsFixed(1)}°
- Elevacion: ${coords.elevationDegrees.toStringAsFixed(1)}°
- Distancia: ${coords.distanceMeters.toStringAsFixed(2)} m
- Retardo Izquierdo: ${spatialEngine.leftDelayMs.toStringAsFixed(3)} ms
- Retardo Derecho: ${spatialEngine.rightDelayMs.toStringAsFixed(3)} ms
- ITD Neto: ${spatialEngine.itdMs.toStringAsFixed(3)} ms
- Atenuacion por Distancia: ${(spatialEngine.distanceGain * 100).toStringAsFixed(1)}%
'''.trim());
    }

    final subCmd = args[0].toLowerCase();
    if (subCmd == 'reset') {
      spatialEngine.reset();
      spatialEngine.coordinates = const BinauralPannerEntity();
      return TunnerOsCommandResult.success('[OK] Coordenadas binaurales y lineas de retardo reiniciadas.');
    }

    if (args.length < 2) {
      return TunnerOsCommandResult.error(
        'Sintaxis: spatial [pan|az|elev|dist] <valor> o spatial status',
      );
    }

    final val = double.tryParse(args[1]);
    if (val == null) {
      return TunnerOsCommandResult.error('El parametro espacial debe ser un numero.');
    }

    switch (subCmd) {
      case 'pan':
      case 'az':
      case 'azimuth':
        spatialEngine.setAzimuth(val);
        return TunnerOsCommandResult.success(
          '[OK] Azimut fijado en: ${spatialEngine.coordinates.azimuthDegrees}° (ITD: ${spatialEngine.itdMs.toStringAsFixed(3)} ms)',
        );
      case 'elev':
      case 'elevation':
        spatialEngine.setElevation(val);
        return TunnerOsCommandResult.success(
          '[OK] Elevacion fijada en: ${spatialEngine.coordinates.elevationDegrees}°',
        );
      case 'dist':
      case 'distance':
        if (val <= 0.0) {
          return TunnerOsCommandResult.error('La distancia debe ser estrictamente positiva (> 0.0).');
        }
        spatialEngine.setDistance(val);
        return TunnerOsCommandResult.success(
          '[OK] Distancia fijada en: ${spatialEngine.coordinates.distanceMeters} m (Ganancia: ${(spatialEngine.distanceGain * 100).toStringAsFixed(1)}%)',
        );
      default:
        return TunnerOsCommandResult.error(
          'Comando espacial no valido: $subCmd. Opciones: status, pan, az, elev, dist, reset',
        );
    }
  }
}
