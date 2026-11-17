/// Tipos de archivos musicales y técnicos soportados en el ecosistema Tunner.
enum StudioFileType {
  project(
    extension: '.tunner',
    displayName: 'Proyecto Tunner',
    category: 'Sesión',
    colorHex: 0xFF00E5FF, // Cian neón
  ),
  score(
    extension: '.musicxml',
    displayName: 'Partitura & Notación',
    category: 'Composición',
    colorHex: 0xFF10B981, // Esmeralda
  ),
  audioWav(
    extension: '.wav',
    displayName: 'Toma de Audio WAV',
    category: 'Audio',
    colorHex: 0xFFFF5252, // Rojo grabación
  ),
  rackTool(
    extension: '.tnt',
    displayName: 'Preset de Herramienta',
    category: 'Módulo Rack',
    colorHex: 0xFF8B5CF6, // Púrpura synth
  ),
  tuningPreset(
    extension: '.tpreset',
    displayName: 'Preset de Afinación',
    category: 'Calibración',
    colorHex: 0xFFFFAB00, // Ámbar cálido
  ),
  djBlueprint(
    extension: '.djblueprint',
    displayName: 'Modelo de Consola DJ',
    category: 'Hardware DJ',
    colorHex: 0xFF3D5AFE, // Azul club
  ),
  genericFile(
    extension: '.bin',
    displayName: 'Archivo de Datos',
    category: 'Sistema',
    colorHex: 0xFF8E9BAE, // Gris neutro
  );

  final String extension;
  final String displayName;
  final String category;
  final int colorHex;

  const StudioFileType({
    required this.extension,
    required this.displayName,
    required this.category,
    required this.colorHex,
  });

  /// Deduce el tipo de archivo según la extensión del nombre provisto.
  static StudioFileType fromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.tunner')) return StudioFileType.project;
    if (lower.endsWith('.musicxml') || lower.endsWith('.mxl') || lower.endsWith('.xml')) {
      return StudioFileType.score;
    }
    if (lower.endsWith('.wav') || lower.endsWith('.pcm') || lower.endsWith('.aif')) {
      return StudioFileType.audioWav;
    }
    if (lower.endsWith('.tnt')) return StudioFileType.rackTool;
    if (lower.endsWith('.tpreset')) return StudioFileType.tuningPreset;
    if (lower.endsWith('.djblueprint') || lower.endsWith('.djkeymap')) {
      return StudioFileType.djBlueprint;
    }
    return StudioFileType.genericFile;
  }
}
