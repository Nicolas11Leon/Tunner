import 'dart:math' as math;

/// Representacion canonica e inmutable de una altura musical parseada.
/// Pure Dart: cero dependencias de Flutter UI.
class ParsedPitchNotation {
  /// Letra diatonica anglosajona en mayuscula ('C', 'D', 'E', 'F', 'G', 'A', 'B').
  final String step;

  /// Nombre diatonico latino canonico ('Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si').
  final String solfegeBase;

  /// Alteracion cromatica en semitonos (-2..2; -1 = bemol, 0 = natural, +1 = sostenido).
  final int alter;

  /// Octava cientifica acotada al rango instrumental completo (0..8).
  final int octave;

  /// Numero MIDI estandar (0..127), donde C4 = 60 y A4 = 69.
  final int midiNumber;

  const ParsedPitchNotation({
    required this.step,
    required this.solfegeBase,
    required this.alter,
    required this.octave,
    required this.midiNumber,
  });

  /// Simbolo de alteracion ASCII ('', '#', 'b', '##', 'bb').
  String get accidentalSymbol {
    if (alter == 0) return '';
    if (alter > 0) return '#' * alter;
    return 'b' * alter.abs();
  }

  /// Representacion latina (ej: 'Sib4', 'Do#5', 'Si4').
  String get solfegeName => '$solfegeBase$accidentalSymbol$octave';

  /// Representacion anglosajona (ej: 'Bb4', 'C#5', 'B4').
  String get englishName => '$step$accidentalSymbol$octave';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedPitchNotation &&
        other.step == step &&
        other.solfegeBase == solfegeBase &&
        other.alter == alter &&
        other.octave == octave &&
        other.midiNumber == midiNumber;
  }

  @override
  int get hashCode => Object.hash(step, solfegeBase, alter, octave, midiNumber);

  @override
  String toString() =>
      'ParsedPitchNotation($solfegeName / $englishName, midi: $midiNumber)';
}

/// Codec canonico unificado para conversion bidireccional entre notacion musical
/// (latina y anglosajona), numeros MIDI y frecuencias en Hz.
///
/// Distingue explicitamente la letra de nota 'B'/'b' (Si natural) del modificador
/// de bemol posterior ('b'/'♭'), evitando la colision clasica de parsers ad-hoc.
class CanonicalPitchNotationCodec {
  const CanonicalPitchNotationCodec._();

  static const Map<String, String> _solfegeToStep = {
    'SOL': 'G',
    'DO': 'C',
    'RE': 'D',
    'MI': 'E',
    'FA': 'F',
    'LA': 'A',
    'SI': 'B',
  };

  static const Map<String, String> _stepToSolfege = {
    'C': 'Do',
    'D': 'Re',
    'E': 'Mi',
    'F': 'Fa',
    'G': 'Sol',
    'A': 'La',
    'B': 'Si',
  };

  static const Map<String, int> _stepSemitoneOffset = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };

  static const List<String> _sharpSolfegeScale = [
    'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si',
  ];

  static const List<String> _flatSolfegeScale = [
    'Do', 'Reb', 'Re', 'Mib', 'Mi', 'Fa', 'Solb', 'Sol', 'Lab', 'La', 'Sib', 'Si',
  ];

  static const List<String> _sharpEnglishScale = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  static const List<String> _flatEnglishScale = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
  ];

  /// Parsea un nombre de nota en notacion latina o anglosajona (ej: 'B4', 'b4',
  /// 'Bb4', 'Sib4', 'Do#5', 'Fa♭3', 'C4').
  /// Retorna `null` si la cadena representa un silencio ('--', 'rest') o es invalida.
  static ParsedPitchNotation? parse(String rawName, {int defaultOctave = 4}) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return null;

    final lowerCheck = trimmed.toLowerCase();
    if (trimmed == '--' || lowerCheck == 'rest' || lowerCheck == 'silencio') {
      return null;
    }

    final upper = trimmed.toUpperCase();
    String? step;
    String remainder = trimmed;

    // 1. Intentar coincidencia silabica latina primero (SOL antes de S/SI).
    for (final entry in _solfegeToStep.entries) {
      if (upper.startsWith(entry.key)) {
        step = entry.value;
        remainder = trimmed.substring(entry.key.length);
        break;
      }
    }

    // 2. Si no hubo coincidencia silabica, extraer letra anglosajona A..G.
    // Aqui 'B' o 'b' se consume como la nota Si, nunca como bemol.
    if (step == null) {
      final firstChar = upper[0];
      if (!_stepSemitoneOffset.containsKey(firstChar)) {
        return null;
      }
      step = firstChar;
      remainder = trimmed.substring(1);
    }

    // 3. Parsear alteraciones SOLO a partir del sufijo posterior a la letra base.
    final normalizedAcc = remainder
        .replaceAll('♯', '#')
        .replaceAll('♭', 'b')
        .replaceAll('♮', '');

    int alter = 0;
    int cursor = 0;
    while (cursor < normalizedAcc.length) {
      final ch = normalizedAcc[cursor];
      if (ch == '#') {
        alter++;
        cursor++;
      } else if (ch == 'b' || ch == 'B') {
        alter--;
        cursor++;
      } else {
        break;
      }
    }
    alter = alter.clamp(-2, 2);

    // 4. Extraer octava del tramo restante.
    final octaveSegment = normalizedAcc.substring(cursor).trim();
    int octave = defaultOctave;
    if (octaveSegment.isNotEmpty) {
      final octMatch = RegExp(r'^-?\d+$').firstMatch(octaveSegment);
      if (octMatch == null) {
        final embedded = RegExp(r'-?\d+').firstMatch(octaveSegment);
        if (embedded == null) return null;
        octave = int.tryParse(embedded.group(0)!) ?? defaultOctave;
      } else {
        octave = int.tryParse(octMatch.group(0)!) ?? defaultOctave;
      }
    }
    final clampedOctave = octave.clamp(0, 8);

    // Formula MIDI canonica: MIDI = (octave + 1) * 12 + semitone(step) + alter.
    // Soporta de forma natural enarmonias de borde de octava (ej. Cb4 = 59, B#3 = 60).
    final baseSemitone = _stepSemitoneOffset[step]!;
    final rawMidi = (clampedOctave + 1) * 12 + baseSemitone + alter;
    final midiNumber = rawMidi.clamp(0, 127);

    return ParsedPitchNotation(
      step: step,
      solfegeBase: _stepToSolfege[step]!,
      alter: alter,
      octave: clampedOctave,
      midiNumber: midiNumber,
    );
  }

  /// Parsea una nota o devuelve un valor seguro por defecto (Do4 / C4).
  static ParsedPitchNotation parseOrDefault(
    String rawName, {
    String fallbackStep = 'C',
    int fallbackOctave = 4,
  }) {
    final parsed = parse(rawName, defaultOctave: fallbackOctave);
    if (parsed != null) return parsed;
    final safeStep = _stepSemitoneOffset.containsKey(fallbackStep) ? fallbackStep : 'C';
    final safeOctave = fallbackOctave.clamp(0, 8);
    final midi = ((safeOctave + 1) * 12 + _stepSemitoneOffset[safeStep]!).clamp(0, 127);
    return ParsedPitchNotation(
      step: safeStep,
      solfegeBase: _stepToSolfege[safeStep]!,
      alter: 0,
      octave: safeOctave,
      midiNumber: midi,
    );
  }

  /// Convierte un nombre de nota (latino o anglosajon) a numero MIDI (0..127).
  static int? noteNameToMidi(String rawName, {int defaultOctave = 4}) {
    return parse(rawName, defaultOctave: defaultOctave)?.midiNumber;
  }

  /// Convierte un numero MIDI (0..127) a notacion latina ('Do4', 'Sib4', 'Fa#3').
  static String midiToSolfege(int midiNumber, {bool preferFlats = false}) {
    final clamped = midiNumber.clamp(0, 127);
    final octave = (clamped ~/ 12) - 1;
    final semitone = clamped % 12;
    final scale = preferFlats ? _flatSolfegeScale : _sharpSolfegeScale;
    return '${scale[semitone]}$octave';
  }

  /// Convierte un numero MIDI (0..127) a notacion anglosajona ('C4', 'Bb4', 'F#3').
  static String midiToEnglish(int midiNumber, {bool preferFlats = false}) {
    final clamped = midiNumber.clamp(0, 127);
    final octave = (clamped ~/ 12) - 1;
    final semitone = clamped % 12;
    final scale = preferFlats ? _flatEnglishScale : _sharpEnglishScale;
    return '${scale[semitone]}$octave';
  }

  /// Convierte un numero MIDI a frecuencia en Hz bajo afinacion temperada (12-EDO).
  /// Formula: f = a4Ref * 2^((midi - 69) / 12).
  static double midiToFrequency(int midiNumber, {double a4Ref = 440.0}) {
    final safeRef = (a4Ref > 0.0 && a4Ref.isFinite) ? a4Ref : 440.0;
    return safeRef * math.pow(2.0, (midiNumber - 69) / 12.0).toDouble();
  }

  /// Convierte una frecuencia positiva en Hz al numero MIDI entero mas cercano.
  /// Formula: midi = round(12 * log2(f / a4Ref) + 69).
  static int? frequencyToMidi(double frequencyHz, {double a4Ref = 440.0}) {
    if (frequencyHz <= 0.0 || !frequencyHz.isFinite) return null;
    final safeRef = (a4Ref > 0.0 && a4Ref.isFinite) ? a4Ref : 440.0;
    final exactMidi = 12.0 * (math.log(frequencyHz / safeRef) / math.ln2) + 69.0;
    return exactMidi.round().clamp(0, 127);
  }
}
