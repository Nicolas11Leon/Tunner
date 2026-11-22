import 'package:flutter/foundation.dart';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../../acoustic_lab/domain/harmonic_series_analyzer.dart';
import '../../practice_evaluator/domain/note_evaluation_entity.dart';
import '../../audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import '../../audio_synthesizer/domain/i_stem_export_persistence_service.dart';
import '../../audio_synthesizer/domain/stem_audio_synthesizer.dart';
import '../../audio_synthesizer/domain/stem_export_entity.dart';
import '../../exercise_generator/domain/algorithmic_exercise_generator.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
import '../../metronome/domain/tap_tempo_result.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../pedagogy_report/domain/pedagogical_report_models.dart';
import '../../pedagogy_report/domain/pedagogical_report_pdf_generator.dart';
import '../../practice_evaluator/domain/practice_report_entity.dart';
import '../../practice_recorder/domain/multitrack_session_entity.dart';
import '../../practice_recorder/domain/practice_recording_entity.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../transcription/domain/live_transcription_engine.dart';
import '../../transcription/domain/polyphonic_transcription_engine.dart';
import '../../tuner/domain/note_entity.dart';
import '../../universal_importer/domain/canonical_abc_exporter.dart';
import '../../universal_importer/domain/canonical_midi_exporter.dart';
import '../../universal_importer/domain/canonical_musicxml_exporter.dart';
import '../../universal_importer/domain/canonical_pdf_exporter.dart';
import '../../universal_importer/domain/i_score_parser_service.dart';
import '../../universal_importer/domain/parsed_score_result_entity.dart';
import '../domain/score_editor_domain.dart';

/// Controlador cohesivo para edición de partituras (Memento Undo/Redo),
/// exportación canónica (MusicXML/MIDI/ABC/PDF), transcripción en vivo y exportación de stems.
class ScoreEditorController {
  final ScoreUndoRedoHistory _scoreHistory = ScoreUndoRedoHistory();
  final ScoreEditorOperations _editorOps = const ScoreEditorOperations();
  final CanonicalMusicXmlExporter _musicXmlExporter = const CanonicalMusicXmlExporter();
  final CanonicalMidiExporter _midiExporter = const CanonicalMidiExporter();
  final CanonicalAbcExporter _abcExporter = const CanonicalAbcExporter();
  final CanonicalPdfExporter _pdfExporter = const CanonicalPdfExporter();
  final PedagogicalReportPdfGenerator _pedagogicalPdfGenerator = const PedagogicalReportPdfGenerator();
  final LiveTranscriptionEngine _transcriptionEngine = LiveTranscriptionEngine();
  final PolyphonicTranscriptionEngine _polyphonicTranscriptionEngine = PolyphonicTranscriptionEngine();
  final AlgorithmicExerciseGenerator _exerciseGenerator = const AlgorithmicExerciseGenerator();

  final IAudioSynthesizerService _audioSynthesizer;
  final IScoreParserService _scoreImporterService;
  final StemAudioSynthesizer _stemSynthesizer;
  final IStemExportPersistenceService _exportPersistenceService;
  final IStudioLogger _logger;
  final VoidCallback _onNotify;

  bool _isLiveTranscriptionActive = false;
  bool _isPolyphonicTranscriptionActive = false;
  ExportBundleResult? _lastExportBundle;
  bool _isExportingStems = false;

  ScoreEditorController({
    required IAudioSynthesizerService audioSynthesizer,
    required IScoreParserService scoreImporterService,
    required StemAudioSynthesizer stemSynthesizer,
    required IStemExportPersistenceService exportPersistenceService,
    required IStudioLogger logger,
    required VoidCallback onNotify,
  })  : _audioSynthesizer = audioSynthesizer,
        _scoreImporterService = scoreImporterService,
        _stemSynthesizer = stemSynthesizer,
        _exportPersistenceService = exportPersistenceService,
        _logger = logger,
        _onNotify = onNotify;

  bool get canUndoScoreEdit => _scoreHistory.canUndo;
  bool get canRedoScoreEdit => _scoreHistory.canRedo;
  int get scoreUndoCount => _scoreHistory.undoCount;
  int get scoreRedoCount => _scoreHistory.redoCount;
  bool get isLiveTranscriptionActive => _isLiveTranscriptionActive;
  bool get isPolyphonicTranscriptionActive => _isPolyphonicTranscriptionActive;
  ExportBundleResult? get lastExportBundle => _lastExportBundle;
  bool get isExportingStems => _isExportingStems;

  PolyphonicTranscriptionEngine get polyphonicTranscriptionEngine => _polyphonicTranscriptionEngine;

  void recordUndoSnapshot(SongPackage package) {
    _scoreHistory.recordState(package);
  }

  SongPackage? processLiveTranscriptionFrame({
    required SongPackage activePackage,
    required double pitchHz,
    required double clarity,
    required String noteName,
  }) {
    if (!_isLiveTranscriptionActive) return null;
    final updatedPkg = _transcriptionEngine.processPitchFrame(
      frequencyHz: pitchHz,
      clarity: clarity,
      noteName: noteName,
    );
    if (updatedPkg != null) {
      _scoreHistory.recordState(activePackage);
    }
    return updatedPkg;
  }

  SongPackage insertOrUpdateScoreNote({
    required SongPackage activePackage,
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required String noteName,
    required double referencePitch,
    required int bpm,
    bool playAudibleFeedback = true,
  }) {
    _scoreHistory.recordState(activePackage);
    final updated = _editorOps.insertOrUpdateNote(
      package: activePackage,
      measureIndex: measureIndex,
      startTick: startTick,
      durationTicks: durationTicks,
      noteName: noteName,
    );

    if (playAudibleFeedback && noteName != '--' && noteName.toLowerCase() != 'rest') {
      final freq = NoteEntity.frequencyForNote(noteName, a4Ref: referencePitch);
      if (freq > 20.0) {
        final ms = (durationTicks * (60000.0 / bpm / 4.0)).round();
        _audioSynthesizer.playNoteTone(
          frequency: freq,
          duration: Duration(milliseconds: ms),
          volume: 0.85,
        );
      }
    }

    return updated;
  }

  SongPackage deleteScoreNote({
    required SongPackage activePackage,
    required int measureIndex,
    required int startTick,
  }) {
    _scoreHistory.recordState(activePackage);
    return _editorOps.deleteNoteAt(
      package: activePackage,
      measureIndex: measureIndex,
      startTick: startTick,
    );
  }

  SongPackage? undoScoreEdit(SongPackage activePackage) => _scoreHistory.undo(activePackage);

  SongPackage? redoScoreEdit(SongPackage activePackage) => _scoreHistory.redo(activePackage);

  SongPackage addScoreMeasure(SongPackage activePackage) {
    _scoreHistory.recordState(activePackage);
    return _editorOps.addMeasure(package: activePackage);
  }

  SongPackage removeScoreMeasure(SongPackage activePackage, int measureIndex) {
    _scoreHistory.recordState(activePackage);
    return _editorOps.removeMeasure(
      package: activePackage,
      measureIndex: measureIndex,
    );
  }

  SongPackage? transposeActiveScore(SongPackage activePackage, int semitones) {
    if (semitones == 0) return null;
    _scoreHistory.recordState(activePackage);
    return _editorOps.transposeScore(
      package: activePackage,
      semitones: semitones,
    );
  }

  SongPackage? transposeActiveScoreForInstrument(
    SongPackage activePackage,
    InstrumentProfileEntity targetInstrument,
  ) {
    if (targetInstrument.transpositionSemitones == 0) return null;
    final semitones = -targetInstrument.transpositionSemitones;
    return transposeActiveScore(activePackage, semitones);
  }

  String exportActiveScoreToMusicXml(SongPackage activePackage) =>
      _musicXmlExporter.exportToMusicXml(activePackage);

  Uint8List exportActiveScoreToMidi(SongPackage activePackage) =>
      _midiExporter.exportToMidi(activePackage);

  String exportActiveScoreToAbc(SongPackage activePackage) =>
      _abcExporter.exportToAbc(activePackage);

  Uint8List exportActiveScoreToPdf(SongPackage activePackage) =>
      _pdfExporter.exportToPdf(activePackage);

  PedagogicalSessionData buildPedagogicalSessionData({
    required SongPackage activePackage,
    required List<PracticeReportEntity> sessionHistory,
    required MultiTrackSessionEntity multiTrackSession,
    required double cents,
    required int bpm,
    required TapTempoResult? lastTapTempoResult,
    TimbreAnalysisResult? timbreAnalysis,
    List<NoteEvaluationEntity> activeEvaluations = const [],
  }) {
    final lastReport = sessionHistory.isNotEmpty ? sessionHistory.last : null;
    final lastTake = multiTrackSession.takes.isNotEmpty ? multiTrackSession.takes.last : null;

    final title = lastReport?.songTitle ?? activePackage.title;
    final int notes;
    final int inTune;
    final double accuracy;
    final double avgCents;

    if (lastReport != null) {
      notes = lastReport.totalNotes;
      inTune = lastReport.hitNotes;
      accuracy = lastReport.pitchAccuracyPercentage;
      avgCents = lastReport.averageCentsDeviation;
    } else if (activeEvaluations.isNotEmpty) {
      notes = activeEvaluations.length;
      inTune = activeEvaluations.where((e) => e.isPitchAccurate).length;
      accuracy = notes > 0 ? (inTune / notes) * 100.0 : 0.0;
      final sumCents = activeEvaluations.fold<double>(
        0.0,
        (acc, e) => acc + e.centsDeviation.abs(),
      );
      avgCents = notes > 0 ? sumCents / notes : 0.0;
    } else {
      notes = 0;
      inTune = 0;
      accuracy = 0.0;
      avgCents = cents.abs() < 50 ? cents : 0.0;
    }

    final List<TimedCentsSample> samples;
    if (lastTake != null && lastTake.pitchTrack.isNotEmpty) {
      samples = lastTake.pitchTrack
          .map((s) => TimedCentsSample(
                timeSec: s.timeMs / 1000.0,
                cents: s.centsDeviation,
              ))
          .toList(growable: false);
    } else {
      samples = const <TimedCentsSample>[];
    }

    final double jitter = lastTapTempoResult != null && lastTapTempoResult.jitterMs > 0
        ? lastTapTempoResult.jitterMs
        : 0.0;

    final double stabilityDelta;
    if (samples.length >= 2) {
      final mean = samples.fold<double>(0.0, (a, b) => a + b.cents) / samples.length;
      double variance = 0.0;
      for (final s in samples) {
        final d = s.cents - mean;
        variance += d * d;
      }
      stabilityDelta = variance > 0 ? (variance / samples.length) : 0.0;
    } else {
      stabilityDelta = 0.0;
    }

    final double centroidHz = timbreAnalysis?.spectralCentroidHz ?? 0.0;
    final double thdPct = timbreAnalysis?.totalHarmonicDistortionPercent ?? 0.0;
    final List<double> harmonicRatios = timbreAnalysis != null && timbreAnalysis.harmonics.isNotEmpty
        ? timbreAnalysis.harmonics.map((h) => h.relativeAmplitude).toList(growable: false)
        : const <double>[];

    final String level;
    if (notes == 0) {
      level = 'Sin sesiones registradas';
    } else if (accuracy >= 90 && jitter <= 12) {
      level = 'Virtuoso / Conservatorio';
    } else if (accuracy >= 80) {
      level = 'Avanzado';
    } else if (accuracy >= 65) {
      level = 'Intermedio';
    } else {
      level = 'Iniciacion';
    }

    return PedagogicalSessionData(
      sessionTitle: title,
      sessionDate: lastReport?.timestamp ?? DateTime.now(),
      duration: lastTake?.duration ?? Duration.zero,
      totalEvaluatedNotes: notes,
      inTuneNotesCount: inTune,
      tuningAccuracyPercentage: accuracy,
      averageCentsDeviation: avgCents,
      centsStabilityDelta: stabilityDelta,
      spectralCentroidHz: centroidHz,
      thdPercentage: thdPct,
      harmonicRatios: harmonicRatios,
      rhythmMeanBpm: bpm.toDouble(),
      rhythmJitterMs: jitter,
      timedPitchSamples: samples,
      masteryLevel: level,
      pedagogicalDiagnostic: notes == 0
          ? 'Aun no se han evaluado notas en esta sesion. Inicia una practica guiada para medir afinacion y pulso.'
          : 'Precision medida: ${accuracy.toStringAsFixed(1)}% sobre $notes notas evaluadas (desviacion media ${avgCents.toStringAsFixed(1)} cents).',
      recommendations: notes == 0
          ? const [
              'Activa el modo practica sobre una partitura o ejercicio para registrar metricas reales.',
            ]
          : const [
              'Mantener el apoyo diafragmatico y regularidad del flujo aereo en registros agudos.',
              'Ejercitar intervalos de quinta justa y octava con el Dron Armonico de referencia.',
              'Continuar rutinas de metronomo con acentos alternos para afianzar el pulso.',
            ],
    );
  }

  Uint8List exportPedagogicalReportPdf({
    required PedagogicalSessionData sessionData,
    required PedagogicalReportConfig config,
  }) {
    return _pedagogicalPdfGenerator.generateReportPdf(
      session: sessionData,
      config: config,
    );
  }

  Future<ParsedScoreResult?> transcribeAudioFileToScore(
    Uint8List audioBytes,
    String fileName,
  ) async {
    try {
      return await _scoreImporterService.parseScoreData(
        bytes: audioBytes,
        fileName: fileName,
      );
    } catch (e) {
      _logger.warning('ScoreEditorController', 'Error al transcribir audio a partitura: $e');
      return null;
    }
  }

  SongPackage? toggleLiveTranscription({
    required SongPackage activePackage,
    required int currentMeasureIndex,
    required int currentSubTick,
  }) {
    _isLiveTranscriptionActive = !_isLiveTranscriptionActive;
    if (_isLiveTranscriptionActive) {
      _transcriptionEngine.start(
        initialPackage: activePackage,
        startMeasureIndex: currentMeasureIndex,
        startTick: currentSubTick >= 0 ? currentSubTick : 0,
      );
      return null;
    } else {
      final finalPkg = _transcriptionEngine.stop();
      if (finalPkg != null) {
        _scoreHistory.recordState(activePackage);
      }
      return finalPkg;
    }
  }

  SongPackage? togglePolyphonicLiveTranscription({
    required SongPackage activePackage,
    required int currentMeasureIndex,
    required int currentSubTick,
    required VoidCallback ensureChordRecognitionActive,
  }) {
    _isPolyphonicTranscriptionActive = !_isPolyphonicTranscriptionActive;
    if (_isPolyphonicTranscriptionActive) {
      ensureChordRecognitionActive();
      _polyphonicTranscriptionEngine.start(
        initialPackage: activePackage,
        startMeasureIndex: currentMeasureIndex,
        startTick: currentSubTick >= 0 ? currentSubTick : 0,
      );
      return null;
    } else {
      final finalPkg = _polyphonicTranscriptionEngine.stop();
      if (finalPkg != null) {
        _scoreHistory.recordState(activePackage);
      }
      return finalPkg;
    }
  }

  SongPackage? processPolyphonicTranscriptionFrame({
    required SongPackage activePackage,
    required List<String> noteNames,
    double energyRms = 0.1,
  }) {
    if (!_isPolyphonicTranscriptionActive) return null;

    final updatedPkg = _polyphonicTranscriptionEngine.processPolyphonicFrame(
      noteNames: noteNames,
      energyRms: energyRms,
    );
    if (updatedPkg != null) {
      _scoreHistory.recordState(activePackage);
    }
    return updatedPkg;
  }

  SongPackage generateExercise({
    required SongPackage activePackage,
    required String rootNote,
    required ExerciseType type,
    ExerciseRhythm rhythm = ExerciseRhythm.quarter,
    int bpm = 80,
  }) {
    _scoreHistory.recordState(activePackage);
    return _exerciseGenerator.generate(
      rootNote: rootNote,
      type: type,
      rhythm: rhythm,
      bpm: bpm,
    );
  }

  Future<ExportBundleResult> exportStemsAndMidi({
    required SongPackage activePackage,
    required MixerConsoleEntity mixerConsole,
    required int bpm,
    required PracticeRecordingEntity? recordedTake,
    StemExportConfig config = const StemExportConfig(),
  }) async {
    _isExportingStems = true;
    _onNotify();

    try {
      final bundle = _stemSynthesizer.exportStemsAndMidi(
        score: activePackage.score,
        mixerConsole: mixerConsole,
        bpm: bpm,
        trackTitle: activePackage.title,
        config: config,
        recordedTake: recordedTake,
      );

      _lastExportBundle = bundle;
      await _exportPersistenceService.saveExportBundle(
        bundle,
        customSubfolder: activePackage.title.toLowerCase().replaceAll(' ', '_'),
      );
      return bundle;
    } finally {
      _isExportingStems = false;
      _onNotify();
    }
  }
}
