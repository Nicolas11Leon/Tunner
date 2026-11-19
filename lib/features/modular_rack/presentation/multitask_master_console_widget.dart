import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modular_rack_viewmodel.dart';
import 'studio_patchbay_modal.dart';
import 'universal_instrument_search_modal.dart';
import '../../instrument/presentation/instrument_customization_modal.dart';
import '../../instrument/presentation/universal_master_keyboard_widget.dart';
import '../../tuner_viewmodel.dart';

/// Consola Central Multitarea de Coordinación y Control Maestro.
/// Muestra transporte global sincronizado (Play, Rec, Stop), estado de sincronía,
/// botón de Matriz de Conexiones por ID y selector del instrumento activo.
class MultitaskMasterConsoleWidget extends StatelessWidget {
  final ModularRackViewModel viewModel;

  const MultitaskMasterConsoleWidget({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final instrument = viewModel.activeInstrument;
        final primaryColor = instrument.visualProfile.primaryAccentColor;
        final isRunning = viewModel.isSessionRunning;
        final isRecording = viewModel.isRecording;
        final connectionsCount = viewModel.signalBus.activeConnections.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border(
              bottom: BorderSide(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fila superior: Selector de Instrumento & Matriz de IDs
              Row(
                children: [
                  // Badge interactivo de instrumento con su estética
                  Flexible(
                    child: InkWell(
                      onTap: () => UniversalInstrumentSearchModal.show(context, viewModel),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: instrument.visualProfile.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(instrument.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                instrument.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: primaryColor, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Botón Teclado Emulador de Estrofas
                  IconButton(
                    icon: const Icon(Icons.piano, color: Color(0xFF38BDF8), size: 22),
                    tooltip: 'Teclado Maestro & Reproductor de Estrofas',
                    onPressed: () {
                      UniversalMasterKeyboardWidget.show(
                        context,
                        customization: viewModel.customization,
                        onUpdated: viewModel.updateCustomization,
                      );
                    },
                  ),

                  // Botón Personalización Acústica y Desafinación
                  IconButton(
                    icon: Icon(Icons.tune, color: primaryColor, size: 22),
                    tooltip: 'Personalizar Tono, Timbre & Desafinación',
                    onPressed: () {
                      InstrumentCustomizationModal.show(
                        context,
                        currentProfile: viewModel.customization,
                        onUpdated: viewModel.updateCustomization,
                      );
                    },
                  ),

                  // Botón de Matriz de Canales / IDs de Conexión
                  InkWell(
                    onTap: () => StudioPatchbayModal.show(context, viewModel),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: connectionsCount > 0 ? const Color(0xFF10B981) : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.alt_route,
                            size: 14,
                            color: connectionsCount > 0 ? const Color(0xFF10B981) : Colors.white60,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'PATCHBAY ($connectionsCount)',
                            style: TextStyle(
                              color: connectionsCount > 0 ? const Color(0xFF10B981) : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Menú de Gestión de Archivos de Proyecto Propietario (.tunner / .tnt)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.folder_open, color: Color(0xFF38BDF8), size: 20),
                    color: const Color(0xFF1E293B),
                    tooltip: 'Proyectos y Archivos (.tunner)',
                    onSelected: (action) {
                      switch (action) {
                        case 'save_project':
                          _showSaveProjectDialog(context);
                          break;
                        case 'new_project':
                          viewModel.loadPreset('default');
                          break;
                        case 'import_tool':
                          _showImportToolDialog(context);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'save_project',
                        child: Row(
                          children: [
                            Icon(Icons.save, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text('Guardar Proyecto Comprimido (.tunner)', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'import_tool',
                        child: Row(
                          children: [
                            Icon(Icons.file_open, size: 16, color: Color(0xFF38BDF8)),
                            SizedBox(width: 8),
                            Text('Importar Herramienta Preset (.tnt)', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'new_project',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 16, color: Colors.white60),
                            SizedBox(width: 8),
                            Text('Reiniciar Sesión Vacía / Default', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 4),

                  // Menú rápido de Presets de Estudio
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
                    color: const Color(0xFF1E293B),
                    tooltip: 'Presets de Sesión',
                    onSelected: (preset) => viewModel.loadPreset(preset),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'calentamiento',
                        child: Text('Preset Calentamiento (Afinador + Dron + Metrónomo)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'transcripcion_partitura',
                        child: Text('Preset Transcripción (Tocar -> Escribir en Pentagrama)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'produccion_vocal',
                        child: Text('Preset Vocal (Autotune + Grabador + Espectro)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Fila inferior: Barra de Transporte Maestro Global
              Row(
                children: [
                  // Indicador luminoso de sincronía
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning ? const Color(0xFF10B981) : Colors.white24,
                      boxShadow: isRunning
                          ? [const BoxShadow(color: Color(0xFF10B981), blurRadius: 8, spreadRadius: 2)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRunning
                        ? (isRecording ? 'MULTITAREA: GRABANDO & EN VIVO' : 'MULTITAREA: ACTIVA')
                        : 'MULTITAREA: EN ESPERA',
                    style: TextStyle(
                      color: isRunning ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),

                  const Spacer(),

                  // Botón STOP Maestro
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.white70, size: 22),
                    tooltip: 'Detener Todo',
                    onPressed: isRunning || isRecording
                        ? () {
                            viewModel.stopMasterSession();
                            try {
                              final tunerVM = context.read<TunerViewModel>();
                              if (tunerVM.isMetronomeActive) tunerVM.toggleMetronome();
                              if (tunerVM.isRecording) tunerVM.stopPracticeRecording();
                            } catch (_) {}
                          }
                        : null,
                  ),

                  // Botón PLAY / PAUSE Maestro
                  IconButton(
                    icon: Icon(
                      isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: primaryColor,
                      size: 32,
                    ),
                    tooltip: isRunning ? 'Pausar Sesión' : 'Iniciar Sesión',
                    onPressed: () {
                      viewModel.toggleMasterSession();
                      try {
                        final tunerVM = context.read<TunerViewModel>();
                        tunerVM.toggleMetronome();
                      } catch (_) {}
                    },
                  ),

                  // Botón RECORD Maestro
                  IconButton(
                    icon: Icon(
                      isRecording ? Icons.radio_button_checked : Icons.fiber_manual_record,
                      color: isRecording ? const Color(0xFFEF4444) : Colors.white60,
                      size: 26,
                    ),
                    tooltip: isRecording ? 'Detener Grabación' : 'Grabar Sesión',
                    onPressed: () {
                      viewModel.toggleMasterRecording();
                      try {
                        final tunerVM = context.read<TunerViewModel>();
                        if (tunerVM.isRecording) {
                          tunerVM.stopPracticeRecording();
                        } else {
                          tunerVM.startPracticeRecording();
                        }
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSaveProjectDialog(BuildContext context) {
    final controller = TextEditingController(text: 'Mi_Proyecto_Estudio');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'GUARDAR PROYECTO COMPRIMIDO (.TUNNER)',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guarda la sesión completa en el formato binario hiper-comprimido (.tunner). Se preservan todas las herramientas, nombres y el cableado del Patchbay.',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Nombre del Proyecto',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF10B981)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final safeName = name.replaceAll(RegExp(r'\s+'), '_');
                final path = '/tmp/$safeName.tunner';
                await viewModel.saveProjectToFile(path, projectName: name);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Proyecto guardado exitosamente en: $path'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              }
            },
            child: const Text('GUARDAR (.TUNNER)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showImportToolDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'IMPORTAR HERRAMIENTA PRESET (.TNT)',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        content: const Text(
          'Las herramientas guardadas como presets individuales (.tnt) pueden importarse directamente en cualquier sesión manteniendo su configuración acústica.',
          style: TextStyle(color: Colors.white60, fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CERRAR', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
