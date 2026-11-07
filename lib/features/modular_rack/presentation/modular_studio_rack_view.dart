import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modular_rack_viewmodel.dart';
import '../domain/rack_module_entity.dart';
import 'multitask_master_console_widget.dart';
import 'rack_unit_card.dart';

/// Vista principal del Rack de Estudio Modular y Consola Multitarea.
/// Permite arrastrar, reorganizar, conectar y emular instrumentos libremente.
class ModularStudioRackView extends StatelessWidget {
  const ModularStudioRackView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ModularRackViewModel(),
      child: const _ModularStudioRackBody(),
    );
  }
}

class _ModularStudioRackBody extends StatelessWidget {
  const _ModularStudioRackBody();

  void _showAddModuleSheet(BuildContext context, ModularRackViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'BIBLIOTECA DE MÓDULOS DE ESTUDIO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toca cualquier herramienta para montarla de inmediato en tu rack de trabajo.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: RackModuleType.values.length,
                  itemBuilder: (context, index) {
                    final type = RackModuleType.values[index];
                    final isAlreadyActive = viewModel.activeModules.any((m) => m.moduleType == type);

                    return ListTile(
                      leading: Text(type.icon, style: const TextStyle(fontSize: 22)),
                      title: Text(
                        type.displayName,
                        style: TextStyle(
                          color: isAlreadyActive ? Colors.white38 : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: isAlreadyActive
                          ? const Text('ACTIVO', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF38BDF8),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () {
                                viewModel.addModule(type);
                                Navigator.pop(context);
                              },
                              child: const Text('+ AGREGAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                      onTap: isAlreadyActive
                          ? null
                          : () {
                              viewModel.addModule(type);
                              Navigator.pop(context);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ModularRackViewModel>();
    final modules = viewModel.activeModules;
    final instrument = viewModel.activeInstrument;
    final primaryColor = instrument.visualProfile.primaryAccentColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Column(
          children: [
            // Consola Multitarea de Control Maestro en la cabecera
            MultitaskMasterConsoleWidget(viewModel: viewModel),

            // Lienzo de Módulos Reordenables (Drag & Drop Studio Rack)
            Expanded(
              child: modules.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.dashboard_customize_outlined, color: Colors.white24, size: 54),
                          const SizedBox(height: 16),
                          const Text(
                            'Tu rack de estudio está vacío',
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Agrega módulos desde la bandeja inferior o carga un preset.',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('EXPLORAR HERRAMIENTAS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => _showAddModuleSheet(context, viewModel),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: modules.length,
                      onReorder: viewModel.reorderModules,
                      itemBuilder: (context, index) {
                        final mod = modules[index];
                        return RackUnitCard(
                          key: ValueKey(mod.moduleId),
                          module: mod,
                          viewModel: viewModel,
                          index: index,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // Botón flotante para desplegar la bandeja de módulos
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'AGREGAR MÓDULO',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
        ),
        onPressed: () => _showAddModuleSheet(context, viewModel),
      ),
    );
  }
}
