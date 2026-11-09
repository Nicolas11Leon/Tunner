/// Dominios principales de aprendizaje y práctica musical en Tunner.
enum TaskDomain {
  ear('EAR', 'Entrenamiento Auditivo', 'Discriminación de intervalos, acordes y tonos'),
  rhythm('RHY', 'Ritmo & Metrónomo', 'Compases, polirritmias, síncopas y tempo'),
  pitch('PCH', 'Afinación & Tono', 'Notas largas, estabilidad estroboscópica y cents'),
  sightReading('SGT', 'Lectura & Partitura', 'Lectura a primera vista en pentagrama SMuFL'),
  harmony('HRM', 'Armonía & Acordes', 'Voicing, inversiones y progresiones armónicas'),
  technique('TEC', 'Técnica Instrumental', 'Digitación, arpegios y escalas virtuosas');

  final String code;
  final String displayName;
  final String description;

  const TaskDomain(this.code, this.displayName, this.description);

  static TaskDomain? fromCode(String code) {
    final upper = code.toUpperCase().trim();
    for (final d in TaskDomain.values) {
      if (d.code == upper) return d;
    }
    return null;
  }
}

/// Niveles pedagógicos estandarizados de dificultad.
enum TaskLevel {
  level1(1, '01', 'Principiante', 'Nivel Fundacional'),
  level2(2, '02', 'Intermedio', 'Nivel Técnico'),
  level3(3, '03', 'Avanzado', 'Nivel de Maestría'),
  level4(4, '04', 'Conservatorio', 'Grado Superior'),
  level5(5, '05', 'Virtuoso', 'Grado Concertista');

  final int numericValue;
  final String code;
  final String displayName;
  final String description;

  const TaskLevel(this.numericValue, this.code, this.displayName, this.description);

  static TaskLevel? fromNumeric(int value) {
    for (final l in TaskLevel.values) {
      if (l.numericValue == value) return l;
    }
    return null;
  }

  static TaskLevel? fromCode(String code) {
    final clean = code.trim();
    for (final l in TaskLevel.values) {
      if (l.code == clean || l.numericValue.toString() == clean) return l;
    }
    return null;
  }
}

/// Subtipos técnicos específicos de tareas pedagógicas.
enum TaskSubtype {
  intervals('INTV', 'Intervalos'),
  polyrhythm('POLY', 'Polirritmias'),
  strobe('STRB', 'Afinación Estroboscópica'),
  smufl('SMUF', 'Notación SMuFL'),
  voicing('VOIC', 'Voicing Armónico'),
  longTones('LONG', 'Notas Largas'),
  syncopation('SYNC', 'Síncopas'),
  arpeggios('ARPG', 'Arpegios'),
  scales('SCAL', 'Escalas');

  final String code;
  final String displayName;

  const TaskSubtype(this.code, this.displayName);

  static TaskSubtype? fromCode(String code) {
    final upper = code.toUpperCase().trim();
    for (final s in TaskSubtype.values) {
      if (s.code == upper) return s;
    }
    return null;
  }
}

/// Value Object inmutable que representa el Código Canónico de Taxonomía de Tareas (TTC).
///
/// Estructura formal: `[DOMINIO].[NIVEL].[SUBTIPO].[SECUENCIAL]` (ej: `EAR.01.INTV.001`).
/// Implementa [Comparable] para permitir ordenamiento natural determinista en tiempo logarítmico.
class TaskTaxonomyCode implements Comparable<TaskTaxonomyCode> {
  static final RegExp _codeRegex = RegExp(r'^([A-Z]{3})\.([0-9]{2})\.([A-Z]{4})\.([0-9]{3})$');

  final TaskDomain domain;
  final TaskLevel level;
  final TaskSubtype subtype;
  final int sequence;

  const TaskTaxonomyCode({
    required this.domain,
    required this.level,
    required this.subtype,
    required this.sequence,
  }) : assert(sequence >= 1 && sequence <= 999, 'La secuencia debe estar comprendida entre 1 y 999');

  /// Representación canónica en cadena (ej: 'EAR.01.INTV.001').
  String get formatted =>
      '${domain.code}.${level.code}.${subtype.code}.${sequence.toString().padLeft(3, '0')}';

  /// Nombre corto amigable para pantallas reducidas (ej: 'E1-001').
  String get shortCode =>
      '${domain.code[0]}${level.numericValue}-${sequence.toString().padLeft(3, '0')}';

  /// Parsea una cadena al código taxonómico correspondiente.
  /// Lanza [FormatException] si el formato es inválido o alguno de los componentes no existe.
  factory TaskTaxonomyCode.parse(String input) {
    final trimmed = input.trim().toUpperCase();
    final match = _codeRegex.firstMatch(trimmed);

    if (match == null) {
      throw FormatException(
        'Código TTC inválido: "$input". El formato obligatorio es [DOMINIO].[NIVEL].[SUBTIPO].[NUMERO] (ej: EAR.01.INTV.001)',
      );
    }

    final domainStr = match.group(1)!;
    final levelStr = match.group(2)!;
    final subtypeStr = match.group(3)!;
    final seqStr = match.group(4)!;

    final domain = TaskDomain.fromCode(domainStr);
    if (domain == null) {
      throw FormatException('Dominio desconocido: "$domainStr" en código "$input"');
    }

    final level = TaskLevel.fromCode(levelStr);
    if (level == null) {
      throw FormatException('Nivel desconocido: "$levelStr" en código "$input"');
    }

    final subtype = TaskSubtype.fromCode(subtypeStr);
    if (subtype == null) {
      throw FormatException('Subtipo desconocido: "$subtypeStr" en código "$input"');
    }

    final sequence = int.parse(seqStr);

    return TaskTaxonomyCode(
      domain: domain,
      level: level,
      subtype: subtype,
      sequence: sequence,
    );
  }

  /// Intenta parsear una cadena; retorna null de forma segura si no cumple el estándar.
  static TaskTaxonomyCode? tryParse(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    try {
      return TaskTaxonomyCode.parse(input);
    } catch (_) {
      return null;
    }
  }

  @override
  int compareTo(TaskTaxonomyCode other) {
    // Ordenar primero por dominio, luego por nivel, subtipo y secuencia
    final domainComp = domain.index.compareTo(other.domain.index);
    if (domainComp != 0) return domainComp;

    final levelComp = level.numericValue.compareTo(other.level.numericValue);
    if (levelComp != 0) return levelComp;

    final subtypeComp = subtype.index.compareTo(other.subtype.index);
    if (subtypeComp != 0) return subtypeComp;

    return sequence.compareTo(other.sequence);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTaxonomyCode &&
          runtimeType == other.runtimeType &&
          domain == other.domain &&
          level == other.level &&
          subtype == other.subtype &&
          sequence == other.sequence;

  @override
  int get hashCode => Object.hash(domain, level, subtype, sequence);

  @override
  String toString() => formatted;
}
