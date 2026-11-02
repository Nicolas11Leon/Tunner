import 'dart:convert';
import 'dart:typed_data';
import 'sf2_models.dart';

/// Decodificador y parser de archivos binarios SoundFont 2 (RIFF/SF2).
/// 100% Dart puro, determinista, tolerante a fallos y sin dependencias externas.
class Sf2Parser {
  const Sf2Parser();

  /// Parsea un arreglo binario de bytes correspondiente a un archivo `.sf2`.
  Sf2SoundFont parse(Uint8List bytes) {
    if (bytes.length < 12) {
      throw const FormatException('Archivo SF2 inválido o truncado: longitud < 12 bytes');
    }

    final byteData = ByteData.sublistView(bytes);

    // Validar cabecera RIFF
    final riffTag = _readFourCC(byteData, 0);
    if (riffTag != 'RIFF') {
      throw FormatException('Formato no soportado: esperado RIFF pero encontrado "$riffTag"');
    }

    final sfTag = _readFourCC(byteData, 8);
    if (sfTag != 'sfbk') {
      throw FormatException('Formato no soportado: esperado sfbk pero encontrado "$sfTag"');
    }

    String sfName = 'SoundFont Desconocido';
    Int16List sampleData = Int16List(0);
    List<Sf2SampleHeader> sampleHeaders = [];
    List<Sf2Instrument> instruments = [];
    List<Sf2Preset> presets = [];

    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = _readFourCC(byteData, offset);
      final chunkSize = byteData.getUint32(offset + 4, Endian.little);
      final chunkDataOffset = offset + 8;

      if (chunkId == 'LIST') {
        if (chunkDataOffset + 4 <= bytes.length) {
          final listType = _readFourCC(byteData, chunkDataOffset);
          final listPayloadOffset = chunkDataOffset + 4;
          final listPayloadSize = chunkSize - 4;

          if (listType == 'INFO') {
            sfName = _parseInfoList(byteData, listPayloadOffset, listPayloadSize);
          } else if (listType == 'sdta') {
            sampleData = _parseSdtaList(bytes, byteData, listPayloadOffset, listPayloadSize);
          } else if (listType == 'pdta') {
            final pdtaResult = _parsePdtaList(bytes, byteData, listPayloadOffset, listPayloadSize);
            presets = pdtaResult.presets;
            instruments = pdtaResult.instruments;
            sampleHeaders = pdtaResult.sampleHeaders;
          }
        }
      }

      // Los chunks en RIFF se alinean a palabras de 2 bytes
      offset += 8 + chunkSize + (chunkSize % 2);
    }

    return Sf2SoundFont(
      soundFontName: sfName,
      presets: presets,
      instruments: instruments,
      sampleHeaders: sampleHeaders,
      sampleData: sampleData,
    );
  }

  static String _readFourCC(ByteData data, int offset) {
    if (offset + 4 > data.lengthInBytes) return '';
    final codeUnits = [
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
      data.getUint8(offset + 3),
    ];
    return String.fromCharCodes(codeUnits);
  }

  static String _readFixedAscii(ByteData data, int offset, int length) {
    final codeUnits = <int>[];
    for (int i = 0; i < length; i++) {
      if (offset + i >= data.lengthInBytes) break;
      final b = data.getUint8(offset + i);
      if (b == 0) break;
      codeUnits.add(b);
    }
    return latin1.decode(codeUnits).trim();
  }

  String _parseInfoList(ByteData data, int offset, int size) {
    int cur = offset;
    final end = offset + size;
    String name = 'Tunner SoundFont';

    while (cur + 8 <= end && cur + 8 <= data.lengthInBytes) {
      final subId = _readFourCC(data, cur);
      final subSize = data.getUint32(cur + 4, Endian.little);
      final subDataOffset = cur + 8;

      if (subId == 'INAM') {
        name = _readFixedAscii(data, subDataOffset, subSize);
      }

      cur += 8 + subSize + (subSize % 2);
    }

    return name;
  }

  Int16List _parseSdtaList(Uint8List rawBytes, ByteData data, int offset, int size) {
    int cur = offset;
    final end = offset + size;

    while (cur + 8 <= end && cur + 8 <= data.lengthInBytes) {
      final subId = _readFourCC(data, cur);
      final subSize = data.getUint32(cur + 4, Endian.little);
      final subDataOffset = cur + 8;

      if (subId == 'smpl') {
        final sampleCount = subSize ~/ 2;
        final list = Int16List(sampleCount);
        for (int i = 0; i < sampleCount; i++) {
          final sampleOffset = subDataOffset + (i * 2);
          if (sampleOffset + 2 <= rawBytes.length) {
            list[i] = data.getInt16(sampleOffset, Endian.little);
          }
        }
        return list;
      }

      cur += 8 + subSize + (subSize % 2);
    }

    return Int16List(0);
  }

  _PdtaResult _parsePdtaList(Uint8List rawBytes, ByteData data, int offset, int size) {
    int cur = offset;
    final end = offset + size;

    final rawPresets = <_RawPreset>[];
    final rawPbag = <int>[];
    final rawPgen = <_RawGen>[];

    final rawInsts = <_RawInst>[];
    final rawIbag = <int>[];
    final rawIgen = <_RawGen>[];

    final sampleHeaders = <Sf2SampleHeader>[];

    while (cur + 8 <= end && cur + 8 <= data.lengthInBytes) {
      final subId = _readFourCC(data, cur);
      final subSize = data.getUint32(cur + 4, Endian.little);
      final subDataOffset = cur + 8;

      if (subId == 'phdr') {
        // 38 bytes por registro de preset
        final count = subSize ~/ 38;
        for (int i = 0; i < count; i++) {
          final pOffset = subDataOffset + (i * 38);
          final name = _readFixedAscii(data, pOffset, 20);
          final patch = data.getUint16(pOffset + 20, Endian.little);
          final bank = data.getUint16(pOffset + 22, Endian.little);
          final bagNdx = data.getUint16(pOffset + 24, Endian.little);
          rawPresets.add(_RawPreset(name: name, patch: patch, bank: bank, bagIndex: bagNdx));
        }
      } else if (subId == 'pbag') {
        // 4 bytes por registro (genNdx 2B, modNdx 2B)
        final count = subSize ~/ 4;
        for (int i = 0; i < count; i++) {
          final bOffset = subDataOffset + (i * 4);
          rawPbag.add(data.getUint16(bOffset, Endian.little));
        }
      } else if (subId == 'pgen') {
        // 4 bytes por registro (oper 2B, amount 2B)
        final count = subSize ~/ 4;
        for (int i = 0; i < count; i++) {
          final gOffset = subDataOffset + (i * 4);
          final oper = data.getUint16(gOffset, Endian.little);
          final amount = data.getUint16(gOffset + 2, Endian.little);
          rawPgen.add(_RawGen(oper: oper, amount: amount));
        }
      } else if (subId == 'inst') {
        // 22 bytes por registro
        final count = subSize ~/ 22;
        for (int i = 0; i < count; i++) {
          final iOffset = subDataOffset + (i * 22);
          final name = _readFixedAscii(data, iOffset, 20);
          final bagNdx = data.getUint16(iOffset + 20, Endian.little);
          rawInsts.add(_RawInst(name: name, bagIndex: bagNdx));
        }
      } else if (subId == 'ibag') {
        final count = subSize ~/ 4;
        for (int i = 0; i < count; i++) {
          final bOffset = subDataOffset + (i * 4);
          rawIbag.add(data.getUint16(bOffset, Endian.little));
        }
      } else if (subId == 'igen') {
        final count = subSize ~/ 4;
        for (int i = 0; i < count; i++) {
          final gOffset = subDataOffset + (i * 4);
          final oper = data.getUint16(gOffset, Endian.little);
          final amount = data.getUint16(gOffset + 2, Endian.little);
          rawIgen.add(_RawGen(oper: oper, amount: amount));
        }
      } else if (subId == 'shdr') {
        // 46 bytes por registro de muestra
        final count = subSize ~/ 46;
        for (int i = 0; i < count; i++) {
          final sOffset = subDataOffset + (i * 46);
          final name = _readFixedAscii(data, sOffset, 20);
          final start = data.getUint32(sOffset + 20, Endian.little);
          final end = data.getUint32(sOffset + 24, Endian.little);
          final startLoop = data.getUint32(sOffset + 28, Endian.little);
          final endLoop = data.getUint32(sOffset + 32, Endian.little);
          final sampleRate = data.getUint32(sOffset + 36, Endian.little);
          final originalPitch = data.getUint8(sOffset + 40);
          final pitchCorrection = data.getInt8(sOffset + 41);
          final sampleLink = data.getUint16(sOffset + 42, Endian.little);
          final sampleType = data.getUint16(sOffset + 44, Endian.little);

          sampleHeaders.add(Sf2SampleHeader(
            name: name,
            start: start,
            end: end,
            startLoop: startLoop,
            endLoop: endLoop,
            sampleRate: sampleRate,
            originalPitch: originalPitch,
            pitchCorrection: pitchCorrection,
            sampleLink: sampleLink,
            sampleType: sampleType,
          ));
        }
      }

      cur += 8 + subSize + (subSize % 2);
    }

    // Reconstruir instrumentos y zonas
    final instruments = <Sf2Instrument>[];
    for (int i = 0; i < rawInsts.length - 1; i++) {
      final inst = rawInsts[i];
      final nextInst = rawInsts[i + 1];
      final zones = <Sf2Zone>[];

      for (int b = inst.bagIndex; b < nextInst.bagIndex && b < rawIbag.length - 1; b++) {
        final genStart = rawIbag[b];
        final genEnd = rawIbag[b + 1];
        final genMap = <int, int>{};
        int? sampleId;
        Sf2Range keyRange = const Sf2Range(low: 0, high: 127);
        Sf2Range velRange = const Sf2Range(low: 0, high: 127);

        for (int g = genStart; g < genEnd && g < rawIgen.length; g++) {
          final gen = rawIgen[g];
          genMap[gen.oper] = gen.amount;
          if (gen.oper == Sf2GeneratorType.sampleID) {
            sampleId = gen.amount;
          } else if (gen.oper == Sf2GeneratorType.keyRange) {
            keyRange = Sf2Range(low: gen.amount & 0xFF, high: (gen.amount >> 8) & 0xFF);
          } else if (gen.oper == Sf2GeneratorType.velRange) {
            velRange = Sf2Range(low: gen.amount & 0xFF, high: (gen.amount >> 8) & 0xFF);
          }
        }

        zones.add(Sf2Zone(
          keyRange: keyRange,
          velRange: velRange,
          generators: genMap,
          sampleId: sampleId,
        ));
      }

      instruments.add(Sf2Instrument(name: inst.name, zones: zones));
    }

    // Reconstruir presets y zonas
    final presets = <Sf2Preset>[];
    for (int i = 0; i < rawPresets.length - 1; i++) {
      final pr = rawPresets[i];
      final nextPr = rawPresets[i + 1];
      final zones = <Sf2Zone>[];

      for (int b = pr.bagIndex; b < nextPr.bagIndex && b < rawPbag.length - 1; b++) {
        final genStart = rawPbag[b];
        final genEnd = rawPbag[b + 1];
        final genMap = <int, int>{};
        int? instId;
        Sf2Range keyRange = const Sf2Range(low: 0, high: 127);
        Sf2Range velRange = const Sf2Range(low: 0, high: 127);

        for (int g = genStart; g < genEnd && g < rawPgen.length; g++) {
          final gen = rawPgen[g];
          genMap[gen.oper] = gen.amount;
          if (gen.oper == Sf2GeneratorType.instrument) {
            instId = gen.amount;
          } else if (gen.oper == Sf2GeneratorType.keyRange) {
            keyRange = Sf2Range(low: gen.amount & 0xFF, high: (gen.amount >> 8) & 0xFF);
          } else if (gen.oper == Sf2GeneratorType.velRange) {
            velRange = Sf2Range(low: gen.amount & 0xFF, high: (gen.amount >> 8) & 0xFF);
          }
        }

        zones.add(Sf2Zone(
          keyRange: keyRange,
          velRange: velRange,
          generators: genMap,
          instrumentId: instId,
        ));
      }

      presets.add(Sf2Preset(
        name: pr.name,
        patch: pr.patch,
        bank: pr.bank,
        zones: zones,
      ));
    }

    return _PdtaResult(
      presets: presets,
      instruments: instruments,
      sampleHeaders: sampleHeaders,
    );
  }
}

class _RawPreset {
  final String name;
  final int patch;
  final int bank;
  final int bagIndex;
  const _RawPreset({required this.name, required this.patch, required this.bank, required this.bagIndex});
}

class _RawInst {
  final String name;
  final int bagIndex;
  const _RawInst({required this.name, required this.bagIndex});
}

class _RawGen {
  final int oper;
  final int amount;
  const _RawGen({required this.oper, required this.amount});
}

class _PdtaResult {
  final List<Sf2Preset> presets;
  final List<Sf2Instrument> instruments;
  final List<Sf2SampleHeader> sampleHeaders;

  const _PdtaResult({
    required this.presets,
    required this.instruments,
    required this.sampleHeaders,
  });
}
