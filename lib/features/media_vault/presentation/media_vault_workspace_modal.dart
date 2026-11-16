import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/design_system/atoms/studio_badge.dart';
import '../../../core/design_system/atoms/studio_button.dart';
import '../../../core/design_system/atoms/studio_panel.dart';
import '../../../core/design_system/atoms/studio_theme_switcher.dart';
import '../../../core/design_system/atoms/studio_toolbar.dart';
import '../../../core/design_system/studio_design_tokens.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../domain/media_asset_entity.dart';
import '../domain/media_synergy_target.dart';
import '../domain/timeline_project_entity.dart';
import 'media_vault_viewmodel.dart';
import 'timeline_arrangement_painter.dart';

/// Full-featured Multimedia Vault, Synchronized Multi-Track Timeline (Drag & Drop),
/// and Universal Import/Export Studio Modal styled with the atomized Adobe Spectrum
/// Design System.
class MediaVaultWorkspaceModal extends StatefulWidget {
  final MediaVaultViewModel viewModel;

  const MediaVaultWorkspaceModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(
    BuildContext context, {
    required MediaVaultViewModel viewModel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog.fullscreen(
        child: MediaVaultWorkspaceModal(viewModel: viewModel),
      ),
    );
  }

  @override
  State<MediaVaultWorkspaceModal> createState() =>
      _MediaVaultWorkspaceModalState();
}

class _MediaVaultWorkspaceModalState extends State<MediaVaultWorkspaceModal> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleImportFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const <String>[
          'wav',
          'mid',
          'midi',
          'musicxml',
          'xml',
          'mxl',
          'abc',
          'pdf',
          'json',
        ],
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      await widget.viewModel.importExternalBytes(
        fileName: file.name,
        bytes: bytes,
      );
    } catch (_) {
      // File picker canceled or unavailable on headless test runner.
    }
  }

  Future<void> _handleExport(MediaExportFormat format) async {
    final result = await widget.viewModel.exportTimeline(format);
    if (!mounted) {
      return;
    }
    final tokens = StudioThemeScope.of(context);
    if (result.success) {
      String savedPathNote = '';
      try {
        final dir = await getApplicationDocumentsDirectory();
        final outFile = File('${dir.path}/${result.fileName}');
        await outFile.writeAsBytes(result.bytes, flush: true);
        savedPathNote = ' | Guardado en ${outFile.path}';
      } catch (_) {
        // Headless test environment without path_provider channel.
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tokens.panelHeaderBackground,
          content: Text(
            '${result.message}$savedPathNote',
            style: TextStyle(color: tokens.textPrimary, fontSize: 12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: tokens.accentDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final assets = vm.filteredAssets;
        final timeline = vm.timeline;

        return Scaffold(
          key: const Key('media_vault_workspace_modal'),
          backgroundColor: tokens.canvasBackground,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _buildTopMenuBar(tokens),
                _buildTransportToolbar(vm, timeline, tokens),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        if (isNarrow) {
                          return Column(
                            children: <Widget>[
                              SizedBox(
                                height: constraints.maxHeight * 0.42,
                                child: _buildVaultPanel(vm, assets, tokens),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: _buildTimelineAndSynergy(
                                  vm,
                                  timeline,
                                  tokens,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: <Widget>[
                            SizedBox(
                              width: 310,
                              child: _buildVaultPanel(vm, assets, tokens),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildTimelineAndSynergy(
                                vm,
                                timeline,
                                tokens,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                _buildStatusFooter(vm, tokens),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopMenuBar(StudioDesignTokens tokens) {
    return StudioToolbar(
      height: 40,
      children: <Widget>[
        Icon(Icons.layers_outlined, size: 16, color: tokens.accentPrimary),
        const SizedBox(width: 8),
        Text(
          'TUNNER STUDIO  |  BOVEDA MULTIMEDIA & LINEA DE TIEMPO',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 18),
        const StudioThemeSwitcher(),
        const SizedBox(width: 10),
        StudioButton(
          key: const Key('media_vault_import_btn'),
          label: 'Importar',
          icon: Icons.file_upload_outlined,
          variant: StudioButtonVariant.secondary,
          compact: true,
          onPressed: _handleImportFile,
        ),
        const SizedBox(width: 6),
        PopupMenuButton<MediaExportFormat>(
          key: const Key('media_vault_export_menu'),
          tooltip: 'Exportar Proyecto / Audio / Partitura',
          color: tokens.panelHeaderBackground,
          onSelected: _handleExport,
          itemBuilder: (context) => MediaExportFormat.values
              .map(
                (fmt) => PopupMenuItem<MediaExportFormat>(
                  value: fmt,
                  child: Text(
                    fmt.displayName,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                  ),
                ),
              )
              .toList(growable: false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: tokens.accentPrimary,
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.file_download_outlined,
                  size: 14,
                  color: tokens.textOnAccent,
                ),
                const SizedBox(width: 5),
                Text(
                  'Exportar',
                  style: TextStyle(
                    color: tokens.textOnAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('media_vault_close_btn'),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.close, size: 17, color: tokens.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTransportToolbar(
    MediaVaultViewModel vm,
    TimelineProjectEntity timeline,
    StudioDesignTokens tokens,
  ) {
    return StudioToolbar(
      height: 36,
      children: <Widget>[
        StudioButton(
          key: const Key('timeline_play_btn'),
          label: vm.isPlaying ? 'Pausa' : 'Reproducir',
          icon: vm.isPlaying ? Icons.pause : Icons.play_arrow,
          variant: vm.isPlaying
              ? StudioButtonVariant.primary
              : StudioButtonVariant.secondary,
          compact: true,
          onPressed: vm.togglePlayback,
        ),
        const SizedBox(width: 6),
        StudioButton(
          key: const Key('timeline_stop_btn'),
          label: 'Stop',
          icon: Icons.stop,
          variant: StudioButtonVariant.secondary,
          compact: true,
          onPressed: vm.stopPlayback,
        ),
        const SizedBox(width: 10),
        StudioBadge(
          label: '${(vm.playheadMs / 1000.0).toStringAsFixed(2)} s',
          accentColor: tokens.accentPrimary,
        ),
        const SizedBox(width: 12),
        StudioButton(
          label: '-',
          compact: true,
          onPressed: () => vm.setMasterBpm(timeline.masterBpm - 2.0),
        ),
        const SizedBox(width: 4),
        StudioBadge(
          label: '${timeline.masterBpm.toStringAsFixed(0)} BPM',
        ),
        const SizedBox(width: 4),
        StudioButton(
          label: '+',
          compact: true,
          onPressed: () => vm.setMasterBpm(timeline.masterBpm + 2.0),
        ),
        const SizedBox(width: 10),
        StudioToggleChip(
          key: const Key('timeline_snap_chip'),
          label: 'Snap Beatgrid',
          icon: Icons.grid_on,
          selected: timeline.snapToBeatgrid,
          onTap: vm.toggleSnapToBeatgrid,
        ),
        const SizedBox(width: 10),
        StudioButton(
          label: 'Zoom -',
          compact: true,
          onPressed: () => vm.setZoom(vm.pixelsPerSecond - 20.0),
        ),
        const SizedBox(width: 4),
        StudioButton(
          label: 'Zoom +',
          compact: true,
          onPressed: () => vm.setZoom(vm.pixelsPerSecond + 20.0),
        ),
      ],
    );
  }

  Widget _buildVaultPanel(
    MediaVaultViewModel vm,
    List<MediaAssetEntity> assets,
    StudioDesignTokens tokens,
  ) {
    return StudioPanel(
      title: 'Boveda de Activos (${assets.length})',
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const Key('media_vault_search_field'),
            controller: _searchController,
            onChanged: vm.setSearchQuery,
            style: TextStyle(color: tokens.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Filtrar por nombre, tipo, BPM o Camelot...',
              hintStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
              prefixIcon: Icon(Icons.search, color: tokens.textMuted, size: 16),
              filled: true,
              fillColor: tokens.inputSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                borderSide: BorderSide(color: tokens.borderHairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                borderSide: BorderSide(color: tokens.borderFocus),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                StudioToggleChip(
                  label: 'Todos',
                  selected: vm.kindFilter == null,
                  onTap: () => vm.setKindFilter(null),
                ),
                const SizedBox(width: 4),
                ...MediaAssetKind.values.map(
                  (kind) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: StudioToggleChip(
                      label: kind.displayName,
                      selected: vm.kindFilter == kind,
                      onTap: () => vm.setKindFilter(
                        vm.kindFilter == kind ? null : kind,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: assets.isEmpty
                ? Center(
                    child: Text(
                      'Sin activos que coincidan con el filtro.',
                      style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                    ),
                  )
                : ListView.builder(
                    itemCount: assets.length,
                    itemBuilder: (context, index) {
                      final asset = assets[index];
                      return _buildDraggableAssetRow(vm, asset, tokens);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableAssetRow(
    MediaVaultViewModel vm,
    MediaAssetEntity asset,
    StudioDesignTokens tokens,
  ) {
    final row = Container(
      key: Key('vault_asset_card_${asset.id}'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.elevatedSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: tokens.borderHairline,
          width: tokens.borderWidth,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _iconForKind(asset.kind),
            color: tokens.accentSecondary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  asset.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: <Widget>[
                    StudioBadge(label: asset.kind.displayName),
                    StudioBadge(label: '${asset.bpm.toStringAsFixed(0)} BPM'),
                    StudioBadge(
                      label: asset.camelotKey,
                      accentColor: tokens.accentPrimary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: Key('vault_asset_actions_${asset.id}'),
            icon: Icon(
              Icons.more_vert,
              color: tokens.textSecondary,
              size: 16,
            ),
            color: tokens.panelHeaderBackground,
            tooltip: 'Sincronizar o agregar a pista',
            onSelected: (value) {
              if (value.startsWith('track:')) {
                final trackId = value.substring('track:'.length);
                vm.dropAssetOnTrack(asset: asset, trackId: trackId);
              } else if (value.startsWith('tool:')) {
                final targetName = value.substring('tool:'.length);
                final target = MediaSynergyTarget.values.firstWhere(
                  (t) => t.name == targetName,
                );
                vm.dispatchAssetToTool(asset, target);
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'track:track_deck_a',
                child: Text(
                  'Agregar a Pista Deck A',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                ),
              ),
              PopupMenuItem<String>(
                value: 'track:track_deck_b',
                child: Text(
                  'Agregar a Pista Deck B',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                ),
              ),
              PopupMenuItem<String>(
                value: 'track:track_score_midi',
                child: Text(
                  'Agregar a Pista Partitura / MIDI',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                ),
              ),
              const PopupMenuDivider(),
              ...MediaSynergyTarget.values.map(
                (target) => PopupMenuItem<String>(
                  value: 'tool:${target.name}',
                  child: Text(
                    'Enviar a ${target.displayName}',
                    style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Draggable<MediaAssetEntity>(
      data: asset,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.accentPrimary,
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            border: Border.all(color: tokens.borderFocus),
          ),
          child: Text(
            asset.title,
            style: TextStyle(
              color: tokens.textOnAccent,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );
  }

  Widget _buildTimelineAndSynergy(
    MediaVaultViewModel vm,
    TimelineProjectEntity timeline,
    StudioDesignTokens tokens,
  ) {
    final timelineWidth =
        ((timeline.totalDurationMs > 16000 ? timeline.totalDurationMs : 16000) /
                1000.0) *
            vm.pixelsPerSecond;

    return Column(
      children: <Widget>[
        Expanded(
          child: StudioPanel(
            title: 'Secuenciador Multi-Pista (Drag & Drop)',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: timelineWidth < 680 ? 680 : timelineWidth + 160,
                child: CustomPaint(
                  painter: TimelineArrangementPainter(
                    masterBpm: timeline.masterBpm,
                    pixelsPerSecond: vm.pixelsPerSecond,
                    playheadMs: vm.playheadMs,
                    snapToBeatgrid: timeline.snapToBeatgrid,
                    tokens: tokens,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: timeline.tracks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final track = timeline.tracks[index];
                      return _buildTimelineTrackLane(vm, track, tokens);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _buildSynergyDropBar(vm, tokens),
      ],
    );
  }

  Widget _buildTimelineTrackLane(
    MediaVaultViewModel vm,
    TimelineTrackEntity track,
    StudioDesignTokens tokens,
  ) {
    return DragTarget<MediaAssetEntity>(
      key: Key('timeline_drop_lane_${track.trackId}'),
      onAcceptWithDetails: (details) {
        vm.dropAssetOnTrack(
          asset: details.data,
          trackId: track.trackId,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          height: 76,
          decoration: BoxDecoration(
            color: isHovered
                ? tokens.accentPrimary.withValues(alpha: 0.18)
                : tokens.panelBackground.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            border: Border.all(
              color: isHovered ? tokens.borderFocus : tokens.borderHairline,
              width: tokens.borderWidth,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 155,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.panelHeaderBackground,
                  border: Border(
                    right: BorderSide(
                      color: tokens.borderHairline,
                      width: tokens.borderWidth,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        _buildLaneToggleButton(
                          label: 'M',
                          active: track.isMuted,
                          activeColor: tokens.accentDanger,
                          tokens: tokens,
                          onTap: () => vm.toggleTrackMute(track.trackId),
                        ),
                        const SizedBox(width: 5),
                        _buildLaneToggleButton(
                          label: 'S',
                          active: track.isSolo,
                          activeColor: tokens.accentWarning,
                          tokens: tokens,
                          onTap: () => vm.toggleTrackSolo(track.trackId),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: track.clips.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Arrastra musica, stems o partituras aqui',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      )
                    : Stack(
                        children: track.clips.map((clip) {
                          final leftPx =
                              (clip.startMs / 1000.0) * vm.pixelsPerSecond;
                          final widthPx =
                              ((clip.durationMs / 1000.0) * vm.pixelsPerSecond)
                                  .clamp(92.0, 600.0);
                          return Positioned(
                            left: leftPx,
                            top: 6,
                            bottom: 6,
                            width: widthPx,
                            child: Container(
                              key: Key('timeline_clip_${clip.clipId}'),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: tokens.accentPrimary.withValues(alpha: 0.85),
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSmall),
                                border: Border.all(color: tokens.borderFocus),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      clip.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tokens.textOnAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => vm.removeClip(
                                      trackId: track.trackId,
                                      clipId: clip.clipId,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 13,
                                      color: tokens.textOnAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLaneToggleButton({
    required String label,
    required bool active,
    required Color activeColor,
    required StudioDesignTokens tokens,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: active ? activeColor : tokens.inputSurface,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: active ? activeColor : tokens.borderHairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? tokens.textOnAccent : tokens.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSynergyDropBar(
    MediaVaultViewModel vm,
    StudioDesignTokens tokens,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: tokens.borderHairline,
          width: tokens.borderWidth,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            Text(
              'DESTINOS DE SINCRONIZACION (DRAG & DROP):',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(width: 10),
            ...MediaSynergyTarget.values.map(
              (target) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: DragTarget<MediaAssetEntity>(
                  key: Key('synergy_drop_target_${target.name}'),
                  onAcceptWithDetails: (details) =>
                      vm.dispatchAssetToTool(details.data, target),
                  builder: (context, candidates, _) {
                    final active = candidates.isNotEmpty;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? tokens.accentPrimary
                            : tokens.elevatedSurface,
                        borderRadius:
                            BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(
                          color: active
                              ? tokens.borderFocus
                              : tokens.borderHairline,
                        ),
                      ),
                      child: Text(
                        target.displayName,
                        style: TextStyle(
                          color: active
                              ? tokens.textOnAccent
                              : tokens.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFooter(
    MediaVaultViewModel vm,
    StudioDesignTokens tokens,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        border: Border(
          top: BorderSide(
            color: tokens.borderHairline,
            width: tokens.borderWidth,
          ),
        ),
      ),
      child: Text(
        vm.statusMessage,
        style: TextStyle(color: tokens.textSecondary, fontSize: 11),
      ),
    );
  }

  IconData _iconForKind(MediaAssetKind kind) {
    switch (kind) {
      case MediaAssetKind.audioTrack:
        return Icons.audiotrack;
      case MediaAssetKind.stem:
        return Icons.graphic_eq;
      case MediaAssetKind.sheetMusic:
        return Icons.description_outlined;
      case MediaAssetKind.midiSequence:
        return Icons.piano;
      case MediaAssetKind.practiceRecording:
        return Icons.mic_none;
      case MediaAssetKind.djSessionPreset:
        return Icons.tune;
    }
  }
}
