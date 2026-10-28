import 'guided_lesson_entity.dart';

/// Catálogo canónico curado de lecciones guiadas interactivas.
/// 100% Pure Dart: sin dependencias de plugins o UI.
class CuratedGuidedLessons {
  const CuratedGuidedLessons._();

  static const List<GuidedLessonEntity> all = [
    // Lección 1: Iniciación
    GuidedLessonEntity(
      id: 'lesson_01_master_notes',
      title: 'Iniciación: Las Tres Notas Maestras',
      description: 'Aprende a emitir y sostener con estabilidad las notas Sol4, La4 y Si4.',
      category: GuidedLessonCategory.fundamentals,
      difficulty: 'Principiante',
      steps: [
        GuidedLessonStepEntity(
          stepIndex: 0,
          instruction: 'Sostén la nota Sol4 por 2.5 segundos continuos dentro de la tolerancia.',
          targetNoteName: 'Sol4',
          targetFrequencyHz: 392.00,
          targetDurationSeconds: 2.5,
          toleranceCents: 15.0,
          feedbackTip: 'Alinea la columna de aire con la boquilla sin forzar los labios.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 1,
          instruction: 'Sostén la nota La4 (Concierto 440 Hz) por 2.5 segundos continuos.',
          targetNoteName: 'La4',
          targetFrequencyHz: 440.00,
          targetDurationSeconds: 2.5,
          toleranceCents: 12.0,
          feedbackTip: 'Mantén la garganta abierta como si pronunciaras la vocal "O".',
        ),
        GuidedLessonStepEntity(
          stepIndex: 2,
          instruction: 'Sostén la nota Si4 por 2.5 segundos continuos en el centro del afinador.',
          targetNoteName: 'Si4',
          targetFrequencyHz: 493.88,
          targetDurationSeconds: 2.5,
          toleranceCents: 12.0,
          feedbackTip: 'Mantén el soporte diafragmático firme sin apretar la mandíbula.',
        ),
      ],
    ),

    // Lección 2: Notas Largas & Embocadura
    GuidedLessonEntity(
      id: 'lesson_02_long_tones',
      title: 'Estabilidad de Embocadura: Notas Largas',
      description: 'Desarrolla resistencia pulmonar y afinación centrada en el registro medio.',
      category: GuidedLessonCategory.longTones,
      difficulty: 'Intermedio',
      steps: [
        GuidedLessonStepEntity(
          stepIndex: 0,
          instruction: 'Sostén Do4 (Do central) por 3.5 segundos continuos.',
          targetNoteName: 'Do4',
          targetFrequencyHz: 261.63,
          targetDurationSeconds: 3.5,
          toleranceCents: 10.0,
          feedbackTip: 'Busca una resonancia redonda y uniforme desde el ataque hasta el final.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 1,
          instruction: 'Sostén Re4 por 3.5 segundos continuos con afinación centrada.',
          targetNoteName: 'Re4',
          targetFrequencyHz: 293.66,
          targetDurationSeconds: 3.5,
          toleranceCents: 10.0,
          feedbackTip: 'Monitorea que la velocidad del aire no decaiga al final de la nota.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 2,
          instruction: 'Sostén Mi4 por 3.5 segundos continuos.',
          targetNoteName: 'Mi4',
          targetFrequencyHz: 329.63,
          targetDurationSeconds: 3.5,
          toleranceCents: 10.0,
          feedbackTip: 'Evita morder la boquilla; el aire es quien sostiene la altura.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 3,
          instruction: 'Sostén Fa4 por 3.5 segundos continuos.',
          targetNoteName: 'Fa4',
          targetFrequencyHz: 349.23,
          targetDurationSeconds: 3.5,
          toleranceCents: 10.0,
          feedbackTip: 'Verifica que la afinación no suba en el diminuendo final.',
        ),
      ],
    ),

    // Lección 3: Saltos de Intervalo
    GuidedLessonEntity(
      id: 'lesson_03_intervals',
      title: 'Flexibilidad de Intervalos: Quinta y Octava',
      description: 'Ejercita el salto melódico entre notas distantes manteniendo la precisión.',
      category: GuidedLessonCategory.intervals,
      difficulty: 'Avanzado',
      steps: [
        GuidedLessonStepEntity(
          stepIndex: 0,
          instruction: 'Toca Do4 por 2.0 segundos.',
          targetNoteName: 'Do4',
          targetFrequencyHz: 261.63,
          targetDurationSeconds: 2.0,
          toleranceCents: 8.0,
          feedbackTip: 'Establece una base armónica sólida antes del salto melódico.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 1,
          instruction: 'Salta a Sol4 (Quinta Justa superior) y sostén por 2.0 segundos.',
          targetNoteName: 'Sol4',
          targetFrequencyHz: 392.00,
          targetDurationSeconds: 2.0,
          toleranceCents: 8.0,
          feedbackTip: 'Acelera la columna de aire sin apretar la garganta.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 2,
          instruction: 'Culmina en Do5 (Octava superior) y sostén por 2.5 segundos.',
          targetNoteName: 'Do5',
          targetFrequencyHz: 523.25,
          targetDurationSeconds: 2.5,
          toleranceCents: 8.0,
          feedbackTip: 'En el registro agudo, proyecta la energía hacia la cavidad facial.',
        ),
      ],
    ),

    // Lección 4: Arpegio y Afinación Fina
    GuidedLessonEntity(
      id: 'lesson_04_major_triad',
      title: 'Afinación de Arpegios: Tríada de Do Mayor',
      description: 'Control microtonal fino de cada grado de la tríada mayor: Do4, Mi4, Sol4, Do5.',
      category: GuidedLessonCategory.scales,
      difficulty: 'Virtuoso',
      steps: [
        GuidedLessonStepEntity(
          stepIndex: 0,
          instruction: 'Fundamental: Toca Do4 por 2.0 segundos con precisión de ±6 cents.',
          targetNoteName: 'Do4',
          targetFrequencyHz: 261.63,
          targetDurationSeconds: 2.0,
          toleranceCents: 6.0,
          feedbackTip: 'Cimiento armónico: sonido estable y centrado.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 1,
          instruction: 'Tercera Mayor: Toca Mi4 por 2.0 segundos con precisión de ±6 cents.',
          targetNoteName: 'Mi4',
          targetFrequencyHz: 329.63,
          targetDurationSeconds: 2.0,
          toleranceCents: 6.0,
          feedbackTip: 'La tercera acústica requiere no forzar el flujo de aire.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 2,
          instruction: 'Quinta Justa: Toca Sol4 por 2.0 segundos con precisión de ±6 cents.',
          targetNoteName: 'Sol4',
          targetFrequencyHz: 392.00,
          targetDurationSeconds: 2.0,
          toleranceCents: 6.0,
          feedbackTip: 'Consonancia perfecta con el Do fundamental.',
        ),
        GuidedLessonStepEntity(
          stepIndex: 3,
          instruction: 'Octava: Toca Do5 por 3.0 segundos con precisión de ±6 cents.',
          targetNoteName: 'Do5',
          targetFrequencyHz: 523.25,
          targetDurationSeconds: 3.0,
          toleranceCents: 6.0,
          feedbackTip: 'Resonancia brillante y relajada en la cima del arpegio.',
        ),
      ],
    ),
  ];
}
