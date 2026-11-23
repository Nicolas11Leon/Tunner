import 'package:flutter/material.dart';
import '../../design_system/atoms/studio_hairline.dart';
import '../../design_system/atoms/studio_icon.dart';
import '../../design_system/atoms/studio_listenable_builder.dart';
import '../../design_system/domain/studio_icon_catalog.dart';
import '../../design_system/studio_design_tokens.dart';
import '../../design_system/studio_theme_provider.dart';
import '../domain/audio_device_matrix_entity.dart';
import '../infrastructure/studio_audio_device_matrix_service.dart';
import '../infrastructure/studio_master_clock_service.dart';
import 'panels/hardware_endpoints_panel.dart';
import 'panels/master_clock_panel.dart';
import 'panels/master_strip_panel.dart';
import 'panels/mastering_chain_panel.dart';
import 'panels/matrix_routing_panel.dart';

/// Consola Maestra de E/S de Hardware y Reloj de Transporte Global de Tunner Studio.
/// Orquesta cinco paneles atomicos estrictamente tipados para conmutar transductores fisicos,
/// ajustar ganancia maestra, calibrar cadena DSP y enrutar canales virtuales.
class StudioMasterHardwareConsoleWidget extends StatelessWidget {
  final StudioAudioDeviceMatrixService matrixService;
  final StudioMasterClockService clockService;

  const StudioMasterHardwareConsoleWidget({
    super.key,
    required this.matrixService,
    required this.clockService,
  });

  /// Despliega la consola maestra en un modal de alta fidelidad.
  static void show(
    BuildContext context, {
    required StudioAudioDeviceMatrixService matrixService,
    required StudioMasterClockService clockService,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0x00000000),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
          child: StudioMasterHardwareConsoleWidget(
            matrixService: matrixService,
            clockService: clockService,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StudioDesignTokens tokens = StudioThemeScope.tokensOf(context);

    return StudioListenableBuilder(
      listenable: matrixService,
      builder: (context, _) {
        return StudioListenableBuilder(
          listenable: clockService,
          builder: (context, _) {
            final AudioDeviceMatrixEntity matrix = matrixService.matrix;

            return Container(
              decoration: BoxDecoration(
                color: tokens.panelBackground,
                borderRadius: BorderRadius.circular(tokens.radiusMedium),
                border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: tokens.canvasBackground.withValues(alpha: 0.65),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, tokens),
                  const StudioHairline(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: HardwareEndpointsPanel(
                                  tokens: tokens,
                                  matrix: matrix,
                                  matrixService: matrixService,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 4,
                                child: MasterClockPanel(
                                  tokens: tokens,
                                  clockService: clockService,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          MasterStripPanel(
                            tokens: tokens,
                            matrix: matrix,
                            matrixService: matrixService,
                          ),
                          const SizedBox(height: 16),
                          MasteringChainPanel(
                            tokens: tokens,
                            matrix: matrix,
                            matrixService: matrixService,
                          ),
                          const SizedBox(height: 16),
                          MatrixRoutingPanel(
                            tokens: tokens,
                            matrix: matrix,
                            matrixService: matrixService,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const StudioHairline(),
                  _buildFooter(tokens, matrix),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, StudioDesignTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusMedium)),
      ),
      child: Row(
        children: [
          StudioIcon(
            StudioIconId.moduleTuner,
            size: 18,
            color: tokens.accentPrimary,
            tintCustomAsset: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSOLA MAESTRA DE E/S & RELOJ GLOBAL',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Matriz de transductores físicos y sincronización de transporte unificado',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tokens.accentPrimary.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Tartini DSP 2.1',
              style: TextStyle(
                color: tokens.accentPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: StudioIcon(
              StudioIconId.uiCloseConfirm,
              size: 18,
              color: tokens.textSecondary,
              tintCustomAsset: true,
            ),
            tooltip: 'Cerrar Consola',
            onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(StudioDesignTokens tokens, AudioDeviceMatrixEntity matrix) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(tokens.radiusMedium)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                StudioIcon(
                  StudioIconId.modulePatchbay,
                  size: 14,
                  color: tokens.textSecondary,
                  tintCustomAsset: true,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Canales Activos: ${matrix.channelRoutings.length} asignados a bus Master',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textSecondary, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Ctrl+Shift+I',
            style: TextStyle(
              color: tokens.accentPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
