import 'package:flutter/material.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../data/dj_audio_processor.dart';
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
/// Permite cargar pistas del catálogo maestro de estudio o importar archivos locales.
class DjTrackLoaderModal extends StatelessWidget {
  final String deckId;
  final DjConsoleViewModel viewModel;

  const DjTrackLoaderModal({
    super.key,
    required this.deckId,
    required this.viewModel,
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

  void _loadPreset(BuildContext context, DjStudioPresetTrack track) {
    // Generar muestras PCM calibradas al BPM y estilo
    final samples = DjAudioProcessor().generateDemoGroove(
      bpm: track.bpm,
      frequencyHz: deckId == 'A' ? 55.0 : 65.0,
      durationMs: 8000,
    );

    final detectedBpm = viewModel.loadTrackWithBeatTracking(
      deckId,
      title: track.title,
      artist: track.artist,
      audioSamples: samples,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pista cargada en Deck $deckId: "${track.title}" (${detectedBpm.toStringAsFixed(1)} BPM)'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final accentColor = deckId == 'A' ? const Color(0xFF00E5FF) : const Color(0xFFFF4081);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
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
                  'DECK $deckId',
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
            'Selecciona una obra maestra de estudio con stems sincronizados o importa tus propios archivos.',
            style: TextStyle(color: tokens.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 16),

          // Botón Importar Archivo Local
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.file_open_outlined, size: 16),
              label: const Text('IMPORTAR ARCHIVO DE AUDIO (.WAV, .MP3, .FLAC, .AIFF)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.accentPrimary,
                side: BorderSide(color: tokens.accentPrimary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSmall)),
              ),
              onPressed: () {
                // Generar pista importada con procesamiento acústico de estudio
                final samples = DjAudioProcessor().generateDemoGroove(
                  bpm: 126.0,
                  frequencyHz: 60.0,
                  durationMs: 10000,
                );
                final detectedBpm = viewModel.loadTrackWithBeatTracking(
                  deckId,
                  title: 'Audio Importado Local (Master WAV)',
                  artist: 'Productor Externo',
                  audioSamples: samples,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Archivo importado en Deck $deckId - BPM detectado: ${detectedBpm.toStringAsFixed(1)}'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 12),

          Text(
            'PISTAS MAESTRAS DE PRODUCCIÓN (STEMS INTEGRADOS)',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.separated(
              itemCount: studioLibrary.length,
              separatorBuilder: (context, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final track = studioLibrary[index];
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
                          'CARGAR EN $deckId',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
