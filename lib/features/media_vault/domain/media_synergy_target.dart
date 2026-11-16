import 'dart:typed_data';

import 'media_asset_entity.dart';

/// Destination tools in Tunner that can receive assets dragged or dispatched
/// from the Multimedia Vault.
enum MediaSynergyTarget {
  djDeckA,
  djDeckB,
  djSamplerPad,
  scoreEditor,
  mixerChannel,
}

extension MediaSynergyTargetLabel on MediaSynergyTarget {
  String get displayName {
    switch (this) {
      case MediaSynergyTarget.djDeckA:
        return 'DJ Deck A';
      case MediaSynergyTarget.djDeckB:
        return 'DJ Deck B';
      case MediaSynergyTarget.djSamplerPad:
        return 'Club Sampler';
      case MediaSynergyTarget.scoreEditor:
        return 'Editor Partitura';
      case MediaSynergyTarget.mixerChannel:
        return 'Mixer Multipista';
    }
  }
}

/// Supported export formats from the Universal I/O engine.
enum MediaExportFormat {
  wavMixdown,
  cueSheet,
  tunnerBundleJson,
  midi,
  musicXml,
  abcNotation,
}

extension MediaExportFormatMeta on MediaExportFormat {
  String get fileExtension {
    switch (this) {
      case MediaExportFormat.wavMixdown:
        return 'wav';
      case MediaExportFormat.cueSheet:
        return 'cue';
      case MediaExportFormat.tunnerBundleJson:
        return 'tunner.json';
      case MediaExportFormat.midi:
        return 'mid';
      case MediaExportFormat.musicXml:
        return 'musicxml';
      case MediaExportFormat.abcNotation:
        return 'abc';
    }
  }

  String get displayName {
    switch (this) {
      case MediaExportFormat.wavMixdown:
        return 'Audio WAV (PCM 16-bit)';
      case MediaExportFormat.cueSheet:
        return 'Setlist CUE (.cue)';
      case MediaExportFormat.tunnerBundleJson:
        return 'Proyecto Tunner (.tunner.json)';
      case MediaExportFormat.midi:
        return 'Secuencia MIDI (.mid)';
      case MediaExportFormat.musicXml:
        return 'Partitura MusicXML (.musicxml)';
      case MediaExportFormat.abcNotation:
        return 'Notacion ABC (.abc)';
    }
  }
}

/// Outcome returned when importing an external file into the Multimedia Vault.
class MediaImportResult {
  final bool success;
  final List<MediaAssetEntity> importedAssets;
  final String message;

  const MediaImportResult({
    required this.success,
    this.importedAssets = const <MediaAssetEntity>[],
    required this.message,
  });
}

/// Outcome returned when exporting a timeline mixdown, cue sheet, score, or bundle.
class MediaExportResult {
  final bool success;
  final String fileName;
  final Uint8List bytes;
  final String message;

  const MediaExportResult({
    required this.success,
    required this.fileName,
    required this.bytes,
    required this.message,
  });
}
