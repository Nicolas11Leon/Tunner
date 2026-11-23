/// Entidad inmutable que representa una plantilla canónica de script Tunner DSL.
class TunnerDslTemplate {
  /// Identificador único en formato kebab-case o snake_case (ej. 'ambient_chords').
  final String id;

  /// Título formal descriptivo de la plantilla.
  final String title;

  /// Categoría pedagógica o de producción (ej. 'Ambient / Soundscape', 'Electronic / Bassline', 'Vocal Coaching').
  final String category;

  /// Tempo de referencia sugerido en BPM.
  final double defaultBpm;

  /// Explicación pedagógica y acústica de lo que ejecuta el script.
  final String description;

  /// Ruta al activo físico dentro del repositorio.
  final String assetPath;

  /// Código fuente declarativo canónico en lenguaje Tunner DSL.
  final String sourceCode;

  const TunnerDslTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.defaultBpm,
    required this.description,
    required this.assetPath,
    required this.sourceCode,
  });
}

/// Catálogo canónico de plantillas declarativas Tunner DSL.
///
/// Implementado en la capa de Dominio en Dart puro para garantizar
/// disponibilidad offline y evaluación determinista en cualquier entorno.
class TunnerDslTemplateCatalog {
  /// Plantilla 1: Progresiones modales y espacialización binaural con reverberación.
  static const TunnerDslTemplate ambientChords = TunnerDslTemplate(
    id: 'ambient_chords',
    title: 'Ambient Modal Chords & Spatial Reverb',
    category: 'Ambient / Soundscape',
    defaultBpm: 72.0,
    description:
        'Configura una reverberacion espacial Schroeder-Moorer amplia, pad triangular con release largo y progresiones modales complejas.',
    assetPath: 'assets/dsl/ambient_chords.tun',
    sourceCode: '''
// Ambient Chords - Progresiones modales y reverberacion espacial en Tunner DSL
tempo 72;

// Configuracion de canales y ruteo
channel ambient;
connect @ambient.out -> @master.in;

// Parametros acusticos de reverberacion espacial Schroeder-Moorer
set @reverb.room = 0.85;
set @reverb.damp = 0.20;
set @reverb.wet = 0.65;
set @spatial.distance = 2.5;

// Sintetizador polifonico: envolvente de pad ambiental
set @synth.waveform = "triangle";
set @synth.attack = 350 ms;
set @synth.decay = 200 ms;
set @synth.sustain = 0.8;
set @synth.release = 1200 ms;

// Progresion modal armonica
chord [D3, F3, A3, C4, E4] 1/2;
chord [G2, F3, B3, E4] 1/2;
chord [C3, E3, G3, B3, D4] 1/2;
chord [A2, E3, G3, C4] 1/2;

play;
''',
  );

  /// Plantilla 2: Línea de bajo ácida a 135 BPM con envolventes sintetizadas percusivas.
  static const TunnerDslTemplate acidBassline = TunnerDslTemplate(
    id: 'acid_bassline',
    title: 'Acid Bassline 135 BPM',
    category: 'Electronic / Bassline',
    defaultBpm: 135.0,
    description:
        'Configura un sintetizador con onda diente de sierra, envolvente ultrarrapida, realce de graves y bucle de bajo de 16 notas.',
    assetPath: 'assets/dsl/acid_bassline.tun',
    sourceCode: '''
// Acid Bassline - Sintetizador a 135 BPM y envolventes rapidas en Tunner DSL
tempo 135;

// Canal y conexion directa al bus maestro
channel bass;
connect @bass.out -> @master.in;

// Modulacion de ecualizacion con realce de frecuencias graves
set @eq.low = 4.0 dB;
set @eq.high = 2.5 dB;

// Sintetizador con oscilador diente de sierra y envolvente percusiva corta
set @synth.waveform = "sawtooth";
set @synth.attack = 5 ms;
set @synth.decay = 90 ms;
set @synth.sustain = 0.2;
set @synth.release = 50 ms;

// Patron secuencial de bajo acido en bucle
loop 2 {
  note C2 1/16;
  note C2 1/16;
  note Eb2 1/16;
  note F2 1/16;
  note F#2 1/16;
  note G2 1/16;
  note Bb2 1/16;
  note C3 1/16;
}

play;
''',
  );

  /// Plantilla 3: Rutina pedagógica de calentamiento vocal con escalas diatónicas transpuestas.
  static const TunnerDslTemplate vocalWarmupRoutine = TunnerDslTemplate(
    id: 'vocal_warmup_routine',
    title: 'Vocal Diatonic Warmup Routine',
    category: 'Pedagogy / Vocal Coaching',
    defaultBpm: 96.0,
    description:
        'Guia acustica con tono senoidal suave que ejecuta escalas diatonicas de 5 notas en C, D y E mayor para preparacion de cuerdas vocales.',
    assetPath: 'assets/dsl/vocal_warmup_routine.tun',
    sourceCode: '''
// Vocal Warmup Routine - Escalas diatonicas para entrenamiento vocal en Tunner DSL
tempo 96;

// Canal dedicado a guia vocal
channel vocal;
connect @vocal.out -> @master.in;

// Sintetizador con oscilador senoidal suave para referencia tonal pura
set @synth.waveform = "sine";
set @synth.attack = 50 ms;
set @synth.decay = 80 ms;
set @synth.sustain = 0.9;
set @synth.release = 150 ms;

// 1. Escala diatonica ascendente y descendente en C Mayor
note C4 1/8;
note D4 1/8;
note E4 1/8;
note F4 1/8;
note G4 1/4;
note F4 1/8;
note E4 1/8;
note D4 1/8;
note C4 1/4;
rest 1/4;

// 2. Transposicion a D Mayor
note D4 1/8;
note E4 1/8;
note F#4 1/8;
note G4 1/8;
note A4 1/4;
note G4 1/8;
note F#4 1/8;
note E4 1/8;
note D4 1/4;
rest 1/4;

// 3. Transposicion a E Mayor
note E4 1/8;
note F#4 1/8;
note G#4 1/8;
note A4 1/8;
note B4 1/4;
note A4 1/8;
note G#4 1/8;
note F#4 1/8;
note E4 1/4;

play;
''',
  );

  /// Retorna la lista inmutable con todas las plantillas canónicas registradas.
  static List<TunnerDslTemplate> get allTemplates => const [
        ambientChords,
        acidBassline,
        vocalWarmupRoutine,
      ];

  /// Busca una plantilla por su ID o nombre de archivo (con o sin extensión .tun).
  static TunnerDslTemplate? findById(String query) {
    final clean = query.trim().toLowerCase().replaceAll('.tun', '');
    for (final template in allTemplates) {
      if (template.id.toLowerCase() == clean) {
        return template;
      }
    }
    return null;
  }
}
