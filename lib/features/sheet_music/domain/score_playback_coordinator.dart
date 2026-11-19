import 'dart:async';
import 'dart:math' as math;
import '../../audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import '../../tuner/domain/note_entity.dart';
import 'score_tree.dart';

/// Coordinador de reproducción y audición acústica entre el árbol jerárquico de partitura
/// ([HierarchicalScore]), el grupo de voces de síntesis ([PolyphonicVoicePool]) y el transporte maestro.
///
/// Responsabilidades:
/// 1. Audición Táctil Inmediata (*Tap-to-Listen*): Dispara la nota acústica con envolvente ADSR suave
///    cuando el usuario presiona o selecciona una nota en el pentagrama.
/// 2. Secuenciador Métrico de Sub-Ticks: Recorre las medidas a 60/120 FPS disparando eventos `noteOn` y `noteOff`
///    en fase temporal exacta basada en el tempo (BPM).
class ScorePlaybackCoordinator {
  final PolyphonicVoicePool voicePool;

  Timer? _playbackTimer;
  bool _isPlaying = false;
  int _currentMeasureIndex = 0;
  int _currentSubTick = 0;
  double _bpm = 120.0;

  HierarchicalScore? _activeScore;

  // Callbacks de notificación
  void Function(int measureIndex, int subTick)? onTick;
  void Function()? onPlaybackStarted;
  void Function()? onPlaybackStopped;

  ScorePlaybackCoordinator({
    required this.voicePool,
    double initialBpm = 120.0,
  }) : _bpm = math.max(20.0, initialBpm);

  // Getters
  bool get isPlaying => _isPlaying;
  int get currentMeasureIndex => _currentMeasureIndex;
  int get currentSubTick => _currentSubTick;
  double get bpm => _bpm;
  HierarchicalScore? get activeScore => _activeScore;

  set bpm(double newBpm) {
    _bpm = math.max(20.0, newBpm);
    if (_isPlaying) {
      _restartTimer();
    }
  }

  /// Convierte un nombre de nota musical (en notación silábica o sajona con octava)
  /// a su número de nota MIDI estándar (0 a 127).
  ///
  /// Ejemplos: "Do4" -> 60, "C4" -> 60, "La4" -> 69, "A4" -> 69, "Fa#5" -> 78, "Mib3" -> 51, "B4" -> 71, "Sib4" -> 70.
  static int noteNameToMidi(String noteName) {
    if (noteName.isEmpty || noteName == '--') return -1;

    final clean = noteName.trim();
    // Extraer octava
    final octaveMatch = RegExp(r'[-+]?[0-9]+').firstMatch(clean);
    final octave = octaveMatch != null ? int.tryParse(octaveMatch.group(0)!) ?? 4 : 4;

    // Extraer nombre de la nota sin octava
    final nameWithoutOctave = clean.replaceAll(RegExp(r'[-+]?[0-9]+'), '').trim();
    final semitone = NoteEntity.parseNoteIndex(nameWithoutOctave);
    if (semitone == null) return -1;

    final midi = ((octave + 1) * 12) + semitone;
    return midi.clamp(0, 127);
  }

  /// Dispara una nota táctil individual para audición inmediata (*Tap-to-Listen*).
  void previewNote(HierarchicalNote note, {double durationSeconds = 0.45, double velocity = 0.8}) {
    if (note.isRest || note.noteName.isEmpty) return;

    final midi = noteNameToMidi(note.noteName);
    if (midi < 0) return;

    voicePool.noteOn(midi, velocity);

    // Liberar la nota al concluir la duración de pre-escucha
    Timer(Duration(milliseconds: (durationSeconds * 1000).round()), () {
      voicePool.noteOff(midi);
    });
  }

  /// Inicia la reproducción sincronizada de la partitura.
  void startPlayback({
    required HierarchicalScore score,
    int startMeasure = 0,
    int startSubTick = 0,
  }) {
    _activeScore = score;
    _currentMeasureIndex = startMeasure.clamp(0, math.max(0, score.measures.length - 1));
    _currentSubTick = startSubTick;
    _isPlaying = true;

    onPlaybackStarted?.call();
    _restartTimer();
    _processCurrentTick();
  }

  /// Pausa la reproducción manteniendo la posición actual del playhead.
  void pausePlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlaying = false;
    voicePool.allNotesOff();
    onPlaybackStopped?.call();
  }

  /// Detiene la reproducción y rebobina el cursor al inicio de la partitura.
  void stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlaying = false;
    _currentMeasureIndex = 0;
    _currentSubTick = 0;
    voicePool.panic();
    onTick?.call(0, 0);
    onPlaybackStopped?.call();
  }

  void _restartTimer() {
    _playbackTimer?.cancel();
    // 1 sub-tick = 1 semicorchea (resolución base 1/16).
    // Duración de una negra = 60 / BPM segundos.
    // Duración de 1 sub-tick = (60 / BPM) / 4 = 15 / BPM segundos.
    final tickDurationSeconds = 15.0 / _bpm;
    final tickDurationMs = math.max(10, (tickDurationSeconds * 1000).round());

    _playbackTimer = Timer.periodic(Duration(milliseconds: tickDurationMs), (timer) {
      _advanceTick();
    });
  }

  void _advanceTick() {
    if (!_isPlaying || _activeScore == null || _activeScore!.measures.isEmpty) {
      return;
    }

    final currentMeasure = _activeScore!.measures[_currentMeasureIndex];
    final totalTicks = currentMeasure.timeSignature.totalTicks;

    _currentSubTick++;
    if (_currentSubTick >= totalTicks) {
      // Despachar noteOff para notas que concluyen exactamente al final de este compás
      for (final note in currentMeasure.notes) {
        if (!note.isRest && note.endTick >= totalTicks) {
          final midi = noteNameToMidi(note.noteName);
          if (midi >= 0) {
            voicePool.noteOff(midi);
          }
        }
      }

      _currentSubTick = 0;
      _currentMeasureIndex++;
      if (_currentMeasureIndex >= _activeScore!.measures.length) {
        // Fin de la partitura
        stopPlayback();
        return;
      }
    }

    _processCurrentTick();
  }

  void _processCurrentTick() {
    if (_activeScore == null || _activeScore!.measures.isEmpty) return;
    final currentMeasure = _activeScore!.measures[_currentMeasureIndex];

    // 1. Despachar noteOff para notas que concluyen en este sub-tick
    for (final note in currentMeasure.notes) {
      if (!note.isRest && note.endTick == _currentSubTick) {
        final midi = noteNameToMidi(note.noteName);
        if (midi >= 0) {
          voicePool.noteOff(midi);
        }
      }
    }

    // 2. Despachar noteOn para notas que inician en este sub-tick
    for (final note in currentMeasure.notes) {
      if (!note.isRest && note.startTick == _currentSubTick) {
        final midi = noteNameToMidi(note.noteName);
        if (midi >= 0) {
          voicePool.noteOn(midi, 0.85);
        }
      }
    }

    // Notificar actualización visual del playhead a los oyentes (60/120 FPS)
    onTick?.call(_currentMeasureIndex, _currentSubTick);
  }

  void dispose() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    voicePool.panic();
  }
}
