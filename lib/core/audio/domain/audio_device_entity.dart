/// Representación inmutable de una interfaz física o virtual de captura de audio.
class AudioDeviceEntity {
  final String id;
  final String label;
  final bool isDefault;
  final int inputChannels;
  final List<int> supportedSampleRates;

  const AudioDeviceEntity({
    required this.id,
    required this.label,
    this.isDefault = false,
    this.inputChannels = 1,
    this.supportedSampleRates = const [44100, 48000],
  });

  /// Crea un dispositivo genérico o por defecto del sistema.
  factory AudioDeviceEntity.systemDefault() {
    return const AudioDeviceEntity(
      id: 'default',
      label: 'Micrófono Predeterminado del Sistema',
      isDefault: true,
      inputChannels: 1,
      supportedSampleRates: [44100, 48000],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDeviceEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AudioDeviceEntity(id: $id, label: $label, channels: $inputChannels)';
}
