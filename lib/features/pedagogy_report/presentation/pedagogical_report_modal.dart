import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/pedagogical_report_models.dart';
import '../../tuner_viewmodel.dart';

/// Modal interactivo para configurar y exportar el informe pedagógico y certificado en PDF.
class PedagogicalReportModal extends StatefulWidget {
  const PedagogicalReportModal({super.key});

  static Future<void> show(BuildContext context) {
    final vm = Provider.of<TunerViewModel>(context, listen: false);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: vm.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const PedagogicalReportModal(),
    );
  }

  @override
  State<PedagogicalReportModal> createState() => _PedagogicalReportModalState();
}

class _PedagogicalReportModalState extends State<PedagogicalReportModal> {
  late TextEditingController _studentNameController;
  late TextEditingController _instrumentController;
  late TextEditingController _institutionController;
  late TextEditingController _teacherController;

  bool _includeIntonation = true;
  bool _includeHarmonics = true;
  bool _includeJitter = true;
  bool _includeCertificate = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _studentNameController =
        TextEditingController(text: 'Estudiante Conservatorio');
    _instrumentController =
        TextEditingController(text: 'Flauta Traversa / Voz');
    _institutionController =
        TextEditingController(text: 'Tunner Acoustic Academy');
    _teacherController =
        TextEditingController(text: 'Cátedra de Instrumento y Acústica');
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _instrumentController.dispose();
    _institutionController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;
    final session = vm.currentPedagogicalSessionData;
    final cardBorder = palette.staffLinesColor.withValues(alpha: 0.3);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          // Barra de arrastre superior
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: palette.textMutedColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.primaryAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.picture_as_pdf,
                      size: 20, color: palette.primaryAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reporte Pedagógico y Certificado PDF',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: palette.textColor,
                        ),
                      ),
                      Text(
                        'Compilación Vectorial Imprimible (ISO 32000-1)',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textMutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textMutedColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Contenido con scroll
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Resumen de Métricas de la Sesión
                Text(
                  'RESUMEN ACÚSTICO DE SESIÓN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: palette.primaryAccent,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    _buildKpiCard(
                      label: 'Afinación <= 5c',
                      value:
                          '${session.tuningAccuracyPercentage.toStringAsFixed(1)}%',
                      palette: palette,
                      accentColor: palette.correctPitchColor,
                      cardBorder: cardBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      label: 'Desv. Media',
                      value:
                          '${session.averageCentsDeviation >= 0 ? '+' : ''}${session.averageCentsDeviation.toStringAsFixed(1)} c',
                      palette: palette,
                      accentColor: palette.primaryAccent,
                      cardBorder: cardBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      label: 'Nivel Logro',
                      value: session.masteryLevel,
                      palette: palette,
                      accentColor: palette.secondaryAccent,
                      cardBorder: cardBorder,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Formulario de Personalización
                Text(
                  'METADATOS DEL DOCUMENTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: palette.primaryAccent,
                  ),
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  key: const Key('student_name_field'),
                  label: 'Nombre del Estudiante',
                  controller: _studentNameController,
                  icon: Icons.person_outline,
                  palette: palette,
                  cardBorder: cardBorder,
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  key: const Key('instrument_name_field'),
                  label: 'Instrumento / Registro Vocal',
                  controller: _instrumentController,
                  icon: Icons.music_note_outlined,
                  palette: palette,
                  cardBorder: cardBorder,
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  key: const Key('institution_field'),
                  label: 'Institución / Conservatorio',
                  controller: _institutionController,
                  icon: Icons.school_outlined,
                  palette: palette,
                  cardBorder: cardBorder,
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  key: const Key('teacher_name_field'),
                  label: 'Docente / Cátedra',
                  controller: _teacherController,
                  icon: Icons.badge_outlined,
                  palette: palette,
                  cardBorder: cardBorder,
                ),
                const SizedBox(height: 22),

                // Secciones a Incluir en el Documento
                Text(
                  'SECCIONES INCLUIDAS EN EL PDF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: palette.primaryAccent,
                  ),
                ),
                const SizedBox(height: 8),

                _buildSwitchTile(
                  key: const Key('toggle_intonation_graph'),
                  title: 'Curva Vectorial de Micro-Entonación (+-5c)',
                  subtitle:
                      'Gráfico de desviación en cents vs tiempo con bandas de conservatorio',
                  value: _includeIntonation,
                  onChanged: (v) => setState(() => _includeIntonation = v),
                  palette: palette,
                  cardBorder: cardBorder,
                ),

                _buildSwitchTile(
                  key: const Key('toggle_harmonics_histogram'),
                  title: 'Histograma Armónico (Serie de Fourier h1-h8)',
                  subtitle:
                      'Distribución de energía espectral y centroide tímbrico',
                  value: _includeHarmonics,
                  onChanged: (v) => setState(() => _includeHarmonics = v),
                  palette: palette,
                  cardBorder: cardBorder,
                ),

                _buildSwitchTile(
                  key: const Key('toggle_rhythm_jitter'),
                  title: 'Variabilidad del Pulso (Jitter Temporal ms)',
                  subtitle:
                      'Desviación estándar de intervalos y consistencia métrica',
                  value: _includeJitter,
                  onChanged: (v) => setState(() => _includeJitter = v),
                  palette: palette,
                  cardBorder: cardBorder,
                ),

                _buildSwitchTile(
                  key: const Key('toggle_certificate'),
                  title: 'Certificado de Aprovechamiento (Página 2)',
                  subtitle:
                      'Orla ornamental dorada, código criptográfico y sello oficial',
                  value: _includeCertificate,
                  onChanged: (v) => setState(() => _includeCertificate = v),
                  palette: palette,
                  cardBorder: cardBorder,
                ),
              ],
            ),
          ),

          // Botón de Exportación Inferior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              border: Border(top: BorderSide(color: cardBorder)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('export_pedagogical_pdf_btn'),
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf, size: 20),
                label: Text(
                  _isExporting
                      ? 'Compilando Documento...'
                      : 'Exportar Reporte PDF Vectorial',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isExporting ? null : () => _exportPdf(vm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportPdf(TunerViewModel vm) {
    setState(() => _isExporting = true);

    try {
      final config = PedagogicalReportConfig(
        studentName: _studentNameController.text.trim().isNotEmpty
            ? _studentNameController.text.trim()
            : 'Estudiante Conservatorio',
        instrument: _instrumentController.text.trim().isNotEmpty
            ? _instrumentController.text.trim()
            : 'Flauta Traversa / Voz',
        institution: _institutionController.text.trim().isNotEmpty
            ? _institutionController.text.trim()
            : 'Tunner Acoustic Academy',
        teacherName: _teacherController.text.trim().isNotEmpty
            ? _teacherController.text.trim()
            : 'Cátedra de Instrumento y Acústica',
        includeIntonationGraph: _includeIntonation,
        includeHarmonicsRadar: _includeHarmonics,
        includeRhythmJitter: _includeJitter,
        includeCertificate: _includeCertificate,
      );

      final pdfBytes = vm.exportPedagogicalReportPdf(config);
      final sizeKb = (pdfBytes.length / 1024).toStringAsFixed(1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reporte PDF exportado exitosamente ($sizeKb KB)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF00C853),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required TunnerThemePalette palette,
    required Color accentColor,
    required Color cardBorder,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: palette.textMutedColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required TunnerThemePalette palette,
    required Color cardBorder,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      style: TextStyle(color: palette.textColor, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: palette.textMutedColor, fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: palette.primaryAccent),
        filled: true,
        fillColor: palette.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.primaryAccent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  Widget _buildSwitchTile({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required TunnerThemePalette palette,
    required Color cardBorder,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.textMutedColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: key,
            value: value,
            onChanged: onChanged,
            activeThumbColor: palette.primaryAccent,
            activeTrackColor: palette.primaryAccent.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}
