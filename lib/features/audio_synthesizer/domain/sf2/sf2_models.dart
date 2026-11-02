import 'dart:typed_data';

/// Enumeración canónica de generadores SF2 según la especificación SoundFont 2.04.
class Sf2GeneratorType {
  static const int startAddrsOffset = 0;
  static const int endAddrsOffset = 1;
  static const int startloopAddrsOffset = 2;
  static const int endloopAddrsOffset = 3;
  static const int initialFilterFc = 8;
  static const int initialFilterQ = 9;
  static const int pan = 17;
  static const int delayVolEnv = 33;
  static const int attackVolEnv = 34;
  static const int holdVolEnv = 35;
  static const int decayVolEnv = 36;
  static const int sustainVolEnv = 37;
  static const int releaseVolEnv = 38;
  static const int instrument = 41;
  static const int keyRange = 43;
  static const int velRange = 44;
  static const int initialAttenuation = 48;
  static const int sampleID = 53;
  static const int sampleModes = 54;
  static const int overridingRootKey = 58;
}

/// Rango de notas MIDI o velocidades.
class Sf2Range {
  final int low;
  final int high;

  const Sf2Range({required this.low, required this.high});

  bool contains(int value) => value >= low && value <= high;

  @override
  String toString() => '[$low..$high]';
}

/// Metadatos de una muestra de audio PCM individual en el SoundFont.
class Sf2SampleHeader {
  final String name;
  final int start;
  final int end;
  final int startLoop;
  final int endLoop;
  final int sampleRate;
  final int originalPitch;
  final int pitchCorrection;
  final int sampleLink;
  final int sampleType;

  const Sf2SampleHeader({
    required this.name,
    required this.start,
    required this.end,
    required this.startLoop,
    required this.endLoop,
    required this.sampleRate,
    required this.originalPitch,
    required this.pitchCorrection,
    required this.sampleLink,
    required this.sampleType,
  });

  int get length => end - start;
  bool get hasLoop => endLoop > startLoop && (sampleType & 1) != 0;
}

/// Zona de generadores asociada a un preset o instrumento.
class Sf2Zone {
  final Sf2Range keyRange;
  final Sf2Range velRange;
  final Map<int, int> generators;
  final int? sampleId;
  final int? instrumentId;

  const Sf2Zone({
    this.keyRange = const Sf2Range(low: 0, high: 127),
    this.velRange = const Sf2Range(low: 0, high: 127),
    this.generators = const {},
    this.sampleId,
    this.instrumentId,
  });
}

/// Instrumento SF2 compuesto por una colección de zonas de muestras.
class Sf2Instrument {
  final String name;
  final List<Sf2Zone> zones;

  const Sf2Instrument({
    required this.name,
    required this.zones,
  });
}

/// Preset accesible vía número de programa MIDI y banco.
class Sf2Preset {
  final String name;
  final int patch;
  final int bank;
  final List<Sf2Zone> zones;

  const Sf2Preset({
    required this.name,
    required this.patch,
    required this.bank,
    required this.zones,
  });
}

/// Contenedor completo de un banco SoundFont decodificado en memoria.
class Sf2SoundFont {
  final String soundFontName;
  final List<Sf2Preset> presets;
  final List<Sf2Instrument> instruments;
  final List<Sf2SampleHeader> sampleHeaders;
  final Int16List sampleData;

  const Sf2SoundFont({
    required this.soundFontName,
    required this.presets,
    required this.instruments,
    required this.sampleHeaders,
    required this.sampleData,
  });

  /// Busca un preset por número de patch y banco.
  Sf2Preset? findPreset(int patch, {int bank = 0}) {
    for (final p in presets) {
      if (p.patch == patch && p.bank == bank) return p;
    }
    if (presets.isNotEmpty) return presets.first;
    return null;
  }
}
