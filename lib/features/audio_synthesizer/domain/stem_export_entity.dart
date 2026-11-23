import 'dart:typed_data';

/// Configuración paramétrica para la exportación de stems y secuencias MIDI.
class StemExportConfig {
  final int sampleRate;
  final bool includeMasterMixdown;
  final bool includeIndividualStems;
  final bool includeMidiFile;
  final bool includeMelodyTrack;
  final bool includeMetronomeTrack;
  final bool includeAccompanimentTrack;
  final bool includeRecordedTake;

  const StemExportConfig({
    this.sampleRate = 44100,
    this.includeMasterMixdown = true,
    this.includeIndividualStems = true,
    this.includeMidiFile = true,
    this.includeMelodyTrack = true,
    this.includeMetronomeTrack = true,
    this.includeAccompanimentTrack = true,
    this.includeRecordedTake = false,
  });

  StemExportConfig copyWith({
    int? sampleRate,
    bool? includeMasterMixdown,
    bool? includeIndividualStems,
    bool? includeMidiFile,
    bool? includeMelodyTrack,
    bool? includeMetronomeTrack,
    bool? includeAccompanimentTrack,
    bool? includeRecordedTake,
  }) {
    return StemExportConfig(
      sampleRate: sampleRate ?? this.sampleRate,
      includeMasterMixdown: includeMasterMixdown ?? this.includeMasterMixdown,
      includeIndividualStems: includeIndividualStems ?? this.includeIndividualStems,
      includeMidiFile: includeMidiFile ?? this.includeMidiFile,
      includeMelodyTrack: includeMelodyTrack ?? this.includeMelodyTrack,
      includeMetronomeTrack: includeMetronomeTrack ?? this.includeMetronomeTrack,
      includeAccompanimentTrack: includeAccompanimentTrack ?? this.includeAccompanimentTrack,
      includeRecordedTake: includeRecordedTake ?? this.includeRecordedTake,
    );
  }

  Map<String, dynamic> toJson() => {
        'sampleRate': sampleRate,
        'includeMasterMixdown': includeMasterMixdown,
        'includeIndividualStems': includeIndividualStems,
        'includeMidiFile': includeMidiFile,
        'includeMelodyTrack': includeMelodyTrack,
        'includeMetronomeTrack': includeMetronomeTrack,
        'includeAccompanimentTrack': includeAccompanimentTrack,
        'includeRecordedTake': includeRecordedTake,
      };

  factory StemExportConfig.fromJson(Map<String, dynamic> json) => StemExportConfig(
        sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 44100,
        includeMasterMixdown: json['includeMasterMixdown'] as bool? ?? true,
        includeIndividualStems: json['includeIndividualStems'] as bool? ?? true,
        includeMidiFile: json['includeMidiFile'] as bool? ?? true,
        includeMelodyTrack: json['includeMelodyTrack'] as bool? ?? true,
        includeMetronomeTrack: json['includeMetronomeTrack'] as bool? ?? true,
        includeAccompanimentTrack: json['includeAccompanimentTrack'] as bool? ?? true,
        includeRecordedTake: json['includeRecordedTake'] as bool? ?? false,
      );
}

/// Representa un archivo individual de audio o MIDI generado en el proceso de exportación.
class ExportedStemFile {
  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  final Duration duration;
  final String description;

  const ExportedStemFile({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
    required this.duration,
    required this.description,
  });

  int get sizeBytes => bytes.lengthInBytes;

  /// Retorna el tamaño del archivo formateado en KB o MB legibles.
  String get formattedSize {
    if (sizeBytes < 1024) {
      return "$sizeBytes B";
    } else if (sizeBytes < 1024 * 1024) {
      final kb = (sizeBytes / 1024).toStringAsFixed(1);
      return "$kb KB";
    } else {
      final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(2);
      return "$mb MB";
    }
  }

  /// Serializa metadatos del archivo exportado (sin bytes binarios).
  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'durationMs': duration.inMilliseconds,
        'description': description,
      };
}

/// Paquete consolidado resultante de una exportación de stems y síntesis de audio/MIDI.
class ExportBundleResult {
  final List<ExportedStemFile> files;
  final DateTime createdAt;

  const ExportBundleResult({
    required this.files,
    required this.createdAt,
  });

  int get totalBytes => files.fold(0, (acc, f) => acc + f.sizeBytes);

  String get formattedTotalSize {
    if (totalBytes < 1024 * 1024) {
      final kb = (totalBytes / 1024).toStringAsFixed(1);
      return "$kb KB";
    }
    final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(2);
    return "$mb MB";
  }

  bool get isEmpty => files.isEmpty;
  bool get isNotEmpty => files.isNotEmpty;
}
