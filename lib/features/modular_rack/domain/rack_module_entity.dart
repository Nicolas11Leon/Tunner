import 'port_id.dart';
import 'signal_type.dart';

/// Tipo de módulo funcional disponible en el Rack de Estudio.
enum RackModuleType {
  /// Afinador Estroboscópico de ultra alta precisión (±0.1 cents, MPM/NSDF).
  strobeTuner('strobe_tuner', 'Afinador Estroboscópico Pro', 'TUN'),

  /// Metrónomo determinista con reloj en Isolate y Tap Tempo.
  metronome('metronome', 'Metrónomo Determinista', 'CLK'),

  /// Pentagrama vectorial SMuFL interactivo con modo "Tocar y Transcribir".
  scoreNotation('score_notation', 'Pentagrama en Vivo & Partitura', 'SCR'),

  /// Grabador de práctica de estudio con auto-escucha y bucles.
  practiceRecorder('practice_recorder', 'Grabador de Audio & Auto-Escucha', 'REC'),

  /// Procesador de afinación vocal y corrección de tono en tiempo real.
  vocalAutoTune('vocal_autotune', 'Autotune & Corrector de Tono DSP', 'ATN'),

  /// Dron armónico tonal de quintas y sobretonos de oído.
  harmonicDrone('harmonic_drone', 'Dron Armónico & Afinación de Oído', 'DRN'),

  /// Espectrograma FFT y distribución de armónicos acústicos.
  spectrogram('spectrogram', 'Espectrograma FFT & Armónicos', 'FFT'),

  /// Analizador de acordes polifónicos en tiempo real.
  chordAnalyzer('chord_analyzer', 'Analizador Polifónico de Acordes', 'CHD'),

  /// Tutor de lecciones guiadas y evaluación de rushing/dragging.
  guidedLessons('guided_lessons', 'Tutor & Lecciones Interactivas', 'TTR'),

  /// Entrenador auditivo de intervalos a ciegas.
  earTrainer('ear_trainer', 'Entrenador Auditivo a Ciegas', 'EAR'),

  /// Consola DJ virtual con decks, EQ, FX, Camelot y Smart Automix.
  djConsole('dj_console', 'Consola DJ & Automix Pro', 'DJ'),

  /// Mezclador multipista de stems con paneo estereo, mute y solo.
  stemMixer('stem_mixer', 'Mezclador Multipista de Stems', 'MIX');

  final String code;
  final String displayName;
  final String icon;

  const RackModuleType(this.code, this.displayName, this.icon);
}

/// Estado de visualización y despliegue del módulo en el rack.
enum ModuleViewMode {
  /// Modo colapsado: Barra delgada con controles esenciales (48-60px de alto).
  compact('compact', 'Modo Compacto'),

  /// Modo expandido: Vista completa de trabajo con todos los diales y visualizadores.
  expanded('expanded', 'Modo Expandido');

  final String code;
  final String displayName;

  const ModuleViewMode(this.code, this.displayName);
}

/// Entidad inmutable que representa una unidad de módulo montada en el Rack de Estudio.
class RackModuleEntity {
  /// ID único de la instancia montada en el rack (ej: 'rack_unit_tuner_1').
  final String moduleId;

  /// Tipo de módulo.
  final RackModuleType moduleType;

  /// Título personalizado o nombre del módulo.
  final String title;

  /// Estado de vista (compacto o expandido).
  final ModuleViewMode viewMode;

  /// Orden secuencial en la pila de módulos (0, 1, 2, ...).
  final int orderIndex;

  /// Indica si el módulo está actualmente encendido y procesando.
  final bool isPoweredOn;

  /// Lista de puertos de entrada disponibles en este módulo.
  final List<PortId> inputPorts;

  /// Lista de puertos de salida que emite este módulo.
  final List<PortId> outputPorts;

  const RackModuleEntity({
    required this.moduleId,
    required this.moduleType,
    required this.title,
    this.viewMode = ModuleViewMode.expanded,
    required this.orderIndex,
    this.isPoweredOn = true,
    this.inputPorts = const [],
    this.outputPorts = const [],
  });

  /// Crea una instancia estándar con los puertos canónicos predefinidos de su tipo.
  factory RackModuleEntity.standard(RackModuleType type, int orderIndex, {String? customId}) {
    final id = customId ?? 'mod_${type.code}_$orderIndex';

    final inputs = <PortId>[];
    final outputs = <PortId>[];

    switch (type) {
      case RackModuleType.strobeTuner:
        inputs.add(PortId(
          id: 'audio_in',
          displayName: 'Entrada Mic / Audio',
          signalType: SignalType.audioPcm,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'pitch_out',
          displayName: 'Pitch & Cents Detectado',
          signalType: SignalType.pitchEvents,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.metronome:
        outputs.add(PortId(
          id: 'clock_out',
          displayName: 'Pulso de Reloj (BPM)',
          signalType: SignalType.temporalClock,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.scoreNotation:
        inputs.add(PortId(
          id: 'clock_in',
          displayName: 'Reloj de Sincronía',
          signalType: SignalType.temporalClock,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        inputs.add(PortId(
          id: 'pitch_in',
          displayName: 'Notas en Vivo (Mic-to-Score)',
          signalType: SignalType.pitchEvents,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'notes_out',
          displayName: 'Flujo de Notas Escritas',
          signalType: SignalType.musicalNotes,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.practiceRecorder:
        inputs.add(PortId(
          id: 'audio_in',
          displayName: 'Entrada de Grabación',
          signalType: SignalType.audioPcm,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'playback_out',
          displayName: 'Salida de Reproducción',
          signalType: SignalType.audioPcm,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.vocalAutoTune:
        inputs.add(PortId(
          id: 'vocal_in',
          displayName: 'Entrada Voz Cruda',
          signalType: SignalType.audioPcm,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'tuned_out',
          displayName: 'Voz Corregida DSP',
          signalType: SignalType.audioPcm,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.harmonicDrone:
        outputs.add(PortId(
          id: 'drone_audio_out',
          displayName: 'Audio Dron Tonal',
          signalType: SignalType.audioPcm,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.spectrogram:
        inputs.add(PortId(
          id: 'audio_in',
          displayName: 'Entrada Espectral',
          signalType: SignalType.audioPcm,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.chordAnalyzer:
        inputs.add(PortId(
          id: 'audio_in',
          displayName: 'Entrada Polifónica',
          signalType: SignalType.audioPcm,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.guidedLessons:
        inputs.add(PortId(
          id: 'pitch_in',
          displayName: 'Evaluación de Notas',
          signalType: SignalType.pitchEvents,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'lesson_clock_out',
          displayName: 'Tempo de la Lección',
          signalType: SignalType.temporalClock,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.earTrainer:
        inputs.add(PortId(
          id: 'pitch_in',
          displayName: 'Entrada de Canto / Afinación',
          signalType: SignalType.pitchEvents,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'audio_out',
          displayName: 'Tono de Referencia / Intervalo',
          signalType: SignalType.audioPcm,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.djConsole:
        inputs.add(PortId(
          id: 'clock_in',
          displayName: 'Sincronia Reloj BPM',
          signalType: SignalType.temporalClock,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        inputs.add(PortId(
          id: 'audio_in',
          displayName: 'Entrada Audio Auxiliar DJ',
          signalType: SignalType.audioPcm,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'master_audio_out',
          displayName: 'Salida Master DJ PCM',
          signalType: SignalType.audioPcm,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'clock_out',
          displayName: 'Pulso Master BPM DJ',
          signalType: SignalType.temporalClock,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;

      case RackModuleType.stemMixer:
        inputs.add(PortId(
          id: 'stem_audio_in',
          displayName: 'Entrada Audio de Stems',
          signalType: SignalType.audioPcm,
          direction: PortDirection.input,
          ownerModuleId: id,
        ));
        outputs.add(PortId(
          id: 'master_mix_out',
          displayName: 'Salida Master Mezclador',
          signalType: SignalType.audioPcm,
          direction: PortDirection.output,
          ownerModuleId: id,
        ));
        break;
    }

    return RackModuleEntity(
      moduleId: id,
      moduleType: type,
      title: type.displayName,
      viewMode: ModuleViewMode.expanded,
      orderIndex: orderIndex,
      isPoweredOn: true,
      inputPorts: inputs,
      outputPorts: outputs,
    );
  }

  RackModuleEntity copyWith({
    String? title,
    ModuleViewMode? viewMode,
    int? orderIndex,
    bool? isPoweredOn,
  }) {
    return RackModuleEntity(
      moduleId: moduleId,
      moduleType: moduleType,
      title: title ?? this.title,
      viewMode: viewMode ?? this.viewMode,
      orderIndex: orderIndex ?? this.orderIndex,
      isPoweredOn: isPoweredOn ?? this.isPoweredOn,
      inputPorts: inputPorts,
      outputPorts: outputPorts,
    );
  }

  Map<String, dynamic> toJson() => {
        'moduleId': moduleId,
        'moduleType': moduleType.code,
        'title': title,
        'viewMode': viewMode.code,
        'orderIndex': orderIndex,
        'isPoweredOn': isPoweredOn,
        'inputPorts': inputPorts.map((p) => p.toJson()).toList(growable: false),
        'outputPorts': outputPorts.map((p) => p.toJson()).toList(growable: false),
      };

  factory RackModuleEntity.fromJson(Map<String, dynamic> json) {
    final rawType = json['moduleType'] as String? ?? RackModuleType.strobeTuner.code;
    final moduleType = RackModuleType.values.firstWhere(
      (t) => t.code == rawType || t.name == rawType,
      orElse: () => RackModuleType.strobeTuner,
    );
    final rawViewMode = json['viewMode'] as String? ?? ModuleViewMode.expanded.code;
    final viewMode = ModuleViewMode.values.firstWhere(
      (v) => v.code == rawViewMode || v.name == rawViewMode,
      orElse: () => ModuleViewMode.expanded,
    );
    final int orderIndex = (json['orderIndex'] as num?)?.toInt() ?? 0;
    final String moduleId =
        json['moduleId'] as String? ?? 'mod_${moduleType.code}_$orderIndex';

    final rawInputs = json['inputPorts'] as List<dynamic>?;
    final rawOutputs = json['outputPorts'] as List<dynamic>?;
    final standardFallback = RackModuleEntity.standard(
      moduleType,
      orderIndex,
      customId: moduleId,
    );

    final inputs = rawInputs != null
        ? rawInputs
            .whereType<Map<String, dynamic>>()
            .map(PortId.fromJson)
            .toList(growable: false)
        : standardFallback.inputPorts;
    final outputs = rawOutputs != null
        ? rawOutputs
            .whereType<Map<String, dynamic>>()
            .map(PortId.fromJson)
            .toList(growable: false)
        : standardFallback.outputPorts;

    return RackModuleEntity(
      moduleId: moduleId,
      moduleType: moduleType,
      title: json['title'] as String? ?? moduleType.displayName,
      viewMode: viewMode,
      orderIndex: orderIndex,
      isPoweredOn: json['isPoweredOn'] as bool? ?? true,
      inputPorts: inputs,
      outputPorts: outputs,
    );
  }
}
