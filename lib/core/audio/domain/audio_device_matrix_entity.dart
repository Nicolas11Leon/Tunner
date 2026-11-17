import 'dart:math' as math;
import 'audio_device_entity.dart';

/// Entidad inmutable que representa el estado de enrutamiento y calibración
/// de la Matriz de Dispositivos de Audio y Consola Maestra de Tunner Studio.
class AudioDeviceMatrixEntity {
  final AudioDeviceEntity activeInputDevice;
  final AudioDeviceEntity activeOutputDevice;
  final AudioDeviceEntity? cueOutputDevice;
  final List<AudioDeviceEntity> availableInputs;
  final List<AudioDeviceEntity> availableOutputs;
  
  /// Tamaño de búfer en muestras de audio (128, 256, 512, 1024).
  final int bufferSize;

  /// Frecuencia de muestreo en Hz (ej. 44100, 48000).
  final int sampleRate;

  /// Ganancia lineal del bus maestro (0.0 a 1.5). 1.0 equivale a 0 dBFS.
  final double masterGain;

  /// Indica si la salida maestra está completamente silenciada (Mute).
  final bool isMuted;

  /// Indica si la salida maestra está atenuada en -20 dB (DIM).
  final bool isDimmed;

  /// Indica si la mezcla estéreo L/R se colapsa a una señal monoaural idéntica (MONO).
  final bool isMono;

  /// Mapeo de enrutamiento de canales de audio virtuales hacia destinos de bus.
  /// Ejemplo: {'dj_deck_a': 'master', 'dj_deck_b': 'cue', 'metronome_click': 'master'}
  final Map<String, String> channelRoutings;

  const AudioDeviceMatrixEntity({
    required this.activeInputDevice,
    required this.activeOutputDevice,
    this.cueOutputDevice,
    this.availableInputs = const [],
    this.availableOutputs = const [],
    this.bufferSize = 512,
    this.sampleRate = 44100,
    this.masterGain = 1.0,
    this.isMuted = false,
    this.isDimmed = false,
    this.isMono = false,
    this.channelRoutings = const {
      'dj_deck_a': 'master',
      'dj_deck_b': 'master',
      'metronome_click': 'master',
      'tuning_diapason': 'master',
      'instrument_note': 'master',
      'harmonic_drone': 'master',
      'practice_take': 'master',
    },
  });

  /// Crea una configuración por defecto con dispositivos estándar del sistema.
  factory AudioDeviceMatrixEntity.defaultConfiguration() {
    final defInput = AudioDeviceEntity.systemDefault();
    final defOutput = AudioDeviceEntity.defaultOutput();
    final cueOut = AudioDeviceEntity.cueHeadphones();

    return AudioDeviceMatrixEntity(
      activeInputDevice: defInput,
      activeOutputDevice: defOutput,
      cueOutputDevice: cueOut,
      availableInputs: [defInput],
      availableOutputs: [defOutput, cueOut],
      bufferSize: 512,
      sampleRate: 44100,
      masterGain: 1.0,
      isMuted: false,
      isDimmed: false,
      isMono: false,
    );
  }

  /// Latencia acústica de búfer teórica estimada en milisegundos:
  /// $$\text{Latencia (ms)} = \frac{\text{bufferSize}}{\text{sampleRate}} \times 1000$$
  double get estimatedBufferLatencyMs => (bufferSize / sampleRate) * 1000.0;

  /// Nivel de ganancia efectiva considerando los modificadores MUTE y DIM (-20 dB).
  ///
  /// $$-20\text{ dB} \implies 10^{-\frac{20}{20}} = 0.1$$
  double get effectiveMasterGain {
    if (isMuted) return 0.0;
    if (isDimmed) return masterGain * 0.1;
    return masterGain;
  }

  /// Nivel de ganancia maestro expresado en decibelios (dB).
  ///
  /// $$\text{dB} = 20 \log_{10}(\text{gain})$$
  double get masterGainDb {
    if (masterGain <= 0.00001) return -96.0;
    return 20.0 * (math.log(masterGain) / math.ln10);
  }

  AudioDeviceMatrixEntity copyWith({
    AudioDeviceEntity? activeInputDevice,
    AudioDeviceEntity? activeOutputDevice,
    AudioDeviceEntity? cueOutputDevice,
    List<AudioDeviceEntity>? availableInputs,
    List<AudioDeviceEntity>? availableOutputs,
    int? bufferSize,
    int? sampleRate,
    double? masterGain,
    bool? isMuted,
    bool? isDimmed,
    bool? isMono,
    Map<String, String>? channelRoutings,
  }) {
    return AudioDeviceMatrixEntity(
      activeInputDevice: activeInputDevice ?? this.activeInputDevice,
      activeOutputDevice: activeOutputDevice ?? this.activeOutputDevice,
      cueOutputDevice: cueOutputDevice ?? this.cueOutputDevice,
      availableInputs: availableInputs ?? this.availableInputs,
      availableOutputs: availableOutputs ?? this.availableOutputs,
      bufferSize: bufferSize ?? this.bufferSize,
      sampleRate: sampleRate ?? this.sampleRate,
      masterGain: masterGain ?? this.masterGain,
      isMuted: isMuted ?? this.isMuted,
      isDimmed: isDimmed ?? this.isDimmed,
      isMono: isMono ?? this.isMono,
      channelRoutings: channelRoutings ?? this.channelRoutings,
    );
  }

  Map<String, dynamic> toJson() => {
        'activeInputDevice': activeInputDevice.toJson(),
        'activeOutputDevice': activeOutputDevice.toJson(),
        'cueOutputDevice': cueOutputDevice?.toJson(),
        'bufferSize': bufferSize,
        'sampleRate': sampleRate,
        'masterGain': masterGain,
        'isMuted': isMuted,
        'isDimmed': isDimmed,
        'isMono': isMono,
        'channelRoutings': channelRoutings,
      };

  factory AudioDeviceMatrixEntity.fromJson(Map<String, dynamic> json) {
    return AudioDeviceMatrixEntity(
      activeInputDevice: json['activeInputDevice'] != null
          ? AudioDeviceEntity.fromJson(json['activeInputDevice'] as Map<String, dynamic>)
          : AudioDeviceEntity.systemDefault(),
      activeOutputDevice: json['activeOutputDevice'] != null
          ? AudioDeviceEntity.fromJson(json['activeOutputDevice'] as Map<String, dynamic>)
          : AudioDeviceEntity.defaultOutput(),
      cueOutputDevice: json['cueOutputDevice'] != null
          ? AudioDeviceEntity.fromJson(json['cueOutputDevice'] as Map<String, dynamic>)
          : null,
      bufferSize: json['bufferSize'] as int? ?? 512,
      sampleRate: json['sampleRate'] as int? ?? 44100,
      masterGain: (json['masterGain'] as num?)?.toDouble() ?? 1.0,
      isMuted: json['isMuted'] as bool? ?? false,
      isDimmed: json['isDimmed'] as bool? ?? false,
      isMono: json['isMono'] as bool? ?? false,
      channelRoutings: (json['channelRoutings'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {
            'dj_deck_a': 'master',
            'dj_deck_b': 'master',
            'metronome_click': 'master',
            'tuning_diapason': 'master',
            'instrument_note': 'master',
            'harmonic_drone': 'master',
            'practice_take': 'master',
          },
    );
  }
}
