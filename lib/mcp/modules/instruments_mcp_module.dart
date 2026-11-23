import 'dart:io';
import 'dart:math' as math;

import '../../features/instrument/domain/instrument_catalog_bridge.dart';
import '../../features/instrument/domain/instrument_customization_profile.dart';
import '../../features/instrument/domain/instrument_transposition_service.dart';
import '../../features/instrument/domain/musical_phrase_entity.dart';
import '../../features/instrument/domain/per_note_detuning_profile.dart';
import '../../features/instrument/domain/procedural_instrument_synthesizer.dart';
import '../../features/instrument/domain/smart_instrument_detector.dart';
import '../../features/instrument/domain/universal_instrument_definition.dart';
import '../../features/instrument/domain/universal_instrument_taxonomy.dart';
import '../../features/tuner/domain/temperament_engine.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing the unified catalog of 40+ instruments,
/// Hornbostel-Sachs taxonomy, pure concert-pitch tuning derivation,
/// musical transposition (including enharmonic octave boundaries such as
/// `Cb4`, `E#4`, `B#3`, and `Fb4`), microtonal customization, procedural WAV
/// synthesis, acoustic range validation, and spectral instrument detection.
class InstrumentsMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final InstrumentCatalogBridge _catalogBridge;
  final InstrumentTranspositionService _transpositionService;
  final SmartInstrumentDetector _smartDetector;

  /// Session-scoped instrument customization profiles keyed by `universalId`.
  final Map<String, InstrumentCustomizationProfile> _sessionCustomizations = {};

  InstrumentsMcpModule(
    this.facade, {
    InstrumentCatalogBridge catalogBridge = const InstrumentCatalogBridge(),
    InstrumentTranspositionService transpositionService =
        const InstrumentTranspositionService(),
    SmartInstrumentDetector? smartDetector,
  })  : _catalogBridge = catalogBridge,
        _transpositionService = transpositionService,
        _smartDetector = smartDetector ?? SmartInstrumentDetector();

  @override
  String get moduleName => 'instruments';

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ===========================================================================
  // Resources (4)
  // ===========================================================================

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://catalog/instruments',
        name: 'Unified Universal Instrument Catalog',
        description:
            'Complete unified catalog of 40+ universal instruments with Hornbostel-Sachs taxonomy, acoustic ranges, transpositions, timbral profiles, and legacy profile mappings.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://catalog/instruments',
            data: _catalogBridge.toJson(),
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://catalog/taxonomy',
        name: 'Hornbostel-Sachs Instrument Taxonomy',
        description:
            'Formal Hornbostel-Sachs taxonomy (6 categories and 14 subfamilies) with instrument counts per branch.',
        mimeType: 'application/json',
        reader: () async {
          final categories = HornbostelSachsCategory.values.map((cat) {
            final count =
                UniversalInstrumentDefinition.filterByCategory(cat).length;
            return {
              'name': cat.name,
              'code': cat.code,
              'displayName': cat.displayName,
              'instrumentCount': count,
            };
          }).toList(growable: false);

          final subfamilies = InstrumentSubfamily.values.map((sub) {
            final count =
                UniversalInstrumentDefinition.filterBySubfamily(sub).length;
            return {
              'name': sub.name,
              'code': sub.code,
              'displayName': sub.displayName,
              'instrumentCount': count,
            };
          }).toList(growable: false);

          return McpResourceContent.json(
            uri: 'tunner://catalog/taxonomy',
            data: {
              'categoryCount': categories.length,
              'subfamilyCount': subfamilies.length,
              'categories': categories,
              'subfamilies': subfamilies,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://catalog/detuning-presets',
        name: 'Microtonal Detuning Presets',
        description:
            'Canonical per-note and per-string microtonal detuning presets (standard, honky-tonk, Railsback stretch, 12-string shimmer, Maqam quarter-tone).',
        mimeType: 'application/json',
        reader: () async {
          final presets = PerNoteDetuningProfile.presets
              .map(_detuningProfileToJson)
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://catalog/detuning-presets',
            data: {
              'count': presets.length,
              'presets': presets,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://catalog/phrases',
        name: 'Canonical Musical Phrases Catalog',
        description:
            'Canonical musical phrases for procedural timbral calibration, synthesis testing, and ethnomusicology demos.',
        mimeType: 'application/json',
        reader: () async {
          final phrases = MusicalPhraseEntity.canonicalPhrases
              .map(_phraseToJson)
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://catalog/phrases',
            data: {
              'count': phrases.length,
              'phrases': phrases,
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (9)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_search_instruments',
        description:
            'Searches and filters the universal instrument catalog by free-text query, Hornbostel-Sachs category, subfamily, MIDI note coverage, or transposing status.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Optional free-text keyword search query.',
            },
            'category': {
              'type': 'string',
              'description':
                  'Optional Hornbostel-Sachs category name or code (e.g. chordophone, aerophone, vocal).',
            },
            'subfamily': {
              'type': 'string',
              'description':
                  'Optional subfamily name or code (e.g. woodwind, brass, plucked_strings).',
            },
            'minMidiNote': {
              'type': 'integer',
              'minimum': 0,
              'maximum': 127,
              'description':
                  'Optional MIDI note that the instrument must be able to reach.',
            },
            'maxMidiNote': {
              'type': 'integer',
              'minimum': 0,
              'maximum': 127,
              'description':
                  'Optional upper MIDI note that the instrument must be able to reach.',
            },
            'onlyTransposing': {
              'type': 'boolean',
              'description':
                  'When true, returns only transposing instruments (transpositionSemitones != 0).',
            },
          },
        },
        handler: _handleSearchInstruments,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_get_instrument_detail',
        description:
            'Retrieves full acoustic, timbral, visual, and scaled tuning specifications for a single instrument by universalId or legacyProfileId.',
        inputSchema: const {
          'type': 'object',
          'required': ['instrumentId'],
          'properties': {
            'instrumentId': {
              'type': 'string',
              'description':
                  'Universal ID (e.g. aerophone.woodwind.clarinet_bb) or legacy profile ID (e.g. bb_clarinet).',
            },
            'referencePitchA4': {
              'type': 'number',
              'minimum': 415.0,
              'maximum': 466.0,
              'default': 440.0,
            },
          },
        },
        handler: _handleGetInstrumentDetail,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_validate_instrument_range',
        description:
            'Validates whether lists of MIDI notes and/or frequencies in Hz fall within the playable acoustic range (tessitura) of an instrument.',
        inputSchema: const {
          'type': 'object',
          'required': ['instrumentId'],
          'properties': {
            'instrumentId': {
              'type': 'string',
              'description': 'Universal ID or legacy profile ID.',
            },
            'midiNotes': {
              'type': 'array',
              'items': {'type': 'integer', 'minimum': 0, 'maximum': 127},
              'description': 'Optional list of MIDI note numbers to validate.',
            },
            'frequenciesHz': {
              'type': 'array',
              'items': {'type': 'number', 'exclusiveMinimum': 0},
              'description': 'Optional list of frequencies in Hz to validate.',
            },
          },
        },
        handler: _handleValidateInstrumentRange,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_transpose_note',
        description:
            'Transposes a note between written notation and concert sounding pitch for any instrument, supporting solfege, scientific notation, and enharmonic boundaries (Cb4, E#4, B#3, Fb4).',
        inputSchema: const {
          'type': 'object',
          'required': ['note', 'instrumentId'],
          'properties': {
            'note': {
              'type': 'string',
              'description':
                  'Input note in scientific or solfege notation (e.g. C4, Cb4, B#3, E#4, Sib3).',
            },
            'instrumentId': {
              'type': 'string',
              'description': 'Universal ID or legacy profile ID.',
            },
            'direction': {
              'type': 'string',
              'enum': ['written_to_sounding', 'sounding_to_written'],
              'default': 'written_to_sounding',
            },
            'a4RefHz': {
              'type': 'number',
              'minimum': 415.0,
              'maximum': 466.0,
              'default': 440.0,
            },
            'outputFormat': {
              'type': 'string',
              'enum': ['scientific', 'solfege'],
              'default': 'scientific',
            },
          },
        },
        handler: _handleTransposeNote,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_calculate_microtonal_frequency',
        description:
            'Computes the exact physical frequency in Hz for a MIDI note on an instrument applying concert pitch A4, transposition, historical temperament, and per-note/per-string microtonal detuning.',
        inputSchema: const {
          'type': 'object',
          'required': ['instrumentId', 'midiNote'],
          'properties': {
            'instrumentId': {'type': 'string'},
            'midiNote': {'type': 'integer', 'minimum': 0, 'maximum': 127},
            'stringIndex': {'type': 'integer', 'minimum': 0},
            'referencePitchA4': {
              'type': 'number',
              'minimum': 415.0,
              'maximum': 466.0,
              'default': 440.0,
            },
            'temperamentId': {'type': 'string'},
            'detuningPresetId': {'type': 'string'},
            'customNoteCents': {
              'type': 'object',
              'description': 'Map of MIDI note (string key) to cents offset.',
            },
            'customStringCents': {
              'type': 'object',
              'description': 'Map of string index (string key) to cents offset.',
            },
          },
        },
        handler: _handleCalculateMicrotonalFrequency,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_get_standard_tuning',
        description:
            'Derives pure scaled open-string or standard tuning frequencies for an instrument at any concert pitch A4 (e.g. 440 Hz, 442 Hz, 415 Hz).',
        inputSchema: const {
          'type': 'object',
          'required': ['instrumentId'],
          'properties': {
            'instrumentId': {'type': 'string'},
            'referencePitchA4': {
              'type': 'number',
              'minimum': 415.0,
              'maximum': 466.0,
              'default': 440.0,
            },
          },
        },
        handler: _handleGetStandardTuning,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_synthesize_instrument_note',
        description:
            'Synthesizes a procedural single-note PCM WAV file for any universal instrument with configurable sampleRate, resonanceFactor, harmonic brightness, and microtonal customization.',
        inputSchema: const {
          'type': 'object',
          'required': ['instrumentId', 'outputWavPath'],
          'properties': {
            'instrumentId': {'type': 'string'},
            'midiNote': {'type': 'integer', 'minimum': 0, 'maximum': 127},
            'frequencyHz': {'type': 'number', 'exclusiveMinimum': 0},
            'durationSeconds': {
              'type': 'number',
              'minimum': 0.05,
              'maximum': 15.0,
              'default': 1.0,
            },
            'velocity': {
              'type': 'number',
              'minimum': 0.0,
              'maximum': 1.0,
              'default': 0.8,
            },
            'sampleRate': {
              'type': 'integer',
              'minimum': 8000,
              'maximum': 192000,
              'default': 44100,
            },
            'outputWavPath': {
              'type': 'string',
              'description':
                  'Relative or workspace-contained path where the 16-bit PCM WAV will be written.',
            },
            'customization': {
              'type': 'object',
              'description':
                  'Optional customization overrides (referencePitchA4, temperamentId, detuningPresetId, attackMultiplier, sustainMultiplier, harmonicBrightness, resonanceFactor).',
            },
          },
        },
        handler: _handleSynthesizeInstrumentNote,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_synthesize_instrument_phrase',
        description:
            'Synthesizes a canonical or custom musical phrase into a 16-bit PCM WAV file using ProceduralInstrumentSynthesizer with full timbral and microtonal customization.',
        inputSchema: const {
          'type': 'object',
          'required': ['instrumentId', 'outputWavPath'],
          'properties': {
            'instrumentId': {'type': 'string'},
            'phraseId': {
              'type': 'string',
              'description':
                  'Canonical phrase ID (major_arpeggio, bach_prelude, andean_pentatonic, funk_bassline, maqam_bayati_stanza).',
            },
            'customNotes': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': ['midiNote', 'durationTicks'],
                'properties': {
                  'midiNote': {'type': 'integer', 'minimum': 0, 'maximum': 127},
                  'durationTicks': {'type': 'integer', 'minimum': 1},
                  'velocity': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
                  'isRest': {'type': 'boolean'},
                },
              },
            },
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'sampleRate': {
              'type': 'integer',
              'minimum': 8000,
              'maximum': 192000,
              'default': 44100,
            },
            'outputWavPath': {'type': 'string'},
            'customization': {'type': 'object'},
          },
        },
        handler: _handleSynthesizeInstrumentPhrase,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_detect_instrument_from_signature',
        description:
            'Classifies the most likely musical instrument from an acoustic spectral signature (fundamental Hz, clarity, 8 overtone amplitudes, spectral centroid) using SmartInstrumentDetector.',
        inputSchema: const {
          'type': 'object',
          'required': [
            'fundamentalFrequencyHz',
            'clarity',
            'overtoneAmplitudes',
            'spectralCentroidHz',
          ],
          'properties': {
            'fundamentalFrequencyHz': {'type': 'number', 'minimum': 20.0},
            'clarity': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'overtoneAmplitudes': {
              'type': 'array',
              'items': {'type': 'number', 'minimum': 0.0},
              'minItems': 1,
              'maxItems': 8,
            },
            'spectralCentroidHz': {'type': 'number', 'minimum': 0.0},
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 9, 'default': 3},
            'minimumConfidence': {
              'type': 'number',
              'minimum': 0.0,
              'maximum': 1.0,
              'default': 0.75,
            },
          },
        },
        handler: _handleDetectInstrumentFromSignature,
      ),
    );
  }

  // ===========================================================================
  // Prompts (3)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_orchestration_range_audit',
        description:
            'Audits a multi-instrument arrangement against physical instrument tessituras and derives written parts for transposing instruments.',
        arguments: const [
          McpPromptArgument(
            name: 'ensemble',
            description:
                'Comma-separated list of instruments in the arrangement (e.g. flute, bb_clarinet, f_horn, cello).',
            required: false,
          ),
          McpPromptArgument(
            name: 'pieceTitle',
            description: 'Optional title of the score or arrangement being audited.',
            required: false,
          ),
        ],
        builder: (args) async {
          final ensemble = args['ensemble'] ?? 'flute, bb_clarinet, f_horn, cello';
          final pieceTitle = args['pieceTitle'] ?? 'Untitled Arrangement';
          return McpPromptResult(
            description: 'Orchestration range and transposition audit workflow.',
            messages: [
              McpPromptMessage.user(
                'Audit the orchestration for "$pieceTitle" with ensemble [$ensemble]. '
                'Step 1: Read tunner://catalog/instruments to inspect exact acoustic ranges and transposition semitones. '
                'Step 2: Call tunner_validate_instrument_range for each instrument part to detect out-of-range MIDI notes or frequencies. '
                'Step 3: Call tunner_transpose_note with direction="sounding_to_written" for every transposing instrument to produce accurate written parts.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_microtonal_ethnomusicology_lab',
        description:
            'Configures and synthesizes a traditional or microtonal phrase (e.g. Maqam Bayati, Andean Charango, Kora, Sitar) with historical temperaments and per-note detuning.',
        arguments: const [
          McpPromptArgument(
            name: 'tradition',
            description:
                'Musical tradition or system (e.g. Maqam Bayati, Andean Pentatonic, Baroque Vallotti).',
            required: false,
          ),
          McpPromptArgument(
            name: 'instrumentId',
            description: 'Target universalId or legacyProfileId.',
            required: false,
          ),
          McpPromptArgument(
            name: 'phraseId',
            description: 'Canonical phrase ID from tunner://catalog/phrases.',
            required: false,
          ),
        ],
        builder: (args) async {
          final tradition = args['tradition'] ?? 'Maqam Bayati';
          final instrumentId = args['instrumentId'] ?? 'sitar';
          final phraseId = args['phraseId'] ?? 'maqam_bayati_stanza';
          return McpPromptResult(
            description: 'Microtonal ethnomusicology synthesis lab workflow.',
            messages: [
              McpPromptMessage.user(
                'Prepare a microtonal ethnomusicology demonstration for "$tradition" using instrument "$instrumentId" and phrase "$phraseId". '
                'Step 1: Read tunner://catalog/detuning-presets and tunner://catalog/phrases. '
                'Step 2: Call tunner_calculate_microtonal_frequency for the key scale degrees to verify cent deviations. '
                'Step 3: Render a WAV demonstration with tunner_synthesize_instrument_phrase using the matching detuningPresetId.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_timbral_identification_diagnostic',
        description:
            'Classifies an acoustic instrument from spectral metrics and provides tessitura, tuning, and transposition guidance.',
        arguments: const [
          McpPromptArgument(
            name: 'fundamentalHz',
            description: 'Measured fundamental frequency in Hz.',
            required: false,
          ),
          McpPromptArgument(
            name: 'context',
            description: 'Optional recording context or acoustic notes.',
            required: false,
          ),
        ],
        builder: (args) async {
          final fundamentalHz = args['fundamentalHz'] ?? '440.0';
          final context = args['context'] ?? 'studio solo take';
          return McpPromptResult(
            description: 'Timbral instrument identification diagnostic workflow.',
            messages: [
              McpPromptMessage.user(
                'Identify the instrument recorded in "$context" (f0 = $fundamentalHz Hz). '
                'Step 1: Call tunner_detect_instrument_from_signature with the measured fundamental, clarity, overtone amplitudes, and spectral centroid. '
                'Step 2: Call tunner_get_instrument_detail for the top candidate to retrieve its full acoustic range, transposition, and standard tuning. '
                'Step 3: Summarize the diagnostic confidence, expected tessitura, and recommended concert pitch setup.',
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tool Handlers
  // ===========================================================================

  Future<McpToolResult> _handleSearchInstruments(
    Map<String, dynamic> args,
  ) async {
    final query = _optionalString(args, 'query');
    final categoryRaw = _optionalString(args, 'category');
    final subfamilyRaw = _optionalString(args, 'subfamily');
    final minMidiNote = _optionalInt(args, 'minMidiNote');
    final maxMidiNote = _optionalInt(args, 'maxMidiNote');
    final onlyTransposing = _optionalBool(args, 'onlyTransposing') ?? false;

    List<UniversalInstrumentDefinition> candidates = query != null && query.isNotEmpty
        ? UniversalInstrumentDefinition.search(query)
        : List<UniversalInstrumentDefinition>.from(
            UniversalInstrumentDefinition.masterCatalog,
          );

    if (categoryRaw != null && categoryRaw.isNotEmpty) {
      final category = _parseCategory(categoryRaw);
      candidates = candidates.where((i) => i.category == category).toList();
    }

    if (subfamilyRaw != null && subfamilyRaw.isNotEmpty) {
      final subfamily = _parseSubfamily(subfamilyRaw);
      candidates = candidates.where((i) => i.subfamily == subfamily).toList();
    }

    if (minMidiNote != null) {
      _validateMidiRange(minMidiNote, 'minMidiNote');
      candidates = candidates
          .where((i) => i.acousticRange.containsMidiNote(minMidiNote))
          .toList();
    }

    if (maxMidiNote != null) {
      _validateMidiRange(maxMidiNote, 'maxMidiNote');
      candidates = candidates
          .where((i) => i.acousticRange.containsMidiNote(maxMidiNote))
          .toList();
    }

    if (onlyTransposing) {
      candidates = candidates.where((i) => i.isTransposing).toList();
    }

    final serialized = candidates
        .map(InstrumentCatalogBridge.universalToJson)
        .toList(growable: false);

    return McpToolResult.json({
      'total': serialized.length,
      'matches': serialized,
    });
  }

  Future<McpToolResult> _handleGetInstrumentDetail(
    Map<String, dynamic> args,
  ) async {
    final instrumentId = _requireString(args, 'instrumentId');
    final referencePitchA4 = _optionalDouble(args, 'referencePitchA4') ?? 440.0;
    _validateReferencePitch(referencePitchA4, 'referencePitchA4');

    final universal = InstrumentCatalogBridge.findUniversalByAnyId(instrumentId);
    if (universal == null) {
      final legacy = InstrumentCatalogBridge.findProfileByAnyId(instrumentId);
      if (legacy != null) {
        return McpToolResult.json({
          'foundInUniversalCatalog': false,
          'legacyProfile': InstrumentCatalogBridge.profileToJson(legacy),
        });
      }
      throw McpException.fileNotFound('Instrument not found: "$instrumentId".');
    }

    final scaledTuning = universal.standardTuningFrequenciesFor(
      referencePitchHz: referencePitchA4,
    );
    final activeCustomization = _sessionCustomizations[universal.universalId];

    return McpToolResult.json({
      'foundInUniversalCatalog': true,
      ...InstrumentCatalogBridge.universalToJson(universal),
      'referencePitchA4': referencePitchA4,
      'standardTuningFrequenciesScaled': scaledTuning,
      'visualProfile': {
        'rendererType': universal.visualProfile.rendererType.name,
        'rendererCode': universal.visualProfile.rendererType.code,
        'visualMaterialTheme': universal.visualProfile.visualMaterialTheme,
        'primaryAccentHex': _toHexArgb(universal.visualProfile.primaryAccentHex),
        'secondaryAccentHex':
            _toHexArgb(universal.visualProfile.secondaryAccentHex),
        'surfaceHex': _toHexArgb(universal.visualProfile.surfaceHex),
        'smuflGlyph': universal.visualProfile.smuflGlyph,
        'tactileLabels': List<String>.from(universal.visualProfile.tactileLabels),
      },
      'activeCustomization': activeCustomization != null
          ? _customizationToJson(activeCustomization)
          : null,
    });
  }

  Future<McpToolResult> _handleValidateInstrumentRange(
    Map<String, dynamic> args,
  ) async {
    final instrumentId = _requireString(args, 'instrumentId');
    final rawMidiNotes = args['midiNotes'];
    final rawFrequencies = args['frequenciesHz'];

    if (rawMidiNotes == null && rawFrequencies == null) {
      throw const McpException.invalidParams(
        'Provide at least one of "midiNotes" or "frequenciesHz".',
      );
    }

    final universal = InstrumentCatalogBridge.findUniversalByAnyId(instrumentId);
    final profile = InstrumentCatalogBridge.findProfileByAnyId(instrumentId);
    if (universal == null && profile == null) {
      throw McpException.fileNotFound('Instrument not found: "$instrumentId".');
    }

    final outOfRangeItems = <Map<String, dynamic>>[];

    final minFreq =
        universal?.acousticRange.minFrequencyHz ?? profile!.minFrequencyHz;
    final maxFreq =
        universal?.acousticRange.maxFrequencyHz ?? profile!.maxFrequencyHz;
    final minMidi = universal?.acousticRange.minMidiNote ??
        _frequencyToNearestMidi(minFreq);
    final maxMidi = universal?.acousticRange.maxMidiNote ??
        _frequencyToNearestMidi(maxFreq);

    if (rawMidiNotes != null) {
      if (rawMidiNotes is! List) {
        throw const McpException.invalidParams(
          'Parameter "midiNotes" must be an array of integers.',
        );
      }
      for (final item in rawMidiNotes) {
        if (item is! num || item % 1 != 0) {
          throw McpException.invalidParams(
            'Invalid MIDI note value in "midiNotes": $item',
          );
        }
        final midi = item.toInt();
        _validateMidiRange(midi, 'midiNotes[]');
        final inRange = universal != null
            ? universal.acousticRange.containsMidiNote(midi)
            : (midi >= minMidi && midi <= maxMidi);
        if (!inRange) {
          outOfRangeItems.add({
            'type': 'midiNote',
            'input': midi,
            'reason': midi < minMidi
                ? 'Below instrument minimum MIDI note ($minMidi).'
                : 'Above instrument maximum MIDI note ($maxMidi).',
          });
        }
      }
    }

    if (rawFrequencies != null) {
      if (rawFrequencies is! List) {
        throw const McpException.invalidParams(
          'Parameter "frequenciesHz" must be an array of numbers.',
        );
      }
      for (final item in rawFrequencies) {
        if (item is! num || !item.isFinite || item <= 0) {
          throw McpException.invalidParams(
            'Invalid frequency value in "frequenciesHz": $item',
          );
        }
        final hz = item.toDouble();
        final inRange = universal != null
            ? universal.acousticRange.containsFrequency(hz)
            : (hz >= minFreq && hz <= maxFreq);
        if (!inRange) {
          outOfRangeItems.add({
            'type': 'frequencyHz',
            'input': hz,
            'reason': hz < minFreq
                ? 'Below instrument minimum frequency (${minFreq.toStringAsFixed(2)} Hz).'
                : 'Above instrument maximum frequency (${maxFreq.toStringAsFixed(2)} Hz).',
          });
        }
      }
    }

    return McpToolResult.json({
      'instrumentId': instrumentId,
      'universalId': universal?.universalId,
      'displayName': universal?.displayName ?? profile!.name,
      'allInRange': outOfRangeItems.isEmpty,
      'outOfRangeCount': outOfRangeItems.length,
      'outOfRangeItems': outOfRangeItems,
      'supportedRange': {
        'minMidiNote': minMidi,
        'maxMidiNote': maxMidi,
        'minFrequencyHz': minFreq,
        'maxFrequencyHz': maxFreq,
      },
    });
  }

  Future<McpToolResult> _handleTransposeNote(Map<String, dynamic> args) async {
    final note = _requireString(args, 'note');
    final instrumentId = _requireString(args, 'instrumentId');
    final direction =
        _optionalString(args, 'direction') ?? 'written_to_sounding';
    final a4RefHz = _optionalDouble(args, 'a4RefHz') ?? 440.0;
    final outputFormat = _optionalString(args, 'outputFormat') ?? 'scientific';

    _validateReferencePitch(a4RefHz, 'a4RefHz');

    if (direction != 'written_to_sounding' &&
        direction != 'sounding_to_written') {
      throw McpException.invalidParams(
        'Parameter "direction" must be "written_to_sounding" or "sounding_to_written".',
      );
    }
    if (outputFormat != 'scientific' && outputFormat != 'solfege') {
      throw McpException.invalidParams(
        'Parameter "outputFormat" must be "scientific" or "solfege".',
      );
    }

    final profile = InstrumentCatalogBridge.findProfileByAnyId(instrumentId);
    if (profile == null) {
      throw McpException.fileNotFound('Instrument not found: "$instrumentId".');
    }

    final inputMidi = _transpositionService.noteNameToMidi(note);
    if (inputMidi == null) {
      throw McpException.invalidMusicTheory(
        'Unrecognized musical note syntax: "$note".',
      );
    }

    final useScientific = outputFormat == 'scientific';
    final String resultNote;
    final int soundingMidi;
    final int writtenMidi;

    if (direction == 'written_to_sounding') {
      resultNote = _transpositionService.getSoundingNote(
        note,
        profile,
        useScientificNotation: useScientific,
      );
      writtenMidi = inputMidi;
      soundingMidi = inputMidi + profile.transpositionSemitones;
    } else {
      resultNote = _transpositionService.getWrittenNote(
        note,
        profile,
        useScientificNotation: useScientific,
      );
      soundingMidi = inputMidi;
      writtenMidi = inputMidi - profile.transpositionSemitones;
    }

    final soundingFrequencyHz = direction == 'written_to_sounding'
        ? _transpositionService.getSoundingFrequency(
            note,
            profile,
            a4Ref: a4RefHz,
          )
        : a4RefHz * math.pow(2.0, (soundingMidi - 69) / 12.0);

    return McpToolResult.json({
      'inputNote': note,
      'inputMidi': inputMidi,
      'direction': direction,
      'outputFormat': outputFormat,
      'resultNote': resultNote,
      'writtenMidi': writtenMidi,
      'soundingMidi': soundingMidi,
      'soundingFrequencyHz': soundingFrequencyHz,
      'a4RefHz': a4RefHz,
      'transpositionSemitones': profile.transpositionSemitones,
      'instrumentId': profile.id,
      'universalId': InstrumentCatalogBridge.universalIdForLegacyId(profile.id),
      'instrumentKey': profile.key.name,
      'notationClef': profile.clef.name,
    });
  }

  Future<McpToolResult> _handleCalculateMicrotonalFrequency(
    Map<String, dynamic> args,
  ) async {
    final instrumentId = _requireString(args, 'instrumentId');
    final midiNote = _requireInt(args, 'midiNote');
    _validateMidiRange(midiNote, 'midiNote');
    final stringIndex = _optionalInt(args, 'stringIndex');
    if (stringIndex != null && stringIndex < 0) {
      throw const McpException.invalidParams(
        'Parameter "stringIndex" must be >= 0.',
      );
    }

    final universal = _requireUniversalInstrument(instrumentId);
    final customization = _buildCustomizationProfile(universal, args);

    final frequencyHz = customization.calculateFrequencyForMidiNote(
      midiNote,
      stringIndex: stringIndex,
    );
    final transposedMidiNote = midiNote + universal.transpositionSemitones;
    final equal12EdoHz = customization.referencePitchA4 *
        math.pow(2.0, (transposedMidiNote - 69) / 12.0);
    final totalOffsetCents =
        1200.0 * (math.log(frequencyHz / equal12EdoHz) / math.ln2);

    return McpToolResult.json({
      'instrumentId': instrumentId,
      'universalId': universal.universalId,
      'midiNote': midiNote,
      'transposedMidiNote': transposedMidiNote,
      'stringIndex': stringIndex,
      'referencePitchA4': customization.referencePitchA4,
      'temperamentId': customization.temperament.id,
      'detuningPresetId': customization.detuningProfile.id,
      'frequencyHz': frequencyHz,
      'equal12EdoHz': equal12EdoHz,
      'totalOffsetCents': totalOffsetCents,
    });
  }

  Future<McpToolResult> _handleGetStandardTuning(
    Map<String, dynamic> args,
  ) async {
    final instrumentId = _requireString(args, 'instrumentId');
    final referencePitchA4 = _optionalDouble(args, 'referencePitchA4') ?? 440.0;
    _validateReferencePitch(referencePitchA4, 'referencePitchA4');

    final universal = _requireUniversalInstrument(instrumentId);
    final freqs = universal.standardTuningFrequenciesFor(
      referencePitchHz: referencePitchA4,
    );
    final names = universal.acousticRange.standardTuningNoteNames;

    final strings = <Map<String, dynamic>>[];
    for (int i = 0; i < freqs.length; i++) {
      strings.add({
        'index': i,
        'noteName': i < names.length ? names[i] : 'String ${i + 1}',
        'frequencyHz': freqs[i],
      });
    }

    return McpToolResult.json({
      'instrumentId': instrumentId,
      'universalId': universal.universalId,
      'displayName': universal.displayName,
      'referencePitchA4': referencePitchA4,
      'stringCount': strings.length,
      'strings': strings,
    });
  }

  Future<McpToolResult> _handleSynthesizeInstrumentNote(
    Map<String, dynamic> args,
  ) async {
    final instrumentId = _requireString(args, 'instrumentId');
    final outputWavPath = _requireString(args, 'outputWavPath');
    final durationSeconds = _optionalDouble(args, 'durationSeconds') ?? 1.0;
    final velocity = _optionalDouble(args, 'velocity') ?? 0.8;
    final sampleRate = _optionalInt(args, 'sampleRate') ??
        ProceduralInstrumentSynthesizer.sampleRate;

    if (durationSeconds < 0.05 || durationSeconds > 15.0) {
      throw const McpException.invalidParams(
        'Parameter "durationSeconds" must be between 0.05 and 15.0.',
      );
    }
    if (velocity < 0.0 || velocity > 1.0) {
      throw const McpException.invalidParams(
        'Parameter "velocity" must be between 0.0 and 1.0.',
      );
    }
    if (sampleRate < 8000 || sampleRate > 192000) {
      throw const McpException.invalidParams(
        'Parameter "sampleRate" must be between 8000 and 192000 Hz.',
      );
    }

    final midiNote = _optionalInt(args, 'midiNote');
    final explicitFreq = _optionalDouble(args, 'frequencyHz');
    if (midiNote == null && explicitFreq == null) {
      throw const McpException.invalidParams(
        'Provide either "midiNote" or "frequencyHz".',
      );
    }
    if (midiNote != null) {
      _validateMidiRange(midiNote, 'midiNote');
    }
    if (explicitFreq != null && (!explicitFreq.isFinite || explicitFreq <= 0)) {
      throw const McpException.invalidParams(
        'Parameter "frequencyHz" must be a finite number > 0.',
      );
    }

    final universal = _requireUniversalInstrument(instrumentId);
    final rawCust = args['customization'];
    final custMap = rawCust is Map<String, dynamic> ? rawCust : const <String, dynamic>{};
    final customization = _buildCustomizationProfile(universal, custMap);
    _sessionCustomizations[universal.universalId] = customization;

    final frequencyHz = explicitFreq ??
        customization.calculateFrequencyForMidiNote(midiNote!);

    final outputFile = _resolveSandboxedFile(outputWavPath);
    if (!await outputFile.parent.exists()) {
      await outputFile.parent.create(recursive: true);
    }

    final pcmSamples = ProceduralInstrumentSynthesizer.synthesizeCustomNote(
      customization: customization,
      frequencyHz: frequencyHz,
      durationSeconds: durationSeconds,
      velocity: velocity,
      sampleRate: sampleRate,
    );
    final wavBytes = ProceduralInstrumentSynthesizer.floatBufferToWavBytes(
      pcmSamples,
      sampleRate: sampleRate,
    );
    await outputFile.writeAsBytes(wavBytes, flush: true);

    return McpToolResult.json({
      'instrumentId': instrumentId,
      'universalId': universal.universalId,
      'outputWavPath': outputFile.path,
      'sampleRate': sampleRate,
      'numSamples': pcmSamples.length,
      'durationSeconds': durationSeconds,
      'bytesWritten': wavBytes.length,
      'frequencyHz': frequencyHz,
      'resonanceFactor': customization.resonanceFactor,
    });
  }

  Future<McpToolResult> _handleSynthesizeInstrumentPhrase(
    Map<String, dynamic> args,
  ) async {
    final instrumentId = _requireString(args, 'instrumentId');
    final outputWavPath = _requireString(args, 'outputWavPath');
    final phraseId = _optionalString(args, 'phraseId');
    final rawCustomNotes = args['customNotes'];
    final bpmOverride = _optionalInt(args, 'bpm');
    final sampleRate = _optionalInt(args, 'sampleRate') ??
        ProceduralInstrumentSynthesizer.sampleRate;

    if (bpmOverride != null && (bpmOverride < 20 || bpmOverride > 300)) {
      throw const McpException.invalidParams(
        'Parameter "bpm" must be between 20 and 300.',
      );
    }
    if (sampleRate < 8000 || sampleRate > 192000) {
      throw const McpException.invalidParams(
        'Parameter "sampleRate" must be between 8000 and 192000 Hz.',
      );
    }

    final MusicalPhraseEntity phrase;
    if (rawCustomNotes != null) {
      if (rawCustomNotes is! List || rawCustomNotes.isEmpty) {
        throw const McpException.invalidParams(
          'Parameter "customNotes" must be a non-empty array.',
        );
      }
      final notes = <MusicalPhraseNote>[];
      for (final raw in rawCustomNotes) {
        if (raw is! Map<String, dynamic>) {
          throw const McpException.invalidParams(
            'Each item in "customNotes" must be an object.',
          );
        }
        final midi = _requireInt(raw, 'midiNote');
        _validateMidiRange(midi, 'customNotes[].midiNote');
        final ticks = _requireInt(raw, 'durationTicks');
        if (ticks <= 0) {
          throw const McpException.invalidParams(
            'Each note "durationTicks" must be >= 1.',
          );
        }
        final vel = _optionalDouble(raw, 'velocity') ?? 0.8;
        final isRest = _optionalBool(raw, 'isRest') ?? false;
        notes.add(
          MusicalPhraseNote(
            midiNote: midi,
            durationTicks: ticks,
            velocity: vel.clamp(0.0, 1.0),
            isRest: isRest,
          ),
        );
      }
      phrase = MusicalPhraseEntity(
        id: 'custom_phrase',
        title: 'Custom MCP Phrase',
        description: 'User-defined phrase synthesized via MCP.',
        genreOrTradition: 'Custom',
        defaultBpm: bpmOverride ?? 120,
        notes: notes,
      );
    } else if (phraseId != null && phraseId.isNotEmpty) {
      final found = MusicalPhraseEntity.canonicalPhrases
          .where((p) => p.id == phraseId)
          .toList();
      if (found.isEmpty) {
        throw McpException.fileNotFound('Canonical phrase not found: "$phraseId".');
      }
      phrase = found.first;
    } else {
      throw const McpException.invalidParams(
        'Provide either "phraseId" or "customNotes".',
      );
    }

    final universal = _requireUniversalInstrument(instrumentId);
    final rawCust = args['customization'];
    final custMap = rawCust is Map<String, dynamic> ? rawCust : const <String, dynamic>{};
    final customization = _buildCustomizationProfile(universal, custMap);
    _sessionCustomizations[universal.universalId] = customization;

    final outputFile = _resolveSandboxedFile(outputWavPath);
    if (!await outputFile.parent.exists()) {
      await outputFile.parent.create(recursive: true);
    }

    final effectiveBpm = bpmOverride ?? phrase.defaultBpm;
    final pcmSamples = ProceduralInstrumentSynthesizer.synthesizePhrase(
      customization: customization,
      phrase: phrase,
      bpmOverride: effectiveBpm,
      sampleRate: sampleRate,
    );
    final wavBytes = ProceduralInstrumentSynthesizer.floatBufferToWavBytes(
      pcmSamples,
      sampleRate: sampleRate,
    );
    await outputFile.writeAsBytes(wavBytes, flush: true);

    final durationSeconds = pcmSamples.length / sampleRate;

    return McpToolResult.json({
      'instrumentId': instrumentId,
      'universalId': universal.universalId,
      'phraseId': phrase.id,
      'outputWavPath': outputFile.path,
      'bpm': effectiveBpm,
      'totalTicks': phrase.totalTicks,
      'sampleRate': sampleRate,
      'numSamples': pcmSamples.length,
      'durationSeconds': durationSeconds,
      'bytesWritten': wavBytes.length,
    });
  }

  Future<McpToolResult> _handleDetectInstrumentFromSignature(
    Map<String, dynamic> args,
  ) async {
    final fundamentalHz = _requireDouble(args, 'fundamentalFrequencyHz');
    final clarity = _requireDouble(args, 'clarity');
    final spectralCentroidHz = _requireDouble(args, 'spectralCentroidHz');
    final limit = _optionalInt(args, 'limit') ?? 3;
    final minimumConfidence =
        _optionalDouble(args, 'minimumConfidence') ?? 0.75;

    if (fundamentalHz <= 0 || !fundamentalHz.isFinite) {
      throw const McpException.invalidParams(
        'Parameter "fundamentalFrequencyHz" must be > 0.',
      );
    }
    if (clarity < 0.0 || clarity > 1.0) {
      throw const McpException.invalidParams(
        'Parameter "clarity" must be between 0.0 and 1.0.',
      );
    }
    if (spectralCentroidHz < 0.0 || !spectralCentroidHz.isFinite) {
      throw const McpException.invalidParams(
        'Parameter "spectralCentroidHz" must be >= 0.',
      );
    }

    final rawOvertones = args['overtoneAmplitudes'];
    if (rawOvertones is! List || rawOvertones.isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "overtoneAmplitudes" must be a non-empty array of numbers.',
      );
    }
    final overtones = <double>[];
    for (final v in rawOvertones) {
      if (v is! num || !v.isFinite || v < 0) {
        throw McpException.invalidParams(
          'Invalid overtone amplitude value: $v',
        );
      }
      overtones.add(v.toDouble());
    }

    final signature = AcousticSignature(
      fundamentalFrequencyHz: fundamentalHz,
      clarity: clarity,
      overtoneAmplitudes: overtones,
      spectralCentroidHz: spectralCentroidHz,
    );

    final candidates = _smartDetector.detectCandidates(
      signature,
      limit: limit.clamp(1, 9),
    );
    final best = _smartDetector.bestMatch(
      signature,
      minimumConfidence: minimumConfidence.clamp(0.0, 1.0),
    );

    return McpToolResult.json({
      'signatureMetrics': {
        'fundamentalFrequencyHz': signature.fundamentalFrequencyHz,
        'clarity': signature.clarity,
        'spectralCentroidHz': signature.spectralCentroidHz,
        'oddHarmonicEnergyFraction': signature.oddHarmonicEnergyFraction,
        'highFrequencyHarmonicRatio': signature.highFrequencyHarmonicRatio,
      },
      'bestMatch': best != null ? _smartMatchToJson(best) : null,
      'candidatesCount': candidates.length,
      'candidates': candidates.map(_smartMatchToJson).toList(growable: false),
    });
  }

  // ===========================================================================
  // Domain Helpers & Serialization
  // ===========================================================================

  UniversalInstrumentDefinition _requireUniversalInstrument(String id) {
    final universal = InstrumentCatalogBridge.findUniversalByAnyId(id);
    if (universal == null) {
      throw McpException.fileNotFound(
        'Universal instrument not found for id "$id".',
      );
    }
    return universal;
  }

  InstrumentCustomizationProfile _buildCustomizationProfile(
    UniversalInstrumentDefinition universal,
    Map<String, dynamic> map,
  ) {
    final referencePitchA4 = _optionalDouble(map, 'referencePitchA4') ?? 440.0;
    _validateReferencePitch(referencePitchA4, 'referencePitchA4');

    final temperamentId = _optionalString(map, 'temperamentId');
    final temperament = temperamentId != null && temperamentId.isNotEmpty
        ? TemperamentEngine.getById(temperamentId)
        : TemperamentEngine.equalTemperament;

    final detuningPresetId = _optionalString(map, 'detuningPresetId');
    PerNoteDetuningProfile detuning = PerNoteDetuningProfile.standard;
    if (detuningPresetId != null && detuningPresetId.isNotEmpty) {
      final matches = PerNoteDetuningProfile.presets
          .where((p) => p.id == detuningPresetId)
          .toList();
      if (matches.isEmpty) {
        throw McpException.invalidParams(
          'Unknown detuningPresetId: "$detuningPresetId".',
        );
      }
      detuning = matches.first;
    }

    final rawNoteCents = map['customNoteCents'];
    if (rawNoteCents is Map) {
      for (final entry in rawNoteCents.entries) {
        final midi = int.tryParse(entry.key.toString());
        final cents = entry.value is num ? (entry.value as num).toDouble() : null;
        if (midi == null || cents == null) {
          throw McpException.invalidParams(
            'Invalid customNoteCents entry: ${entry.key}: ${entry.value}',
          );
        }
        detuning = detuning.withNoteOffset(midi, cents);
      }
    }

    final rawStringCents = map['customStringCents'];
    if (rawStringCents is Map) {
      for (final entry in rawStringCents.entries) {
        final idx = int.tryParse(entry.key.toString());
        final cents = entry.value is num ? (entry.value as num).toDouble() : null;
        if (idx == null || cents == null) {
          throw McpException.invalidParams(
            'Invalid customStringCents entry: ${entry.key}: ${entry.value}',
          );
        }
        detuning = detuning.withStringOffset(idx, cents);
      }
    }

    final attackMultiplier =
        (_optionalDouble(map, 'attackMultiplier') ?? 1.0).clamp(0.1, 5.0);
    final sustainMultiplier =
        (_optionalDouble(map, 'sustainMultiplier') ?? 1.0).clamp(0.2, 2.0);
    final harmonicBrightness =
        (_optionalDouble(map, 'harmonicBrightness') ?? 1.0).clamp(0.2, 2.0);
    final resonanceFactor =
        (_optionalDouble(map, 'resonanceFactor') ??
                universal.timbralProfile.resonanceFactor)
            .clamp(0.0, 1.0);

    return InstrumentCustomizationProfile(
      instrument: universal,
      referencePitchA4: referencePitchA4,
      temperament: temperament,
      detuningProfile: detuning,
      attackMultiplier: attackMultiplier,
      sustainMultiplier: sustainMultiplier,
      harmonicBrightness: harmonicBrightness,
      resonanceFactor: resonanceFactor,
    );
  }

  static Map<String, dynamic> _detuningProfileToJson(
    PerNoteDetuningProfile profile,
  ) {
    return {
      'id': profile.id,
      'name': profile.name,
      'description': profile.description,
      'centsOffsetsByMidiNote': {
        for (final e in profile.centsOffsetsByMidiNote.entries)
          e.key.toString(): e.value,
      },
      'centsOffsetsByStringIndex': {
        for (final e in profile.centsOffsetsByStringIndex.entries)
          e.key.toString(): e.value,
      },
    };
  }

  static Map<String, dynamic> _phraseToJson(MusicalPhraseEntity phrase) {
    return {
      'id': phrase.id,
      'title': phrase.title,
      'description': phrase.description,
      'genreOrTradition': phrase.genreOrTradition,
      'defaultBpm': phrase.defaultBpm,
      'timeSignature': phrase.timeSignature,
      'totalTicks': phrase.totalTicks,
      'notes': phrase.notes
          .map(
            (n) => {
              'midiNote': n.midiNote,
              'durationTicks': n.durationTicks,
              'velocity': n.velocity,
              'isRest': n.isRest,
              if (n.lyricSyllable != null) 'lyricSyllable': n.lyricSyllable,
            },
          )
          .toList(growable: false),
    };
  }

  static Map<String, dynamic> _customizationToJson(
    InstrumentCustomizationProfile c,
  ) {
    return {
      'referencePitchA4': c.referencePitchA4,
      'temperamentId': c.temperament.id,
      'detuningPresetId': c.detuningProfile.id,
      'attackMultiplier': c.attackMultiplier,
      'sustainMultiplier': c.sustainMultiplier,
      'harmonicBrightness': c.harmonicBrightness,
      'resonanceFactor': c.resonanceFactor,
    };
  }

  static Map<String, dynamic> _smartMatchToJson(SmartInstrumentMatch match) {
    return {
      'instrument': InstrumentCatalogBridge.profileToJson(match.instrument),
      'confidence': match.confidence,
      'detectionReason': match.detectionReason,
      'soundFontPatch': match.soundFontPatch,
    };
  }

  static HornbostelSachsCategory _parseCategory(String raw) {
    final norm = raw.trim().toLowerCase();
    for (final cat in HornbostelSachsCategory.values) {
      if (cat.name.toLowerCase() == norm || cat.code.toLowerCase() == norm) {
        return cat;
      }
    }
    throw McpException.invalidParams(
      'Unknown Hornbostel-Sachs category: "$raw".',
    );
  }

  static InstrumentSubfamily _parseSubfamily(String raw) {
    final norm = raw.trim().toLowerCase();
    for (final sub in InstrumentSubfamily.values) {
      if (sub.name.toLowerCase() == norm || sub.code.toLowerCase() == norm) {
        return sub;
      }
    }
    throw McpException.invalidParams(
      'Unknown instrument subfamily: "$raw".',
    );
  }

  static int _frequencyToNearestMidi(double hz) {
    if (hz <= 0) return 0;
    return (69 + 12 * (math.log(hz / 440.0) / math.ln2)).round().clamp(0, 127);
  }

  static String _toHexArgb(int argb) =>
      '0x${argb.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';

  // ===========================================================================
  // Path Sandboxing & Argument Validation
  // ===========================================================================

  File _resolveSandboxedFile(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty || trimmed.contains('\u0000')) {
      throw const McpException.securityViolation('Invalid or empty file path.');
    }

    final rootPath =
        _normalizeAbsolutePath(facade.workspaceDirectory.absolute.path);
    final candidateRaw = _isAbsolutePath(trimmed)
        ? trimmed
        : '$rootPath${Platform.pathSeparator}$trimmed';
    final resolvedPath = _normalizeAbsolutePath(candidateRaw);

    final prefix = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';
    if (resolvedPath != rootPath && !resolvedPath.startsWith(prefix)) {
      throw McpException.securityViolation(
        'Path traversal violation: "$rawPath" escapes workspace directory.',
      );
    }
    return File(resolvedPath);
  }

  static bool _isAbsolutePath(String p) {
    if (p.startsWith('/') || p.startsWith('\\')) return true;
    return p.length >= 2 && p[1] == ':';
  }

  static String _normalizeAbsolutePath(String path) {
    final uri = Uri.file(path, windows: Platform.isWindows).normalizePath();
    var normalized = uri.toFilePath(windows: Platform.isWindows);
    if (normalized.length > 1 && normalized.endsWith(Platform.pathSeparator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static void _validateMidiRange(int midi, String name) {
    if (midi < 0 || midi > 127) {
      throw McpException.invalidParams(
        'Parameter "$name" must be in range 0..127 (got $midi).',
      );
    }
  }

  static void _validateReferencePitch(double a4, String name) {
    if (!a4.isFinite || a4 < 415.0 || a4 > 466.0) {
      throw McpException.invalidParams(
        'Parameter "$name" must be between 415.0 and 466.0 Hz (got $a4).',
      );
    }
  }

  static String _requireString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty) {
      throw McpException.invalidParams(
        'Missing or invalid required string parameter "$key".',
      );
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! String) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a string.',
      );
    }
    return value.trim();
  }

  static int _requireInt(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! num || value % 1 != 0) {
      throw McpException.invalidParams(
        'Missing or invalid required integer parameter "$key".',
      );
    }
    return value.toInt();
  }

  static int? _optionalInt(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! num || value % 1 != 0) {
      throw McpException.invalidParams(
        'Parameter "$key" must be an integer.',
      );
    }
    return value.toInt();
  }

  static double _requireDouble(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! num || !value.isFinite) {
      throw McpException.invalidParams(
        'Missing or invalid required numeric parameter "$key".',
      );
    }
    return value.toDouble();
  }

  static double? _optionalDouble(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! num || !value.isFinite) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a finite number.',
      );
    }
    return value.toDouble();
  }

  static bool? _optionalBool(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! bool) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a boolean.',
      );
    }
    return value;
  }
}
