import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'pedagogical_report_models.dart';

/// Compilador en Pure Dart de reportes analíticos y certificados de conservatorio
/// al estándar internacional PDF (ISO 32000-1 / PDF 1.4).
/// 100% Offline, sin dependencias externas ni código nativo.
class PedagogicalReportPdfGenerator {
  static const double pageWidth = 595.28; // A4 ancho en puntos PostScript (72 pt/pulgada)
  static const double pageHeight = 841.89; // A4 alto en puntos PostScript

  const PedagogicalReportPdfGenerator();

  /// Compila el reporte y certificado a un array de bytes binarios PDF válidos.
  Uint8List generateReportPdf({
    required PedagogicalSessionData session,
    required PedagogicalReportConfig config,
  }) {
    final pageStreams = <String>[];

    // Página 1: Informe Pedagógico y Analítica Acústica
    pageStreams.add(_buildPage1Analytics(session, config));

    // Página 2: Certificado Formal de Logro de Conservatorio (si está activado)
    if (config.includeCertificate) {
      pageStreams.add(_buildPage2Certificate(session, config));
    }

    return _compilePdfDocument(
      pageStreams,
      title: 'Informe Pedagogico - ${config.studentName}',
      author: 'Tunner Acoustic Studio',
    );
  }

  // ==========================================
  // PAGINA 1: INFORME ANALITICO
  // ==========================================
  String _buildPage1Analytics(
    PedagogicalSessionData session,
    PedagogicalReportConfig config,
  ) {
    final b = StringBuffer();

    // 1. Franja de Cabecera Superior (Azul / Índigo oscuro: #111827 / #1E293B)
    b.writeln('q');
    b.writeln('0.07 0.09 0.15 rg'); // Fill oscuro
    b.writeln('0 760 595.28 81.89 re f'); // Rectángulo superior
    b.writeln('0.22 0.74 0.97 RG 3 w'); // Borde inferior Cyan
    b.writeln('0 760 m 595.28 760 l S');

    // Título en cabecera
    b.writeln('BT');
    b.writeln('/F2 20 Tf'); // Helvetica-Bold 20pt
    b.writeln('1 1 1 rg'); // Blanco
    b.writeln('35 798 Td');
    b.writeln('(${_sanitize("TUNER ACOUSTIC STUDIO")}) Tj');
    b.writeln('ET');

    // Subtítulo cabecera
    b.writeln('BT');
    b.writeln('/F1 11 Tf'); // Helvetica 11pt
    b.writeln('0.7 0.85 0.95 rg');
    b.writeln('35 778 Td');
    b.writeln('(${_sanitize("INFORME ANALITICO DE PROGRESO PEDAGOGICO Y ACUSTICO")}) Tj');
    b.writeln('ET');
    b.writeln('Q');

    // 2. Bloque de Metadatos del Estudiante (y=700 a y=745)
    b.writeln('q');
    b.writeln('0.95 0.96 0.98 rg');
    b.writeln('35 700 525.28 48 re f');
    b.writeln('0.85 0.88 0.92 RG 1 w');
    b.writeln('35 700 525.28 48 re S');

    b.writeln('BT');
    b.writeln('/F2 10 Tf');
    b.writeln('0.15 0.2 0.3 rg');
    b.writeln('45 732 Td');
    b.writeln('(${_sanitize("Estudiante: ${config.studentName}")}) Tj');
    b.writeln('/F1 9 Tf');
    b.writeln('0.3 0.35 0.4 rg');
    b.writeln('0 -14 Td');
    b.writeln('(${_sanitize("Instrumento: ${config.instrument}  |  Institucion: ${config.institution}")}) Tj');
    b.writeln('ET');

    // Metadatos columna derecha
    final dateStr =
        '${session.sessionDate.year}-${session.sessionDate.month.toString().padLeft(2, '0')}-${session.sessionDate.day.toString().padLeft(2, '0')}';
    final durStr =
        '${session.duration.inMinutes}m ${(session.duration.inSeconds % 60)}s';
    b.writeln('BT');
    b.writeln('/F2 9 Tf');
    b.writeln('0.15 0.2 0.3 rg');
    b.writeln('380 732 Td');
    b.writeln('(${_sanitize("Fecha: $dateStr  |  Duracion: $durStr")}) Tj');
    b.writeln('/F2 9 Tf');
    b.writeln('0.05 0.6 0.3 rg'); // Verde nivel
    b.writeln('0 -14 Td');
    b.writeln('(${_sanitize("Nivel de Logro: ${session.masteryLevel}")}) Tj');
    b.writeln('ET');
    b.writeln('Q');

    // 3. Tarjetas KPI de Rendimiento (y=620 a y=685)
    final cardW = 124.0;
    final cardH = 65.0;
    final cardGap = 9.7;
    final startX = 35.0;
    final cardY = 620.0;

    _drawKpiCard(
      b,
      x: startX,
      y: cardY,
      w: cardW,
      h: cardH,
      title: 'Afinacion <= 5c',
      value: '${session.tuningAccuracyPercentage.toStringAsFixed(1)}%',
      subtitle: '${session.inTuneNotesCount}/${session.totalEvaluatedNotes} notas',
      accentR: 0.0,
      accentG: 0.75,
      accentB: 0.45,
    );

    _drawKpiCard(
      b,
      x: startX + (cardW + cardGap),
      y: cardY,
      w: cardW,
      h: cardH,
      title: 'Desviacion Media',
      value:
          '${session.averageCentsDeviation >= 0 ? "+" : ""}${session.averageCentsDeviation.toStringAsFixed(1)} c',
      subtitle: 'Estabilidad: ${session.centsStabilityDelta.toStringAsFixed(1)} c',
      accentR: 0.05,
      accentG: 0.6,
      accentB: 0.9,
    );

    _drawKpiCard(
      b,
      x: startX + 2 * (cardW + cardGap),
      y: cardY,
      w: cardW,
      h: cardH,
      title: 'Centroide / THD',
      value: '${session.spectralCentroidHz.toStringAsFixed(0)} Hz',
      subtitle: 'THD: ${session.thdPercentage.toStringAsFixed(1)}%',
      accentR: 0.9,
      accentG: 0.55,
      accentB: 0.1,
    );

    _drawKpiCard(
      b,
      x: startX + 3 * (cardW + cardGap),
      y: cardY,
      w: cardW,
      h: cardH,
      title: 'Jitter de Pulso',
      value: '${session.rhythmJitterMs.toStringAsFixed(1)} ms',
      subtitle: 'Tempo: ${session.rhythmMeanBpm.toStringAsFixed(0)} BPM',
      accentR: 0.6,
      accentG: 0.3,
      accentB: 0.85,
    );

    // 4. Lienzo Vectorial de Micro-Entonacion (y=415 a y=595, alto=180)
    if (config.includeIntonationGraph) {
      _drawIntonationChart(b, session: session, x: 35.0, y: 415.0, w: 525.28, h: 180.0);
    }

    // 5. Histograma de Armonicos Espectrales (y=280 a y=395, alto=115)
    if (config.includeHarmonicsRadar) {
      _drawHarmonicsHistogram(b, session: session, x: 35.0, y: 280.0, w: 525.28, h: 115.0);
    }

    // 6. Diagnostico Pedagogico y Pautas de Estudio (y=55 a y=260, alto=205)
    _drawDiagnosticBox(b, session: session, config: config, x: 35.0, y: 55.0, w: 525.28, h: 205.0);

    // Pie de pagina analitico
    b.writeln('BT');
    b.writeln('/F1 8 Tf');
    b.writeln('0.5 0.55 0.6 rg');
    b.writeln('35 30 Td');
    b.writeln('(${_sanitize("Tunner Studio v1.0 | Acreditacion Acustica Digital | Pagina 1 de ${config.includeCertificate ? '2' : '1'}")}) Tj');
    b.writeln('ET');

    return b.toString();
  }

  // ==========================================
  // PAGINA 2: CERTIFICADO DE CONSERVATORIO
  // ==========================================
  String _buildPage2Certificate(
    PedagogicalSessionData session,
    PedagogicalReportConfig config,
  ) {
    final b = StringBuffer();

    // 1. Fondo suave crema de pergamino de conservatorio (#FBFBFA)
    b.writeln('q');
    b.writeln('0.985 0.985 0.975 rg');
    b.writeln('0 0 595.28 841.89 re f');

    // 2. Orla Ornamental Vectorial Exterior (Borde dorado / añil noble)
    b.writeln('0.75 0.6 0.2 RG 3 w'); // Borde exterior dorado
    b.writeln('25 25 545.28 791.89 re S');

    b.writeln('0.1 0.15 0.25 RG 1 w'); // Filete interior fino azul noche
    b.writeln('32 32 531.28 777.89 re S');

    // Esquinas decorativas de la orla
    _drawOrnamentalCorner(b, 32, 32, 1, 1);
    _drawOrnamentalCorner(b, 563.28, 32, -1, 1);
    _drawOrnamentalCorner(b, 32, 809.89, 1, -1);
    _drawOrnamentalCorner(b, 563.28, 809.89, -1, -1);
    b.writeln('Q');

    // 3. Encabezado Institucional Ceremonial
    b.writeln('BT');
    b.writeln('/F2 13 Tf');
    b.writeln('0.4 0.45 0.5 rg');
    b.writeln('160 740 Td');
    b.writeln('(${_sanitize("TUNER CONSERVATORY ACADEMY OF MUSIC")}) Tj');
    b.writeln('ET');

    b.writeln('BT');
    b.writeln('/F1 10 Tf');
    b.writeln('0.6 0.5 0.2 rg');
    b.writeln('215 722 Td');
    b.writeln('(${_sanitize("CATEDRA DE ACUSTICA Y ENTRENAMIENTO AUDITIVO")}) Tj');
    b.writeln('ET');

    // Separador ornamental dorado central
    b.writeln('q');
    b.writeln('0.75 0.6 0.2 RG 1.5 w');
    b.writeln('180 705 m 415 705 l S');
    b.writeln('297.64 705 4 0 360 arc f'); // Pequeño círculo central
    b.writeln('Q');

    // 4. Gran Titulo del Certificado
    b.writeln('BT');
    b.writeln('/F2 26 Tf');
    b.writeln('0.1 0.15 0.28 rg');
    b.writeln('105 655 Td');
    b.writeln('(${_sanitize("CERTIFICADO DE APROVECHAMIENTO")}) Tj');
    b.writeln('ET');

    b.writeln('BT');
    b.writeln('/F1 13 Tf');
    b.writeln('0.45 0.5 0.55 rg');
    b.writeln('180 630 Td');
    b.writeln('(${_sanitize("Y EXCELENCIA DE ENTONACION ACUSTICA")}) Tj');
    b.writeln('ET');

    // 5. Formula de Otorgamiento
    b.writeln('BT');
    b.writeln('/F1 11 Tf');
    b.writeln('0.3 0.35 0.4 rg');
    b.writeln('80 575 Td');
    b.writeln('(${_sanitize("Por cuanto se ha acreditado el riguroso cumplimiento de los estandares de afinacion,")}) Tj');
    b.writeln('0 -16 Td');
    b.writeln('(${_sanitize("estabilidad microtonal y regularidad timbrica en sesiones de practica deliberada,")}) Tj');
    b.writeln('0 -16 Td');
    b.writeln('(${_sanitize("se confiere con distincion formal el presente certificado a:")}) Tj');
    b.writeln('ET');

    // 6. Nombre del Estudiante (Grande, centrado, destacado)
    b.writeln('BT');
    b.writeln('/F2 24 Tf');
    b.writeln('0.05 0.25 0.5 rg'); // Azul zafiro destacado
    b.writeln('110 485 Td');
    b.writeln('(${_sanitize(config.studentName.toUpperCase())}) Tj');
    b.writeln('ET');

    // Línea de base dorada bajo el nombre
    b.writeln('q');
    b.writeln('0.75 0.6 0.2 RG 2 w');
    b.writeln('100 475 m 495 475 l S');
    b.writeln('Q');

    // 7. Detalle del Logro y Nivel
    b.writeln('BT');
    b.writeln('/F1 11 Tf');
    b.writeln('0.25 0.3 0.35 rg');
    b.writeln('80 430 Td');
    b.writeln('(${_sanitize("En reconocimiento a la maestria demostrada en la disciplina de: ${config.instrument}")}) Tj');
    b.writeln('0 -20 Td');
    b.writeln('/F2 12 Tf');
    b.writeln('0.05 0.55 0.3 rg'); // Verde nivel
    b.writeln('(${_sanitize("Nivel Evaluado: ${session.masteryLevel.toUpperCase()}")}) Tj');
    b.writeln('/F1 10 Tf');
    b.writeln('0.4 0.45 0.5 rg');
    b.writeln('0 -18 Td');
    b.writeln('(${_sanitize("Precision en Cents: ${session.tuningAccuracyPercentage.toStringAsFixed(1)}%  |  Tolerancia: +-5 cents  |  Desviacion: ${session.averageCentsDeviation.toStringAsFixed(1)} c")}) Tj');
    b.writeln('0 -16 Td');
    b.writeln('(${_sanitize("Estabilidad de Pulso: ${session.rhythmJitterMs.toStringAsFixed(1)} ms jitter  |  Centroide: ${session.spectralCentroidHz.toStringAsFixed(0)} Hz")}) Tj');
    b.writeln('ET');

    // 8. Sello Acústico Ornamental Vectorial (y=160 a y=260, x=100 a x=200)
    _drawAcousticSeal(b, 150.0, 230.0);

    // 9. Bloque de Firma y Acreditación (y=180 a y=260, x=340 a x=500)
    b.writeln('q');
    b.writeln('0.3 0.35 0.4 RG 1.5 w');
    b.writeln('340 220 m 490 220 l S'); // Línea de firma
    b.writeln('Q');

    b.writeln('BT');
    b.writeln('/F2 9.5 Tf');
    b.writeln('0.15 0.2 0.25 rg');
    b.writeln('355 204 Td');
    b.writeln('(${_sanitize(config.teacherName)}) Tj');
    b.writeln('/F1 8.5 Tf');
    b.writeln('0.45 0.5 0.55 rg');
    b.writeln('0 -13 Td');
    b.writeln('(${_sanitize(config.institution)}) Tj');
    b.writeln('0 -13 Td');
    b.writeln('(${_sanitize("Firma Autorizada de Conservatorio")}) Tj');
    b.writeln('ET');

    // 10. Código de Autenticación Criptográfica Local y Fecha
    final dateStr =
        '${session.sessionDate.year}-${session.sessionDate.month.toString().padLeft(2, '0')}-${session.sessionDate.day.toString().padLeft(2, '0')}';
    final tokenHash =
        'TN-${session.sessionDate.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}-${session.inTuneNotesCount.toRadixString(16).toUpperCase()}';

    b.writeln('BT');
    b.writeln('/F1 8 Tf');
    b.writeln('0.5 0.55 0.6 rg');
    b.writeln('70 85 Td');
    b.writeln('(${_sanitize("Credencial Acustica Digital: $tokenHash   |   Expedido el: $dateStr")}) Tj');
    b.writeln('0 -12 Td');
    b.writeln('(${_sanitize("Tunner Open-Source Architecture | Pure Dart Offline Engine | Pagina 2 de 2")}) Tj');
    b.writeln('ET');

    return b.toString();
  }

  // ==========================================
  // GRAFICOS VECTORIALES AUXILIARES
  // ==========================================

  void _drawKpiCard(
    StringBuffer b, {
    required double x,
    required double y,
    required double w,
    required double h,
    required String title,
    required String value,
    required String subtitle,
    required double accentR,
    required double accentG,
    required double accentB,
  }) {
    b.writeln('q');
    // Fondo de tarjeta
    b.writeln('0.97 0.98 0.99 rg');
    b.writeln('$x $y $w $h re f');

    // Borde suave
    b.writeln('0.85 0.88 0.92 RG 1 w');
    b.writeln('$x $y $w $h re S');

    // Barra de acento lateral izquierda
    b.writeln('$accentR $accentG $accentB rg');
    b.writeln('$x $y 4 $h re f');

    // Textos
    b.writeln('BT');
    b.writeln('/F1 8 Tf');
    b.writeln('0.4 0.45 0.5 rg');
    b.writeln('${x + 10} ${y + h - 16} Td');
    b.writeln('(${_sanitize(title)}) Tj');

    b.writeln('/F2 14 Tf');
    b.writeln('0.1 0.15 0.22 rg');
    b.writeln('0 -18 Td');
    b.writeln('(${_sanitize(value)}) Tj');

    b.writeln('/F1 7.5 Tf');
    b.writeln('0.5 0.55 0.6 rg');
    b.writeln('0 -14 Td');
    b.writeln('(${_sanitize(subtitle)}) Tj');
    b.writeln('ET');
    b.writeln('Q');
  }

  void _drawIntonationChart(
    StringBuffer b, {
    required PedagogicalSessionData session,
    required double x,
    required double y,
    required double w,
    required double h,
  }) {
    b.writeln('q');

    // Marco y fondo del gráfico
    b.writeln('0.985 0.988 0.995 rg');
    b.writeln('$x $y $w $h re f');
    b.writeln('0.82 0.86 0.9 RG 1 w');
    b.writeln('$x $y $w $h re S');

    // Título del gráfico
    b.writeln('BT');
    b.writeln('/F2 9.5 Tf');
    b.writeln('0.15 0.2 0.3 rg');
    b.writeln('${x + 12} ${y + h - 16} Td');
    b.writeln('(${_sanitize("ESTABILIDAD DE MICRO-ENTONACION (DESVIACION EN CENTS vs TIEMPO)")}) Tj');
    b.writeln('ET');

    final plotX = x + 35.0;
    final plotY = y + 20.0;
    final plotW = w - 45.0;
    final plotH = h - 45.0;
    final midY = plotY + (plotH / 2.0); // 0 cents

    // Banda Verde Conservatorio (+-5 cents) -> escala: +-50 cents mapeado a plotH
    final centsScale = (plotH / 2.0) / 50.0; // Puntos por cent
    final band5H = 10.0 * centsScale;
    b.writeln('0.88 0.97 0.91 rg'); // Verde pálido
    b.writeln('$plotX ${midY - (5.0 * centsScale)} $plotW $band5H re f');

    // Banda Ámbar Ensamble (+-15 cents)
    b.writeln('0.98 0.95 0.88 rg'); // Ámbar pálido
    // Solo dibujamos los límites
    b.writeln('0.8 0.7 0.4 RG 0.5 w');
    b.writeln('$plotX ${midY + (15.0 * centsScale)} m ${plotX + plotW} ${midY + (15.0 * centsScale)} l S');
    b.writeln('$plotX ${midY - (15.0 * centsScale)} m ${plotX + plotW} ${midY - (15.0 * centsScale)} l S');

    // Eje Central 0 cents (Línea discontinua o sólida gris)
    b.writeln('0.4 0.75 0.5 RG 1 w');
    b.writeln('$plotX $midY m ${plotX + plotW} $midY l S');

    // Etiquetas del eje Y
    b.writeln('BT');
    b.writeln('/F1 7 Tf');
    b.writeln('0.45 0.5 0.55 rg');
    b.writeln('${x + 8} ${midY + (45.0 * centsScale) - 3} Td');
    b.writeln('(${_sanitize("+50c")}) Tj');
    b.writeln('${x + 8} ${midY - 3} Td');
    b.writeln('(${_sanitize("  0c")}) Tj');
    b.writeln('${x + 8} ${midY - (45.0 * centsScale) - 3} Td');
    b.writeln('(${_sanitize("-50c")}) Tj');
    b.writeln('ET');

    // Curva Vectorial de Entonación
    final samples = session.timedPitchSamples;
    if (samples.length >= 2) {
      final maxTime = samples.last.timeSec > 0 ? samples.last.timeSec : 1.0;
      b.writeln('0.05 0.55 0.9 RG 1.5 w'); // Azul/Cyan intenso

      for (int i = 0; i < samples.length; i++) {
        final s = samples[i];
        final px = plotX + ((s.timeSec / maxTime) * plotW);
        final py = (midY + (s.cents * centsScale)).clamp(plotY, plotY + plotH);
        if (i == 0) {
          b.writeln('$px $py m');
        } else {
          b.writeln('$px $py l');
        }
      }
      b.writeln('S');
    }

    b.writeln('Q');
  }

  void _drawHarmonicsHistogram(
    StringBuffer b, {
    required PedagogicalSessionData session,
    required double x,
    required double y,
    required double w,
    required double h,
  }) {
    b.writeln('q');
    // Marco y fondo
    b.writeln('0.985 0.988 0.995 rg');
    b.writeln('$x $y $w $h re f');
    b.writeln('0.82 0.86 0.9 RG 1 w');
    b.writeln('$x $y $w $h re S');

    // Título
    b.writeln('BT');
    b.writeln('/F2 9.5 Tf');
    b.writeln('0.15 0.2 0.3 rg');
    b.writeln('${x + 12} ${y + h - 16} Td');
    b.writeln('(${_sanitize("DISTRIBUCION DE ENERGIA ARMONICA (SERIE DE FOURIER h1 - h8)")}) Tj');
    b.writeln('ET');

    final ratios = session.harmonicRatios;
    final count = math.min(8, ratios.length);
    final plotX = x + 30.0;
    final plotY = y + 20.0;
    final plotW = w - 50.0;
    final plotH = h - 45.0;
    final barW = (plotW / 8.0) * 0.55;
    final stepX = plotW / 8.0;

    for (int i = 0; i < count; i++) {
      final ratio = ratios[i].clamp(0.0, 1.0);
      final bx = plotX + (i * stepX) + (stepX - barW) / 2.0;
      final bh = math.max(2.0, ratio * plotH);

      // Barra vectorial con color degradado armónico
      b.writeln('0.2 0.6 0.85 rg');
      b.writeln('$bx $plotY $barW $bh re f');

      // Etiqueta h1, h2...
      b.writeln('BT');
      b.writeln('/F1 7.5 Tf');
      b.writeln('0.4 0.45 0.5 rg');
      b.writeln('${bx + 2} ${plotY - 11} Td');
      b.writeln('(${_sanitize("h${i + 1}")}) Tj');
      b.writeln('ET');
    }

    b.writeln('Q');
  }

  void _drawDiagnosticBox(
    StringBuffer b, {
    required PedagogicalSessionData session,
    required PedagogicalReportConfig config,
    required double x,
    required double y,
    required double w,
    required double h,
  }) {
    b.writeln('q');
    // Fondo de diagnóstico
    b.writeln('0.96 0.975 0.985 rg');
    b.writeln('$x $y $w $h re f');
    b.writeln('0.8 0.85 0.9 RG 1 w');
    b.writeln('$x $y $w $h re S');

    // Título de diagnóstico
    b.writeln('BT');
    b.writeln('/F2 10 Tf');
    b.writeln('0.12 0.18 0.28 rg');
    b.writeln('${x + 14} ${y + h - 18} Td');
    b.writeln('(${_sanitize("DIAGNOSTICO PEDAGOGICO FORMATIVO Y PAUTAS TECNICAS")}) Tj');
    b.writeln('ET');

    // Texto de diagnóstico
    b.writeln('BT');
    b.writeln('/F1 8.5 Tf');
    b.writeln('0.25 0.3 0.35 rg');
    b.writeln('${x + 14} ${y + h - 36} Td');
    b.writeln('(${_sanitize(session.pedagogicalDiagnostic)}) Tj');

    // Recomendaciones con viñetas
    b.writeln('/F2 8.5 Tf');
    b.writeln('0.15 0.2 0.3 rg');
    b.writeln('0 -22 Td');
    b.writeln('(${_sanitize("Prescripciones de Estudio Focalizado:")}) Tj');

    b.writeln('/F1 8 Tf');
    b.writeln('0.3 0.35 0.4 rg');
    for (int i = 0; i < session.recommendations.length; i++) {
      b.writeln('0 -15 Td');
      b.writeln('(${_sanitize("- ${session.recommendations[i]}")}) Tj');
    }
    b.writeln('ET');
    b.writeln('Q');
  }

  void _drawOrnamentalCorner(
    StringBuffer b,
    double cx,
    double cy,
    double dx,
    double dy,
  ) {
    // Dibuja una escuadra ornamental geométrica
    final len = 20.0;
    b.writeln('$cx $cy m ${cx + (dx * len)} $cy l S');
    b.writeln('$cx $cy m $cx ${cy + (dy * len)} l S');
    b.writeln('${cx + (dx * 6)} ${cy + (dy * 6)} 2.5 0 360 arc f');
  }

  void _drawAcousticSeal(StringBuffer b, double cx, double cy) {
    b.writeln('q');
    b.writeln('0.75 0.6 0.2 RG 1.5 w');
    // Círculo exterior
    b.writeln('$cx $cy 38 0 360 arc S');
    // Círculo interior
    b.writeln('0.15 0.2 0.3 RG 0.8 w');
    b.writeln('$cx $cy 32 0 360 arc S');

    // Letras dentro del sello
    b.writeln('BT');
    b.writeln('/F2 8 Tf');
    b.writeln('0.75 0.6 0.2 rg');
    b.writeln('${cx - 24} ${cy + 6} Td');
    b.writeln('(${_sanitize("TUNER")}) Tj');
    b.writeln('/F1 6.5 Tf');
    b.writeln('${cx - 27} ${cy - 8} Td');
    b.writeln('(${_sanitize("ACCREDITED")}) Tj');
    b.writeln('ET');
    b.writeln('Q');
  }

  // ==========================================
  // COMPILACION DE ESTRUCTURA BINARIA PDF 1.4
  // ==========================================
  Uint8List _compilePdfDocument(
    List<String> pageStreams, {
    required String title,
    required String author,
  }) {
    final cleanTitle = _sanitize(title);
    final cleanAuthor = _sanitize(author);

    // Tipografías estándar PostScript Type 1
    final fontF1 =
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>';
    final fontF2 =
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>';

    final totalPages = pageStreams.length;
    final objects = <String>[];

    // Objeto 1: Catalog
    objects.add('<< /Type /Catalog /Pages 2 0 R >>');

    // Objeto 2: Pages Tree
    final kidsRefs = StringBuffer();
    for (int p = 0; p < totalPages; p++) {
      final pageObjIndex = 5 + (p * 2);
      kidsRefs.write('$pageObjIndex 0 R ');
    }
    objects.add('<< /Type /Pages /Kids [ $kidsRefs] /Count $totalPages >>');

    // Objeto 3: Font F1
    objects.add(fontF1);

    // Objeto 4: Font F2
    objects.add(fontF2);

    // Objetos de páginas y sus flujos de contenidos
    for (int p = 0; p < totalPages; p++) {
      final streamObjIndex = 6 + (p * 2);
      final pageObject = '<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 $pageWidth $pageHeight] '
          '/Contents $streamObjIndex 0 R '
          '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> >>';
      objects.add(pageObject);

      final streamData = utf8.encode(pageStreams[p]);
      final streamLength = streamData.length;
      final contentStreamObject =
          '<< /Length $streamLength >>\nstream\n${pageStreams[p]}\nendstream';
      objects.add(contentStreamObject);
    }

    // Objeto Info
    final infoObject = '<< /Title ($cleanTitle) '
        '/Author ($cleanAuthor) '
        '/Creator (Tunner Open-Source Platform) '
        '/Producer (Tunner Pedagogical Report Generator ISO 32000-1) >>';
    objects.add(infoObject);
    final infoObjIndex = objects.length;

    // Ensamble binario de tabla xref y trailer
    final header = '%PDF-1.4\n%\xE2\xE3\xCF\xD3\n';
    final bytesBuilder = BytesBuilder();
    bytesBuilder.add(utf8.encode(header));

    final offsets = <int>[];
    int currentOffset = header.length;

    for (int i = 0; i < objects.length; i++) {
      offsets.add(currentOffset);
      final objDef = '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
      final encoded = utf8.encode(objDef);
      bytesBuilder.add(encoded);
      currentOffset += encoded.length;
    }

    final startXref = currentOffset;
    final xrefBuilder = StringBuffer();
    final totalObjectsCount = objects.length + 1;
    xrefBuilder.writeln('xref');
    xrefBuilder.writeln('0 $totalObjectsCount');
    xrefBuilder.writeln('0000000000 65535 f ');

    for (final off in offsets) {
      final padded = off.toString().padLeft(10, '0');
      xrefBuilder.writeln('$padded 00000 n ');
    }

    xrefBuilder.writeln('trailer');
    xrefBuilder.writeln(
        '<< /Size $totalObjectsCount /Root 1 0 R /Info $infoObjIndex 0 R >>');
    xrefBuilder.writeln('startxref');
    xrefBuilder.writeln('$startXref');
    xrefBuilder.writeln('%%EOF');

    bytesBuilder.add(utf8.encode(xrefBuilder.toString()));
    return bytesBuilder.toBytes();
  }

  /// Sanitiza cadenas para literales seguros en sintaxis PDF (...)
  /// y normaliza caracteres acentuados para compatibilidad con WinAnsiEncoding Type 1.
  String _sanitize(String text) {
    return text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }
}
