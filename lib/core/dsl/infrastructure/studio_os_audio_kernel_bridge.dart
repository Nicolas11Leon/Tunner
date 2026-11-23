import 'dart:async';
import '../../audio/domain/i_studio_audio_device_matrix_service.dart';
import '../../audio/domain/i_studio_master_clock_service.dart';
import '../../audio/domain/reverb/schroeder_reverb_engine.dart';
import '../../audio/domain/spatial/binaural_panner_engine.dart';
import '../domain/i_synth_voice_pool_port.dart';
import '../domain/studio_os_audio_event.dart';
import '../domain/studio_os_audio_kernel.dart';
import '../domain/tunner_dsl_interpreter.dart';

/// Puente de infraestructura que vincula los eventos abstractos del `StudioOsAudioKernel`
/// con los servicios de hardware, matriz de masterización, sintetizadores y reloj de Tunner.
class StudioOsAudioKernelBridge {
  final StudioOsAudioKernel kernel;
  final IStudioAudioDeviceMatrixService? matrixService;
  ISynthVoicePoolPort? synthVoicePool;
  final IStudioMasterClockService? clockService;
  void Function(int bpm)? onBpmUpdate;
  final SchroederReverbEngine? reverbEngine;
  final BinauralPannerEngine? spatialEngine;

  final Set<Timer> _activeNoteTimers = <Timer>{};
  bool _isDisposed = false;
  double _currentBpm = 120.0;

  StudioOsAudioKernelBridge({
    required this.kernel,
    this.matrixService,
    this.synthVoicePool,
    this.clockService,
    this.onBpmUpdate,
    this.reverbEngine,
    this.spatialEngine,
  }) {
    _bindHandlers();
  }

  void _bindHandlers() {
    kernel.onTempoChanged = _handleTempoChanged;
    kernel.onChannelDeclared = _handleChannelDeclared;
    kernel.onConnectionChanged = _handleConnectionChanged;
    kernel.onParameterChanged = _handleParameterChanged;
    kernel.onScheduledNoteTriggered = _handleScheduledNoteTriggered;
    kernel.onScheduledChordTriggered = _handleScheduledChordTriggered;
    kernel.onScheduledRestTriggered = _handleScheduledRestTriggered;
    kernel.onTransportChanged = _handleTransportChanged;
  }

  /// Cantidad de temporizadores DSL actualmente programados o activos.
  int get activeScheduledTimerCount => _activeNoteTimers.length;

  Future<void> _handleTempoChanged(double bpm) async {
    _currentBpm = bpm;
    clockService?.setBpm(bpm);
    onBpmUpdate?.call(bpm.round());
  }

  Future<void> _handleChannelDeclared(String channel) async {
    // Registra el canal en la matriz si tiene destino por defecto 'master'
    matrixService?.setChannelRouting(channel, 'master');
  }

  Future<void> _handleConnectionChanged(String source, String destination) async {
    // Normaliza prefijos '@'
    final cleanSource = source.replaceFirst('@', '');
    final cleanDest = destination.replaceFirst('@', '');
    matrixService?.setChannelRouting(cleanSource, cleanDest);
  }

  Future<void> _handleParameterChanged(
    String target,
    String parameter,
    dynamic value,
    String? unit,
  ) async {
    final cleanTarget = target.replaceFirst('@', '').toLowerCase();
    final cleanParam = parameter.toLowerCase();

    // 1. Modulación en Matriz Master
    if (cleanTarget == 'master') {
      if (cleanParam == 'gain') {
        if (value is num) {
          if (unit?.toLowerCase() == 'db') {
            matrixService?.setMasterGainDb(value.toDouble());
          } else {
            matrixService?.setMasterGain(value.toDouble());
          }
        }
      } else if (cleanParam == 'mute') {
        matrixService?.toggleMute();
      } else if (cleanParam == 'dim') {
        matrixService?.toggleDim();
      } else if (cleanParam == 'mono') {
        matrixService?.toggleMono();
      }
    }
    // 2. Modulación en Ecualizador
    else if (cleanTarget == 'eq') {
      final numVal = (value is num) ? value.toDouble() : 0.0;
      if (cleanParam == 'low') {
        matrixService?.setEqLow(numVal);
      } else if (cleanParam == 'mid') {
        matrixService?.setEqMid(numVal);
      } else if (cleanParam == 'high') {
        matrixService?.setEqHigh(numVal);
      } else if (cleanParam == 'bypass') {
        matrixService?.toggleEqBypass();
      }
    }
    // 3. Modulación en Compresor
    else if (cleanTarget == 'comp') {
      final numVal = (value is num) ? value.toDouble() : 0.0;
      if (cleanParam == 'threshold') {
        matrixService?.setCompThreshold(numVal);
      } else if (cleanParam == 'ratio') {
        matrixService?.setCompRatio(numVal);
      } else if (cleanParam == 'bypass') {
        matrixService?.toggleCompBypass();
      }
    }
    // 4. Modulación en Sintetizador Polifónico
    else if (cleanTarget == 'synth') {
      if (synthVoicePool != null) {
        if (cleanParam == 'waveform' || cleanParam == 'wave') {
          final waveStr = value.toString().toLowerCase().replaceAll('"', '').replaceAll("'", '');
          switch (waveStr) {
            case 'sine':
              synthVoicePool!.setDslWaveform(DslSynthWaveform.sine);
              break;
            case 'saw':
            case 'sawtooth':
              synthVoicePool!.setDslWaveform(DslSynthWaveform.sawtooth);
              break;
            case 'pulse':
            case 'square':
              synthVoicePool!.setDslWaveform(DslSynthWaveform.pulse);
              break;
            case 'triangle':
            default:
              synthVoicePool!.setDslWaveform(DslSynthWaveform.triangle);
              break;
          }
        } else if (cleanParam == 'attack') {
          final s = _normalizeTimeSeconds(value, unit);
          synthVoicePool!.attackSeconds = s;
        } else if (cleanParam == 'decay') {
          final s = _normalizeTimeSeconds(value, unit);
          synthVoicePool!.decaySeconds = s;
        } else if (cleanParam == 'sustain') {
          if (value is num) {
            synthVoicePool!.sustainLevel = value.toDouble().clamp(0.0, 1.0);
          }
        } else if (cleanParam == 'release') {
          final s = _normalizeTimeSeconds(value, unit);
          synthVoicePool!.releaseSeconds = s;
        }
      }
    }
    // 5. Modulación en Reverberador Schroeder-Moorer
    else if (cleanTarget == 'reverb') {
      if (reverbEngine != null) {
        final numVal = (value is num) ? value.toDouble() : 0.5;
        if (cleanParam == 'room' || cleanParam == 'roomsize') {
          reverbEngine!.roomSize = numVal;
        } else if (cleanParam == 'damping' || cleanParam == 'damp') {
          reverbEngine!.damping = numVal;
        } else if (cleanParam == 'wet') {
          reverbEngine!.wetMix = numVal;
        } else if (cleanParam == 'dry') {
          reverbEngine!.dryMix = numVal;
        } else if (cleanParam == 'width') {
          reverbEngine!.width = numVal;
        }
      }
    }
    // 6. Modulacion en Motor de Espacializacion Binaural 3D
    else if (cleanTarget == 'spatial' || cleanTarget == 'panner') {
      if (spatialEngine != null) {
        final numVal = (value is num) ? value.toDouble() : 0.0;
        if (cleanParam == 'azimuth' || cleanParam == 'pan') {
          spatialEngine!.setAzimuth(numVal);
        } else if (cleanParam == 'elevation') {
          spatialEngine!.setElevation(numVal);
        } else if (cleanParam == 'distance') {
          spatialEngine!.setDistance(numVal);
        }
      }
    }
  }

  Future<void> _handleScheduledNoteTriggered(StudioOsNoteEvent event) async {
    if (_isDisposed || synthVoicePool == null) return;

    final effectiveDurationMs = (event.durationMs > 0
            ? event.durationMs
            : TunnerDslInterpreter.calculateDurationMs(
                event.durationFraction,
                _currentBpm,
              ).round())
        .clamp(10, 10000);
    final offsetMs = event.scheduledOffsetMs > 0 ? event.scheduledOffsetMs : 0;

    void triggerNote() {
      if (_isDisposed || synthVoicePool == null) return;
      synthVoicePool!.noteOn(
        event.midiNote,
        event.velocity,
        frequency: event.frequencyHz,
      );

      // Liberación programada no bloqueante con rastreo determinista
      late final Timer offTimer;
      offTimer = Timer(Duration(milliseconds: effectiveDurationMs), () {
        _activeNoteTimers.remove(offTimer);
        if (!_isDisposed) {
          synthVoicePool?.noteOff(event.midiNote);
        }
      });
      _activeNoteTimers.add(offTimer);
    }

    if (offsetMs <= 0) {
      triggerNote();
    } else {
      late final Timer onTimer;
      onTimer = Timer(Duration(milliseconds: offsetMs), () {
        _activeNoteTimers.remove(onTimer);
        triggerNote();
      });
      _activeNoteTimers.add(onTimer);
    }
  }

  Future<void> _handleScheduledChordTriggered(StudioOsChordEvent event) async {
    if (_isDisposed || synthVoicePool == null) return;

    final effectiveDurationMs = (event.durationMs > 0
            ? event.durationMs
            : TunnerDslInterpreter.calculateDurationMs(
                event.durationFraction,
                _currentBpm,
              ).round())
        .clamp(10, 10000);
    final offsetMs = event.scheduledOffsetMs > 0 ? event.scheduledOffsetMs : 0;

    void triggerChord() {
      if (_isDisposed || synthVoicePool == null) return;
      for (var i = 0; i < event.midiNotes.length; i++) {
        synthVoicePool!.noteOn(
          event.midiNotes[i],
          event.velocity,
          frequency: event.frequenciesHz[i],
        );
      }

      late final Timer offTimer;
      offTimer = Timer(Duration(milliseconds: effectiveDurationMs), () {
        _activeNoteTimers.remove(offTimer);
        if (!_isDisposed) {
          for (final midi in event.midiNotes) {
            synthVoicePool?.noteOff(midi);
          }
        }
      });
      _activeNoteTimers.add(offTimer);
    }

    if (offsetMs <= 0) {
      triggerChord();
    } else {
      late final Timer onTimer;
      onTimer = Timer(Duration(milliseconds: offsetMs), () {
        _activeNoteTimers.remove(onTimer);
        triggerChord();
      });
      _activeNoteTimers.add(onTimer);
    }
  }

  Future<void> _handleScheduledRestTriggered(StudioOsRestEvent event) async {
    // El cursor temporal del intérprete ya avanzó el offset acumulado para
    // todas las notas y acordes posteriores a este silencio métrico.
  }

  void _cancelActiveNoteTimers() {
    for (final t in _activeNoteTimers) {
      t.cancel();
    }
    _activeNoteTimers.clear();
  }

  Future<void> _handleTransportChanged(String action) async {
    if (_isDisposed) return;
    switch (action.toLowerCase()) {
      case 'play':
      case 'start':
        if (clockService != null && !clockService!.isPlaying) {
          clockService!.startTransport();
        }
        break;
      case 'pause':
        if (clockService != null && clockService!.isPlaying) {
          clockService!.pauseTransport();
        }
        break;
      case 'stop':
        _cancelActiveNoteTimers();
        clockService?.stopTransport();
        synthVoicePool?.panic();
        break;
    }
  }

  /// Libera todos los temporizadores de notas DSL activos de forma determinista.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _cancelActiveNoteTimers();
  }

  double _normalizeTimeSeconds(dynamic value, String? unit) {
    final numVal = (value is num) ? value.toDouble() : 0.05;
    if (unit?.toLowerCase() == 'ms') {
      return (numVal / 1000.0).clamp(0.001, 10.0);
    }
    return numVal.clamp(0.001, 10.0);
  }
}
