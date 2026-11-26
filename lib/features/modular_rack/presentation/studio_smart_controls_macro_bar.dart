import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system/atoms/studio_rotary_knob.dart';
import '../../../core/design_system/studio_design_tokens.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../../tuner_viewmodel.dart';
import 'modular_rack_viewmodel.dart';

/// Organismo de Barra de Macro-Perillas Smart Controls (estilo Apple Logic Pro)
/// para el Rack Modular ([ModularStudioRackView]).
///
/// Expone 6 macro-perillas rotatorias con telemetria numerica instantanea,
/// selector rapido de 3 perfiles macro de estudio y boton de restauracion
/// a valores por defecto, con enlace bidireccional en tiempo real con
/// [TunerViewModel], [ModularRackViewModel] y [SignalBus].
class StudioSmartControlsMacroBar extends StatefulWidget {
  final ValueChanged<double>? onA4Changed;
  final ValueChanged<double>? onMasterTempoChanged;
  final ValueChanged<double>? onNoiseGateChanged;
  final ValueChanged<double>? onDroneMixChanged;
  final ValueChanged<double>? onRetuneSpeedChanged;
  final ValueChanged<double>? onRoomReverbChanged;

  const StudioSmartControlsMacroBar({
    super.key = const Key('studio_smart_controls_macro_bar'),
    this.onA4Changed,
    this.onMasterTempoChanged,
    this.onNoiseGateChanged,
    this.onDroneMixChanged,
    this.onRetuneSpeedChanged,
    this.onRoomReverbChanged,
  });

  @override
  State<StudioSmartControlsMacroBar> createState() =>
      _StudioSmartControlsMacroBarState();
}

class _StudioSmartControlsMacroBarState
    extends State<StudioSmartControlsMacroBar> {
  static const double _defaultA4Pitch = 440.0;
  static const double _defaultMasterTempo = 120.0;
  static const double _defaultNoiseGateDb = -42.0;
  static const double _defaultDroneMixPercent = 50.0;
  static const double _defaultRetuneSpeedMs = 25.0;
  static const double _defaultRoomReverbPercent = 18.0;

  double _a4Pitch = _defaultA4Pitch;
  double _masterTempo = _defaultMasterTempo;
  double _noiseGateDb = _defaultNoiseGateDb;
  double _droneMixPercent = _defaultDroneMixPercent;
  double _retuneSpeedMs = _defaultRetuneSpeedMs;
  double _roomReverbPercent = _defaultRoomReverbPercent;
  String _activePresetId = 'custom';

  TunerViewModel? _boundTunerVm;
  ModularRackViewModel? _boundRackVm;
  bool _isUpdatingViewModels = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rackVm = _tryReadRackViewModel(context);
    final tunerVm = _tryReadTunerViewModel(context) ?? rackVm?.tunerViewModel;

    if (!identical(_boundRackVm, rackVm)) {
      _boundRackVm?.removeListener(_onRackVmChanged);
      _boundRackVm = rackVm;
      _boundRackVm?.addListener(_onRackVmChanged);
      if (rackVm != null) {
        _syncStateFromRackVm(rackVm);
      }
    }

    if (!identical(_boundTunerVm, tunerVm)) {
      _boundTunerVm?.removeListener(_onTunerVmChanged);
      _boundTunerVm = tunerVm;
      _boundTunerVm?.addListener(_onTunerVmChanged);
      if (tunerVm != null) {
        _syncStateFromTunerVm(tunerVm);
      }
    }
  }

  @override
  void dispose() {
    _boundTunerVm?.removeListener(_onTunerVmChanged);
    _boundRackVm?.removeListener(_onRackVmChanged);
    super.dispose();
  }

  /// Convierte un nivel en decibelios dBFS ($[-70, -10]\text{ dB}$) a amplitud lineal RMS:
  /// $$A_{\text{lin}} = 10^{\frac{L_{\text{dB}}}{20}}$$
  static double _dbToLinearThreshold(double db) {
    return math.pow(10.0, db / 20.0).toDouble();
  }

  /// Convierte un umbral lineal RMS ($[0.0001, 1.0]$) a decibelios dBFS:
  /// $$L_{\text{dB}} = 20 \cdot \log_{10}(A_{\text{lin}})$$
  static double _linearThresholdToDb(double linear) {
    final safeLinear = math.max(1e-5, linear);
    return (20.0 * (math.log(safeLinear) / math.ln10)).clamp(-70.0, -10.0);
  }

  void _syncStateFromTunerVm(TunerViewModel vm) {
    _a4Pitch = vm.referencePitch.clamp(415.0, 466.0);
    _masterTempo = vm.bpm.toDouble().clamp(40.0, 240.0);
    _noiseGateDb = _linearThresholdToDb(vm.micProfile.noiseGateThreshold);
    _droneMixPercent = (vm.droneConfig.volume * 100.0).clamp(0.0, 100.0);
    _retuneSpeedMs = vm.autoTuneConfig.retuneSpeedMs.clamp(0.0, 100.0);
  }

  void _syncStateFromRackVm(ModularRackViewModel rackVm) {
    _roomReverbPercent =
        (rackVm.customization.resonanceFactor * 100.0).clamp(0.0, 100.0);
    if (_boundTunerVm == null) {
      _a4Pitch = rackVm.customization.referencePitchA4.clamp(415.0, 466.0);
    }
  }

  void _onTunerVmChanged() {
    final vm = _boundTunerVm;
    if (!mounted || vm == null || _isUpdatingViewModels) return;
    setState(() {
      _syncStateFromTunerVm(vm);
    });
  }

  void _onRackVmChanged() {
    final rackVm = _boundRackVm;
    if (!mounted || rackVm == null || _isUpdatingViewModels) return;
    setState(() {
      _syncStateFromRackVm(rackVm);
    });
  }

  TunerViewModel? _tryReadTunerViewModel(BuildContext context) {
    try {
      return Provider.of<TunerViewModel>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  ModularRackViewModel? _tryReadRackViewModel(BuildContext context) {
    try {
      return Provider.of<ModularRackViewModel>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _runWithOutboundSyncGuard(VoidCallback action) {
    _isUpdatingViewModels = true;
    try {
      action();
    } finally {
      _isUpdatingViewModels = false;
    }
  }

  void _updateA4Pitch(double value) {
    final clamped = value.clamp(415.0, 466.0);
    setState(() {
      _a4Pitch = clamped;
      _activePresetId = 'custom';
    });
    widget.onA4Changed?.call(clamped);
    _runWithOutboundSyncGuard(() {
      final rackVm = _boundRackVm ?? _tryReadRackViewModel(context);
      final tunerVm = _boundTunerVm ??
          _tryReadTunerViewModel(context) ??
          rackVm?.tunerViewModel;
      tunerVm?.setReferencePitch(clamped);
      if (rackVm != null) {
        rackVm.updateCustomization(
          rackVm.customization.copyWith(referencePitchA4: clamped),
        );
      }
    });
  }

  void _updateMasterTempo(double value) {
    final clamped = value.clamp(40.0, 240.0);
    setState(() {
      _masterTempo = clamped;
      _activePresetId = 'custom';
    });
    widget.onMasterTempoChanged?.call(clamped);
    _runWithOutboundSyncGuard(() {
      final rackVm = _boundRackVm ?? _tryReadRackViewModel(context);
      final tunerVm = _boundTunerVm ??
          _tryReadTunerViewModel(context) ??
          rackVm?.tunerViewModel;
      tunerVm?.updateBpm(clamped.round());
    });
  }

  void _updateNoiseGate(double value) {
    final clamped = value.clamp(-70.0, -10.0);
    setState(() {
      _noiseGateDb = clamped;
      _activePresetId = 'custom';
    });
    widget.onNoiseGateChanged?.call(clamped);
    final linearThreshold = _dbToLinearThreshold(clamped);
    _runWithOutboundSyncGuard(() {
      final rackVm = _boundRackVm ?? _tryReadRackViewModel(context);
      final tunerVm = _boundTunerVm ??
          _tryReadTunerViewModel(context) ??
          rackVm?.tunerViewModel;
      tunerVm?.setNoiseGateThreshold(linearThreshold);
    });
  }

  void _updateDroneMix(double value) {
    final clamped = value.clamp(0.0, 100.0);
    setState(() {
      _droneMixPercent = clamped;
      _activePresetId = 'custom';
    });
    widget.onDroneMixChanged?.call(clamped);
    _runWithOutboundSyncGuard(() {
      final rackVm = _boundRackVm ?? _tryReadRackViewModel(context);
      final tunerVm = _boundTunerVm ??
          _tryReadTunerViewModel(context) ??
          rackVm?.tunerViewModel;
      if (tunerVm != null) {
        tunerVm.setDroneConfig(
          tunerVm.droneConfig.copyWith(
            volume: (clamped / 100.0).clamp(0.0, 1.0),
          ),
        );
      }
    });
  }

  void _updateRetuneSpeed(double value) {
    final clamped = value.clamp(0.0, 100.0);
    setState(() {
      _retuneSpeedMs = clamped;
      _activePresetId = 'custom';
    });
    widget.onRetuneSpeedChanged?.call(clamped);
    _runWithOutboundSyncGuard(() {
      final rackVm = _boundRackVm ?? _tryReadRackViewModel(context);
      final tunerVm = _boundTunerVm ??
          _tryReadTunerViewModel(context) ??
          rackVm?.tunerViewModel;
      if (tunerVm != null) {
        tunerVm.updateAutoTuneConfig(
          tunerVm.autoTuneConfig.copyWith(retuneSpeedMs: clamped),
        );
      }
    });
  }

  void _updateRoomReverb(double value) {
    final clamped = value.clamp(0.0, 100.0);
    setState(() {
      _roomReverbPercent = clamped;
      _activePresetId = 'custom';
    });
    widget.onRoomReverbChanged?.call(clamped);
    final normalizedResonance = (clamped / 100.0).clamp(0.0, 1.0);
    _runWithOutboundSyncGuard(() {
      final rackVm = _boundRackVm ?? _tryReadRackViewModel(context);
      final tunerVm = _boundTunerVm ??
          _tryReadTunerViewModel(context) ??
          rackVm?.tunerViewModel;
      if (rackVm != null) {
        rackVm.updateCustomization(
          rackVm.customization.copyWith(resonanceFactor: normalizedResonance),
        );
      }
      if (tunerVm != null) {
        // Escala el tiempo de liberación de las voces polifónicas (0.05s a 1.25s)
        tunerVm.polyphonicVoicePool.releaseSeconds =
            (0.05 + normalizedResonance * 1.20).clamp(0.05, 2.0);
      }
    });
  }

  void _applyPreset({
    required String presetId,
    required double a4,
    required double gateDb,
    required double reverbPercent,
    double? droneMixPercent,
    double? retuneSpeedMs,
  }) {
    final clampedA4 = a4.clamp(415.0, 466.0);
    final clampedGate = gateDb.clamp(-70.0, -10.0);
    final clampedReverb = reverbPercent.clamp(0.0, 100.0);
    final clampedDrone = (droneMixPercent ?? _droneMixPercent).clamp(0.0, 100.0);
    final clampedRetune = (retuneSpeedMs ?? _retuneSpeedMs).clamp(0.0, 100.0);

    setState(() {
      _activePresetId = presetId;
      _a4Pitch = clampedA4;
      _noiseGateDb = clampedGate;
      _roomReverbPercent = clampedReverb;
      _droneMixPercent = clampedDrone;
      _retuneSpeedMs = clampedRetune;
    });

    widget.onA4Changed?.call(clampedA4);
    widget.onNoiseGateChanged?.call(clampedGate);
    widget.onDroneMixChanged?.call(clampedDrone);
    widget.onRetuneSpeedChanged?.call(clampedRetune);
    widget.onRoomReverbChanged?.call(clampedReverb);

    final linearThreshold = _dbToLinearThreshold(clampedGate);
    final normalizedResonance = (clampedReverb / 100.0).clamp(0.0, 1.0);

    _runWithOutboundSyncGuard(() {
      final rackVm = _boundRackVm ?? _tryReadRackViewModel(context);
      final tunerVm = _boundTunerVm ??
          _tryReadTunerViewModel(context) ??
          rackVm?.tunerViewModel;

      if (tunerVm != null) {
        tunerVm.setReferencePitch(clampedA4);
        tunerVm.setNoiseGateThreshold(linearThreshold);
        tunerVm.setDroneConfig(
          tunerVm.droneConfig.copyWith(
            volume: (clampedDrone / 100.0).clamp(0.0, 1.0),
          ),
        );
        tunerVm.updateAutoTuneConfig(
          tunerVm.autoTuneConfig.copyWith(
            retuneSpeedMs: clampedRetune,
            a4Reference: clampedA4,
          ),
        );
        tunerVm.polyphonicVoicePool.releaseSeconds =
            (0.05 + normalizedResonance * 1.20).clamp(0.05, 2.0);
      }

      if (rackVm != null) {
        rackVm.updateCustomization(
          rackVm.customization.copyWith(
            referencePitchA4: clampedA4,
            resonanceFactor: normalizedResonance,
          ),
        );
      }
    });
  }

  void _resetDefaults() {
    setState(() {
      _activePresetId = 'default';
      _a4Pitch = _defaultA4Pitch;
      _masterTempo = _defaultMasterTempo;
      _noiseGateDb = _defaultNoiseGateDb;
      _droneMixPercent = _defaultDroneMixPercent;
      _retuneSpeedMs = _defaultRetuneSpeedMs;
      _roomReverbPercent = _defaultRoomReverbPercent;
    });

    widget.onA4Changed?.call(_defaultA4Pitch);
    widget.onMasterTempoChanged?.call(_defaultMasterTempo);
    widget.onNoiseGateChanged?.call(_defaultNoiseGateDb);
    widget.onDroneMixChanged?.call(_defaultDroneMixPercent);
    widget.onRetuneSpeedChanged?.call(_defaultRetuneSpeedMs);
    widget.onRoomReverbChanged?.call(_defaultRoomReverbPercent);

    final defaultLinearGate = _dbToLinearThreshold(_defaultNoiseGateDb);
    final defaultNormalizedResonance =
        (_defaultRoomReverbPercent / 100.0).clamp(0.0, 1.0);

    _runWithOutboundSyncGuard(() {
      final rackVm = _boundRackVm ?? _tryReadRackViewModel(context);
      final tunerVm = _boundTunerVm ??
          _tryReadTunerViewModel(context) ??
          rackVm?.tunerViewModel;

      if (tunerVm != null) {
        tunerVm.setReferencePitch(_defaultA4Pitch);
        tunerVm.updateBpm(_defaultMasterTempo.round());
        tunerVm.setNoiseGateThreshold(defaultLinearGate);
        tunerVm.setDroneConfig(
          tunerVm.droneConfig.copyWith(
            volume: (_defaultDroneMixPercent / 100.0).clamp(0.0, 1.0),
          ),
        );
        tunerVm.updateAutoTuneConfig(
          tunerVm.autoTuneConfig.copyWith(
            retuneSpeedMs: _defaultRetuneSpeedMs,
            a4Reference: _defaultA4Pitch,
          ),
        );
        tunerVm.polyphonicVoicePool.releaseSeconds =
            (0.05 + defaultNormalizedResonance * 1.20).clamp(0.05, 2.0);
      }

      if (rackVm != null) {
        rackVm.updateCustomization(
          rackVm.customization.copyWith(
            referencePitchA4: _defaultA4Pitch,
            resonanceFactor: defaultNormalizedResonance,
          ),
        );
      }
    });
  }

  Widget _buildPresetChip({
    required Key chipKey,
    required String presetId,
    required String label,
    required StudioDesignTokens tokens,
    required VoidCallback onTap,
  }) {
    final isSelected = _activePresetId == presetId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        key: chipKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.accentPrimary.withValues(alpha: 0.18)
                : tokens.elevatedSurface,
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            border: Border.all(
              color: isSelected ? tokens.accentPrimary : tokens.borderHairline,
              width: tokens.borderWidth,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? tokens.accentPrimary : tokens.textSecondary,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        border: Border.all(
          color: tokens.borderHairline,
          width: tokens.borderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Titulo + Presets Macro + Reset
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dialpad,
                    size: 13,
                    color: tokens.accentPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SMART CONTROLS · LOGIC PRO MACRO RACK',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Row(
                key: const Key('smart_controls_preset_selector'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPresetChip(
                    chipKey: const Key('smart_preset_studio_clean'),
                    presetId: 'studio_clean',
                    label: 'Estudio Limpio',
                    tokens: tokens,
                      onTap: () => _applyPreset(
                        presetId: 'studio_clean',
                        a4: 440.0,
                        gateDb: -38.0,
                        reverbPercent: 10.0,
                        droneMixPercent: 40.0,
                        retuneSpeedMs: 35.0,
                      ),
                    ),
                    _buildPresetChip(
                      chipKey: const Key('smart_preset_concert_hall'),
                      presetId: 'concert_hall',
                      label: 'Sala de Concierto',
                      tokens: tokens,
                      onTap: () => _applyPreset(
                        presetId: 'concert_hall',
                        a4: 442.0,
                        gateDb: -48.0,
                        reverbPercent: 45.0,
                        droneMixPercent: 65.0,
                        retuneSpeedMs: 20.0,
                      ),
                    ),
                    _buildPresetChip(
                      chipKey: const Key('smart_preset_baroque_ensemble'),
                      presetId: 'baroque_ensemble',
                      label: 'Barroco 415 Hz',
                      tokens: tokens,
                      onTap: () => _applyPreset(
                        presetId: 'baroque_ensemble',
                        a4: 415.0,
                        gateDb: -45.0,
                        reverbPercent: 30.0,
                        droneMixPercent: 80.0,
                        retuneSpeedMs: 15.0,
                      ),
                    ),
                  InkWell(
                    key: const Key('smart_controls_reset_defaults_btn'),
                    onTap: _resetDefaults,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.inputSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(
                          color: tokens.borderHairline,
                          width: tokens.borderWidth,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restart_alt,
                            size: 12,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'RESET',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tira horizontal responsiva con las 6 Macro-Perillas rotatorias
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: StudioRotaryKnob(
                    key: const Key('smart_knob_a4_pitch'),
                    label: 'A4 PITCH',
                    value: _a4Pitch,
                    min: 415.0,
                    max: 466.0,
                    defaultValue: _defaultA4Pitch,
                    activeColor: tokens.accentPrimary,
                    size: 48.0,
                    valueFormatter: (v) => '${v.round()} Hz',
                    onChanged: _updateA4Pitch,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: StudioRotaryKnob(
                    key: const Key('smart_knob_master_tempo'),
                    label: 'MASTER TEMPO',
                    value: _masterTempo,
                    min: 40.0,
                    max: 240.0,
                    defaultValue: _defaultMasterTempo,
                    activeColor: tokens.accentSecondary,
                    size: 48.0,
                    valueFormatter: (v) => '${v.round()} BPM',
                    onChanged: _updateMasterTempo,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: StudioRotaryKnob(
                    key: const Key('smart_knob_noise_gate'),
                    label: 'NOISE GATE',
                    value: _noiseGateDb,
                    min: -70.0,
                    max: -10.0,
                    defaultValue: _defaultNoiseGateDb,
                    activeColor: tokens.accentWarning,
                    size: 48.0,
                    valueFormatter: (v) => '${v.round()} dB',
                    onChanged: _updateNoiseGate,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: StudioRotaryKnob(
                    key: const Key('smart_knob_drone_mix'),
                    label: 'DRONE MIX',
                    value: _droneMixPercent,
                    min: 0.0,
                    max: 100.0,
                    defaultValue: _defaultDroneMixPercent,
                    activeColor: tokens.accentSuccess,
                    size: 48.0,
                    valueFormatter: (v) => '${v.round()}%',
                    onChanged: _updateDroneMix,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: StudioRotaryKnob(
                    key: const Key('smart_knob_retune_speed'),
                    label: 'RETUNE SPEED',
                    value: _retuneSpeedMs,
                    min: 0.0,
                    max: 100.0,
                    defaultValue: _defaultRetuneSpeedMs,
                    activeColor: tokens.accentPrimary,
                    size: 48.0,
                    valueFormatter: (v) => '${v.round()} ms',
                    onChanged: _updateRetuneSpeed,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: StudioRotaryKnob(
                    key: const Key('smart_knob_room_reverb'),
                    label: 'ROOM REVERB',
                    value: _roomReverbPercent,
                    min: 0.0,
                    max: 100.0,
                    defaultValue: _defaultRoomReverbPercent,
                    activeColor: tokens.accentSecondary,
                    size: 48.0,
                    valueFormatter: (v) => '${v.round()}%',
                    onChanged: _updateRoomReverb,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
