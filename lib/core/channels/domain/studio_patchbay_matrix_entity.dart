import 'studio_channel_bus.dart';
import 'studio_modular_plug.dart';

/// Opcodes de bajo nivel para compilación DSP de la topología de canales.
enum StudioDspOpcode {
  connectSourceToBus(0x01),
  connectBusToSink(0x02),
  setBusGain(0x03),
  muteBus(0x04),
  disconnectPlug(0x05),
  flushBuffers(0x06);

  final int byteCode;
  const StudioDspOpcode(this.byteCode);
}

/// Instrucción atómica de bajo nivel lista para máquinas virtuales de audio en C/Rust.
class StudioDspInstruction {
  final StudioDspOpcode opcode;
  final String sourceId;
  final String targetId;
  final double parameter;

  const StudioDspInstruction({
    required this.opcode,
    required this.sourceId,
    required this.targetId,
    this.parameter = 0.0,
  });

  @override
  String toString() => '${opcode.name}($sourceId -> $targetId, param: $parameter)';
}

/// Matriz global inmutable de parcheo modular entre plugs y canales.
class StudioPatchbayMatrixEntity {
  final Map<String, StudioChannelBus> channels;
  final Map<String, StudioModularPlug> plugs;

  const StudioPatchbayMatrixEntity({
    required this.channels,
    required this.plugs,
  });

  factory StudioPatchbayMatrixEntity.initial() {
    final channelMap = <String, StudioChannelBus>{};
    for (final ch in StudioChannelBus.defaultTrunkChannels()) {
      channelMap[ch.id] = ch;
    }
    return StudioPatchbayMatrixEntity(
      channels: channelMap,
      plugs: const {},
    );
  }

  /// Retorna todos los plugs que emiten señal hacia un canal dado.
  List<StudioModularPlug> findSourcesForChannel(String channelId) {
    return plugs.values
        .where((p) => p.isOutput && p.connectedChannelId == channelId)
        .toList();
  }

  /// Retorna todos los plugs que reciben señal desde un canal dado.
  List<StudioModularPlug> findSinksForChannel(String channelId) {
    return plugs.values
        .where((p) => p.isInput && p.connectedChannelId == channelId)
        .toList();
  }

  /// Conecta un plug a un canal troncal.
  StudioPatchbayMatrixEntity connectPlug(String plugId, String channelId) {
    final existingPlug = plugs[plugId];
    if (existingPlug == null) return this;

    final updatedPlugs = Map<String, StudioModularPlug>.from(plugs);
    updatedPlugs[plugId] = existingPlug.copyWith(connectedChannelId: channelId);

    return StudioPatchbayMatrixEntity(
      channels: channels,
      plugs: updatedPlugs,
    );
  }

  /// Desconecta un plug de cualquier canal.
  StudioPatchbayMatrixEntity disconnectPlug(String plugId) {
    final existingPlug = plugs[plugId];
    if (existingPlug == null) return this;

    final updatedPlugs = Map<String, StudioModularPlug>.from(plugs);
    updatedPlugs[plugId] = existingPlug.copyWith(clearConnection: true);

    return StudioPatchbayMatrixEntity(
      channels: channels,
      plugs: updatedPlugs,
    );
  }

  /// Registra o actualiza un plug modular.
  StudioPatchbayMatrixEntity registerPlug(StudioModularPlug plug) {
    final updatedPlugs = Map<String, StudioModularPlug>.from(plugs);
    updatedPlugs[plug.id] = plug;

    return StudioPatchbayMatrixEntity(
      channels: channels,
      plugs: updatedPlugs,
    );
  }

  /// Actualiza la ganancia o estado de un canal.
  StudioPatchbayMatrixEntity updateChannel(StudioChannelBus channel) {
    final updatedChannels = Map<String, StudioChannelBus>.from(channels);
    updatedChannels[channel.id] = channel;

    return StudioPatchbayMatrixEntity(
      channels: updatedChannels,
      plugs: plugs,
    );
  }

  /// Compila la topología actual a una secuencia lineal de instrucciones DSP de bajo nivel.
  List<StudioDspInstruction> toDspInstructionSequence() {
    final instructions = <StudioDspInstruction>[];

    for (final channel in channels.values) {
      instructions.add(
        StudioDspInstruction(
          opcode: StudioDspOpcode.setBusGain,
          sourceId: channel.id,
          targetId: 'master',
          parameter: channel.isMuted ? 0.0 : channel.gain,
        ),
      );

      final sources = findSourcesForChannel(channel.id);
      for (final src in sources) {
        instructions.add(
          StudioDspInstruction(
            opcode: StudioDspOpcode.connectSourceToBus,
            sourceId: src.id,
            targetId: channel.id,
          ),
        );
      }

      final sinks = findSinksForChannel(channel.id);
      for (final sink in sinks) {
        instructions.add(
          StudioDspInstruction(
            opcode: StudioDspOpcode.connectBusToSink,
            sourceId: channel.id,
            targetId: sink.id,
          ),
        );
      }
    }

    return instructions;
  }
}
