import 'package:flutter/foundation.dart';
import '../data/harmonic_reference_synth.dart';
import '../domain/harmonic_role_entity.dart';
import '../domain/harmonic_tutor_session_entity.dart';
import '../domain/just_intonation_calculator.dart';

/// ViewModel managing state, calculations, and reference synthesis
/// for the Dynamic Just Intonation & Adaptive Harmonic Tuning Tutor.
class HarmonicTutorViewModel extends ChangeNotifier {
  final HarmonicReferenceSynth _synth;

  HarmonicTutorSessionEntity _session;
  HarmonicRole? _forcedRole;
  Float32List? _currentDroneBuffer;
  bool _isDisposed = false;

  HarmonicTutorViewModel({
    HarmonicReferenceSynth? synth,
    HarmonicTutorSessionEntity? initialSession,
  })  : _synth = synth ?? HarmonicReferenceSynth(),
        _session = initialSession ?? const HarmonicTutorSessionEntity() {
    _updateAnalysis(261.63); // Initial analysis at unison
  }

  HarmonicTutorSessionEntity get session => _session;
  HarmonicRole? get forcedRole => _forcedRole;
  Float32List? get currentDroneBuffer => _currentDroneBuffer;

  /// Changes the active root reference pitch.
  void setRootNote(String noteName, double frequency) {
    if (frequency <= 0) return;
    _session = _session.copyWith(
      rootNoteName: noteName,
      rootFrequency: frequency,
    );
    if (_session.isDroneActive) {
      _regenerateDrone();
    }
    _recomputeActivePitch();
    if (!_isDisposed) notifyListeners();
  }

  /// Changes the chord quality context (e.g. Major Triad, Minor Triad, Dominant 7th).
  void setChordType(HarmonicChordType chordType) {
    _session = _session.copyWith(chordType: chordType);
    if (_session.isDroneActive) {
      _regenerateDrone();
    }
    _recomputeActivePitch();
    if (!_isDisposed) notifyListeners();
  }

  /// Locks analysis to a specific role or sets to automatic detection if null.
  void setForcedRole(HarmonicRole? role) {
    _forcedRole = role;
    _recomputeActivePitch();
    if (!_isDisposed) notifyListeners();
  }

  /// Ingests live pitch from the microphone or synthesis loop.
  void onPitchDetected(double frequency) {
    if (frequency <= 0.0) return;
    _updateAnalysis(frequency);
    if (!_isDisposed) notifyListeners();
  }

  /// Toggles the pure reference harmonic drone on/off.
  void toggleDrone() {
    final nextState = !_session.isDroneActive;
    _session = _session.copyWith(isDroneActive: nextState);
    if (nextState) {
      _regenerateDrone();
    } else {
      _currentDroneBuffer = null;
    }
    if (!_isDisposed) notifyListeners();
  }

  void _regenerateDrone() {
    // Generate guide voices: Root + Fifth (plus Third if applicable)
    final voices = _session.chordType.roles.take(2).toList();
    _currentDroneBuffer = _synth.generateChordBuffer(
      rootFrequency: _session.rootFrequency,
      roles: voices,
      durationMs: 2000,
      volume: 0.40,
    );
  }

  void _updateAnalysis(double userFrequency) {
    final analysis = JustIntonationCalculator.analyze(
      userFrequency: userFrequency,
      rootFrequency: _session.rootFrequency,
      forcedRole: _forcedRole,
    );
    _session = _session.copyWith(
      activeAnalysis: analysis,
      isListening: true,
    );
  }

  void _recomputeActivePitch() {
    final currentFreq = _session.activeAnalysis?.userFrequency ?? _session.rootFrequency;
    _updateAnalysis(currentFreq);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _currentDroneBuffer = null;
    super.dispose();
  }
}
