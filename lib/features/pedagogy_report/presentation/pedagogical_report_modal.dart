import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../domain/pedagogical_report_models.dart';
import '../../tuner_viewmodel.dart';

/// Modal interactivo para configurar y exportar el informe pedagógico y certificado en PDF.
class PedagogicalReportModal extends StatefulWidget {
  const PedagogicalReportModal({super.key});

  static Future<void> show(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
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
    String activeInstrumentName = 'Instrumento Actual';
    try {
      activeInstrumentName = context.read<TunerViewModel>().activeInstrument.name;
    } catch (_) {
      // Fallback cuando el modal se monta sin Provider<TunerViewModel> en pruebas aisladas.
    }
    _studentNameController =
        TextEditingController(text: 'Estudiante Conservatorio');
    _instrumentController =
        TextEditingController(text: activeInstrumentName);
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
    final tokens = StudioThemeScope.of(context);
    final session = vm.currentPedagogicalSessionData;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        children: [
          // Barra de arrastre superior
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: tokens.borderHairline,
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
                    color: tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: StudioIcon(
                    StudioIconId.fileExportPdf,
                    size: 20,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
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
                          color: tokens.textPrimary,
                        ),
                      ),
                      Text(
                        'Compilación Vectorial Imprimible (ISO 32000-1)',
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: StudioIcon(
                    StudioIconId.uiCloseConfirm,
                    size: 18,
                    color: tokens.textSecondary,
                    tintCustomAsset: true,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.borderSubtle),

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
                    color: tokens.accentPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    _buildKpiCard(
                      label: 'Afinación <= 5c',
                      value:
                          '${session.tuningAccuracyPercentage.toStringAsFixed(1)}%',
                      tokens: tokens,
                      accentColor: tokens.accentSuccess,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      label: 'Desv. Media',
                      value:
                          '${session.averageCentsDeviation >= 0 ? '+' : ''}${session.averageCentsDeviation.toStringAsFixed(1)} c',
                      tokens: tokens,
                      accentColor: tokens.accentPrimary,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      label: 'Nivel Logro',
                      value: session.masteryLevel,
                      tokens: tokens,
                      accentColor: tokens.accentSecondary,
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
                    color: tokens.accentPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  key: const Key('student_name_field'),
                  label: 'Nombre del Estudiante',
                  controller: _studentNameController,
                  iconId: StudioIconId.modulePedagogy,
                  fallbackIcon: Icons.person_outline,
                  tokens: tokens,
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  key: const Key('instrument_name_field'),
                  label: 'Instrumento / Registro Vocal',
                  controller: _instrumentController,
                  iconId: StudioIconId.fileMusicXmlMidi,
                  fallbackIcon: Icons.music_note_outlined,
                  tokens: tokens,
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  key: const Key('institution_field'),
                  label: 'Institución / Conservatorio',
                  controller: _institutionController,
                  iconId: StudioIconId.modulePedagogy,
                  fallbackIcon: Icons.school_outlined,
                  tokens: tokens,
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  key: const Key('teacher_name_field'),
                  label: 'Docente / Cátedra',
                  controller: _teacherController,
                  iconId: StudioIconId.moduleScoreSheet,
                  fallbackIcon: Icons.badge_outlined,
                  tokens: tokens,
                ),
                const SizedBox(height: 22),

                // Secciones a Incluir en el Documento
                Text(
                  'SECCIONES INCLUIDAS EN EL PDF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: tokens.accentPrimary,
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
                  tokens: tokens,
                ),

                _buildSwitchTile(
                  key: const Key('toggle_harmonics_histogram'),
                  title: 'Histograma Armónico (Serie de Fourier h1-h8)',
                  subtitle:
                      'Distribución de energía espectral y centroide tímbrico',
                  value: _includeHarmonics,
                  onChanged: (v) => setState(() => _includeHarmonics = v),
                  tokens: tokens,
                ),

                _buildSwitchTile(
                  key: const Key('toggle_rhythm_jitter'),
                  title: 'Variabilidad del Pulso (Jitter Temporal ms)',
                  subtitle:
                      'Desviación estándar de intervalos y consistencia métrica',
                  value: _includeJitter,
                  onChanged: (v) => setState(() => _includeJitter = v),
                  tokens: tokens,
                ),

                _buildSwitchTile(
                  key: const Key('toggle_certificate'),
                  title: 'Certificado de Aprovechamiento (Página 2)',
                  subtitle:
                      'Orla ornamental dorada, código criptográfico y sello oficial',
                  value: _includeCertificate,
                  onChanged: (v) => setState(() => _includeCertificate = v),
                  tokens: tokens,
                ),
              ],
            ),
          ),

          // Botón de Exportación Inferior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              border: Border(top: BorderSide(color: tokens.borderHairline)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('export_pedagogical_pdf_btn'),
                icon: _isExporting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.textOnAccent,
                        ),
                      )
                    : StudioIcon(
                        StudioIconId.fileExportPdf,
                        size: 18,
                        color: tokens.textOnAccent,
                        tintCustomAsset: true,
                      ),
                label: Text(
                  _isExporting
                      ? 'Compilando Documento...'
                      : 'Exportar Reporte PDF Vectorial',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.accentPrimary,
                  foregroundColor: tokens.textOnAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isExporting ? null : () => _exportPdf(vm, tokens),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(TunerViewModel vm, StudioDesignTokens tokens) async {
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
      final savedPath = await vm.platformFileGateway.saveExportedBytes(
        'tunner_pedagogical_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        pdfBytes,
      );

      if (!mounted) return;

      if (savedPath.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Exportacion cancelada o fallida.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: tokens.accentDanger,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reporte PDF exportado exitosamente ($sizeKb KB) en $savedPath',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: tokens.accentSuccess,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al exportar reporte PDF: $e',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: tokens.accentDanger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required StudioDesignTokens tokens,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.canvasBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: tokens.textMuted,
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
    required StudioIconId iconId,
    required IconData fallbackIcon,
    required StudioDesignTokens tokens,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: StudioIcon(
            iconId,
            size: 16,
            color: tokens.accentPrimary,
            tintCustomAsset: true,
            fallbackOverride: fallbackIcon,
          ),
        ),
        filled: true,
        fillColor: tokens.inputSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.borderHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.borderHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.borderFocus, width: 1.5),
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
    required StudioDesignTokens tokens,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.canvasBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderHairline),
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
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: key,
            value: value,
            onChanged: onChanged,
            activeThumbColor: tokens.accentPrimary,
            activeTrackColor: tokens.accentPrimary.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}
