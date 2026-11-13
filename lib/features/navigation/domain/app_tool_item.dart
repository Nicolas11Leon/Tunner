import 'package:flutter/material.dart';

/// Categorías funcionales de las herramientas de Tunner.
enum AppToolCategory {
  tuner('Afinación & Sonido', Icons.tune),
  metronome('Ritmo & Tiempo', Icons.av_timer),
  learning('Tutor & Aprendizaje', Icons.school),
  recording('Grabación & Estudio', Icons.mic),
  library('Canciones & Partituras', Icons.menu_book),
  acousticLab('Laboratorio Acústico', Icons.science),
  settings('Calibración & Ajustes', Icons.settings);

  final String displayName;
  final IconData icon;
  const AppToolCategory(this.displayName, this.icon);
}

/// Elemento inmutable que describe una herramienta o función en el catálogo global.
class AppToolItem {
  final String id;
  final String title;
  final String subtitle;
  final AppToolCategory category;
  final IconData icon;
  final List<String> keywords;
  final int? targetTabIndex;
  final String? actionId;

  const AppToolItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.keywords,
    this.targetTabIndex,
    this.actionId,
  });
}

/// Catálogo canónico de herramientas y motor de búsqueda universal (Spotlight Search).
class AppToolCatalog {
  const AppToolCatalog._();

  static const List<AppToolItem> tools = [
    // 1. Afinación
    AppToolItem(
      id: 'tuner_screen',
      title: 'Afinador de Precisión',
      subtitle: 'Afinación cromática con aguja centesimal y estroboscopio',
      category: AppToolCategory.tuner,
      icon: Icons.tune,
      keywords: ['afinar', 'afinador', 'pitch', 'aguja', 'cents', 'estroboscopio', 'frecuencia', 'herzios'],
      targetTabIndex: 1,
    ),
    AppToolItem(
      id: 'concert_pitch',
      title: 'Calibración A4 (415 Hz - 466 Hz)',
      subtitle: 'Ajuste del tono de concierto de referencia (440 Hz, 442 Hz, 415 Hz Barroco)',
      category: AppToolCategory.tuner,
      icon: Icons.waves,
      keywords: ['440', '442', '415', '432', 'concierto', 'referencia', 'camertono', 'diapason', 'calibrar'],
      actionId: 'open_concert_pitch',
    ),
    AppToolItem(
      id: 'harmonic_tutor',
      title: 'Tutor de Afinación Justa & Rol Armónico',
      subtitle: 'Entonación pura de ensamble, ratios Just Intonation y anulación de batimientos',
      category: AppToolCategory.tuner,
      icon: Icons.graphic_eq,
      keywords: ['armonia', 'justa', 'batimiento', 'consonancia', 'tercera', 'quinta', 'ensamble', 'coro', 'cuerdas', 'puro', 'ji'],
      actionId: 'open_harmonic_tutor',
    ),
    AppToolItem(
      id: 'temperaments',
      title: 'Temperamentos Históricos & Microtonalidad',
      subtitle: 'Pitagórico, Mesotónico, Werckmeister, Vallotti y Just Intonation',
      category: AppToolCategory.tuner,
      icon: Icons.history_edu,
      keywords: ['temperamento', 'pitagorico', 'mesotonico', 'werckmeister', 'vallotti', 'justa', 'antigua', 'barroco'],
      actionId: 'open_temperament_selector',
    ),
    AppToolItem(
      id: 'mic_calibration',
      title: 'Calibración de Micrófono & Puerta de Ruido',
      subtitle: 'Adaptación al ruido ambiental, Noise Gate dBFS y presets de rigurosidad',
      category: AppToolCategory.settings,
      icon: Icons.mic_external_on,
      keywords: ['microfono', 'mic', 'ruido', 'gate', 'sensibilidad', 'ganancia', 'rigurosidad', 'silencio', 'calibrar'],
      actionId: 'open_mic_calibration',
    ),
    AppToolItem(
      id: 'instrument_selector',
      title: 'Selección de Instrumento Musical',
      subtitle: 'Guitarra, Bajo, Trompeta en Si♭, Violín, Cello, Flauta y 21 más',
      category: AppToolCategory.tuner,
      icon: Icons.music_note,
      keywords: ['instrumento', 'guitarra', 'bajo', 'trompeta', 'flauta', 'violin', 'cello', 'saxo', 'clarinete', 'cambiar'],
      actionId: 'open_instrument_selector',
    ),

    // 2. Tutor & Aprendizaje
    AppToolItem(
      id: 'guided_lessons',
      title: 'Aprender a Tocar (Tutor Interactivo)',
      subtitle: 'Lecciones estructuradas paso a paso con validación acústica continua',
      category: AppToolCategory.learning,
      icon: Icons.school,
      keywords: ['aprender', 'lecciones', 'tutor', 'ejercicios', 'estudiar', 'pasos', 'principiante', 'notas'],
      targetTabIndex: 2,
    ),
    AppToolItem(
      id: 'exercise_generator',
      title: 'Generador Algorítmico de Ejercicios',
      subtitle: 'Crea escalas, arpegios y rutinas técnicas a medida para tu nivel',
      category: AppToolCategory.learning,
      icon: Icons.fitness_center,
      keywords: ['ejercicios', 'escalas', 'arpegios', 'rutina', 'entrenar', 'algoritmo', 'generador'],
      actionId: 'open_exercise_generator',
    ),
    AppToolItem(
      id: 'pedagogical_report',
      title: 'Reporte Pedagógico & Certificado PDF',
      subtitle: 'Estadísticas de sesión, estabilidad de embocadura y exportación formal',
      category: AppToolCategory.learning,
      icon: Icons.picture_as_pdf,
      keywords: ['reporte', 'certificado', 'pdf', 'evaluacion', 'estadisticas', 'profesor', 'alumno', 'sesion'],
      actionId: 'open_pedagogical_report',
    ),

    // 3. Ritmo & Metrónomo
    AppToolItem(
      id: 'metronome_tool',
      title: 'Metrónomo Polirrítmico & Audio Clocks',
      subtitle: 'Compases compuestos, subdivisión rítmica y supresión de sangrado',
      category: AppToolCategory.metronome,
      icon: Icons.av_timer,
      keywords: ['metronomo', 'ritmo', 'bpm', 'tempo', 'tiempo', 'subdivision', 'compas', 'click'],
      targetTabIndex: 1,
      actionId: 'focus_metronome',
    ),
    AppToolItem(
      id: 'tap_tempo',
      title: 'Tap Tempo (Detector de Pulsos)',
      subtitle: 'Calcula el BPM exacto tocando rítmicamente la pantalla con el dedo',
      category: AppToolCategory.metronome,
      icon: Icons.touch_app,
      keywords: ['tap', 'tempo', 'pulsos', 'bpm', 'tocar', 'medir'],
      actionId: 'open_tap_tempo',
    ),

    // 4. Grabación & Práctica
    AppToolItem(
      id: 'practice_recorder',
      title: 'Estudio de Grabación & Comparador Espectral',
      subtitle: 'Registra tomas de audio en WAV, reproduce y analiza tu espectro FFT',
      category: AppToolCategory.recording,
      icon: Icons.fiber_manual_record,
      keywords: ['grabar', 'grabacion', 'tomas', 'audio', 'escuchar', 'espectrograma', 'wav', 'estudio'],
      targetTabIndex: 3,
    ),
    AppToolItem(
      id: 'spectral_comparator',
      title: 'Comparador Espectral FFT',
      subtitle: 'Superpone armónicos de dos tomas para verificar proyección y pureza',
      category: AppToolCategory.recording,
      icon: Icons.compare_arrows,
      keywords: ['espectro', 'comparar', 'armonicos', 'fft', 'timbre', 'proyeccion'],
      actionId: 'open_spectral_comparator',
    ),
    AppToolItem(
      id: 'dj_console',
      title: 'Consola de DJ Virtual & Mapeo QWERTY',
      subtitle: 'Mezcla en vivo de pistas y stems con jog wheels, EQ Kill, crossfader curvo y atajos de teclado',
      category: AppToolCategory.recording,
      icon: Icons.album,
      keywords: ['dj', 'consola', 'mezcla', 'mix', 'crossfader', 'teclado', 'qwerty', 'jogwheel', 'scratch', 'bpm', 'sync', 'stems'],
      actionId: 'open_dj_console',
    ),

    // 5. Canciones & Partituras
    AppToolItem(
      id: 'song_library_tool',
      title: 'Biblioteca de Canciones & Pistas Stems',
      subtitle: 'Repertorio adaptado con partitura sincronizada y mezcla por canales',
      category: AppToolCategory.library,
      icon: Icons.library_music,
      keywords: ['canciones', 'biblioteca', 'repertorio', 'stems', 'pistas', 'fur elise', 'canon', 'musica'],
      targetTabIndex: 4,
    ),
    AppToolItem(
      id: 'universal_importer',
      title: 'Importador Universal de Partituras',
      subtitle: 'Carga archivos MusicXML, MIDI, ABC y PDF directamente en el atril',
      category: AppToolCategory.library,
      icon: Icons.file_upload,
      keywords: ['importar', 'partitura', 'musicxml', 'midi', 'pdf', 'abc', 'cargar'],
      actionId: 'open_score_importer',
    ),
    AppToolItem(
      id: 'score_editor',
      title: 'Editor y Creador de Partituras',
      subtitle: 'Escribe compases, notas y silencios con teclado didáctico integrado',
      category: AppToolCategory.library,
      icon: Icons.edit_note,
      keywords: ['editor', 'escribir', 'componer', 'partitura', 'notas', 'descompositor'],
      actionId: 'open_score_editor',
    ),

    // 6. Laboratorio Acústico & Herramientas Pro
    AppToolItem(
      id: 'harmonic_drone',
      title: 'Estudio de Drones Armónicos Acústicos',
      subtitle: 'Sonido continuo de referencia afinado por quintas y octavas',
      category: AppToolCategory.acousticLab,
      icon: Icons.graphic_eq,
      keywords: ['drone', 'pedal', 'armonico', 'continuo', 'referencia', 'sintetizador', 'tonal'],
      actionId: 'open_drone_studio',
    ),
    AppToolItem(
      id: 'polyphonic_chords',
      title: 'Reconocedor Polifónico de Acordes',
      subtitle: 'Identifica acordes mayores, menores, séptimas y notas simultáneas',
      category: AppToolCategory.acousticLab,
      icon: Icons.piano,
      keywords: ['acordes', 'polifonia', 'armonia', 'reconocedor', 'triadas', 'septimas'],
      actionId: 'open_chord_analyzer',
    ),
    AppToolItem(
      id: 'vocal_autotune',
      title: 'AutoTune Vocal & Corrección de Tono',
      subtitle: 'Cuantización de escalas y corrección melódica en tiempo real',
      category: AppToolCategory.acousticLab,
      icon: Icons.mic_external_on_outlined,
      keywords: ['autotune', 'voz', 'canto', 'correccion', 'cuantizacion', 'escala'],
      actionId: 'open_autotune',
    ),
    AppToolItem(
      id: 'soundfont_synthesizer',
      title: 'Banco de Sonidos Acústicos SoundFont SF2',
      subtitle: 'Timbres reales de Piano de Cola, Flauta, Violín, Cello y Guitarras',
      category: AppToolCategory.acousticLab,
      icon: Icons.album,
      keywords: ['soundfont', 'sf2', 'timbres', 'sintesis', 'piano', 'guitarra', 'muestras'],
      actionId: 'open_soundfont_bank',
    ),
  ];

  /// Busca herramientas de forma predictiva por texto libre en tiempo real.
  static List<AppToolItem> searchTools(String query) {
    final cleanQuery = _normalize(query);
    if (cleanQuery.isEmpty) {
      return tools;
    }

    final terms = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

    return tools.where((tool) {
      final titleNorm = _normalize(tool.title);
      final subtitleNorm = _normalize(tool.subtitle);
      final categoryNorm = _normalize(tool.category.displayName);
      final keywordsNorm = tool.keywords.map(_normalize).toList();

      for (final term in terms) {
        final matches = titleNorm.contains(term) ||
            subtitleNorm.contains(term) ||
            categoryNorm.contains(term) ||
            keywordsNorm.any((k) => k.contains(term));

        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }
}
