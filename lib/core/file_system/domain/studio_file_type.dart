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

  static const Set<String> _audioExtensions = {
    '.wav',
    '.pcm',
    '.aif',
    '.aiff',
    '.mp3',
    '.flac',
    '.ogg',
    '.m4a',
    '.aac',
    '.opus',
    '.wma',
    '.webm',
  };

  static const Set<String> _scoreExtensions = {
    '.musicxml',
    '.mxl',
    '.xml',
    '.mid',
    '.midi',
    '.abc',
    '.pdf',
  };

  /// Deduce el tipo de archivo según la extensión del nombre provisto.
  static StudioFileType fromFileName(String fileName) {
    final lower = fileName.trim().toLowerCase();
    if (lower.endsWith('.tunner')) return StudioFileType.project;
    if (_scoreExtensions.any(lower.endsWith)) {
      return StudioFileType.score;
    }
    if (_audioExtensions.any(lower.endsWith)) {
      return StudioFileType.audioWav;
    }
    if (lower.endsWith('.tnt')) return StudioFileType.rackTool;
    if (lower.endsWith('.tpreset')) return StudioFileType.tuningPreset;
    if (lower.endsWith('.djblueprint') || lower.endsWith('.djkeymap')) {
      return StudioFileType.djBlueprint;
    }
    return StudioFileType.genericFile;
  }

  /// Extrae la extensión real del archivo en minúsculas con punto inicial (ej. `.mp3`).
  /// Si el nombre no contiene una extensión explícita válida, retorna [fallbackType.extension].
  static String extractExtension(String fileName, StudioFileType fallbackType) {
    final trimmed = fileName.trim();
    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex >= trimmed.length - 1) {
      return fallbackType.extension;
    }
    final ext = trimmed.substring(dotIndex).toLowerCase();
    if (ext.contains('/') || ext.contains('\\') || ext.contains(' ')) {
      return fallbackType.extension;
    }
    return ext;
  }
}
