import 'dart:convert';
import 'dart:typed_data';

import 'vocal_evaluation_result.dart';

/// Generador canónico de certificados pedagógicos en formato binario PDF-1.4 (ISO 32000-1)
/// en Dart puro, sin dependencias de Flutter UI ni librerías de terceros.
class PedagogicalCertificatePdfGenerator {
  /// Genera los bytes binarios de un certificado PDF oficial para el estudiante especificado.
  static Uint8List generateCertificatePdf({
    required String studentName,
    required VocalEvaluationResult evaluation,
  }) {
    final buffer = BytesBuilder();

    // 1. Cabecera estándar PDF-1.4 con marcador binario de 4 bytes en latin1 1:1
    final header = '%PDF-1.4\n%\xE2\xE3\xCF\xD3\n';
    buffer.add(latin1.encode(header));

    final objectOffsets = <int>[];

    // Helper para escribir un objeto y registrar su desplazamiento
    void writeObject(int objectId, String content) {
      objectOffsets.add(buffer.length);
      final objStr = '$objectId 0 obj\n$content\nendobj\n';
      buffer.add(utf8.encode(objStr));
    }

    // Objeto 1: Catálogo raíz del documento
    writeObject(1, '<< /Type /Catalog /Pages 2 0 R >>');

    // Objeto 2: Árbol de páginas
    writeObject(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');

    // Objeto 5: Fuente Helvetica (Regular) con codificación WinAnsiEncoding
    writeObject(
      5,
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    );

    // Objeto 6: Fuente Helvetica-Bold (Negrita) con codificación WinAnsiEncoding
    writeObject(
      6,
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
    );

    // Construcción del contenido vectorial y tipográfico de la página
    final streamContent = _buildPageStreamContent(studentName, evaluation);
    final streamBytes = utf8.encode(streamContent);

    // Objeto 4: Flujo de contenido (Contents stream)
    writeObject(
      4,
      '<< /Length ${streamBytes.length} >>\nstream\n$streamContent\nendstream',
    );

    // Objeto 3: Página A4 (595.28 x 841.89 puntos)
    writeObject(
      3,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] '
      '/Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>',
    );

    // 2. Tabla de referencias cruzadas (xref)
    final xrefOffset = buffer.length;
    final totalObjects = 7; // Objeto 0 a 6

    final xrefHeader = 'xref\n0 $totalObjects\n0000000000 65535 f \r\n';
    buffer.add(utf8.encode(xrefHeader));

    // Mapa de objetos: 1, 2, 5, 6, 4, 3
    final sortedOffsets = List<int>.filled(totalObjects, 0);
    sortedOffsets[1] = objectOffsets[0];
    sortedOffsets[2] = objectOffsets[1];
    sortedOffsets[5] = objectOffsets[2];
    sortedOffsets[6] = objectOffsets[3];
    sortedOffsets[4] = objectOffsets[4];
    sortedOffsets[3] = objectOffsets[5];

    for (int i = 1; i < totalObjects; i++) {
      final offsetStr = sortedOffsets[i].toString().padLeft(10, '0');
      buffer.add(utf8.encode('$offsetStr 00000 n \r\n'));
    }

    // 3. Trailer y marcador final EOF
    final trailer = 'trailer\n<< /Size $totalObjects /Root 1 0 R >>\n'
        'startxref\n$xrefOffset\n%%EOF\n';
    buffer.add(utf8.encode(trailer));

    return buffer.toBytes();
  }

  /// Construye los comandos gráficos y textuales en sintaxis estándar de flujo PDF.
  static String _buildPageStreamContent(
    String studentName,
    VocalEvaluationResult eval,
  ) {
    final sb = StringBuffer();

    // Escape y sanitización de cadenas de texto PDF compatible con WinAnsiEncoding Type 1
    String escape(String text) => sanitizePdfText(text);

    // 1. Marco exterior decorativo (Borde Azul Oscuro y Gris Técnico)
    sb.writeln('0.10 0.14 0.20 RG 2 w');
    sb.writeln('25 25 545.28 791.89 re S');

    sb.writeln('0.25 0.35 0.45 RG 0.75 w');
    sb.writeln('32 32 531.28 777.89 re S');

    // 2. Cabecera institucional
    sb.writeln('0.08 0.12 0.18 rg');
    sb.writeln('33 735 529.28 73 re f');

    // Texto de Cabecera (Blanco)
    sb.writeln('BT');
    sb.writeln('/F2 18 Tf 1 1 1 rg');
    sb.writeln('135 770 Td (${escape("CONSERVATORIO DE AUDIO Y MUSICA TUNNER")}) Tj');
    sb.writeln('/F1 11 Tf 0.85 0.88 0.92 rg');
    sb.writeln('-40 -20 Td (${escape("CERTIFICADO OFICIAL DE EVALUACION Y ESTABILIDAD VOCAL")}) Tj');
    sb.writeln('ET');

    // 3. Bloque de Datos del Candidato
    sb.writeln('0.96 0.97 0.98 rg');
    sb.writeln('50 620 495 95 re f');
    sb.writeln('0.80 0.84 0.88 RG 1 w');
    sb.writeln('50 620 495 95 re S');

    sb.writeln('BT');
    sb.writeln('/F2 12 Tf 0.12 0.16 0.22 rg');
    sb.writeln('65 690 Td (${escape("CANDIDATO:")}) Tj');
    sb.writeln('/F1 12 Tf 0.20 0.24 0.30 rg');
    sb.writeln('110 0 Td (${escape(studentName)}) Tj');

    sb.writeln('/F2 10 Tf 0.12 0.16 0.22 rg');
    sb.writeln('-110 -22 Td (${escape("ID EVALUACION:")}) Tj');
    sb.writeln('/F1 10 Tf');
    sb.writeln('110 0 Td (${escape(eval.evaluationId)}) Tj');

    sb.writeln('/F2 10 Tf 0.12 0.16 0.22 rg');
    sb.writeln('-110 -22 Td (${escape("FECHA DE EMISION:")}) Tj');
    sb.writeln('/F1 10 Tf');
    sb.writeln('110 0 Td (${escape(eval.timestamp.toIso8601String().substring(0, 16).replaceAll("T", " "))}) Tj');
    sb.writeln('ET');

    // 4. Tabla de Métricas de Desempeño Acústico
    sb.writeln('0.10 0.15 0.22 rg');
    sb.writeln('50 580 495 24 re f');

    sb.writeln('BT');
    sb.writeln('/F2 10 Tf 1 1 1 rg');
    sb.writeln('65 588 Td (${escape("PARAMETRO CLINICO / ACUSTICO")}) Tj');
    sb.writeln('250 0 Td (${escape("VALOR REGISTRADO")}) Tj');
    sb.writeln('100 0 Td (${escape("ESTANDAR CONSERVATORIO")}) Tj');
    sb.writeln('ET');

    final rows = [
      ['Frecuencia Target', '${eval.targetFrequencyHz.toStringAsFixed(1)} Hz', 'Referencia Nominal'],
      ['Frecuencia Media Medida', '${eval.measuredMeanFrequencyHz.toStringAsFixed(1)} Hz', 'Registro Vocal'],
      ['Desviacion de Afinacion', '${eval.centsDeviation.toStringAsFixed(1)} cents', '<= 10.0 cents'],
      ['Jitter Relativo (Frecuencia)', '${eval.jitterPercent.toStringAsFixed(2)} %', '<= 1.00 % (Voz Sana)'],
      ['Shimmer de Amplitud (Volumen)', '${eval.shimmerPercent.toStringAsFixed(2)} %', '<= 3.50 % (Emision Pura)'],
      ['Tasa de Vibrato', '${eval.vibratoRateHz.toStringAsFixed(2)} Hz', '4.5 - 7.0 Hz'],
      ['Profundidad de Vibrato', '${eval.vibratoDepthCents.toStringAsFixed(1)} cents', '25.0 - 75.0 cents'],
    ];

    double currentY = 556.0;
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (i % 2 == 0) {
        sb.writeln('0.97 0.98 0.99 rg');
        sb.writeln('50 $currentY 495 24 re f');
      }
      sb.writeln('0.85 0.88 0.92 RG 0.5 w');
      sb.writeln('50 $currentY 495 24 re S');

      sb.writeln('BT');
      sb.writeln('/F2 9 Tf 0.15 0.20 0.28 rg');
      sb.writeln('65 ${currentY + 7} Td (${escape(row[0])}) Tj');
      sb.writeln('/F1 9 Tf 0.25 0.30 0.38 rg');
      sb.writeln('250 0 Td (${escape(row[1])}) Tj');
      sb.writeln('100 0 Td (${escape(row[2])}) Tj');
      sb.writeln('ET');

      currentY -= 24.0;
    }

    // 5. Cuadro de Calificación Final y Dictamen
    currentY -= 20.0;
    sb.writeln('0.92 0.95 0.98 rg');
    sb.writeln('50 $currentY 495 65 re f');
    sb.writeln('0.15 0.35 0.65 RG 1.5 w');
    sb.writeln('50 $currentY 495 65 re S');

    sb.writeln('BT');
    sb.writeln('/F2 13 Tf 0.10 0.25 0.55 rg');
    sb.writeln('65 ${currentY + 40} Td (${escape("CALIFICACION GLOBAL:")} ${eval.overallScore.toStringAsFixed(1)} / 100) Tj');
    sb.writeln('/F2 11 Tf 0.15 0.20 0.28 rg');
    sb.writeln('0 -22 Td (${escape("DICTAMEN:")} ${escape(eval.classificationLabel)}) Tj');
    sb.writeln('ET');

    // 6. Sello Criptográfico Digital SHA-256 (Inmutable)
    currentY -= 90.0;
    sb.writeln('0.94 0.94 0.95 rg');
    sb.writeln('50 $currentY 495 70 re f');
    sb.writeln('0.65 0.68 0.72 RG 0.75 w');
    sb.writeln('50 $currentY 495 70 re S');

    sb.writeln('BT');
    sb.writeln('/F2 9 Tf 0.20 0.25 0.35 rg');
    sb.writeln('65 ${currentY + 50} Td (${escape("SELLO DIGITAL CRIPTOGRAFICO SHA-256 (INMUTABLE):")}) Tj');
    sb.writeln('/F1 8 Tf 0.30 0.35 0.40 rg');
    sb.writeln('0 -18 Td (${escape(eval.payloadHashSha256)}) Tj');
    sb.writeln('/F1 7.5 Tf 0.45 0.50 0.55 rg');
    sb.writeln('0 -16 Td (${escape("Verificado y emitido por Tunner Acoustic Lab & Audio Engine (Monolito Local)")}) Tj');
    sb.writeln('ET');

    return sb.toString();
  }

  /// Sanitiza cadenas para literales seguros en sintaxis PDF (...)
  /// y normaliza caracteres acentuados y eñes para compatibilidad con WinAnsiEncoding Type 1.
  static String sanitizePdfText(String text) {
    return text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }
}
