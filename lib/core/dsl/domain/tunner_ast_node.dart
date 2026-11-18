/// Clase base inmutable para todos los nodos del Árbol de Sintaxis Abstracta (AST) de Tunner DSL.
abstract class TunnerAstNode {
  const TunnerAstNode();

  /// Despacha la visita del nodo para evaluación o formateo (patrón Visitor).
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context);
}

/// Nodo base para todas las sentencias ejecutables del lenguaje.
abstract class TunnerStatementNode extends TunnerAstNode {
  const TunnerStatementNode();
}

/// Nodo raíz del programa que contiene la secuencia de sentencias del script.
class ProgramNode extends TunnerAstNode {
  /// Lista de sentencias secuenciales del script.
  final List<TunnerStatementNode> statements;

  /// Constructor inmutable.
  const ProgramNode(this.statements);

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitProgram(this, context);
}

/// Sentencia de asignación o sincronización de tempo: `tempo <bpm>;`
class TempoStatementNode extends TunnerStatementNode {
  /// Valor del tempo en pulsos por minuto (BPM).
  final double bpm;

  const TempoStatementNode(this.bpm);

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitTempo(this, context);
}

/// Sentencia de declaración de canal virtual de estudio: `channel <nombre>;`
class ChannelDeclNode extends TunnerStatementNode {
  /// Identificador único del canal (e.g. 'synth', 'drums', 'master').
  final String channelName;

  const ChannelDeclNode(this.channelName);

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitChannelDecl(this, context);
}

/// Sentencia de enrutamiento o conexión de matriz de parcheo: `connect @source -> @dest;`
class ConnectStatementNode extends TunnerStatementNode {
  /// Punto de origen con formato `@nodo.puerto` (e.g. '@synth.out').
  final String source;

  /// Punto de destino con formato `@nodo.puerto` (e.g. '@master.in').
  final String destination;

  const ConnectStatementNode({
    required this.source,
    required this.destination,
  });

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitConnect(this, context);
}

/// Sentencia de modulación o asignación de parámetro: `set @target.param = value [unit];`
class SetParamStatementNode extends TunnerStatementNode {
  /// Nodo o dispositivo objetivo (e.g. '@master', '@eq', '@synth').
  final String target;

  /// Nombre del parámetro modificado (e.g. 'gain', 'low', 'waveform', 'attack').
  final String parameter;

  /// Valor asignado (numérico o cadena textual).
  final dynamic value;

  /// Unidad de medida opcional (e.g. 'dB', 'ms', 's', 'Hz').
  final String? unit;

  const SetParamStatementNode({
    required this.target,
    required this.parameter,
    required this.value,
    this.unit,
  });

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitSetParam(this, context);
}

/// Sentencia de emisión de nota individual: `note <pitch> <fraction>;`
/// (e.g. `note C4 1/4;` o `note F#5 1/8;`)
class NoteStatementNode extends TunnerStatementNode {
  /// Altura tonal en notación científica o anglosajona (e.g. 'C4', 'A#4', 'Eb5').
  final String pitch;

  /// Fracción de duración métrica (e.g. '1/4', '1/8', '1/2', '1/16').
  final String durationFraction;

  const NoteStatementNode({
    required this.pitch,
    required this.durationFraction,
  });

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitNote(this, context);
}

/// Sentencia de emisión de acorde polifónico simultáneo: `chord [<pitches>] <fraction>;`
/// (e.g. `chord [C4, E4, G4] 1/2;`)
class ChordStatementNode extends TunnerStatementNode {
  /// Lista de alturas tonales que componen el acorde.
  final List<String> pitches;

  /// Fracción de duración métrica del acorde simultáneo.
  final String durationFraction;

  const ChordStatementNode({
    required this.pitches,
    required this.durationFraction,
  });

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitChord(this, context);
}

/// Sentencia de silencio métrico: `rest <fraction>;` (e.g. `rest 1/4;`)
class RestStatementNode extends TunnerStatementNode {
  /// Fracción métrica de duración del silencio.
  final String durationFraction;

  const RestStatementNode(this.durationFraction);

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitRest(this, context);
}

/// Sentencia de control de transporte: `play;`, `pause;`, `stop;`
class TransportStatementNode extends TunnerStatementNode {
  /// Acción de transporte: 'play', 'pause' o 'stop'.
  final String action;

  const TransportStatementNode(this.action);

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitTransport(this, context);
}

/// Sentencia de bucle repetitivo: `loop <count> { <statements> }`
class LoopStatementNode extends TunnerStatementNode {
  /// Cantidad de repeticiones del bloque de sentencias.
  final int count;

  /// Bloque de sentencias que se repiten dentro del bucle.
  final List<TunnerStatementNode> body;

  const LoopStatementNode({
    required this.count,
    required this.body,
  });

  @override
  R accept<R, C>(TunnerAstVisitor<R, C> visitor, C context) =>
      visitor.visitLoop(this, context);
}

/// Interfaz del patrón Visitor para recorrer y evaluar el Árbol de Sintaxis Abstracta (AST).
abstract class TunnerAstVisitor<R, C> {
  R visitProgram(ProgramNode node, C context);
  R visitTempo(TempoStatementNode node, C context);
  R visitChannelDecl(ChannelDeclNode node, C context);
  R visitConnect(ConnectStatementNode node, C context);
  R visitSetParam(SetParamStatementNode node, C context);
  R visitNote(NoteStatementNode node, C context);
  R visitChord(ChordStatementNode node, C context);
  R visitRest(RestStatementNode node, C context);
  R visitTransport(TransportStatementNode node, C context);
  R visitLoop(LoopStatementNode node, C context);
}
