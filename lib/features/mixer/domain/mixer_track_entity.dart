/// Entidad de dominio pura que representa una pista de audio individual (Stem) en el mezclador.
class AudioTrack {
  final String id;
  final String title;
  final String instrumentIcon; // Identificador simbólico (ej: "voice", "piano", "guitar", "flute", "metronome")
  final double volume;         // Ganancia lineal de 0.0 (silencio) a 1.0 (máximo volumen)
  final double pan;            // Posición estereofónica de -1.0 (izquierda) a 1.0 (derecha), 0.0 centro
  final bool isMuted;          // True si el canal está en silencio
  final bool isSolo;           // True si el canal está en modo Solo exclusivo

  const AudioTrack({
    required this.id,
    required this.title,
    required this.instrumentIcon,
    this.volume = 0.8,
    this.pan = 0.0,
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
    double? pan,
    bool? isMuted,
    bool? isSolo,
  }) {
    final targetVol = volume ?? this.volume;
    final targetPan = pan ?? this.pan;
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      instrumentIcon: instrumentIcon ?? this.instrumentIcon,
      volume: (targetVol.isFinite ? targetVol : this.volume).clamp(0.0, 1.0),
      pan: (targetPan.isFinite ? targetPan : this.pan).clamp(-1.0, 1.0),
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'instrumentIcon': instrumentIcon,
    'volume': volume,
    'pan': pan,
    'isMuted': isMuted,
    'isSolo': isSolo,
  };

  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    final rawVol = (map['volume'] as num?)?.toDouble() ?? 0.8;
    final rawPan = (map['pan'] as num?)?.toDouble() ?? 0.0;
    return AudioTrack(
      id: map['id'] as String? ?? 'track',
      title: map['title'] as String? ?? 'Pista',
      instrumentIcon: map['instrumentIcon'] as String? ?? 'music_note',
      volume: (rawVol.isFinite ? rawVol : 0.8).clamp(0.0, 1.0),
      pan: (rawPan.isFinite ? rawPan : 0.0).clamp(-1.0, 1.0),
      isMuted: map['isMuted'] as bool? ?? false,
      isSolo: map['isSolo'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioTrack &&
        other.id == id &&
        other.title == title &&
        other.instrumentIcon == instrumentIcon &&
        other.volume == volume &&
        other.pan == pan &&
        other.isMuted == isMuted &&
        other.isSolo == isSolo;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        instrumentIcon,
        volume,
        pan,
        isMuted,
        isSolo,
      );
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

  /// Actualiza la posicion estereofonica (pan en [-1.0, 1.0]) de una pista por ID.
  MixerConsoleEntity copyWithTrackPan(String trackId, double newPan) {
    if (trackId == metronomeTrack.id) {
      return MixerConsoleEntity(
        metronomeTrack: metronomeTrack.copyWith(pan: newPan),
        stems: stems,
      );
    }
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: stems.map((t) => t.id == trackId ? t.copyWith(pan: newPan) : t).toList(),
    );
  }

  MixerConsoleEntity setTrackSolo(String trackId, bool isSolo) {
    if (trackId == metronomeTrack.id) {
      return MixerConsoleEntity(
        metronomeTrack: metronomeTrack.copyWith(isSolo: isSolo),
        stems: stems,
      );
    }
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: stems.map((t) => t.id == trackId ? t.copyWith(isSolo: isSolo) : t).toList(),
    );
  }

  /// Agrega o reemplaza un stem en la consola de mezcla.
  MixerConsoleEntity addStem(AudioTrack track) {
    final existingIdx = stems.indexWhere((t) => t.id == track.id);
    if (existingIdx >= 0) {
      final updated = List<AudioTrack>.from(stems);
      updated[existingIdx] = track;
      return MixerConsoleEntity(metronomeTrack: metronomeTrack, stems: updated);
    }
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: [...stems, track],
    );
  }

  /// Elimina un stem de la consola por su identificador.
  MixerConsoleEntity removeStem(String trackId) {
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: stems.where((t) => t.id != trackId).toList(),
    );
  }

  /// Restaura mute, solo y pan a valores neutros en todas las pistas.
  MixerConsoleEntity resetAll() {
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack.copyWith(pan: 0.0, isMuted: false, isSolo: false),
      stems: stems
          .map((t) => t.copyWith(pan: 0.0, isMuted: false, isSolo: false))
          .toList(),
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

  MixerConsoleEntity setTrackMute(String trackId, bool isMuted) {
    if (trackId == metronomeTrack.id) {
      return MixerConsoleEntity(
        metronomeTrack: metronomeTrack.copyWith(isMuted: isMuted),
        stems: stems,
      );
    }
    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: stems.map((t) => t.id == trackId ? t.copyWith(isMuted: isMuted) : t).toList(),
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

  Map<String, dynamic> toMap() => {
        'metronomeTrack': metronomeTrack.toMap(),
        'stems': stems.map((t) => t.toMap()).toList(),
      };

  factory MixerConsoleEntity.fromMap(Map<String, dynamic> map) {
    final defaultSetup = MixerConsoleEntity.defaultSetup();
    final rawMetro = map['metronomeTrack'];
    final metronomeTrack = rawMetro is Map<String, dynamic>
        ? AudioTrack.fromMap(rawMetro)
        : defaultSetup.metronomeTrack;

    final rawStems = map['stems'] as List<dynamic>? ?? [];
    final stems = rawStems
        .whereType<Map<String, dynamic>>()
        .map(AudioTrack.fromMap)
        .toList();

    return MixerConsoleEntity(
      metronomeTrack: metronomeTrack,
      stems: stems,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MixerConsoleEntity) return false;
    if (other.metronomeTrack != metronomeTrack) return false;
    if (other.stems.length != stems.length) return false;
    for (int i = 0; i < stems.length; i++) {
      if (other.stems[i] != stems[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(metronomeTrack, Object.hashAll(stems));
}
