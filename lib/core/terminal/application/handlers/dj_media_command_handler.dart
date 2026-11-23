import 'dart:async';
import '../../../dsl/domain/i_synth_voice_pool_port.dart';
import '../../domain/i_terminal_command_handler.dart';
import '../../domain/i_terminal_feature_ports.dart';
import '../../domain/tunner_os_command_entity.dart';

/// Manejador modular de comandos de DJ, sintetizador polifonico y reproduccion de partitura.
class DjMediaCommandHandler implements ITerminalCommandHandler {
  final void Function(String deckId, String trackTitle)? Function() _getOnDjLoadTrack;
  final void Function(String deckId)? Function() _getOnDjTogglePlay;
  final void Function(String deckId)? Function() _getOnDjPlayDeck;
  final void Function(String deckId)? Function() _getOnDjPauseDeck;
  final void Function(double val)? Function() _getOnDjSetCrossfader;
  final ISynthVoicePoolPort? Function() _getSynthVoicePool;
  final Future<void> Function(int midiNote, double velocity)? Function() _getOnTriggerSynthNote;
  final ITerminalScorePort? Function() _getScorePlaybackCoordinator;

  const DjMediaCommandHandler({
    required void Function(String deckId, String trackTitle)? Function() getOnDjLoadTrack,
    required void Function(String deckId)? Function() getOnDjTogglePlay,
    required void Function(String deckId)? Function() getOnDjPlayDeck,
    required void Function(String deckId)? Function() getOnDjPauseDeck,
    required void Function(double val)? Function() getOnDjSetCrossfader,
    required ISynthVoicePoolPort? Function() getSynthVoicePool,
    required Future<void> Function(int midiNote, double velocity)? Function() getOnTriggerSynthNote,
    required ITerminalScorePort? Function() getScorePlaybackCoordinator,
  })  : _getOnDjLoadTrack = getOnDjLoadTrack,
        _getOnDjTogglePlay = getOnDjTogglePlay,
        _getOnDjPlayDeck = getOnDjPlayDeck,
        _getOnDjPauseDeck = getOnDjPauseDeck,
        _getOnDjSetCrossfader = getOnDjSetCrossfader,
        _getSynthVoicePool = getSynthVoicePool,
        _getOnTriggerSynthNote = getOnTriggerSynthNote,
        _getScorePlaybackCoordinator = getScorePlaybackCoordinator;

  @override
  Set<String> get supportedDomains => const {
        'dj',
        'synth',
        'score',
      };

  @override
  TunnerOsCommandResult execute(
    String domain,
    List<String> args,
    String rawCommandLine,
  ) {
    switch (domain) {
      case 'dj':
        return _handleDj(args);
      case 'synth':
        return _handleSynth(args);
      case 'score':
        return _handleScore(args);
      default:
        return TunnerOsCommandResult.error("[ERROR] Dominio multimedia no soportado: '$domain'.");
    }
  }

  TunnerOsCommandResult _handleDj(List<String> args) {
    if (args.isEmpty) {
      return TunnerOsCommandResult.error('Sintaxis: dj [load|play|pause|xfader] ...');
    }

    final action = args[0].toLowerCase();
    switch (action) {
      case 'load':
        if (args.length < 3) {
          return TunnerOsCommandResult.error('Sintaxis: dj load <A|B> "<nombre_o_sintesis>"');
        }
        final onDjLoadTrack = _getOnDjLoadTrack();
        if (onDjLoadTrack == null) {
          return TunnerOsCommandResult.error(
            '[ERROR] Controlador DJ (onDjLoadTrack) no conectado al kernel.',
          );
        }
        final deck = args[1].toUpperCase();
        final track = args.sublist(2).join(' ');
        onDjLoadTrack(deck, track);
        return TunnerOsCommandResult.success("[OK] Deck $deck: Pista '$track' cargada.");

      case 'play':
        if (args.length < 2) {
          return TunnerOsCommandResult.error('Sintaxis: dj play <A|B>');
        }
        final onDjPlayDeck = _getOnDjPlayDeck();
        final onDjTogglePlay = _getOnDjTogglePlay();
        if (onDjPlayDeck == null && onDjTogglePlay == null) {
          return TunnerOsCommandResult.error(
            '[ERROR] Controlador de reproduccion DJ no conectado al kernel.',
          );
        }
        final deck = args[1].toUpperCase();
        if (onDjPlayDeck != null) {
          onDjPlayDeck(deck);
        } else {
          onDjTogglePlay!(deck);
        }
        return TunnerOsCommandResult.success('[OK] Deck $deck: Reproduccion iniciada.');

      case 'pause':
        if (args.length < 2) {
          return TunnerOsCommandResult.error('Sintaxis: dj pause <A|B>');
        }
        final onDjPauseDeck = _getOnDjPauseDeck();
        final onDjTogglePlay = _getOnDjTogglePlay();
        if (onDjPauseDeck == null && onDjTogglePlay == null) {
          return TunnerOsCommandResult.error(
            '[ERROR] Controlador de pausa DJ no conectado al kernel.',
          );
        }
        final deck = args[1].toUpperCase();
        if (onDjPauseDeck != null) {
          onDjPauseDeck(deck);
        } else {
          onDjTogglePlay!(deck);
        }
        return TunnerOsCommandResult.success('[OK] Deck $deck: Reproduccion pausada.');

      case 'xfader':
      case 'crossfader':
        if (args.length < 2) {
          return TunnerOsCommandResult.error('Sintaxis: dj xfader <valor de -1.0 a 1.0>');
        }
        final val = double.tryParse(args[1]);
        if (val == null) {
          return TunnerOsCommandResult.error('Valor numérico inválido para crossfader.');
        }
        final onDjSetCrossfader = _getOnDjSetCrossfader();
        if (onDjSetCrossfader == null) {
          return TunnerOsCommandResult.error(
            '[ERROR] Controlador de crossfader DJ (onDjSetCrossfader) no conectado al kernel.',
          );
        }
        onDjSetCrossfader(val.clamp(-1.0, 1.0));
        return TunnerOsCommandResult.success('[OK] Crossfader ajustado a ${val.toStringAsFixed(2)}.');

      default:
        return TunnerOsCommandResult.error("Acción DJ desconocida: '$action'. Usa 'help' para detalles.");
    }
  }

  TunnerOsCommandResult _handleSynth(List<String> args) {
    final synthVoicePool = _getSynthVoicePool();
    if (synthVoicePool == null) {
      return TunnerOsCommandResult.error('Sintetizador polifónico no conectado al kernel.');
    }
    if (args.isEmpty || args[0] == 'status') {
      return TunnerOsCommandResult.success(
        'SINTETIZADOR POLIFÓNICO SMuFL:\n'
        '  Forma de Onda  : ${synthVoicePool.dslWaveformName.toUpperCase()}\n'
        '  Polifonía      : ${synthVoicePool.activeVoiceCount} / ${synthVoicePool.maxPolyphony} voces activas\n'
        '  Ataque (A)     : ${(synthVoicePool.attackSeconds * 1000).round()} ms\n'
        '  Decaimiento (D): ${(synthVoicePool.decaySeconds * 1000).round()} ms\n'
        '  Sostenimiento(S: ${(synthVoicePool.sustainLevel * 100).round()}%\n'
        '  Liberación (R) : ${(synthVoicePool.releaseSeconds * 1000).round()} ms\n'
        '  Ganancia Master: ${(synthVoicePool.masterGain * 100).round()}%',
      );
    }

    final action = args[0].toLowerCase();
    switch (action) {
      case 'wave':
      case 'waveform':
        if (args.length < 2) {
          return TunnerOsCommandResult.error('Sintaxis: synth wave <sine|sawtooth|pulse|triangle>');
        }
        final rawWave = args[1].toLowerCase();
        switch (rawWave) {
          case 'sine':
          case 'seno':
            synthVoicePool.setDslWaveform(DslSynthWaveform.sine);
            break;
          case 'saw':
          case 'sawtooth':
          case 'sierra':
            synthVoicePool.setDslWaveform(DslSynthWaveform.sawtooth);
            break;
          case 'pulse':
          case 'pulso':
          case 'cuadrada':
            synthVoicePool.setDslWaveform(DslSynthWaveform.pulse);
            break;
          case 'tri':
          case 'triangle':
          case 'triangulo':
            synthVoicePool.setDslWaveform(DslSynthWaveform.triangle);
            break;
          default:
            return TunnerOsCommandResult.error(
              'Forma de onda desconocida: $rawWave. Opciones: sine, saw, pulse, tri',
            );
        }
        return TunnerOsCommandResult.success(
          '[OK] Forma de onda del sintetizador: ${synthVoicePool.dslWaveformName.toUpperCase()}',
        );

      case 'adsr':
        if (args.length < 5) {
          return TunnerOsCommandResult.error(
            'Sintaxis: synth adsr <attack_ms> <decay_ms> <sustain_0_1> <release_ms>',
          );
        }
        final a = double.tryParse(args[1]);
        final d = double.tryParse(args[2]);
        final s = double.tryParse(args[3]);
        final r = double.tryParse(args[4]);
        if (a == null || d == null || s == null || r == null) {
          return TunnerOsCommandResult.error('Valores numéricos de ADSR inválidos.');
        }
        synthVoicePool.attackSeconds = a / 1000.0;
        synthVoicePool.decaySeconds = d / 1000.0;
        synthVoicePool.sustainLevel = s;
        synthVoicePool.releaseSeconds = r / 1000.0;
        return TunnerOsCommandResult.success(
          '[OK] Envolvente ADSR configurada: ${a.round()}ms / ${d.round()}ms / ${(s * 100).round()}% / ${r.round()}ms',
        );

      case 'note':
        if (args.length < 2) {
          return TunnerOsCommandResult.error('Sintaxis: synth note <nombre_nota> [velocidad_0_1]');
        }
        final noteName = args[1];
        final vel = args.length >= 3 ? double.tryParse(args[2]) ?? 0.8 : 0.8;
        final midi = terminalNoteNameToMidi(noteName);
        if (midi < 0) {
          return TunnerOsCommandResult.error(
            "Nota musical no válida: '$noteName'. Ejemplos: Do4, C4, Mi5, Fa#4, Sol3",
          );
        }
        synthVoicePool.noteOn(midi, vel);
        final onTriggerSynthNote = _getOnTriggerSynthNote();
        if (onTriggerSynthNote != null) {
          unawaited(onTriggerSynthNote(midi, vel));
        }
        return TunnerOsCommandResult.success(
          '[OK] Disparada nota: $noteName (MIDI $midi, vel: ${(vel * 100).round()}%)',
        );

      case 'panic':
      case 'silence':
        synthVoicePool.panic();
        return TunnerOsCommandResult.success('[OK] Silenciadas todas las voces del sintetizador (PANIC)');

      default:
        return TunnerOsCommandResult.error(
          "Subcomando synth desconocido: '$action'. Opciones: status, wave, adsr, note, panic",
        );
    }
  }

  TunnerOsCommandResult _handleScore(List<String> args) {
    final scorePlaybackCoordinator = _getScorePlaybackCoordinator();
    if (scorePlaybackCoordinator == null) {
      return TunnerOsCommandResult.error('Coordinador de partitura no conectado al kernel.');
    }
    if (args.isEmpty) {
      return TunnerOsCommandResult.success(
        'REPRODUCTOR DE PARTITURA:\n'
        "  Estado : ${scorePlaybackCoordinator.isPlaying ? 'REPRODUCIENDO' : 'DETENIDO'}\n"
        '  Compás : ${scorePlaybackCoordinator.currentMeasureIndex + 1}\n'
        '  Sub-Tick: ${scorePlaybackCoordinator.currentSubTick}\n'
        '  Tempo  : ${scorePlaybackCoordinator.bpm.toStringAsFixed(1)} BPM',
      );
    }

    final action = args[0].toLowerCase();
    switch (action) {
      case 'play':
      case 'start':
        if (!scorePlaybackCoordinator.hasActiveScore) {
          return TunnerOsCommandResult.error('No hay una partitura activa para reproducir.');
        }
        scorePlaybackCoordinator.startActiveScore();
        return TunnerOsCommandResult.success('[OK] Reproducción de partitura iniciada');

      case 'pause':
        scorePlaybackCoordinator.pausePlayback();
        return TunnerOsCommandResult.success('[OK] Reproducción de partitura pausada');

      case 'stop':
        scorePlaybackCoordinator.stopPlayback();
        return TunnerOsCommandResult.success('[OK] Reproducción de partitura detenida y rebobinada');

      case 'bpm':
      case 'tempo':
        if (args.length < 2) return TunnerOsCommandResult.error('Sintaxis: score bpm <valor>');
        final bpmVal = double.tryParse(args[1]);
        if (bpmVal == null) return TunnerOsCommandResult.error('BPM inválido: ${args[1]}');
        scorePlaybackCoordinator.bpm = bpmVal;
        return TunnerOsCommandResult.success(
          '[OK] Tempo de partitura ajustado a: ${bpmVal.toStringAsFixed(1)} BPM',
        );

      default:
        return TunnerOsCommandResult.error(
          "Subcomando score desconocido: '$action'. Opciones: play, pause, stop, bpm",
        );
    }
  }
}
