import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../universal_importer/data/universal_score_importer_service.dart';
import '../domain/i_media_io_port.dart';
import '../domain/media_asset_entity.dart';
import '../domain/media_synergy_target.dart';
import '../domain/timeline_project_entity.dart';
import 'wav_pcm_codec.dart';

/// Unified 100% offline Import/Export orchestrator for the Multimedia Vault.
/// Supports WAV PCM, MIDI, MusicXML, MXL, ABC, PDF, CUE sheets, and
/// `.tunner.json` portable project bundles.
class UniversalMediaIoService implements IMediaIoService {
  static const int defaultExportSampleRate = 44100;

  /// Number of CD/CUE frames per second per CDRWIN CUE specification.
  static const int cueFramesPerSecond = 75;

  final WavPcmCodec _wavCodec;
  final UniversalScoreImporterService _scoreImporter;

  const UniversalMediaIoService({
    WavPcmCodec wavCodec = const WavPcmCodec(),
    UniversalScoreImporterService scoreImporter =
        const UniversalScoreImporterService(),
  })  : _wavCodec = wavCodec,
        _scoreImporter = scoreImporter;

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
      final asset = MediaAssetEntity(
        id: 'asset_${now.microsecondsSinceEpoch}',
        title: baseTitle,
        fileName: fileName,
        extensionName: 'wav',
        kind: MediaAssetKind.audioTrack,
        durationMs: decoded.durationMs,
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
        } catch (_) {
          // Fallback to raw asset registration if score parser rejects malformed tags.
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
        return _exportSimpleMidi(project, '$baseName.mid');
      case MediaExportFormat.musicXml:
        return _exportMusicXml(project, '$baseName.musicxml');
      case MediaExportFormat.abcNotation:
        return _exportAbc(project, '$baseName.abc');
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
          .map((a) => a.toMetadataJson())
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

  MediaExportResult _exportSimpleMidi(
    TimelineProjectEntity project,
    String fileName,
  ) {
    // Minimal Type-0 Standard MIDI File header + tempo meta-event for DAW sync
    final usPerQuarter = (60000000 / project.masterBpm.clamp(40.0, 240.0)).round();
    final trackData = <int>[
      // Tempo meta event: delta 0, FF 51 03 tt tt tt
      0x00, 0xFF, 0x51, 0x03,
      (usPerQuarter >> 16) & 0xFF,
      (usPerQuarter >> 8) & 0xFF,
      usPerQuarter & 0xFF,
      // End of track: delta 0, FF 2F 00
      0x00, 0xFF, 0x2F, 0x00,
    ];
    final header = <int>[
      0x4D, 0x54, 0x68, 0x64, // MThd
      0x00, 0x00, 0x00, 0x06, // length 6
      0x00, 0x00, // format 0
      0x00, 0x01, // 1 track
      0x01, 0xE0, // 480 ticks per quarter
      0x4D, 0x54, 0x72, 0x6B, // MTrk
      (trackData.length >> 24) & 0xFF,
      (trackData.length >> 16) & 0xFF,
      (trackData.length >> 8) & 0xFF,
      trackData.length & 0xFF,
      ...trackData,
    ];
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: Uint8List.fromList(header),
      message: 'Archivo MIDI SMF exportado (${project.masterBpm.toStringAsFixed(0)} BPM).',
    );
  }

  MediaExportResult _exportMusicXml(
    TimelineProjectEntity project,
    String fileName,
  ) {
    final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <work>
    <work-title>${project.title}</work-title>
  </work>
  <part-list>
    <score-part id="P1">
      <part-name>Tunner Timeline</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <sound tempo="${project.masterBpm.toStringAsFixed(0)}"/>
      <note><rest/><duration>4</duration><type>whole</type></note>
    </measure>
  </part>
</score-partwise>''';
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(xml)),
      message: 'Partitura MusicXML exportada.',
    );
  }

  MediaExportResult _exportAbc(
    TimelineProjectEntity project,
    String fileName,
  ) {
    final abc = '''X:1
T:${project.title}
M:4/4
L:1/4
Q:1/4=${project.masterBpm.toStringAsFixed(0)}
K:C
z4 |]
''';
    return MediaExportResult(
      success: true,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(abc)),
      message: 'Notacion ABC exportada.',
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
      final rawAssets = decoded['assets'];
      if (rawAssets is List) {
        final imported = rawAssets
            .whereType<Map<String, dynamic>>()
            .map(MediaAssetEntity.fromMetadataJson)
            .toList(growable: false);
        return MediaImportResult(
          success: true,
          importedAssets: imported,
          message: 'Paquete JSON importado (${imported.length} activos).',
        );
      }
      return const MediaImportResult(
        success: false,
        message: 'El JSON no contiene una lista de activos "assets".',
      );
    } catch (_) {
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
