import 'package:flutter/material.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../../../core/file_system/domain/i_platform_file_gateway.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../../song_library/domain/song_decomposer_service.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../domain/dj_audio_processor.dart';
import 'dj_console_view_model.dart';

class DjStudioPresetTrack {
  final String title;
  final String artist;
  final double bpm;
  final String camelotKey;
  final String genre;
  final String stemsDescription;

  const DjStudioPresetTrack({
    required this.title,
    required this.artist,
    required this.bpm,
    required this.camelotKey,
    required this.genre,
    required this.stemsDescription,
  });
}

/// Selector profesional de pistas y stems de audio para los Decks DJ.
/// Permite cargar obras del catálogo curado de conservatorio, presets de club o importar archivos locales.
class DjTrackLoaderModal extends StatefulWidget {
  final String deckId;
  final DjConsoleViewModel viewModel;
  final IPlatformFileGateway? fileGateway;

  const DjTrackLoaderModal({
    super.key,
    required this.deckId,
    required this.viewModel,
    this.fileGateway,
  });

  static const List<DjStudioPresetTrack> studioLibrary = [
    DjStudioPresetTrack(
      title: 'Midnight Cyber Synthwave',
      artist: 'Tunner Studio Sessions',
      bpm: 128.0,
      camelotKey: '8A (Am)',
      genre: 'Synthwave / Retro Electro',
      stemsDescription: 'Vocals, Analog Synths, 808 Bass, Punchy Drums',
    ),
    DjStudioPresetTrack(
      title: 'Deep Horizon House & Groove',
      artist: 'Klub Monolith',
      bpm: 124.0,
      camelotKey: '9A (Em)',
      genre: 'Deep House / Tech',
      stemsDescription: 'Vocal Chops, House Stabs, Sub Bass, 4x4 Kick/Clap',
    ),
    DjStudioPresetTrack(
      title: 'Acoustic Soul & Funk Fusion',
      artist: 'The Poly Groove Collective',
      bpm: 116.0,
      camelotKey: '7A (Dm)',
      genre: 'Funk / Nu-Soul',
      stemsDescription: 'Live Brass, Electric Guitar, Slap Bass, Acoustic Drums',
    ),
    DjStudioPresetTrack(
      title: 'Afrobeat Energy & Poly-Rhythm',
      artist: 'Lagos Midnight Lab',
      bpm: 120.0,
      camelotKey: '11A (F#m)',
      genre: 'Afrobeat / Percussive',
      stemsDescription: 'Kalimba, Vocal Chants, Percussion Wall, Log Drum',
    ),
    DjStudioPresetTrack(
      title: 'Lo-Fi Chillhop & Rain Piano',
      artist: 'Study Beats Archive',
      bpm: 85.0,
      camelotKey: '4A (Fm)',
      genre: 'Lo-Fi / Downtempo',
      stemsDescription: 'Rhodes Piano, Vinyl Crackle, Boombap Drums, Sub Bass',
    ),
  ];

  static Future<void> show(BuildContext context, {required String deckId, required DjConsoleViewModel viewModel}) {
    final tokens = StudioThemeScope.tokensOf(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      builder: (_) => DjTrackLoaderModal(deckId: deckId, viewModel: viewModel),
    );
  }

  @override
  State<DjTrackLoaderModal> createState() => _DjTrackLoaderModalState();
}

class _DjTrackLoaderModalState extends State<DjTrackLoaderModal> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _pathController = TextEditingController();
  final List<SongPackage> _curatedLibrary = SongDecomposerService.getCuratedLibrary();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  void _loadPreset(BuildContext context, DjStudioPresetTrack track) {
    final samples = DjAudioProcessor().synthesizePresetTrack(
      track.title,
      bpm: track.bpm,
      deckId: widget.deckId,
      durationMs: 16000,
    );

    final detectedBpm = widget.viewModel.loadTrackWithBeatTracking(
      widget.deckId,
      title: track.title,
      artist: track.artist,
      audioSamples: samples,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pista cargada en Deck ${widget.deckId}: "${track.title}" (${detectedBpm.toStringAsFixed(1)} BPM)'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _loadCuratedSong(BuildContext context, SongPackage song) {
    final samples = DjAudioProcessor().synthesizeSongPackageTrack(
      song,
      deckId: widget.deckId,
      durationMs: 16000,
    );

    final detectedBpm = widget.viewModel.loadTrackWithBeatTracking(
      widget.deckId,
      title: song.title,
      artist: song.composer,
      audioSamples: samples,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Obra curada cargada en Deck ${widget.deckId}: "${song.title}" (${detectedBpm.toStringAsFixed(1)} BPM)'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _importLocalFile(BuildContext context) async {
    try {
      final file = await widget.fileGateway?.pickFile(
        allowedExtensions: const ['wav', 'mp3', 'flac', 'ogg', 'm4a', 'aac', 'aiff'],
      );
      if (file != null && context.mounted) {
        final path = file.path;
        final name = file.name;
        final bytes = file.bytes;
        await widget.viewModel.loadDeckTrack(
          deckId: widget.deckId,
          filePath: path,
          wavBytes: bytes,
          title: name,
          artist: 'Archivo Local',
          bpm: 124.0,
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pista cargada en Deck ${widget.deckId}: "$name"'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      StudioDebugLogger.instance.warning('DjTrackLoaderModal', 'Error al seleccionar archivo: $e');
    }
  }

  Future<void> _loadManualPath(BuildContext context) async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;
    try {
      final name = path.split(RegExp(r'[/\\]')).last;
      await widget.viewModel.loadDeckTrack(
        deckId: widget.deckId,
        filePath: path,
        title: name,
        artist: 'Archivo Local',
        bpm: 124.0,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio cargado en Deck ${widget.deckId}: "$name"'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      StudioDebugLogger.instance.warning('DjTrackLoaderModal', 'Error al cargar ruta: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final accentColor = widget.deckId == 'A' ? const Color(0xFF00E5FF) : const Color(0xFFFF4081);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de agarre
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accentColor),
                ),
                child: Text(
                  'DECK ${widget.deckId}',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'BIBLIOTECA DE PISTAS & STEMS DE ESTUDIO',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona una obra curada de repertorio, un preset de club con stems o importa tus propios archivos locales.',
            style: TextStyle(color: tokens.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),

          // Pestañas de Selección
          TabBar(
            controller: _tabController,
            labelColor: accentColor,
            unselectedLabelColor: tokens.textMuted,
            indicatorColor: accentColor,
            indicatorWeight: 2,
            tabs: [
              Tab(
                icon: const Icon(Icons.album, size: 14),
                text: 'Club (${DjTrackLoaderModal.studioLibrary.length})',
              ),
              Tab(
                icon: const Icon(Icons.menu_book, size: 14),
                text: 'Repertorio (${_curatedLibrary.length})',
              ),
              const Tab(
                icon: Icon(Icons.file_open, size: 14),
                text: 'Importar Archivo',
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Pestaña 1: Pistas Club & Presets
                ListView.separated(
                  itemCount: DjTrackLoaderModal.studioLibrary.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = DjTrackLoaderModal.studioLibrary[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  track.bpm.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: tokens.accentPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const Text('BPM', style: TextStyle(color: Colors.white38, fontSize: 8)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${track.artist} • ${track.genre}',
                                  style: TextStyle(color: tokens.textMuted, fontSize: 10),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Stems: ${track.stemsDescription}',
                                  style: TextStyle(color: tokens.accentSuccess, fontSize: 9.5, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              track.camelotKey,
                              style: const TextStyle(
                                color: Color(0xFFA78BFA),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () => _loadPreset(context, track),
                            child: Text(
                              'CARGAR EN ${widget.deckId}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Pestaña 2: Repertorio Curado & Stems
                ListView.separated(
                  itemCount: _curatedLibrary.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final song = _curatedLibrary[index];
                    final stemsText = song.tracks.map((t) => t.title).join(', ');

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  song.defaultBpm.toString(),
                                  style: TextStyle(
                                    color: tokens.accentPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const Text('BPM', style: TextStyle(color: Colors.white38, fontSize: 8)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${song.composer} • ${song.genre.name.toUpperCase()}',
                                  style: TextStyle(color: tokens.textMuted, fontSize: 10),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Stems: $stemsText',
                                  style: TextStyle(color: tokens.accentSuccess, fontSize: 9.5, fontStyle: FontStyle.italic),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () => _loadCuratedSong(context, song),
                            child: Text(
                              'CARGAR EN ${widget.deckId}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Pestaña 3: Importador de Archivo Local & Ruta Directa
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.file_open_outlined, size: 16),
                          label: const Text('EXAMINAR ARCHIVO (.WAV, .MP3, .FLAC, .OGG, .AIFF)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.accentPrimary,
                            side: BorderSide(color: tokens.accentPrimary.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSmall)),
                          ),
                          onPressed: () => _importLocalFile(context),
                        ),
                      ),
                      Text(
                        'O ingresa la ruta absoluta del archivo en disco:',
                        style: TextStyle(color: tokens.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pathController,
                              style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: '/home/usuario/Musica/mi_cancion.wav',
                                hintStyle: TextStyle(color: tokens.textMuted.withValues(alpha: 0.5), fontSize: 11),
                                filled: true,
                                fillColor: tokens.elevatedSurface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                                  borderSide: BorderSide(color: tokens.borderHairline),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('CARGAR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onPressed: () => _loadManualPath(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.elevatedSurface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          border: Border.all(color: tokens.borderHairline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: tokens.accentPrimary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Formatos soportados: WAV PCM (16/24-bit), MP3, FLAC, AIFF y OGG. El motor realizará estimación automática de BPM y detección de tonalidad armónica Camelot en tiempo real.',
                                style: TextStyle(color: tokens.textMuted, fontSize: 10.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
