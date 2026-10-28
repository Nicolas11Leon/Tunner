/// Tipos de espacio de trabajo especializados en Tunner.
enum WorkspaceType {
  /// Espacio dedicado a la práctica instrumental, afinación y pedagogía.
  learning,

  /// Espacio dedicado a la notación, lectura y edición de partituras.
  composition,

  /// Espacio dedicado a la ingeniería acústica, espectrogramas y temperamentos.
  production;

  /// Nombre visible formal del espacio.
  String get displayName {
    switch (this) {
      case WorkspaceType.learning:
        return 'Aprender';
      case WorkspaceType.composition:
        return 'Componer';
      case WorkspaceType.production:
        return 'Producir';
    }
  }

  /// Subtítulo o lema pedagógico/técnico.
  String get tagline {
    switch (this) {
      case WorkspaceType.learning:
        return 'Práctica, Afinación & Pedagogía';
      case WorkspaceType.composition:
        return 'Notación, Partituras & Transcripción';
      case WorkspaceType.production:
        return 'Laboratorio Acústico & Audio';
    }
  }

  /// Clave serializable para persistencia JSON.
  String get serializedKey {
    switch (this) {
      case WorkspaceType.learning:
        return 'learning';
      case WorkspaceType.composition:
        return 'composition';
      case WorkspaceType.production:
        return 'production';
    }
  }

  /// Deserializa desde una clave en almacenamiento local.
  static WorkspaceType fromSerializedKey(String? key) {
    switch (key) {
      case 'composition':
        return WorkspaceType.composition;
      case 'production':
        return WorkspaceType.production;
      case 'learning':
      default:
        return WorkspaceType.learning;
    }
  }
}

/// Configuración de visibilidad y herramientas por espacio de trabajo.
class WorkspaceConfigurationEntity {
  final WorkspaceType type;
  final bool showMetronome;
  final bool showStrobeTuner;
  final bool showSheetMusicCanvas;
  final bool showAcousticSpectrogram;
  final bool showChordAnalyzer;

  const WorkspaceConfigurationEntity({
    required this.type,
    this.showMetronome = true,
    this.showStrobeTuner = true,
    this.showSheetMusicCanvas = true,
    this.showAcousticSpectrogram = false,
    this.showChordAnalyzer = false,
  });

  /// Configuración predeterminada según el modo seleccionado.
  factory WorkspaceConfigurationEntity.defaultFor(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.learning:
        return const WorkspaceConfigurationEntity(
          type: WorkspaceType.learning,
          showMetronome: true,
          showStrobeTuner: true,
          showSheetMusicCanvas: true,
          showAcousticSpectrogram: false,
          showChordAnalyzer: false,
        );
      case WorkspaceType.composition:
        return const WorkspaceConfigurationEntity(
          type: WorkspaceType.composition,
          showMetronome: true,
          showStrobeTuner: false,
          showSheetMusicCanvas: true,
          showAcousticSpectrogram: false,
          showChordAnalyzer: false,
        );
      case WorkspaceType.production:
        return const WorkspaceConfigurationEntity(
          type: WorkspaceType.production,
          showMetronome: false,
          showStrobeTuner: true,
          showSheetMusicCanvas: false,
          showAcousticSpectrogram: true,
          showChordAnalyzer: true,
        );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.serializedKey,
      'showMetronome': showMetronome,
      'showStrobeTuner': showStrobeTuner,
      'showSheetMusicCanvas': showSheetMusicCanvas,
      'showAcousticSpectrogram': showAcousticSpectrogram,
      'showChordAnalyzer': showChordAnalyzer,
    };
  }

  factory WorkspaceConfigurationEntity.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return WorkspaceConfigurationEntity.defaultFor(WorkspaceType.learning);
    }
    final type = WorkspaceType.fromSerializedKey(map['type'] as String?);
    return WorkspaceConfigurationEntity(
      type: type,
      showMetronome: map['showMetronome'] as bool? ?? true,
      showStrobeTuner: map['showStrobeTuner'] as bool? ?? true,
      showSheetMusicCanvas: map['showSheetMusicCanvas'] as bool? ?? true,
      showAcousticSpectrogram: map['showAcousticSpectrogram'] as bool? ?? false,
      showChordAnalyzer: map['showChordAnalyzer'] as bool? ?? false,
    );
  }

  WorkspaceConfigurationEntity copyWith({
    WorkspaceType? type,
    bool? showMetronome,
    bool? showStrobeTuner,
    bool? showSheetMusicCanvas,
    bool? showAcousticSpectrogram,
    bool? showChordAnalyzer,
  }) {
    return WorkspaceConfigurationEntity(
      type: type ?? this.type,
      showMetronome: showMetronome ?? this.showMetronome,
      showStrobeTuner: showStrobeTuner ?? this.showStrobeTuner,
      showSheetMusicCanvas: showSheetMusicCanvas ?? this.showSheetMusicCanvas,
      showAcousticSpectrogram: showAcousticSpectrogram ?? this.showAcousticSpectrogram,
      showChordAnalyzer: showChordAnalyzer ?? this.showChordAnalyzer,
    );
  }
}
