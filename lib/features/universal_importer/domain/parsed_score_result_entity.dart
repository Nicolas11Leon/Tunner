import '../../song_library/domain/song_package_entity.dart';

/// Resultado consolidado de la ingesta y decodificación de un archivo musical externo.
/// Totalmente puro: sin dependencias de Flutter UI.
class ParsedScoreResult {
  final SongPackage package;
  final String format; // "MusicXML" o "MIDI"
  final int totalMeasures;
  final int totalNotes;
  final List<String> warnings;

  const ParsedScoreResult({
    required this.package,
    required this.format,
    required this.totalMeasures,
    required this.totalNotes,
    this.warnings = const [],
  });

  bool get hasWarnings => warnings.isNotEmpty;
}
