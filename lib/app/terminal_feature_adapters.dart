import 'dart:typed_data';

import '../core/terminal/domain/i_terminal_feature_ports.dart';
import '../features/tuner_viewmodel.dart';

export 'headless_terminal_feature_adapters.dart';

/// Adaptador de aplicacion Flutter que conecta [TunerViewModel] al puerto puro [ITerminalProjectPort].
class TunerProjectTerminalAdapter implements ITerminalProjectPort {
  final TunerViewModel viewModel;

  const TunerProjectTerminalAdapter(this.viewModel);

  @override
  String get activeTitle => viewModel.activePackage.title;

  @override
  String get activeComposer => viewModel.activePackage.composer;

  @override
  int get bpm => viewModel.bpm;

  @override
  void updateBpm(int bpm) => viewModel.updateBpm(bpm);

  @override
  Uint8List exportCurrentProjectToTunner({String? projectTitle}) {
    return viewModel.exportCurrentProjectToTunner(projectTitle: projectTitle);
  }
}
