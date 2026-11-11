/// Direccion fisica del transductor o puerto de audio.
enum EndpointDirection {
  input('Entrada'),
  output('Salida');

  final String displayName;
  const EndpointDirection(this.displayName);
}

/// Tipologia de transductor acustico o dispositivo de hardware conectado.
enum AudioEndpointType {
  /// Microfono integrado del chasis del dispositivo.
  builtInMic('Microfono Integrado', EndpointDirection.input, false),

  /// Interfaz de audio USB externa profesional (e.g. Focusrite, Behringer, MOTU).
  usbAudioInterfaceInput('Interfaz USB (Entrada)', EndpointDirection.input, true),

  /// Microfono inalambrico Bluetooth (con compresion HSP/HFP).
  bluetoothInput('Microfono Bluetooth', EndpointDirection.input, false),

  /// Altavoces integrados del dispositivo.
  builtInSpeaker('Altavoz Integrado', EndpointDirection.output, false),

  /// Auriculares cableados (Jack 3.5mm o USB-C DAC).
  wiredHeadphones('Auriculares Cableados', EndpointDirection.output, true),

  /// Salida balanceada de monitores en interfaz USB externa.
  usbAudioInterfaceOutput('Interfaz USB (Salida)', EndpointDirection.output, true),

  /// Auriculares inalambricos Bluetooth (perfil A2DP).
  bluetoothOutput('Auriculares Bluetooth', EndpointDirection.output, false);

  final String displayName;
  final EndpointDirection direction;

  /// True si el transductor esta desacoplado acusticamente del microfono integrado,
  /// permitiendo monitoreo en vivo sin riesgo de retroalimentacion (acople).
  final bool isFeedbackSafe;

  const AudioEndpointType(this.displayName, this.direction, this.isFeedbackSafe);
}

/// Entidad inmutable de dominio que representa un puerto o transductor fisico de audio.
class HardwareAudioEndpoint {
  final String id;
  final String name;
  final AudioEndpointType type;
  final int sampleRate;
  final int channelCount;
  final bool supportsRawCapture;

  const HardwareAudioEndpoint({
    required this.id,
    required this.name,
    required this.type,
    this.sampleRate = 44100,
    this.channelCount = 1,
    this.supportsRawCapture = true,
  });

  EndpointDirection get direction => type.direction;
  bool get isFeedbackSafe => type.isFeedbackSafe;
  bool get isInput => direction == EndpointDirection.input;
  bool get isOutput => direction == EndpointDirection.output;

  HardwareAudioEndpoint copyWith({
    String? id,
    String? name,
    AudioEndpointType? type,
    int? sampleRate,
    int? channelCount,
    bool? supportsRawCapture,
  }) {
    return HardwareAudioEndpoint(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      sampleRate: sampleRate ?? this.sampleRate,
      channelCount: channelCount ?? this.channelCount,
      supportsRawCapture: supportsRawCapture ?? this.supportsRawCapture,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HardwareAudioEndpoint &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HardwareAudioEndpoint($id, $name, $type, $sampleRate Hz)';
}
