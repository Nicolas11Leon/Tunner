import 'package:flutter/material.dart';

import '../../../../core/design_system/atoms/studio_icon.dart';
import '../../../../core/design_system/domain/studio_icon_catalog.dart';
import '../../../../core/design_system/studio_theme_provider.dart';
import '../../../song_library/presentation/song_decomposer_modal.dart';
import '../tuner_viewmodel.dart';

/// Modal de Biblioteca y Descompositor de Canciones extraído de [TunerScreen].
/// Estilizado con [StudioThemeScope] y [StudioIcon].
class TunerLibraryModal extends StatelessWidget {
  final TunerViewModel viewModel;

  const TunerLibraryModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    final tokens = StudioThemeScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TunerLibraryModal(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final library = viewModel.curatedLibrary;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      StudioIcon(
                        StudioIconId.moduleScoreSheet,
                        color: tokens.accentPrimary,
                        size: 22,
                        tintCustomAsset: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BIBLIOTECA & DESCOMPOSITOR',
                        style: TextStyle(
                          color: tokens.accentPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('close_library_modal_btn'),
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      color: tokens.textMuted,
                      size: 20,
                      tintCustomAsset: true,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Repertorio curado con pistas separadas (stems) y carga personalizada',
                style: TextStyle(color: tokens.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Acción destacada para subir y descomponer canción externa
              InkWell(
                key: const Key('upload_decompose_song_btn'),
                onTap: () {
                  Navigator.pop(context);
                  SongDecomposerModal.show(context, viewModel);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: tokens.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tokens.accentPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      StudioIcon(
                        StudioIconId.fileOpen,
                        color: tokens.accentPrimary,
                        size: 22,
                        tintCustomAsset: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Subir & Descomponer Canción',
                              style: TextStyle(
                                color: tokens.accentPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Carga un archivo local (MIDI / MusicXML) y aísla sus instrumentos',
                              style: TextStyle(color: tokens.textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      StudioIcon(
                        StudioIconId.transportForward,
                        color: tokens.accentPrimary,
                        size: 14,
                        tintCustomAsset: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lista del repertorio curado
              Text(
                'Repertorio Clásico & Popular',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              ...library.map((pkg) {
                final isCurrent = viewModel.activePackage.id == pkg.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: tokens.elevatedSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isCurrent ? tokens.accentSecondary : tokens.borderSubtle,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: isCurrent
                            ? tokens.accentSecondary.withValues(alpha: 0.2)
                            : tokens.inputSurface,
                        child: StudioIcon(
                          StudioIconId.fileMusicXmlMidi,
                          color: isCurrent ? tokens.accentSecondary : tokens.textPrimary,
                          size: 18,
                          tintCustomAsset: true,
                        ),
                      ),
                      title: Text(
                        pkg.title,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${pkg.composer} • ${pkg.tracks.length} Pistas • ${pkg.defaultBpm} BPM',
                        style: TextStyle(color: tokens.textMuted, fontSize: 11),
                      ),
                      trailing: ElevatedButton(
                        key: Key('load_song_pkg_btn_${pkg.id}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isCurrent ? tokens.accentSecondary : tokens.accentPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () {
                          viewModel.loadSongPackage(pkg);
                          setModalState(() {});
                          Navigator.pop(context);
                        },
                        child: Text(
                          isCurrent ? 'Activa' : 'Cargar',
                          style: TextStyle(
                            color: tokens.textOnAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
