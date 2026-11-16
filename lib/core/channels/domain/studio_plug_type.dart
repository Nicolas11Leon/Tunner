/// Tipos de plugs modulares para interconexión de herramientas.
enum StudioPlugType {
  audioInput('Entrada Audio', true),
  audioOutput('Salida Audio', false),
  midiInput('Entrada MIDI', true),
  midiOutput('Salida MIDI', false),
  clockSyncInput('Entrada Sync Clock', true),
  clockSyncOutput('Salida Sync Clock', false);

  final String displayName;
  final bool isInput;

  const StudioPlugType(this.displayName, this.isInput);

  bool get isOutput => !isInput;
}
