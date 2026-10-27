/// Entidad de dominio pura que representa una pista de audio individual (Stem) en el mezclador.
class AudioTrack {
  final String id;
  final String title;
  final String instrumentIcon; // Identificador simbólico (ej: "voice", "piano", "guitar", "flute", "metronome")
  final double volume;         // Ganancia lineal de 0.0 (silencio) a 1.0 (máximo volumen)
  final bool isMuted;          // True si el canal está en silencio
  final bool isSolo;           // True si el canal está en modo Solo exclusivo

  const AudioTrack({
    required this.id,
    required this.title,
    required this.instrumentIcon,
    this.volume = 0.8,
    this.isMuted = false,
    this.isSolo = false,
  });

  /// Retorna la ganancia efectiva (de 0.0 a 1.0) teniendo en cuenta si hay algún otro canal en modo solo.
  double getEffectiveGain({required bool hasAnySolo}) {
    if (isMuted) return 0.0;
    if (hasAnySolo) {
      return isSolo ? volume : 0.0;
    }
    return volume;
  }

  AudioTrack copyWith({
    String? id,
    String? title,
    String? instrumentIcon,
    double? volume,
    bool? isMuted,
    bool? isSolo,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      instrumentIcon: instrumentIcon ?? this.instrumentIcon,
      volume: (volume ?? this.volume).clamp(0.0, 1.0),
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }
}

/// Estado global inmutable de la consola de mezcla multicanal.
class MixerConsoleEntity {
  final AudioTrack metronomeTrack;
  final List<AudioTrack> stems;

  const MixerConsoleEntity({
    required this.metronomeTrack,
    required this.stems,
  });

  bool get hasAnySolo => stems.any((t) => t.isSolo) || metronomeTrack.isSolo;

  /// Crea una consola inicial por defecto con metrónomo y stems orquestales/didácticos.
  factory MixerConsoleEntity.defaultSetup() {
    return const MixerConsoleEntity(
      metronomeTrack: AudioTrack(
        id: "metronome",
        title: "Metrónomo",
        instrumentIcon: "timer",
        volume: 0.75,
      ),
      stems: [
        AudioTrack(
          id: "voice",
          title: "Voz Principal",
          instrumentIcon: "mic",
          volume: 0.85,
        ),
        AudioTrack(
          id: "piano",
          title: "Piano Acompañante",
          instrumentIcon: "piano",
          volume: 0.80,
        ),
        AudioTrack(
          id: "guitar",
          title: "Guitarras / Vientos",
          instrumentIcon: "music_note",
          volume: 0.70,
        ),
      ],
    );
  }

  MixerConsoleEntity copyWithTrackVolume(String trackId, double newVolume) {
    if (trackId == metronomeTrack.id) {
      return MixerConsoleEntity(
        metronomeTrack: metronomeTrack.copyWith(volume: newVolume),
        stems: stems,
      );
    }
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: stems.map((t) => t.id == trackId ? t.copyWith(volume: newVolume) : t).toList(),
    );
  }

  MixerConsoleEntity toggleMute(String trackId) {
    if (trackId == metronomeTrack.id) {
      return MixerConsoleEntity(
        metronomeTrack: metronomeTrack.copyWith(isMuted: !metronomeTrack.isMuted),
        stems: stems,
      );
    }
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: stems.map((t) => t.id == trackId ? t.copyWith(isMuted: !t.isMuted) : t).toList(),
    );
  }

  MixerConsoleEntity toggleSolo(String trackId) {
    if (trackId == metronomeTrack.id) {
      return MixerConsoleEntity(
        metronomeTrack: metronomeTrack.copyWith(isSolo: !metronomeTrack.isSolo),
        stems: stems,
      );
    }
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: stems.map((t) => t.id == trackId ? t.copyWith(isSolo: !t.isSolo) : t).toList(),
    );
  }

  /// Retorna la ganancia efectiva (de 0.0 a 1.0) para una pista por su identificador.
  double getEffectiveGain(String trackId) {
    if (trackId == metronomeTrack.id) {
      return metronomeTrack.getEffectiveGain(hasAnySolo: hasAnySolo);
    }
    final track = stems.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return 0.0;
    return track.getEffectiveGain(hasAnySolo: hasAnySolo);
  }
}
