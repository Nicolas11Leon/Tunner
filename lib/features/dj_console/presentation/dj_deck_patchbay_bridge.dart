import 'dart:typed_data';

import '../../../core/channels/domain/studio_modular_plug.dart';
import '../../../core/channels/domain/studio_patchbay_routing_service.dart';
import '../../../core/channels/domain/studio_plug_type.dart';
import 'dj_console_view_model.dart';

/// Puente reutilizable entre una vista de Consola DJ y [IStudioPatchbayRoutingService].
///
/// Encapsula el registro de plugs modulares, la escucha bidireccional de señales
/// y la publicación de parámetros de los Decks A y B utilizando identificadores
/// aislados por instancia (`'${scopePrefix}_plug_dj_deck_a_in'`), eliminando
/// colisiones globales cuando coexisten varias vistas DJ.
class DjDeckPatchbayBridge {
  static int _instanceSequence = 0;

  /// Genera un prefijo determinista único por instancia para evitar colisiones
  /// entre múltiples vistas de Consola DJ montadas simultáneamente.
  static String nextScopePrefix([String base = 'dj']) {
    _instanceSequence++;
    return '${base}_$_instanceSequence';
  }

  final DjConsoleViewModel viewModel;
  final IStudioPatchbayRoutingService routingService;
  final String scopePrefix;
  final bool includeMasterOut;

  late final StudioModularPlug deckAPlug;
  late final StudioModularPlug deckBPlug;
  late final StudioModularPlug? masterOutPlug;

  bool _isDisposed = false;

  DjDeckPatchbayBridge({
    required this.viewModel,
    IStudioPatchbayRoutingService? routingService,
    String? scopePrefix,
    this.includeMasterOut = false,
  })  : routingService = routingService ?? StudioPatchbayRoutingService(),
        scopePrefix = (scopePrefix != null && scopePrefix.trim().isNotEmpty)
            ? scopePrefix.trim()
            : nextScopePrefix() {
    deckAPlug = StudioModularPlug(
      id: deckAPlugId,
      label: 'IN DECK A',
      toolId: 'dj_console',
      type: StudioPlugType.audioInput,
      connectedChannelId: 'canal_a',
    );
    deckBPlug = StudioModularPlug(
      id: deckBPlugId,
      label: 'IN DECK B',
      toolId: 'dj_console',
      type: StudioPlugType.audioInput,
      connectedChannelId: 'canal_b',
    );
    masterOutPlug = includeMasterOut
        ? StudioModularPlug(
            id: masterOutPlugId,
            label: 'OUT MASTER',
            toolId: 'dj_console',
            type: StudioPlugType.audioOutput,
            connectedChannelId: 'canal_d',
          )
        : null;

    this.routingService.registerPlug(deckAPlug);
    this.routingService.registerPlug(deckBPlug);
    if (masterOutPlug != null) {
      this.routingService.registerPlug(masterOutPlug!);
    }

    this.routingService.registerSinkListener(
      deckAPlug.id,
      (sourceId, channelId, payload) => _handleDeckSignal(
        deckId: 'A',
        ownPlugId: deckAPlug.id,
        sourceId: sourceId,
        payload: payload,
      ),
    );
    this.routingService.registerSinkListener(
      deckBPlug.id,
      (sourceId, channelId, payload) => _handleDeckSignal(
        deckId: 'B',
        ownPlugId: deckBPlug.id,
        sourceId: sourceId,
        payload: payload,
      ),
    );

    viewModel.addListener(_syncDecksToChannels);
  }

  /// Identificador con ámbito de instancia para el plug de entrada del Deck A.
  String get deckAPlugId => '${scopePrefix}_plug_dj_deck_a_in';

  /// Identificador con ámbito de instancia para el plug de entrada del Deck B.
  String get deckBPlugId => '${scopePrefix}_plug_dj_deck_b_in';

  /// Identificador con ámbito de instancia para el plug de salida Master.
  String get masterOutPlugId => '${scopePrefix}_plug_dj_master_out';

  bool get isDisposed => _isDisposed;

  void _handleDeckSignal({
    required String deckId,
    required String ownPlugId,
    required String sourceId,
    required Map<String, dynamic> payload,
  }) {
    if (_isDisposed || sourceId == ownPlugId) return;

    final deck = deckId == 'A' ? viewModel.deckA : viewModel.deckB;
    final wavBytes = payload['wavBytes'] as Uint8List?;
    final filePath = payload['filePath'] as String?;
    final title = payload['title'] as String?;
    final bpm = (payload['bpm'] as num?)?.toDouble();
    final key = payload['key'] as String?;

    if (wavBytes != null || filePath != null) {
      viewModel.loadDeckTrack(
        deckId: deckId,
        wavBytes: wavBytes,
        filePath: filePath,
        title: title,
        bpm: bpm,
      );
    } else if (title != null || bpm != null || key != null) {
      viewModel.loadTrackSimple(
        deckId,
        title: title ?? deck.trackTitle,
        bpm: bpm ?? deck.bpm,
        camelotKey: key ?? deck.camelotKey,
      );
    }

    final isPlaying = payload['isPlaying'] as bool?;
    final refreshedDeck = deckId == 'A' ? viewModel.deckA : viewModel.deckB;
    if (isPlaying != null && isPlaying != refreshedDeck.isPlaying) {
      viewModel.togglePlay(deckId);
    }
  }

  void _syncDecksToChannels() {
    if (_isDisposed) return;

    final plugA = routingService.plugs[deckAPlug.id];
    if (plugA != null && plugA.isConnected) {
      routingService.publishChannelParameters(
        plugA.connectedChannelId!,
        title: viewModel.deckA.trackTitle,
        bpm: viewModel.deckA.effectiveBpm,
        key: viewModel.deckA.effectiveCamelotKey.code,
        isPlaying: viewModel.deckA.isPlaying,
        positionMs: viewModel.deckA.currentPositionMs,
        initiatorPlugId: deckAPlug.id,
      );
    }

    final plugB = routingService.plugs[deckBPlug.id];
    if (plugB != null && plugB.isConnected) {
      routingService.publishChannelParameters(
        plugB.connectedChannelId!,
        title: viewModel.deckB.trackTitle,
        bpm: viewModel.deckB.effectiveBpm,
        key: viewModel.deckB.effectiveCamelotKey.code,
        isPlaying: viewModel.deckB.isPlaying,
        positionMs: viewModel.deckB.currentPositionMs,
        initiatorPlugId: deckBPlug.id,
      );
    }
  }

  /// Publica un activo de audio hacia el bus de canal de mezclador del patchbay
  /// sin sobrescribir directamente el estado local del Deck A.
  void publishMixerChannelAsset({
    String channelId = 'canal_c',
    required String title,
    required double bpm,
    required String camelotKey,
    required Float32List pcmBuffer,
  }) {
    if (_isDisposed) return;
    routingService.publishChannelParameters(
      channelId,
      title: title,
      bpm: bpm,
      key: camelotKey,
      pcmBuffer: pcmBuffer,
    );
  }

  /// Libera listeners y desconecta únicamente los plugs pertenecientes a esta instancia.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    viewModel.removeListener(_syncDecksToChannels);
    routingService.unregisterSinkListener(deckAPlug.id);
    routingService.unregisterSinkListener(deckBPlug.id);
    routingService.disconnectPlug(deckAPlug.id);
    routingService.disconnectPlug(deckBPlug.id);
    if (masterOutPlug != null) {
      routingService.disconnectPlug(masterOutPlug!.id);
    }
  }
}
