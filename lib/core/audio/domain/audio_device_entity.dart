/// Dirección del flujo del transductor de audio (captura o emisión).
enum AudioDeviceDirection {
  /// Dispositivo de captura física o virtual (Micrófonos, Entradas de línea, USB Audio In).
  input,

  /// Dispositivo de emisión física o virtual (Monitores de estudio, Auriculares, USB DAC Out).
  output,
}

/// Representación inmutable de una interfaz física o virtual de audio de grado profesional.
class AudioDeviceEntity {
  final String id;
  final String label;
  final bool isDefault;
  final int channels;
  final AudioDeviceDirection direction;
  final List<int> supportedSampleRates;

  const AudioDeviceEntity({
    required this.id,
    required this.label,
    this.isDefault = false,
    int? inputChannels,
    int? channels,
    this.direction = AudioDeviceDirection.input,
    this.supportedSampleRates = const [44100, 48000, 96000],
  }) : channels = channels ?? inputChannels ?? 2;

  /// Accesor de compatibilidad para código existente.
  int get inputChannels => channels;

  /// Crea un dispositivo de entrada predeterminado del sistema operativo.
  factory AudioDeviceEntity.systemDefault() {
    return const AudioDeviceEntity(
      id: 'default',
      label: 'Micrófono / Entrada Predeterminada',
      isDefault: true,
      channels: 1,
      direction: AudioDeviceDirection.input,
      supportedSampleRates: [44100, 48000],
    );
  }

  /// Crea un dispositivo de salida predeterminado del sistema operativo.
  factory AudioDeviceEntity.defaultOutput() {
    return const AudioDeviceEntity(
      id: 'default_output',
      label: 'Monitores / Salida Maestra Predeterminada',
      isDefault: true,
      channels: 2,
      direction: AudioDeviceDirection.output,
      supportedSampleRates: [44100, 48000],
    );
  }

  /// Crea un par de auriculares de monitorización CUE.
  factory AudioDeviceEntity.cueHeadphones() {
    return const AudioDeviceEntity(
      id: 'cue_headphones',
      label: 'Auriculares de Monitoreo CUE',
      isDefault: false,
      channels: 2,
      direction: AudioDeviceDirection.output,
      supportedSampleRates: [44100, 48000],
    );
  }

  AudioDeviceEntity copyWith({
    String? id,
    String? label,
    bool? isDefault,
    int? channels,
    AudioDeviceDirection? direction,
    List<int>? supportedSampleRates,
  }) {
    return AudioDeviceEntity(
      id: id ?? this.id,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      channels: channels ?? this.channels,
      direction: direction ?? this.direction,
      supportedSampleRates: supportedSampleRates ?? this.supportedSampleRates,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'isDefault': isDefault,
        'channels': channels,
        'direction': direction.name,
        'supportedSampleRates': supportedSampleRates,
      };

  factory AudioDeviceEntity.fromJson(Map<String, dynamic> json) {
    return AudioDeviceEntity(
      id: json['id'] as String? ?? 'default',
      label: json['label'] as String? ?? 'Dispositivo Desconocido',
      isDefault: json['isDefault'] as bool? ?? false,
      channels: json['channels'] as int? ?? 2,
      direction: json['direction'] == 'output'
          ? AudioDeviceDirection.output
          : AudioDeviceDirection.input,
      supportedSampleRates: (json['supportedSampleRates'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [44100, 48000],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDeviceEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          direction == other.direction;

  @override
  int get hashCode => Object.hash(id, direction);

  @override
  String toString() =>
      'AudioDeviceEntity(id: $id, label: $label, dir: ${direction.name}, channels: $channels)';
}
