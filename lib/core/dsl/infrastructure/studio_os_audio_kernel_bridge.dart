import 'dart:async';
import '../../../features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import '../../../features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import '../../../features/tuner_viewmodel.dart';
import '../../audio/domain/reverb/schroeder_reverb_engine.dart';
import '../../audio/domain/studio_master_clock_service.dart';
import '../../audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../domain/studio_os_audio_kernel.dart';
import '../domain/tunner_dsl_interpreter.dart';

/// Puente de infraestructura que vincula los eventos abstractos del `StudioOsAudioKernel`
/// con los servicios de hardware, matriz de masterización, sintetizadores y reloj de Tunner.
class StudioOsAudioKernelBridge {
  final StudioOsAudioKernel kernel;
  final StudioAudioDeviceMatrixService? matrixService;
  final PolyphonicVoicePool? synthVoicePool;
  final StudioMasterClockService? clockService;
  final TunerViewModel? viewModel;
  final SchroederReverbEngine? reverbEngine;

  double _currentBpm = 120.0;

  StudioOsAudioKernelBridge({
    required this.kernel,
    this.matrixService,
    this.synthVoicePool,
    this.clockService,
    this.viewModel,
    this.reverbEngine,
  }) {
    _bindHandlers();
  }

  void _bindHandlers() {
    kernel.onTempoChanged = _handleTempoChanged;
    kernel.onChannelDeclared = _handleChannelDeclared;
    kernel.onConnectionChanged = _handleConnectionChanged;
    kernel.onParameterChanged = _handleParameterChanged;
    kernel.onNoteTriggered = _handleNoteTriggered;
    kernel.onChordTriggered = _handleChordTriggered;
    kernel.onRestTriggered = _handleRestTriggered;
    kernel.onTransportChanged = _handleTransportChanged;
  }

  Future<void> _handleTempoChanged(double bpm) async {
    _currentBpm = bpm;
    clockService?.setBpm(bpm);
    viewModel?.updateBpm(bpm.round());
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
              synthVoicePool!.waveform = SynthWaveform.sine;
              break;
            case 'saw':
            case 'sawtooth':
              synthVoicePool!.waveform = SynthWaveform.sawtooth;
              break;
            case 'pulse':
            case 'square':
              synthVoicePool!.waveform = SynthWaveform.pulse;
              break;
            case 'triangle':
            default:
              synthVoicePool!.waveform = SynthWaveform.triangle;
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
  }

  Future<void> _handleNoteTriggered(
    String pitch,
    double frequencyHz,
    int midiNote,
    String durationFraction,
    double velocity,
  ) async {
    if (synthVoicePool == null) return;

    synthVoicePool!.noteOn(
      midiNote,
      velocity,
      frequency: frequencyHz,
    );

    final durationMs = TunnerDslInterpreter.calculateDurationMs(
      durationFraction,
      _currentBpm,
    );

    // Liberación programada no bloqueante
    Timer(Duration(milliseconds: durationMs.round().clamp(10, 10000)), () {
      synthVoicePool?.noteOff(midiNote);
    });
  }

  Future<void> _handleChordTriggered(
    List<String> pitches,
    List<double> frequenciesHz,
    List<int> midiNotes,
    String durationFraction,
    double velocity,
  ) async {
    if (synthVoicePool == null) return;

    for (var i = 0; i < midiNotes.length; i++) {
      synthVoicePool!.noteOn(
        midiNotes[i],
        velocity,
        frequency: frequenciesHz[i],
      );
    }

    final durationMs = TunnerDslInterpreter.calculateDurationMs(
      durationFraction,
      _currentBpm,
    );

    Timer(Duration(milliseconds: durationMs.round().clamp(10, 10000)), () {
      for (final midi in midiNotes) {
        synthVoicePool?.noteOff(midi);
      }
    });
  }

  Future<void> _handleRestTriggered(String durationFraction) async {
    // En ejecución en tiempo real el silencio deja que las envolventes expiren naturalmente
  }

  Future<void> _handleTransportChanged(String action) async {
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
        clockService?.stopTransport();
        synthVoicePool?.panic();
        break;
    }
  }

  double _normalizeTimeSeconds(dynamic value, String? unit) {
    final numVal = (value is num) ? value.toDouble() : 0.05;
    if (unit?.toLowerCase() == 'ms') {
      return (numVal / 1000.0).clamp(0.001, 10.0);
    }
    return numVal.clamp(0.001, 10.0);
  }
}
