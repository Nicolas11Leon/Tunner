import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/design_system/studio_theme_provider.dart';
import 'modular_rack_viewmodel.dart';
import '../domain/rack_module_entity.dart';
import 'multitask_master_console_widget.dart';
import 'rack_unit_card.dart';

/// Vista principal del Rack de Estudio Modular y Consola Multitarea.
/// Permite arrastrar, reorganizar, conectar y emular instrumentos libremente.
class ModularStudioRackView extends StatelessWidget {
  final ModularRackViewModel? viewModel;

  const ModularStudioRackView({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel != null) {
      return ChangeNotifierProvider<ModularRackViewModel>.value(
        value: viewModel!,
        child: const _ModularStudioRackBody(),
      );
    }
    return ChangeNotifierProvider<ModularRackViewModel>(
      create: (_) => ModularRackViewModel(),
      child: const _ModularStudioRackBody(),
    );
  }
}

class _ModularStudioRackBody extends StatelessWidget {
  const _ModularStudioRackBody();

  void _showAddModuleSheet(BuildContext context, ModularRackViewModel viewModel) {
    final tokens = StudioThemeScope.tokensOf(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
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
                    color: tokens.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'BIBLIOTECA DE MÓDULOS DE ESTUDIO',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toca cualquier herramienta para montarla de inmediato en tu rack de trabajo.',
                style: TextStyle(color: tokens.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: RackModuleType.values.length,
                  itemBuilder: (context, index) {
                    final type = RackModuleType.values[index];
                    final isAlreadyActive = viewModel.activeModules.any((m) => m.moduleType == type);

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.elevatedSurface,
                          borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          border: Border.all(color: tokens.borderHairline, width: 0.5),
                        ),
                        child: Text(
                          type.icon,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: tokens.accentPrimary,
                          ),
                        ),
                      ),
                      title: Text(
                        type.displayName,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: isAlreadyActive
                          ? Text(
                              'Ya montado en el rack. Puedes crear otra instancia.',
                              style: TextStyle(color: tokens.textMuted, fontSize: 10),
                            )
                          : null,
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAlreadyActive ? tokens.elevatedSurface : tokens.accentPrimary,
                          foregroundColor: isAlreadyActive ? tokens.accentPrimary : Colors.black,
                          side: isAlreadyActive ? BorderSide(color: tokens.accentPrimary.withValues(alpha: 0.5)) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () {
                          viewModel.addModule(type);
                          Navigator.pop(context);
                        },
                        child: Text(
                          isAlreadyActive ? '+ NUEVA INSTANCIA' : '+ AGREGAR',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () {
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
    final tokens = StudioThemeScope.tokensOf(context);

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
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
                          Icon(Icons.dashboard_customize_outlined, color: tokens.textMuted, size: 54),
                          const SizedBox(height: 16),
                          Text(
                            'Tu rack de estudio está vacío',
                            style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Agrega módulos desde la bandeja inferior o carga un preset.',
                            style: TextStyle(color: tokens.textMuted, fontSize: 12),
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
