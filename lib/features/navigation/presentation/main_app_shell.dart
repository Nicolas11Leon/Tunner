import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../tuner_viewmodel.dart';
import 'home_dashboard_screen.dart';
import '../../tuner_screen.dart';
import '../../workspaces/presentation/learning_practice_workspace_view.dart';
import '../../workspaces/presentation/production_acoustic_lab_workspace_view.dart';
import '../../workspaces/presentation/composition_notation_workspace_view.dart';
import '../../instrument/presentation/instrument_selector_modal.dart';

/// Contenedor principal de navegación de Tunner (MainAppShell).
/// Gestiona la transición limpia entre el Dashboard de Inicio, el Afinador,
/// el Tutor de Aprendizaje, el Estudio de Grabación y la Biblioteca de Canciones,
/// manteniendo vivos los Isolates de audio y el estado del ViewModel sin parpadeos.
class MainAppShell extends StatefulWidget {
  final int initialIndex;

  const MainAppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _openInstrumentSelector(TunerViewModel viewModel) {
    InstrumentSelectorModal.show(context, viewModel);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0: Dashboard Principal con Tarjetas y Buscador
          HomeDashboardScreen(
            onNavigateToTab: _navigateToTab,
          ),

          // 1: Afinador de Precisión & Metrónomo
          const TunerScreen(),

          // 2: Tutor Interactivo & Aprendizaje
          LearningPracticeWorkspaceView(
            viewModel: viewModel,
            palette: palette,
            onOpenInstrumentModal: () => _openInstrumentSelector(viewModel),
          ),

          // 3: Estudio de Grabación & Laboratorio Acústico
          ProductionAcousticLabWorkspaceView(
            viewModel: viewModel,
            palette: palette,
            onOpenMixerModal: () {},
          ),

          // 4: Biblioteca de Canciones & Partituras
          CompositionNotationWorkspaceView(
            viewModel: viewModel,
            palette: palette,
            onOpenLibraryModal: () {},
            onOpenMixerModal: () {},
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.scaffoldBackground,
          border: Border(
            top: BorderSide(
              color: palette.staffLinesColor.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _navigateToTab,
          backgroundColor: palette.scaffoldBackground,
          indicatorColor: palette.primaryAccent.withValues(alpha: 0.18),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              key: const Key('nav_tab_home'),
              icon: Icon(Icons.home_outlined, color: palette.textMutedColor),
              selectedIcon: Icon(Icons.home, color: palette.primaryAccent),
              label: 'Inicio',
            ),
            NavigationDestination(
              key: const Key('nav_tab_tuner'),
              icon: Icon(Icons.tune_outlined, color: palette.textMutedColor),
              selectedIcon: Icon(Icons.tune, color: palette.primaryAccent),
              label: 'Afinador',
            ),
            NavigationDestination(
              key: const Key('nav_tab_learning'),
              icon: Icon(Icons.school_outlined, color: palette.textMutedColor),
              selectedIcon: Icon(Icons.school, color: palette.correctPitchColor),
              label: 'Aprender',
            ),
            NavigationDestination(
              key: const Key('nav_tab_studio'),
              icon: Icon(Icons.fiber_manual_record_outlined, color: palette.textMutedColor),
              selectedIcon: Icon(Icons.fiber_manual_record, color: palette.secondaryAccent),
              label: 'Estudio',
            ),
            NavigationDestination(
              key: const Key('nav_tab_library'),
              icon: Icon(Icons.menu_book_outlined, color: palette.textMutedColor),
              selectedIcon: Icon(Icons.menu_book, color: palette.primaryAccent),
              label: 'Canciones',
            ),
          ],
        ),
      ),
    );
  }
}
