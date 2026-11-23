import 'package:flutter/widgets.dart';

/// Intenciones para el sistema de atajos de teclado de grado profesional y memoria muscular (DAWs).
class TogglePlayIntent extends Intent {
  const TogglePlayIntent();
}

class RewindToStartIntent extends Intent {
  const RewindToStartIntent();
}

class ToggleCycleLoopIntent extends Intent {
  const ToggleCycleLoopIntent();
}

class NudgeMeasureBackIntent extends Intent {
  const NudgeMeasureBackIntent();
}

class NudgeMeasureForwardIntent extends Intent {
  const NudgeMeasureForwardIntent();
}

class ToggleRecordIntent extends Intent {
  const ToggleRecordIntent();
}

class TapTempoIntent extends Intent {
  const TapTempoIntent();
}

class FocusTunerIntent extends Intent {
  const FocusTunerIntent();
}

class FocusMetronomeIntent extends Intent {
  const FocusMetronomeIntent();
}

class FocusScoreIntent extends Intent {
  const FocusScoreIntent();
}

class FocusLessonsIntent extends Intent {
  const FocusLessonsIntent();
}

class IncrementBpmIntent extends Intent {
  final int step;
  const IncrementBpmIntent(this.step);
}

class DecrementBpmIntent extends Intent {
  final int step;
  const DecrementBpmIntent(this.step);
}

class CalibrateReferencePitchIntent extends Intent {
  final double deltaHz;
  const CalibrateReferencePitchIntent(this.deltaHz);
}

class PanicMuteIntent extends Intent {
  const PanicMuteIntent();
}

class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

class OpenShortcutsGuideIntent extends Intent {
  const OpenShortcutsGuideIntent();
}

class ToggleTerminalIntent extends Intent {
  const ToggleTerminalIntent();
}

class OpenInstrumentSelectorIntent extends Intent {
  const OpenInstrumentSelectorIntent();
}

class OpenEarTrainerIntent extends Intent {
  const OpenEarTrainerIntent();
}

class OpenChordAnalyzerIntent extends Intent {
  const OpenChordAnalyzerIntent();
}

class JumpToTaskIntent extends Intent {
  const JumpToTaskIntent();
}

class SwitchTabIntent extends Intent {
  final int tabIndex;
  const SwitchTabIntent(this.tabIndex);
}

class OpenMasterConsoleIntent extends Intent {
  const OpenMasterConsoleIntent();
}

class SaveSessionIntent extends Intent {
  const SaveSessionIntent();
}

class OpenFileIntent extends Intent {
  const OpenFileIntent();
}

class NewProjectIntent extends Intent {
  const NewProjectIntent();
}

class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

class ToggleDualSplitIntent extends Intent {
  const ToggleDualSplitIntent();
}

/// Contenedor principal de navegación de Tunner (MainAppShell).
/// Gestiona la transición limpia entre el Dashboard de Inicio, el Afinador,
