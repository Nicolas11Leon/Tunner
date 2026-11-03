import 'dart:math' as math;
import '../../instrument/domain/instrument_profile_entity.dart';
import 'guided_lesson_entity.dart';

/// Motor de Dominio Puro para adaptar el sistema pedagógico (lecciones guiadas,
/// ejercicios técnicos y canciones) a cualquier instrumento musical.
/// 
/// 100% Pure Dart: Sin dependencias de UI, Flutter ni plugins externos.
class InstrumentPedagogyAdapterEngine {
  const InstrumentPedagogyAdapterEngine();

  static const List<String> _solfegeNoteNames = [
    'Do',
    'Do#',
    'Re',
    'Re#',
    'Mi',
    'Fa',
    'Fa#',
    'Sol',
    'Sol#',
    'La',
    'La#',
    'Si',
  ];

  static const List<String> _scientificNoteNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  /// Adapta una lista completa de lecciones guiadas al instrumento especificado.
  List<GuidedLessonEntity> adaptLessons(
    List<GuidedLessonEntity> lessons,
    InstrumentProfileEntity instrument,
  ) {
    return lessons.map((lesson) => adaptLesson(lesson, instrument)).toList();
  }

  /// Adapta una lección guiada específica al instrumento.
  GuidedLessonEntity adaptLesson(
    GuidedLessonEntity lesson,
    InstrumentProfileEntity instrument,
  ) {
    final adaptedSteps = lesson.steps.map((step) {
      return adaptStep(step, instrument);
    }).toList();

    return GuidedLessonEntity(
      id: lesson.id,
      title: lesson.title,
      description: '${lesson.description} Adaptada a la tesitura y biomecánica de ${instrument.name}.',
      category: lesson.category,
      difficulty: lesson.difficulty,
      steps: adaptedSteps,
    );
  }

  /// Adapta un paso de lección al instrumento:
  /// 1. Desplaza la octava a la zona ergonómica del instrumento.
  /// 2. Calcula la nota escrita para instrumentos transpositores.
  /// 3. Genera consejos biomecánicos específicos para la familia acústica.
  GuidedLessonStepEntity adaptStep(
    GuidedLessonStepEntity step,
    InstrumentProfileEntity instrument,
  ) {
    final parsedMidi = noteNameToMidi(step.targetNoteName);
    if (parsedMidi == null) {
      return step;
    }

    // 1. Desplazar octava al rango cómodo del instrumento
    final targetMidi = shiftMidiToInstrumentRange(parsedMidi, instrument);
    final concertNoteName = midiToNoteName(targetMidi);
    final concertFrequencyHz = midiToFrequency(targetMidi);

    // 2. Calcular nota escrita para transposición
    // Si el instrumento suena en transposición T semitonos, la nota que lee es MIDI - T
    final writtenMidi = targetMidi - instrument.transpositionSemitones;
    final writtenNoteName = midiToNoteName(writtenMidi);

    // 3. Generar consejo biomecánico contextual
    final familyTip = generateFamilyBiomechanicsTip(
      instrument: instrument,
      stepIndex: step.stepIndex,
      isHighRegister: concertFrequencyHz > (instrument.minFrequencyHz * 2.5),
      isLowRegister: concertFrequencyHz < (instrument.minFrequencyHz * 1.5),
    );

    // 4. Redactar instrucción adaptada
    final instruction = _buildAdaptedInstruction(
      originalInstruction: step.instruction,
      concertNoteName: concertNoteName,
      writtenNoteName: writtenNoteName,
      isTransposing: instrument.isTransposing,
      instrumentName: instrument.name,
    );

    return step.copyWith(
      targetNoteName: concertNoteName,
      targetFrequencyHz: concertFrequencyHz,
      instruction: instruction,
      feedbackTip: familyTip,
      writtenNoteName: instrument.isTransposing ? writtenNoteName : null,
    );
  }

  /// Desplaza un valor MIDI por saltos de octava (+/- 12 semitonos) hasta
  /// ubicarlo en la zona ergonómica central de la tesitura del instrumento.
  int shiftMidiToInstrumentRange(int midiNote, InstrumentProfileEntity instrument) {
    final minMidi = frequencyToMidi(instrument.minFrequencyHz);
    final maxMidi = frequencyToMidi(instrument.maxFrequencyHz);

    int shifted = midiNote;

    // Si está por debajo del rango mínimo, subir octavas
    while (shifted < minMidi) {
      shifted += 12;
    }

    // Si está por encima del rango máximo, bajar octavas
    while (shifted > maxMidi) {
      shifted -= 12;
    }

    // Buscar la zona media confortable del instrumento (no los extremos de registro)
    final comfortableMin = minMidi + 3;
    final comfortableMax = maxMidi - 5;

    if (comfortableMax > comfortableMin) {
      // Intentar acercar a la zona media si aún cabe una octava
      if (shifted < comfortableMin && (shifted + 12) <= maxMidi) {
        shifted += 12;
      } else if (shifted > comfortableMax && (shifted - 12) >= minMidi) {
        shifted -= 12;
      }
    }

    return shifted;
  }

  /// Convierte un número de nota MIDI a frecuencia en Hertz (A4 = 69 = 440 Hz).
  double midiToFrequency(int midiNote) {
    return 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);
  }

  /// Convierte una frecuencia en Hertz a número de nota MIDI redondeado.
  int frequencyToMidi(double frequencyHz) {
    if (frequencyHz <= 0) return 60; // Do4 por defecto
    return (69 + 12.0 * (math.log(frequencyHz / 440.0) / math.ln2)).round();
  }

  /// Convierte nombre de nota en solfeo o cifrado (ej. "Sol4", "G4", "Do#3") a número MIDI.
  int? noteNameToMidi(String noteName) {
    final clean = noteName.trim();
    if (clean.isEmpty) return null;

    final match = RegExp(r'^([A-Za-z#♭]+)(\d+)$').firstMatch(clean);
    if (match == null) return null;

    final pitchPart = match.group(1)!;
    final octave = int.tryParse(match.group(2)!) ?? 4;

    // Normalizar accidental
    String basePitch = pitchPart;
    bool isSharp = false;
    bool isFlat = false;

    if (basePitch.endsWith('#')) {
      isSharp = true;
      basePitch = basePitch.substring(0, basePitch.length - 1);
    } else if (basePitch.endsWith('b') || basePitch.endsWith('♭')) {
      isFlat = true;
      basePitch = basePitch.substring(0, basePitch.length - 1);
    }

    int semitoneInOctave = -1;

    // Buscar en solfeo
    for (int i = 0; i < _solfegeNoteNames.length; i++) {
      if (_solfegeNoteNames[i].toLowerCase() == basePitch.toLowerCase()) {
        semitoneInOctave = i;
        break;
      }
    }

    // Buscar en notación científica
    if (semitoneInOctave == -1) {
      for (int i = 0; i < _scientificNoteNames.length; i++) {
        if (_scientificNoteNames[i].toLowerCase() == basePitch.toLowerCase()) {
          semitoneInOctave = i;
          break;
        }
      }
    }

    if (semitoneInOctave == -1) return null;

    if (isSharp) semitoneInOctave += 1;
    if (isFlat) semitoneInOctave -= 1;

    return (octave + 1) * 12 + semitoneInOctave;
  }

  /// Convierte un número MIDI a nombre de nota canónico en Solfeo (ej. 60 -> "Do4").
  String midiToNoteName(int midiNote) {
    final semitone = ((midiNote % 12) + 12) % 12;
    final octave = (midiNote ~/ 12) - 1;
    return '${_solfegeNoteNames[semitone]}$octave';
  }

  /// Genera un consejo biomecánico según la familia del instrumento y registro.
  String generateFamilyBiomechanicsTip({
    required InstrumentProfileEntity instrument,
    required int stepIndex,
    required bool isHighRegister,
    required bool isLowRegister,
  }) {
    switch (instrument.family) {
      case InstrumentFamily.strings:
        if (instrument.id.contains('guitar') || instrument.id.contains('bass')) {
          if (isHighRegister) {
            return 'En trastes agudos, usa la yema del dedo perpendicular al diapasón justo antes del traste para evitar zumbido (fret buzz).';
          }
          if (isLowRegister) {
            return 'En cuerdas graves, pulsa con el pulgar o dedos índice/medio firmes sin estirar la cuerda hacia los lados para no provocar micro-bending.';
          }
          return 'Presiona justo detrás de la barra del traste con la muñeca relajada. Controla la fuerza de pulsación para mantener la afinación estable.';
        } else {
          // Violín, Cello, Contrabajo
          if (isHighRegister) {
            return 'En posiciones altas del diapasón, acerca el punto de contacto del arco hacia el puente (sul ponticello) con menor peso y mayor velocidad.';
          }
          if (isLowRegister) {
            return 'En registros graves, permite que el peso natural del brazo se transfiera a las cerdas del arco sin apretar los dedos izquierdos.';
          }
          return 'Mantén el arco perpendicular a las cuerdas. Verifica la afinación sin trastes ajustando sutilmente la posición del dedo sobre el diapasón.';
        }

      case InstrumentFamily.brass:
        if (isHighRegister) {
          return 'Para notas agudas, incrementa la velocidad del flujo de aire y contrae sutilmente las comisuras sin clavar la boquilla contra los labios.';
        }
        if (isLowRegister) {
          return 'Para notas graves, relaja la abertura labial manteniendo soporte abdominal firme para una vibración amplia y redonda.';
        }
        return 'Inicia con un ataque limpio de lengua ("Ta"). Mantén el soporte diafragmático firme y los hombros completamente relajados.';

      case InstrumentFamily.woodwinds:
        if (isHighRegister) {
          return 'En el registro agudo, proyecta la columna de aire con mayor velocidad y estrecha levemente la embocadura sin morder.';
        }
        if (isLowRegister) {
          return 'En el registro grave, mantén la cavidad bucal amplia como si pronunciaras "O" para evitar que la nota salte al armónico superior.';
        }
        return 'Sostén un flujo de aire constante y homogéneo. Asegúrate de sellar completamente los orificios o llaves sin ejercer fuerza excesiva.';

      case InstrumentFamily.vocals:
        if (isHighRegister) {
          return 'Eleva el velo del paladar y proyecta la resonancia hacia los senos paranasales (máscara) manteniendo la mandíbula caída y relajada.';
        }
        if (isLowRegister) {
          return 'Conecta con la resonancia pectoral sin empujar la laringe hacia abajo. El aire diafragmático sostiene el tono con suavidad.';
        }
        return 'Mantén una postura erguida y respira expandiendo la caja costal inferior. Emite la nota con vocal abierta y articulación relajada.';

      case InstrumentFamily.percussion:
        return 'Controla el punto de ataque y el rebote natural para permitir que el instrumento vibre libremente en su tono fundamental.';
    }
  }

  /// Construye la instrucción pedagógica adaptada.
  String _buildAdaptedInstruction({
    required String originalInstruction,
    required String concertNoteName,
    required String writtenNoteName,
    required bool isTransposing,
    required String instrumentName,
  }) {
    if (isTransposing) {
      return 'Toca la nota escrita $writtenNoteName en tu partitura de $instrumentName (sonará $concertNoteName en tono de concierto) de forma estable.';
    }
    return 'Sostén la nota $concertNoteName en tu $instrumentName de manera continua y centrada en el afinador.';
  }
}
