import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../../../core/logging/infrastructure/studio_stderr_logger.dart';
import '../../dj_console/domain/bpm_beat_tracker_engine.dart';
import '../../dj_console/domain/dj_harmonic_camelot_engine.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../universal_importer/data/universal_score_importer_service.dart';
import '../../universal_importer/domain/canonical_abc_exporter.dart';
import '../../universal_importer/domain/canonical_midi_exporter.dart';
import '../../universal_importer/domain/canonical_musicxml_exporter.dart';
import '../domain/i_media_io_port.dart';
import '../domain/media_asset_entity.dart';
import '../domain/media_synergy_target.dart';
import '../domain/timeline_project_entity.dart';
import '../domain/wav_pcm_codec.dart';

/// Unified 100% offline Import/Export orchestrator for the Multimedia Vault.
/// Supports WAV PCM, MIDI, MusicXML, MXL, ABC, PDF, CUE sheets, and
/// `.tunner.json` portable project bundles.
class UniversalMediaIoService implements IMediaIoService {
  static const int defaultExportSampleRate = 44100;

  /// Number of CD/CUE frames per second per CDRWIN CUE specification.
  static const int cueFramesPerSecond = 75;

  final WavPcmCodec _wavCodec;
  final UniversalScoreImporterService _scoreImporter;
  final IStudioLogger _logger;

  const UniversalMediaIoService({
    WavPcmCodec wavCodec = const WavPcmCodec(),
    UniversalScoreImporterService scoreImporter =
        const UniversalScoreImporterService(),
    IStudioLogger logger = StudioStderrLogger.instance,
  })  : _wavCodec = wavCodec,
        _scoreImporter = scoreImporter,
        _logger = logger;

  @override
  Future<MediaImportResult> importBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      return const MediaImportResult(
        success: false,
        message: 'El archivo esta vacio.',
      );
    }

    final lower = fileName.toLowerCase();
    final ext = lower.contains('.') ? lower.split('.').last : '';
    final baseTitle = _stripExtension(fileName);
    final now = DateTime.now().toUtc();

    if (lower.endsWith('.tunner.json') || ext == 'json') {
      return _importTunnerJson(fileName, bytes);
    }

    if (ext == 'wav') {
      final decoded = _wavCodec.decode(bytes);
      if (decoded == null) {
        return const MediaImportResult(
          success: false,
          message: 'Encabezado WAV invalido o formato PCM no soportado (requiere PCM 16-bit).',
        );
      }
      final peaks = _wavCodec.extractPeaks(decoded.monoSamples);
      final float32Samples = Float32List.fromList(decoded.monoSamples);
      final double estimatedBpm = decoded.monoSamples.length >= 2048
          ? BpmBeatTrackerEngine.estimateBpm(
              samples: float32Samples,
              sampleRate: decoded.sampleRate,
            ).clamp(40.0, 240.0)
          : 120.0;
      final String estimatedCamelot = decoded.monoSamples.length >= 512
          ? DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples(
              float32Samples,
              sampleRate: decoded.sampleRate,
            ).code
          : '8A';
      final asset = MediaAssetEntity(
        id: 'asset_${now.microsecondsSinceEpoch}',
        title: baseTitle,
        fileName: fileName,
        extensionName: 'wav',
        kind: MediaAssetKind.audioTrack,
        durationMs: decoded.durationMs,
        bpm: estimatedBpm,
        camelotKey: estimatedCamelot,
        sampleRate: decoded.sampleRate,
        tags: const <String>['wav', 'lossless'],
        createdAt: now,
        pcmSamples: decoded.monoSamples,
        rawBytes: bytes,
        waveformPeaks: peaks,
      );
      return MediaImportResult(
        success: true,
        importedAssets: <MediaAssetEntity>[asset],
        message: 'Audio WAV importado (${decoded.durationMs} ms).',
      );
    }

    if (_isScoreOrMidiExtension(ext)) {
      if (_scoreImporter.canParse(fileName, bytes)) {
        try {
          final parsed = await _scoreImporter.parseScoreData(
            bytes: bytes,
            fileName: fileName,
          );
          final kind = (ext == 'mid' || ext == 'midi')
              ? MediaAssetKind.midiSequence
              : MediaAssetKind.sheetMusic;
          final asset = MediaAssetEntity(
            id: 'asset_${now.microsecondsSinceEpoch}',
            title: parsed.package.title.isNotEmpty
                ? parsed.package.title
                : baseTitle,
            fileName: fileName,
            extensionName: ext,
            kind: kind,
            durationMs: TimelineProjectEntity.defaultNonAudioClipDurationMs,
            bpm: parsed.package.defaultBpm > 0
                ? parsed.package.defaultBpm.toDouble()
                : 120.0,
            tags: <String>[ext, 'score'],
            createdAt: now,
            rawBytes: bytes,
          );
          return MediaImportResult(
            success: true,
            importedAssets: <MediaAssetEntity>[asset],
            message: 'Partitura/MIDI "${asset.title}" importada correctamente.',
          );
        } catch (e, st) {
          // Fallback to raw asset registration if score parser rejects malformed tags.
          _logger.warning(
            'UniversalMediaIoService',
            'Parser de partitura rechazo "$fileName", registrando como activo raw: $e',
            error: e,
            stackTrace: st,
          );
        }
      }

      final kind = (ext == 'mid' || ext == 'midi')
          ? MediaAssetKind.midiSequence
          : MediaAssetKind.sheetMusic;
      final fallbackAsset = MediaAssetEntity(
        id: 'asset_${now.microsecondsSinceEpoch}',
        title: baseTitle,
        fileName: fileName,
        extensionName: ext,
        kind: kind,
        durationMs: TimelineProjectEntity.defaultNonAudioClipDurationMs,
        tags: <String>[ext],
        createdAt: now,
        rawBytes: bytes,
      );
      return MediaImportResult(
        success: true,
        importedAssets: <MediaAssetEntity>[fallbackAsset],
        message: 'Archivo "$fileName" registrado en la Boveda Multimedia.',
      );
    }

    return MediaImportResult(
      success: false,
      message: 'Formato ".$ext" no soportado. Usa WAV, MIDI, MusicXML, MXL, ABC, PDF o JSON.',
    );
  }

  @override
  Future<MediaExportResult> exportTimeline({
    required TimelineProjectEntity project,
    required Map<String, MediaAssetEntity> assetsById,
    required MediaExportFormat format,
  }) async {
    final safeBase = project.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final baseName = safeBase.isEmpty ? 'tunner_project' : safeBase;

    switch (format) {
      case MediaExportFormat.wavMixdown:
        return _exportWavMixdown(project, assetsById, '$baseName.wav');
      case MediaExportFormat.cueSheet:
        return _exportCueSheet(project, assetsById, '$baseName.cue');
      case MediaExportFormat.tunnerBundleJson:
        return _exportBundleJson(project, assetsById, '$baseName.tunner.json');
      case MediaExportFormat.midi:
        return _exportSimpleMidi(project, assetsById, '$baseName.mid');
      case MediaExportFormat.musicXml:
        return _exportMusicXml(project, assetsById, '$baseName.musicxml');
      case MediaExportFormat.abcNotation:
        return _exportAbc(project, assetsById, '$baseName.abc');
    }
  }

  MediaExportResult _exportWavMixdown(
    TimelineProjectEntity project,
    Map<String, MediaAssetEntity> assetsById,
    String fileName,
  ) {
    if (project.isEmpty) {
      return MediaExportResult(
        success: false,
        fileName: fileName,
        bytes: Uint8List(0),
        message: 'La linea de tiempo esta vacia. Arrastra al menos un clip.',
      );
    }

    final totalMs = math.max(1000, project.totalDurationMs);
    final totalSamples =
        ((totalMs / 1000.0) * defaultExportSampleRate).ceil();
    final mixBuffer = Float64List(totalSamples);

    for (final track in project.tracks) {
      if (!project.isTrackAudible(track)) {
        continue;
      }
      for (final clip in track.clips) {
        final asset = assetsById[clip.assetId];
        final startSample =
            ((clip.startMs / 1000.0) * defaultExportSampleRate).round();
        final clipGain = (track.volume * clip.gain).clamp(0.0, 1.5);

        if (asset?.pcmSamples != null && asset!.pcmSamples!.isNotEmpty) {
          final src = asset.pcmSamples!;
          final maxLen = math.min(src.length, totalSamples - startSample);
          for (int i = 0; i < maxLen; i++) {
            final dstIdx = startSample + i;
            if (dstIdx >= 0 && dstIdx < mixBuffer.length) {
              mixBuffer[dstIdx] += src[i] * clipGain;
            }
          }
        } else {
          // Synthesize a soft 440 Hz marker click at clip start for non-PCM score/MIDI clips
          final clickLen = math.min(
            (0.05 * defaultExportSampleRate).round(),
            totalSamples - startSample,
          );
          for (int i = 0; i < clickLen; i++) {
            final env = 1.0 - (i / math.max(1, clickLen));
            final s = math.sin(2.0 * math.pi * 440.0 * (i / defaultExportSampleRate));
            mixBuffer[startSample + i] += s * env * 0.25 * clipGain;
          }
        }
      }
    }

    // Soft-clip limiter to avoid digital clipping on summed tracks
    for (int i = 0; i < mixBuffer.length; i++) {
      if (mixBuffer[i].abs() > 1.0) {
        mixBuffer[i] = mixBuffer[i] > 0 ? 1.0 : -1.0;
      }
    }

    final wavBytes = _wavCodec.encodeMono16Bit(
      mixBuffer,
      sampleRate: defaultExportSampleRate,
    );
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: wavBytes,
      message: 'Mixdown WAV exportado (${(wavBytes.length / 1024).toStringAsFixed(1)} KB).',
    );
  }

  MediaExportResult _exportCueSheet(
    TimelineProjectEntity project,
    Map<String, MediaAssetEntity> assetsById,
    String fileName,
  ) {
    final clips = <_TrackClipPair>[];
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        clips.add(_TrackClipPair(track.name, clip));
      }
    }
    clips.sort((a, b) => a.clip.startMs.compareTo(b.clip.startMs));

    if (clips.isEmpty) {
      return MediaExportResult(
        success: false,
        fileName: fileName,
        bytes: Uint8List(0),
        message: 'No hay clips en la linea de tiempo para generar el archivo CUE.',
      );
    }

    final sb = StringBuffer()
      ..writeln('TITLE "${project.title}"')
      ..writeln('REM BPM ${project.masterBpm.toStringAsFixed(1)}')
      ..writeln('FILE "${fileName.replaceAll('.cue', '.wav')}" WAVE');

    for (int i = 0; i < clips.length; i++) {
      final entry = clips[i];
      final asset = assetsById[entry.clip.assetId];
      final trackNum = (i + 1).toString().padLeft(2, '0');
      final indexTime = _formatCueTimestamp(entry.clip.startMs);
      sb
        ..writeln('  TRACK $trackNum AUDIO')
        ..writeln('    TITLE "${entry.clip.label}"')
        ..writeln('    PERFORMER "Tunner (${entry.trackName})"')
        ..writeln('    REM CAMELOT ${asset?.camelotKey ?? '8A'}')
        ..writeln('    INDEX 01 $indexTime');
    }

    final bytes = Uint8List.fromList(utf8.encode(sb.toString()));
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: bytes,
      message: 'Setlist CUE exportado con ${clips.length} marcadores.',
    );
  }

  MediaExportResult _exportBundleJson(
    TimelineProjectEntity project,
    Map<String, MediaAssetEntity> assetsById,
    String fileName,
  ) {
    final payload = <String, dynamic>{
      'format': 'tunner_multimedia_bundle',
      'version': '1.0',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'timeline': project.toJson(),
      'assets': assetsById.values
          .map((a) => a.toMetadataJson(includeRawBytes: true))
          .toList(growable: false),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: bytes,
      message: 'Proyecto Tunner JSON exportado (${assetsById.length} activos).',
    );
  }

  Future<HierarchicalScore> _buildScoreFromTimeline(
    TimelineProjectEntity project,
    Map<String, MediaAssetEntity> assetsById,
  ) async {
    final extractedMeasures = <MeasureEntity>[];
    for (final track in project.tracks) {
      if (!project.isTrackAudible(track)) continue;
      for (final clip in track.clips) {
        final asset = assetsById[clip.assetId];
        if (asset?.rawBytes != null &&
            _scoreImporter.canParse(asset!.fileName, asset.rawBytes!)) {
          try {
            final parsed = await _scoreImporter.parseScoreData(
              bytes: asset.rawBytes!,
              fileName: asset.fileName,
            );
            if (parsed.package.score.measures.isNotEmpty) {
              extractedMeasures.addAll(parsed.package.score.measures);
              continue;
            }
          } catch (_) {
            // Fallback a eventos sintetizados desde metadatos del clip.
          }
        }

        // Si el clip es de audio o no tiene partitura parseable, generar nota musical
        // acorde a su clave Camelot y duracion en el timeline.
        final camelot = DjHarmonicCamelotEngine.findByCode(asset?.camelotKey ?? '8A');
        const noteNames = <String>[
          'C4', 'C#4', 'D4', 'Eb4', 'E4', 'F4', 'F#4', 'G4', 'Ab4', 'A4', 'Bb4', 'B4',
        ];
        final noteName = noteNames[camelot.rootPitchClass % noteNames.length];
        extractedMeasures.add(
          MeasureEntity(
            index: extractedMeasures.length,
            timeSignature: TimeSignature.commonTime44,
            notes: <HierarchicalNote>[
              HierarchicalNote.note(
                startTick: 0,
                durationTicks: TimeSignature.commonTime44.totalTicks,
                noteName: noteName,
              ),
            ],
          ),
        );
      }
    }

    if (extractedMeasures.isEmpty) {
      extractedMeasures.add(
        MeasureEntity(
          index: 0,
          timeSignature: TimeSignature.commonTime44,
          notes: <HierarchicalNote>[
            HierarchicalNote.rest(
              startTick: 0,
              durationTicks: TimeSignature.commonTime44.totalTicks,
            ),
          ],
        ),
      );
    }

    final reindexed = List<MeasureEntity>.generate(
      extractedMeasures.length,
      (i) => extractedMeasures[i].copyWith(index: i),
    );
    return HierarchicalScore(
      title: project.title,
      baseBpm: project.masterBpm.round().clamp(40, 240),
      measures: reindexed,
    );
  }

  Future<MediaExportResult> _exportSimpleMidi(
    TimelineProjectEntity project,
    Map<String, MediaAssetEntity> assetsById,
    String fileName,
  ) async {
    final score = await _buildScoreFromTimeline(project, assetsById);
    final midiBytes = const CanonicalMidiExporter().exportScore(
      score: score,
      trackName: project.title,
    );
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: midiBytes,
      message: 'Archivo MIDI SMF exportado (${score.totalMeasures} compases, ${project.masterBpm.toStringAsFixed(0)} BPM).',
    );
  }

  Future<MediaExportResult> _exportMusicXml(
    TimelineProjectEntity project,
    Map<String, MediaAssetEntity> assetsById,
    String fileName,
  ) async {
    final score = await _buildScoreFromTimeline(project, assetsById);
    final xml = const CanonicalMusicXmlExporter().exportScore(
      score: score,
      title: project.title,
    );
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(xml)),
      message: 'Partitura MusicXML exportada (${score.totalMeasures} compases).',
    );
  }

  Future<MediaExportResult> _exportAbc(
    TimelineProjectEntity project,
    Map<String, MediaAssetEntity> assetsById,
    String fileName,
  ) async {
    final score = await _buildScoreFromTimeline(project, assetsById);
    final abc = const CanonicalAbcExporter().exportScore(
      score: score,
      title: project.title,
    );
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(abc)),
      message: 'Notacion ABC exportada (${score.totalMeasures} compases).',
    );
  }

  MediaImportResult _importTunnerJson(String fileName, Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        return const MediaImportResult(
          success: false,
          message: 'Estructura JSON invalida.',
        );
      }
      TimelineProjectEntity? restoredTimeline;
      final rawTimeline = decoded['timeline'];
      if (rawTimeline is Map<String, dynamic>) {
        restoredTimeline = TimelineProjectEntity.fromJson(rawTimeline);
      }
      final rawAssets = decoded['assets'];
      if (rawAssets is List) {
        final imported = rawAssets
            .whereType<Map<String, dynamic>>()
            .map((json) {
              var entity = MediaAssetEntity.fromMetadataJson(json);
              if (entity.pcmSamples == null &&
                  entity.rawBytes != null &&
                  entity.extensionName.toLowerCase() == 'wav') {
                final wav = _wavCodec.decode(entity.rawBytes!);
                if (wav != null) {
                  entity = entity.copyWith(
                    pcmSamples: wav.monoSamples,
                    waveformPeaks: entity.waveformPeaks.isEmpty
                        ? _wavCodec.extractPeaks(wav.monoSamples)
                        : entity.waveformPeaks,
                  );
                }
              }
              return entity;
            })
            .toList(growable: false);
        return MediaImportResult(
          success: true,
          importedAssets: imported,
          restoredTimeline: restoredTimeline,
          message: 'Paquete JSON importado (${imported.length} activos).',
        );
      }
      return const MediaImportResult(
        success: false,
        message: 'El JSON no contiene una lista de activos "assets".',
      );
    } catch (e, st) {
      _logger.warning(
        'UniversalMediaIoService',
        'Error decodificando JSON "$fileName": $e',
        error: e,
        stackTrace: st,
      );
      return MediaImportResult(
        success: false,
        message: 'No se pudo decodificar el archivo JSON "$fileName".',
      );
    }
  }

  String _formatCueTimestamp(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final remMs = ms % 1000;
    final frames = ((remMs * cueFramesPerSecond) ~/ 1000)
        .clamp(0, 74)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds:$frames';
  }

  bool _isScoreOrMidiExtension(String ext) {
    return ext == 'mid' ||
        ext == 'midi' ||
        ext == 'musicxml' ||
        ext == 'xml' ||
        ext == 'mxl' ||
        ext == 'abc' ||
        ext == 'pdf';
  }

  String _stripExtension(String fileName) {
    final idx = fileName.lastIndexOf('.');
    return idx > 0 ? fileName.substring(0, idx) : fileName;
  }
}

class _TrackClipPair {
  final String trackName;
  final TimelineClipEntity clip;

  const _TrackClipPair(this.trackName, this.clip);
}
