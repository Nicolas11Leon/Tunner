import 'dart:io';
import 'dart:typed_data';

import '../../core/audio/domain/offline_wav_decoder.dart';
import '../../features/dj_console/domain/dj_audio_processor.dart';
import '../../features/dj_console/domain/dj_channel_fx_entity.dart';
import '../../features/dj_console/domain/dj_crossfader_entity.dart';
import '../../features/dj_console/domain/dj_hardware_catalog.dart';
import '../../features/dj_console/domain/dj_harmonic_camelot_engine.dart';
import '../../features/dj_console/domain/dj_mix_wav_encoder.dart';
import '../../features/dj_console/domain/dj_smart_automix_engine.dart';
import '../../features/dj_console/domain/dj_stem_isolation_entity.dart';
import '../../features/mixer/domain/mixer_track_entity.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing the Virtual DJ Console (Decks A/B, BPM/Camelot
/// harmonic engine, crossfader, EQ, FX, 4-Stems, loops, offline Automix WAV
/// rendering) and the Multi-Track Stereo Stem Mixer (`MixerAudioRenderer`).
class DjMixerMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  MixerConsoleEntity _mixerConsole;

  DjMixerMcpModule(
    this.facade, {
    MixerConsoleEntity? initialMixerConsole,
  }) : _mixerConsole = initialMixerConsole ?? MixerConsoleEntity.defaultSetup();

  @override
  String get moduleName => 'dj_mixer';

  /// Current immutable snapshot of the headless stem mixer console.
  MixerConsoleEntity get mixerConsole => _mixerConsole;

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
        uri: 'tunner://dj/state',
        name: 'DJ Console Live Headless State',
        description:
            'Complete state of Decks A and B, crossfader, EQ, FX, 4-Stems, loops, hot cues, Camelot compatibility, and Smart Automix.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://dj/state',
            data: facade.djController.toJson(),
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://dj/camelot-wheel',
        name: 'Camelot Harmonic Wheel Table',
        description:
            'Canonical 24-key Camelot Wheel (1A-12B) and harmonic compatibility classifications.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://dj/camelot-wheel',
            data: {
              'keys': DjHarmonicCamelotEngine.wheel
                  .map((k) => k.toJson())
                  .toList(growable: false),
              'compatibilityRules': CamelotCompatibility.values
                  .map(
                    (c) => {
                      'id': c.name,
                      'label': c.label,
                    },
                  )
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://dj/hardware-skins',
        name: 'DJ Hardware Controller Skins Catalog',
        description:
            'Catalog of built-in and custom vector DJ hardware controller skins.',
        mimeType: 'application/json',
        reader: () async {
          final skins = DjHardwareCatalog.allSkins();
          return McpResourceContent.json(
            uri: 'tunner://dj/hardware-skins',
            data: {
              'count': skins.length,
              'skins': skins
                  .map(
                    (s) => {
                      'id': s.id,
                      'name': s.name,
                      'manufacturer': s.manufacturer,
                      'aspectRatio': s.aspectRatio,
                      'zonesCount': s.zones.length,
                    },
                  )
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://mixer/state',
        name: 'Multi-Track Stem Mixer State',
        description:
            'Current state of the multi-track stem mixer including volume, stereo pan, mute, solo, and effective linear gain per track.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://mixer/state',
            data: _mixerStateToJson(_mixerConsole),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (10)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dj_analyze_track',
        description:
            'Statelessly decodes a local WAV file inside the workspace and estimates BPM, multi-window Camelot key, duration, and RGB spectral waveform summary.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'file_path': {
              'type': 'string',
              'description': 'Workspace-relative or sandboxed path to a WAV file.',
            },
            'deck_id': {
              'type': 'string',
              'enum': ['A', 'B'],
              'description': 'Optional deck label for the analysis summary (does not mutate deck state).',
            },
            'waveform_buckets': {
              'type': 'integer',
              'minimum': 8,
              'maximum': 512,
              'description': 'Number of RGB spectral summary buckets (default 64).',
            },
          },
          'required': ['file_path'],
        },
        handler: _handleAnalyzeTrack,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dj_check_harmonic_compatibility',
        description:
            'Evaluates Camelot Wheel harmonic compatibility between two keys and computes the optimal semitone shift.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'source_key': {
              'type': 'string',
              'description': 'Source Camelot key code (1A..12B).',
            },
            'target_key': {
              'type': 'string',
              'description': 'Target Camelot key code (1A..12B).',
            },
          },
          'required': ['source_key', 'target_key'],
        },
        handler: _handleCheckHarmonicCompatibility,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dj_load_deck',
        description:
            'Loads a WAV file from the workspace into Deck A or Deck B with optional automatic BPM and Camelot key analysis.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'deck_id': {
              'type': 'string',
              'enum': ['A', 'B'],
            },
            'file_path': {
              'type': 'string',
              'description': 'Workspace-relative or sandboxed path to a WAV file.',
            },
            'title': {'type': 'string'},
            'artist': {'type': 'string'},
            'auto_analyze': {
              'type': 'boolean',
              'description': 'Run BPM and Camelot analysis on load (default true).',
            },
          },
          'required': ['deck_id', 'file_path'],
        },
        handler: _handleLoadDeck,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dj_configure_deck_dsp',
        description:
            'Configures volume, trim, 3-band EQ, EQ kills, bipolar filter, beat-synced delay, and 4-stem isolation presets for Deck A or Deck B.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'deck_id': {
              'type': 'string',
              'enum': ['A', 'B'],
            },
            'volume': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'trim': {'type': 'number', 'minimum': 0.0, 'maximum': 2.0},
            'eq_low': {'type': 'number', 'minimum': 0.0, 'maximum': 1.5},
            'eq_mid': {'type': 'number', 'minimum': 0.0, 'maximum': 1.5},
            'eq_high': {'type': 'number', 'minimum': 0.0, 'maximum': 1.5},
            'toggle_kill_band': {
              'type': 'string',
              'enum': ['low', 'mid', 'high'],
            },
            'filter': {'type': 'number', 'minimum': -1.0, 'maximum': 1.0},
            'delay_active': {'type': 'boolean'},
            'delay_division': {
              'type': 'string',
              'enum': ['halfBeat', 'quarterBeat', 'eighthBeat', 'sixteenthBeat'],
            },
            'delay_feedback': {'type': 'number', 'minimum': 0.0, 'maximum': 0.8},
            'delay_dry_wet': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'stem_preset': {
              'type': 'string',
              'enum': ['acapella', 'instrumental', 'rhythm', 'reset'],
            },
          },
          'required': ['deck_id'],
        },
        handler: _handleConfigureDeckDsp,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dj_control_mixer_and_loops',
        description:
            'Controls DJ crossfader position/curve, master volume, quantized auto-loops, beat jumps, slip mode, and hot cues.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'crossfader_position': {
              'type': 'number',
              'minimum': -1.0,
              'maximum': 1.0,
            },
            'crossfader_curve': {
              'type': 'string',
              'enum': ['linear', 'equalPower', 'constantPower', 'fastCut', 'sharpCut'],
            },
            'master_volume': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'deck_id': {
              'type': 'string',
              'enum': ['A', 'B'],
            },
            'loop_action': {
              'type': 'string',
              'enum': ['engage', 'toggle', 'exit', 'halve', 'double'],
            },
            'loop_beats': {'type': 'number', 'minimum': 0.125, 'maximum': 32.0},
            'beat_jump': {'type': 'number'},
            'toggle_slip_mode': {'type': 'boolean'},
            'hot_cue_trigger': {'type': 'integer', 'minimum': 1, 'maximum': 4},
            'hot_cue_clear': {'type': 'integer', 'minimum': 1, 'maximum': 4},
          },
        },
        handler: _handleControlMixerAndLoops,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dj_sync_decks',
        description:
            'Synchronizes target deck BPM and/or Camelot musical key to the opposite deck.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'target_deck_id': {
              'type': 'string',
              'enum': ['A', 'B'],
            },
            'sync_bpm': {'type': 'boolean'},
            'sync_key': {'type': 'boolean'},
          },
          'required': ['target_deck_id'],
        },
        handler: _handleSyncDecks,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dj_render_transition_wav',
        description:
            'Renders an offline Smart Automix transition between Deck A and Deck B (with optional Bass-Swap EQ automation) to a stereo 16-bit PCM WAV file inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'deck_a_path': {
              'type': 'string',
              'description': 'Optional WAV file path for Deck A; uses currently loaded Deck A buffer if omitted.',
            },
            'deck_b_path': {
              'type': 'string',
              'description': 'Optional WAV file path for Deck B; uses currently loaded Deck B buffer if omitted.',
            },
            'output_path': {
              'type': 'string',
              'description': 'Destination WAV file path inside the workspace.',
            },
            'direction': {
              'type': 'string',
              'enum': ['deckAToDeckB', 'deckBToDeckA'],
            },
            'duration_bars': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 64,
            },
            'enable_bass_swap': {'type': 'boolean'},
            'crossfader_curve': {
              'type': 'string',
              'enum': ['linear', 'equalPower', 'constantPower', 'fastCut', 'sharpCut'],
            },
            'reference_bpm': {'type': 'number', 'minimum': 40.0, 'maximum': 240.0},
            'sample_rate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
          },
          'required': ['output_path'],
        },
        handler: _handleRenderTransitionWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dj_extract_stem_wav',
        description:
            'Applies 4-stem isolation (acapella, instrumental, rhythm, or custom gains) to an input WAV file and writes the processed WAV inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'input_path': {'type': 'string'},
            'output_path': {'type': 'string'},
            'preset': {
              'type': 'string',
              'enum': ['acapella', 'instrumental', 'rhythm', 'custom'],
            },
            'gains': {
              'type': 'object',
              'properties': {
                'vocals': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
                'drums': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
                'bass': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
                'melody': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
              },
            },
          },
          'required': ['input_path', 'output_path', 'preset'],
        },
        handler: _handleExtractStemWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_mixer_configure_track',
        description:
            'Configures volume, stereo pan, mute, and solo flags for a track in the multi-track stem mixer.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'track_id': {'type': 'string'},
            'title': {'type': 'string'},
            'volume': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'pan': {'type': 'number', 'minimum': -1.0, 'maximum': 1.0},
            'is_muted': {'type': 'boolean'},
            'is_solo': {'type': 'boolean'},
            'add_if_missing': {'type': 'boolean'},
          },
          'required': ['track_id'],
        },
        handler: _handleMixerConfigureTrack,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_mixer_render_stems_wav',
        description:
            'Renders a stereo 16-bit PCM WAV mixdown from multiple WAV stem files using constant-power panning, mute/solo logic, and soft-knee master limiting.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'stems': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'track_id': {'type': 'string'},
                  'file_path': {'type': 'string'},
                  'title': {'type': 'string'},
                  'volume': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
                  'pan': {'type': 'number', 'minimum': -1.0, 'maximum': 1.0},
                  'is_muted': {'type': 'boolean'},
                  'is_solo': {'type': 'boolean'},
                },
                'required': ['track_id', 'file_path'],
              },
            },
            'output_path': {'type': 'string'},
            'sample_rate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
            'master_gain': {'type': 'number', 'minimum': 0.0, 'maximum': 2.0},
          },
          'required': ['stems', 'output_path'],
        },
        handler: _handleMixerRenderStemsWav,
      ),
    );
  }

  // ===========================================================================
  // Prompts (3)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'dj_harmonic_setlist_planner',
        description:
            'Analyzes a list of WAV tracks and orders them by optimal Camelot Wheel harmonic progression and smooth BPM transitions.',
        arguments: const [
          McpPromptArgument(
            name: 'track_paths',
            description: 'Comma-separated workspace WAV file paths to analyze.',
            required: true,
          ),
          McpPromptArgument(
            name: 'target_bpm',
            description: 'Optional target starting BPM for the setlist.',
          ),
        ],
        builder: (args) async {
          final trackPaths = args['track_paths']!;
          final targetBpm = args['target_bpm'];
          final bpmClause = targetBpm != null && targetBpm.trim().isNotEmpty
              ? ' Anchor the setlist opening near $targetBpm BPM.'
              : '';
          return McpPromptResult(
            description: 'Guided workflow for harmonic DJ setlist planning.',
            messages: [
              McpPromptMessage.user(
                'Plan an optimal harmonic DJ setlist for the following workspace WAV tracks: $trackPaths.$bpmClause '
                'Step 1: Read tunner://dj/camelot-wheel. '
                'Step 2: Call tunner_dj_analyze_track for each file to obtain BPM and Camelot key. '
                'Step 3: Use tunner_dj_check_harmonic_compatibility to order transitions favoring perfectUnison, harmonicStep, relativeSwitch, or energyBoost while keeping BPM jumps within +/-6%. '
                'Step 4: Return the ordered setlist table with transition notes.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'dj_auto_mashup_builder',
        description:
            'Loads an instrumental on Deck A and a vocal track on Deck B, synchronizes BPM and key, isolates acapella stems, and renders a Bass-Swap mashup WAV.',
        arguments: const [
          McpPromptArgument(
            name: 'instrumental_path',
            description: 'Workspace WAV path for the instrumental backing track (Deck A).',
            required: true,
          ),
          McpPromptArgument(
            name: 'vocal_path',
            description: 'Workspace WAV path for the vocal track (Deck B).',
            required: true,
          ),
          McpPromptArgument(
            name: 'output_path',
            description: 'Optional output WAV path inside workspace (default mashup_output.wav).',
          ),
        ],
        builder: (args) async {
          final instPath = args['instrumental_path']!;
          final vocalPath = args['vocal_path']!;
          final outPath = (args['output_path']?.trim().isNotEmpty ?? false)
              ? args['output_path']!.trim()
              : 'mashup_output.wav';
          return McpPromptResult(
            description: 'Guided workflow for automated harmonic DJ mashup creation.',
            messages: [
              McpPromptMessage.user(
                'Build a harmonic mashup combining instrumental "$instPath" and vocal "$vocalPath". '
                'Step 1: Load Deck A with tunner_dj_load_deck (file_path="$instPath") and Deck B with tunner_dj_load_deck (file_path="$vocalPath"). '
                'Step 2: Call tunner_dj_sync_decks on Deck B with sync_bpm=true and sync_key=true. '
                'Step 3: Call tunner_dj_configure_deck_dsp on Deck B with stem_preset="acapella". '
                'Step 4: Render the transition using tunner_dj_render_transition_wav to output_path="$outPath" with enable_bass_swap=true and report the resulting WAV telemetry.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'stem_mixdown_engineer',
        description:
            'Inspects the stem mixer state, configures gain, stereo panning, mute/solo for balanced or Minus-One mixes, and renders the stereo WAV mixdown.',
        arguments: const [
          McpPromptArgument(
            name: 'mix_goal',
            description: 'Mixing objective (e.g., "Minus-One vocal backing track" or "wide stereo balance").',
            required: true,
          ),
          McpPromptArgument(
            name: 'output_path',
            description: 'Optional destination WAV path inside workspace.',
          ),
        ],
        builder: (args) async {
          final goal = args['mix_goal']!;
          final outPath = (args['output_path']?.trim().isNotEmpty ?? false)
              ? args['output_path']!.trim()
              : 'stem_mixdown.wav';
          return McpPromptResult(
            description: 'Guided workflow for multi-track stem mixdown engineering.',
            messages: [
              McpPromptMessage.user(
                'Act as a mixing engineer to achieve: $goal. '
                'Step 1: Read tunner://mixer/state to inspect current stems, gains, pan, mute, and solo flags. '
                'Step 2: Adjust channel parameters using tunner_mixer_configure_track. '
                'Step 3: Render the final stereo mixdown to "$outPath" using tunner_mixer_render_stems_wav and verify peakDbfs headroom.',
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

  Future<McpToolResult> _handleAnalyzeTrack(Map<String, dynamic> args) async {
    final rawPath = _requireNonEmptyString(args, 'file_path');
    final deckId = _optionalDeckId(args, 'deck_id') ?? 'A';
    final buckets = _optionalInt(args, 'waveform_buckets')?.clamp(8, 512) ?? 64;

    final resolvedPath = _resolveWorkspacePath(rawPath);
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      throw McpException.fileNotFound('WAV file not found: $rawPath');
    }

    try {
      final bytes = file.readAsBytesSync();
      final result = facade.djController.analyzeWavBytes(
        bytes,
        deckId: deckId,
        title: _extractBaseName(resolvedPath),
        waveformBuckets: buckets,
      );
      return McpToolResult.json(result.toJson());
    } on FormatException catch (e) {
      throw McpException.acousticError('Invalid WAV format: ${e.message}');
    }
  }

  Future<McpToolResult> _handleCheckHarmonicCompatibility(
    Map<String, dynamic> args,
  ) async {
    final sourceKeyRaw = _requireNonEmptyString(args, 'source_key');
    final targetKeyRaw = _requireNonEmptyString(args, 'target_key');

    final sourceKey = DjHarmonicCamelotEngine.findByCode(sourceKeyRaw);
    final targetKey = DjHarmonicCamelotEngine.findByCode(targetKeyRaw);
    final compatibility = DjHarmonicCamelotEngine.analyzeCompatibility(
      sourceKey.code,
      targetKey.code,
    );
    final optimalShift = DjHarmonicCamelotEngine.calculateOptimalSemitoneShift(
      sourceKey.code,
      targetKey.code,
    );
    final transposed = DjHarmonicCamelotEngine.transpose(
      sourceKey.code,
      optimalShift,
    );

    return McpToolResult.json({
      'sourceKey': sourceKey.code,
      'sourceMusicalName': sourceKey.musicalName,
      'targetKey': targetKey.code,
      'targetMusicalName': targetKey.musicalName,
      'compatibilityCode': compatibility.name,
      'compatibility': compatibility.label,
      'optimalSemitoneShift': optimalShift,
      'transposedKey': transposed.code,
      'transposedMusicalName': transposed.musicalName,
    });
  }

  Future<McpToolResult> _handleLoadDeck(Map<String, dynamic> args) async {
    final deckId = _requireDeckId(args, 'deck_id');
    final rawPath = _requireNonEmptyString(args, 'file_path');
    final title = _optionalString(args, 'title');
    final artist = _optionalString(args, 'artist');
    final autoAnalyze = _optionalBool(args, 'auto_analyze') ?? true;

    final resolvedPath = _resolveWorkspacePath(rawPath);
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      throw McpException.fileNotFound('WAV file not found: $rawPath');
    }

    try {
      final derivedTitle =
          title ?? resolvedPath.split(Platform.pathSeparator).last;
      final result = facade.djController.loadWavBytes(
        deckId,
        file.readAsBytesSync(),
        title: derivedTitle,
        artist: artist ?? 'Local File',
        audioPath: resolvedPath,
        autoAnalyze: autoAnalyze,
      );
      facade.emitIpcEvent('dj.deck.loaded', result.toJson());
      return McpToolResult.json(result.toJson());
    } on FormatException catch (e) {
      throw McpException.acousticError('Failed to decode WAV file: ${e.message}');
    }
  }

  Future<McpToolResult> _handleConfigureDeckDsp(
    Map<String, dynamic> args,
  ) async {
    final deckId = _requireDeckId(args, 'deck_id');
    final ctrl = facade.djController;

    final volume = _optionalDouble(args, 'volume');
    if (volume != null) ctrl.setDeckVolume(deckId, volume);

    final trim = _optionalDouble(args, 'trim');
    if (trim != null) ctrl.setTrim(deckId, trim);

    final eqLow = _optionalDouble(args, 'eq_low');
    final eqMid = _optionalDouble(args, 'eq_mid');
    final eqHigh = _optionalDouble(args, 'eq_high');
    if (eqLow != null || eqMid != null || eqHigh != null) {
      ctrl.setEqGains(deckId, low: eqLow, mid: eqMid, high: eqHigh);
    }

    final toggleKillBand = _optionalString(args, 'toggle_kill_band');
    if (toggleKillBand != null) {
      ctrl.toggleEqKill(deckId, toggleKillBand.toLowerCase());
    }

    final filter = _optionalDouble(args, 'filter');
    if (filter != null) ctrl.setChannelFilter(deckId, filter);

    final delayActive = _optionalBool(args, 'delay_active');
    if (delayActive != null) {
      final currentFx = deckId == 'A' ? ctrl.fxA : ctrl.fxB;
      if (currentFx.isDelayActive != delayActive) {
        ctrl.toggleChannelDelay(deckId);
      }
    }

    final delayDivRaw = _optionalString(args, 'delay_division');
    if (delayDivRaw != null) {
      ctrl.setChannelDelayDivision(deckId, _parseDelayDivision(delayDivRaw));
    }

    final delayFeedback = _optionalDouble(args, 'delay_feedback');
    final delayDryWet = _optionalDouble(args, 'delay_dry_wet');
    if (delayFeedback != null || delayDryWet != null) {
      ctrl.setChannelDelayParams(
        deckId,
        feedback: delayFeedback,
        dryWet: delayDryWet,
      );
    }

    final stemPreset = _optionalString(args, 'stem_preset');
    if (stemPreset != null) {
      ctrl.applyStemPreset(deckId, stemPreset.toLowerCase());
    }

    final snapshot = ctrl.toJson();
    final deckSnapshot =
        (deckId == 'A' ? snapshot['deckA'] : snapshot['deckB'])
            as Map<String, dynamic>;
    return McpToolResult.json(deckSnapshot);
  }

  Future<McpToolResult> _handleControlMixerAndLoops(
    Map<String, dynamic> args,
  ) async {
    final ctrl = facade.djController;

    final xfPos = _optionalDouble(args, 'crossfader_position');
    if (xfPos != null) ctrl.setCrossfaderPosition(xfPos);

    final xfCurveRaw = _optionalString(args, 'crossfader_curve');
    if (xfCurveRaw != null) {
      ctrl.setCrossfaderCurve(_parseCrossfaderCurve(xfCurveRaw));
    }

    final masterVol = _optionalDouble(args, 'master_volume');
    if (masterVol != null) ctrl.setMasterVolume(masterVol);

    final deckId = _optionalDeckId(args, 'deck_id');
    final loopAction = _optionalString(args, 'loop_action');
    final beatJump = _optionalDouble(args, 'beat_jump');
    final toggleSlip = _optionalBool(args, 'toggle_slip_mode') ?? false;
    final hotCueTrigger = _optionalInt(args, 'hot_cue_trigger');
    final hotCueClear = _optionalInt(args, 'hot_cue_clear');

    if (loopAction != null ||
        beatJump != null ||
        toggleSlip ||
        hotCueTrigger != null ||
        hotCueClear != null) {
      if (deckId == null) {
        throw const McpException.invalidParams(
          'Parameter "deck_id" is required when performing loop, beat jump, slip mode, or hot cue actions.',
        );
      }
      if (loopAction != null) {
        switch (loopAction.toLowerCase()) {
          case 'engage':
            final beats = _optionalDouble(args, 'loop_beats') ?? 4.0;
            ctrl.engageAutoLoop(deckId, beats);
          case 'toggle':
            ctrl.toggleLoop(deckId);
          case 'exit':
            ctrl.exitLoop(deckId);
          case 'halve':
            ctrl.halveLoop(deckId);
          case 'double':
            ctrl.doubleLoop(deckId);
          default:
            throw McpException.invalidParams(
              'Invalid loop_action "$loopAction". Expected engage, toggle, exit, halve, or double.',
            );
        }
      }
      if (beatJump != null) ctrl.beatJump(deckId, beatJump);
      if (toggleSlip) ctrl.toggleSlipMode(deckId);
      if (hotCueTrigger != null) ctrl.triggerHotCue(deckId, hotCueTrigger);
      if (hotCueClear != null) ctrl.clearHotCue(deckId, hotCueClear);
    }

    return McpToolResult.json(ctrl.toJson());
  }

  Future<McpToolResult> _handleSyncDecks(Map<String, dynamic> args) async {
    final targetDeckId = _requireDeckId(args, 'target_deck_id');
    final syncBpm = _optionalBool(args, 'sync_bpm') ?? true;
    final syncKey = _optionalBool(args, 'sync_key') ?? true;

    final ctrl = facade.djController;
    if (syncBpm) ctrl.syncBpm(targetDeckId);
    if (syncKey) ctrl.syncKey(targetDeckId);

    final deck = targetDeckId == 'A' ? ctrl.deckA : ctrl.deckB;
    return McpToolResult.json({
      'targetDeckId': targetDeckId,
      'effectiveBpm': deck.effectiveBpm,
      'effectiveCamelotKey': deck.effectiveCamelotKey.code,
      'pitchSemitonesShift': deck.pitchSemitonesShift,
      'harmonicCompatibility': ctrl.harmonicCompatibility.label,
    });
  }

  Future<McpToolResult> _handleRenderTransitionWav(
    Map<String, dynamic> args,
  ) async {
    final rawOutputPath = _requireNonEmptyString(args, 'output_path');
    final outputPath = _resolveWorkspacePath(rawOutputPath);

    Uint8List? deckABytes;
    final rawDeckAPath = _optionalString(args, 'deck_a_path');
    if (rawDeckAPath != null) {
      final pathA = _resolveWorkspacePath(rawDeckAPath);
      final fileA = File(pathA);
      if (!fileA.existsSync()) {
        throw McpException.fileNotFound('Deck A WAV file not found: $rawDeckAPath');
      }
      deckABytes = fileA.readAsBytesSync();
    }

    Uint8List? deckBBytes;
    final rawDeckBPath = _optionalString(args, 'deck_b_path');
    if (rawDeckBPath != null) {
      final pathB = _resolveWorkspacePath(rawDeckBPath);
      final fileB = File(pathB);
      if (!fileB.existsSync()) {
        throw McpException.fileNotFound('Deck B WAV file not found: $rawDeckBPath');
      }
      deckBBytes = fileB.readAsBytesSync();
    }

    final directionRaw = _optionalString(args, 'direction') ?? 'deckAToDeckB';
    final direction = _parseAutomixDirection(directionRaw);
    final durationBars = _optionalInt(args, 'duration_bars') ?? 8;
    final enableBassSwap = _optionalBool(args, 'enable_bass_swap') ?? true;
    final curveRaw = _optionalString(args, 'crossfader_curve');
    final curve = curveRaw != null ? _parseCrossfaderCurve(curveRaw) : null;
    final referenceBpm = _optionalDouble(args, 'reference_bpm');
    final sampleRate = _optionalInt(args, 'sample_rate') ?? 44100;

    try {
      final result = facade.djController.renderAutomixTransition(
        direction: direction,
        durationBars: durationBars,
        enableBassSwap: enableBassSwap,
        crossfaderCurve: curve,
        referenceBpm: referenceBpm,
        sampleRate: sampleRate,
        deckAWavBytes: deckABytes,
        deckBWavBytes: deckBBytes,
      );

      final outFile = File(outputPath);
      if (!outFile.parent.existsSync()) {
        outFile.parent.createSync(recursive: true);
      }
      outFile.writeAsBytesSync(result.wavBytes, flush: true);

      return McpToolResult.json({
        'outputPath': outputPath,
        ...result.toJson(),
      });
    } on StateError catch (e) {
      throw McpException.acousticError(e.message);
    } on FormatException catch (e) {
      throw McpException.acousticError('Invalid WAV input: ${e.message}');
    }
  }

  Future<McpToolResult> _handleExtractStemWav(Map<String, dynamic> args) async {
    final rawInputPath = _requireNonEmptyString(args, 'input_path');
    final rawOutputPath = _requireNonEmptyString(args, 'output_path');
    final preset = _requireNonEmptyString(args, 'preset').toLowerCase();

    final inputPath = _resolveWorkspacePath(rawInputPath);
    final outputPath = _resolveWorkspacePath(rawOutputPath);

    final inFile = File(inputPath);
    if (!inFile.existsSync()) {
      throw McpException.fileNotFound('Input WAV file not found: $rawInputPath');
    }

    DjStemIsolationEntity stems;
    switch (preset) {
      case 'acapella':
        stems = const DjStemIsolationEntity().isolateAcapella();
      case 'instrumental':
        stems = const DjStemIsolationEntity().isolateInstrumental();
      case 'rhythm':
        stems = const DjStemIsolationEntity().isolateRhythm();
      case 'custom':
        final gainsMap = args['gains'];
        if (gainsMap is! Map<String, dynamic>) {
          throw const McpException.invalidParams(
            'Parameter "gains" object is required when preset is "custom".',
          );
        }
        stems = DjStemIsolationEntity(
          vocalGain: (_optionalDouble(gainsMap, 'vocals') ?? 1.0).clamp(0.0, 1.0),
          drumsGain: (_optionalDouble(gainsMap, 'drums') ?? 1.0).clamp(0.0, 1.0),
          bassGain: (_optionalDouble(gainsMap, 'bass') ?? 1.0).clamp(0.0, 1.0),
          melodyGain: (_optionalDouble(gainsMap, 'melody') ?? 1.0).clamp(0.0, 1.0),
        );
      default:
        throw McpException.invalidParams(
          'Invalid stem preset "$preset". Expected acapella, instrumental, rhythm, or custom.',
        );
    }

    try {
      final decoded = OfflineWavDecoder.decode(inFile.readAsBytesSync());
      final float32 = Float32List(decoded.samples.length);
      for (int i = 0; i < decoded.samples.length; i++) {
        float32[i] = decoded.samples[i];
      }

      final processor = DjAudioProcessor(sampleRate: decoded.sampleRate);
      final isolated = processor.applyStemIsolation(float32, stems);
      final wavBytes = DjMixWavEncoder.encode(
        samples: isolated,
        sampleRate: decoded.sampleRate,
        numChannels: 1,
      );

      final outFile = File(outputPath);
      if (!outFile.parent.existsSync()) {
        outFile.parent.createSync(recursive: true);
      }
      outFile.writeAsBytesSync(wavBytes, flush: true);

      return McpToolResult.json({
        'outputPath': outputPath,
        'preset': preset,
        'sampleRate': decoded.sampleRate,
        'durationMs': (decoded.durationSeconds * 1000.0).round(),
        'bytesWritten': wavBytes.length,
      });
    } on FormatException catch (e) {
      throw McpException.acousticError('Failed to decode WAV input: ${e.message}');
    }
  }

  Future<McpToolResult> _handleMixerConfigureTrack(
    Map<String, dynamic> args,
  ) async {
    final trackId = _requireNonEmptyString(args, 'track_id');
    final title = _optionalString(args, 'title');
    final volume = _optionalDouble(args, 'volume');
    final pan = _optionalDouble(args, 'pan');
    final isMuted = _optionalBool(args, 'is_muted');
    final isSolo = _optionalBool(args, 'is_solo');
    final addIfMissing = _optionalBool(args, 'add_if_missing') ?? false;

    final exists = trackId == _mixerConsole.metronomeTrack.id ||
        _mixerConsole.stems.any((t) => t.id == trackId);

    if (!exists) {
      if (!addIfMissing) {
        throw McpException.invalidParams(
          'Mixer track not found: "$trackId". Set add_if_missing=true to create it.',
        );
      }
      _mixerConsole = _mixerConsole.addStem(
        AudioTrack(
          id: trackId,
          title: title ?? trackId,
          instrumentIcon: 'music_note',
          volume: (volume ?? 0.8).clamp(0.0, 1.0),
          pan: (pan ?? 0.0).clamp(-1.0, 1.0),
          isMuted: isMuted ?? false,
          isSolo: isSolo ?? false,
        ),
      );
    } else {
      if (volume != null) {
        _mixerConsole = _mixerConsole.copyWithTrackVolume(trackId, volume);
      }
      if (pan != null) {
        _mixerConsole = _mixerConsole.copyWithTrackPan(trackId, pan);
      }
      if (isMuted != null) {
        _mixerConsole = _mixerConsole.setTrackMute(trackId, isMuted);
      }
      if (isSolo != null) {
        _mixerConsole = _mixerConsole.setTrackSolo(trackId, isSolo);
      }
    }

    return McpToolResult.json(_mixerStateToJson(_mixerConsole));
  }

  Future<McpToolResult> _handleMixerRenderStemsWav(
    Map<String, dynamic> args,
  ) async {
    final rawStems = args['stems'];
    if (rawStems is! List || rawStems.isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "stems" must be a non-empty array of stem definitions.',
      );
    }

    final rawOutputPath = _requireNonEmptyString(args, 'output_path');
    final outputPath = _resolveWorkspacePath(rawOutputPath);
    final sampleRate = _optionalInt(args, 'sample_rate') ?? 44100;
    final masterGain = _optionalDouble(args, 'master_gain') ?? 1.0;

    final trackWavBytes = <String, Uint8List>{};
    var renderConsole = _mixerConsole;

    for (final entry in rawStems) {
      if (entry is! Map<String, dynamic>) {
        throw const McpException.invalidParams(
          'Each item in "stems" must be a JSON object.',
        );
      }
      final trackId = _requireNonEmptyString(entry, 'track_id');
      final rawFilePath = _requireNonEmptyString(entry, 'file_path');
      final resolvedPath = _resolveWorkspacePath(rawFilePath);

      final file = File(resolvedPath);
      if (!file.existsSync()) {
        throw McpException.fileNotFound('Stem WAV file not found: $rawFilePath');
      }
      trackWavBytes[trackId] = file.readAsBytesSync();

      final title = _optionalString(entry, 'title') ?? trackId;
      final volume = _optionalDouble(entry, 'volume');
      final pan = _optionalDouble(entry, 'pan');
      final isMuted = _optionalBool(entry, 'is_muted');
      final isSolo = _optionalBool(entry, 'is_solo');

      final exists = trackId == renderConsole.metronomeTrack.id ||
          renderConsole.stems.any((t) => t.id == trackId);
      if (!exists) {
        renderConsole = renderConsole.addStem(
          AudioTrack(
            id: trackId,
            title: title,
            instrumentIcon: 'music_note',
            volume: (volume ?? 0.8).clamp(0.0, 1.0),
            pan: (pan ?? 0.0).clamp(-1.0, 1.0),
            isMuted: isMuted ?? false,
            isSolo: isSolo ?? false,
          ),
        );
      } else {
        if (volume != null) {
          renderConsole = renderConsole.copyWithTrackVolume(trackId, volume);
        }
        if (pan != null) {
          renderConsole = renderConsole.copyWithTrackPan(trackId, pan);
        }
        if (isMuted != null) {
          renderConsole = renderConsole.setTrackMute(trackId, isMuted);
        }
        if (isSolo != null) {
          renderConsole = renderConsole.setTrackSolo(trackId, isSolo);
        }
      }
    }

    try {
      final result = facade.mixerAudioRenderer.renderWavTracks(
        console: renderConsole,
        trackWavBytes: trackWavBytes,
        sampleRate: sampleRate,
        masterGain: masterGain,
      );
      _mixerConsole = renderConsole;

      final outFile = File(outputPath);
      if (!outFile.parent.existsSync()) {
        outFile.parent.createSync(recursive: true);
      }
      outFile.writeAsBytesSync(result.wavBytes, flush: true);

      return McpToolResult.json({
        'outputPath': outputPath,
        ...result.toJson(),
      });
    } on FormatException catch (e) {
      throw McpException.acousticError('Invalid stem WAV format: ${e.message}');
    }
  }

  // ===========================================================================
  // Helpers & Sandbox Security
  // ===========================================================================

  Map<String, dynamic> _mixerStateToJson(MixerConsoleEntity console) {
    final hasAnySolo = console.hasAnySolo;
    Map<String, dynamic> trackJson(AudioTrack t) => {
          ...t.toMap(),
          'effectiveGain': t.getEffectiveGain(hasAnySolo: hasAnySolo),
        };
    return {
      'hasAnySolo': hasAnySolo,
      'metronomeTrack': trackJson(console.metronomeTrack),
      'stems': console.stems.map(trackJson).toList(growable: false),
    };
  }

  String _resolveWorkspacePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      throw const McpException.invalidParams('Path must not be empty.');
    }
    if (trimmed.contains('\x00')) {
      throw McpException.securityViolation(
        'Null byte rejected in path: $rawPath',
      );
    }

    final normalized = trimmed.replaceAll('\\', '/');
    for (final segment in normalized.split('/')) {
      if (segment == '..') {
        throw McpException.securityViolation(
          'Path traversal sequence rejected: $rawPath',
        );
      }
    }

    final rootDir = facade.workspaceDirectory;
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final canonicalRoot = rootDir.resolveSymbolicLinksSync();

    final bool isAbsolute =
        normalized.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(normalized);
    final String candidatePath = isAbsolute
        ? trimmed
        : '$canonicalRoot${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';

    var probe = Directory(candidatePath);
    final trailing = <String>[];
    while (!probe.existsSync() && probe.parent.path != probe.path) {
      trailing.add(probe.path.split(Platform.pathSeparator).last);
      probe = probe.parent;
    }
    final canonicalBase = probe.existsSync()
        ? probe.resolveSymbolicLinksSync()
        : probe.absolute.path;
    final canonicalTarget = trailing.isEmpty
        ? canonicalBase
        : '$canonicalBase${Platform.pathSeparator}${trailing.reversed.join(Platform.pathSeparator)}';

    final rootPrefix = canonicalRoot.endsWith(Platform.pathSeparator)
        ? canonicalRoot
        : '$canonicalRoot${Platform.pathSeparator}';
    if (!canonicalTarget.startsWith(rootPrefix)) {
      throw McpException.securityViolation(
        'Resolved path escapes workspace sandbox: $rawPath',
      );
    }
    return canonicalTarget;
  }

  static CrossfaderCurve _parseCrossfaderCurve(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'linear':
        return CrossfaderCurve.linear;
      case 'equalpower':
      case 'constantpower':
        return CrossfaderCurve.equalPower;
      case 'fastcut':
      case 'sharpcut':
        return CrossfaderCurve.fastCut;
      default:
        throw McpException.invalidParams(
          'Invalid crossfader_curve "$raw". Expected linear, equalPower, constantPower, fastCut, or sharpCut.',
        );
    }
  }

  static AutomixDirection _parseAutomixDirection(String raw) {
    switch (raw.trim()) {
      case 'deckAToDeckB':
        return AutomixDirection.deckAToDeckB;
      case 'deckBToDeckA':
        return AutomixDirection.deckBToDeckA;
      default:
        throw McpException.invalidParams(
          'Invalid direction "$raw". Expected deckAToDeckB or deckBToDeckA.',
        );
    }
  }

  static DjDelayDivision _parseDelayDivision(String raw) {
    for (final value in DjDelayDivision.values) {
      if (value.name.toLowerCase() == raw.trim().toLowerCase() ||
          value.label == raw.trim()) {
        return value;
      }
    }
    throw McpException.invalidParams(
      'Invalid delay_division "$raw". Expected halfBeat, quarterBeat, eighthBeat, or sixteenthBeat.',
    );
  }

  static String _requireDeckId(Map<String, dynamic> args, String key) {
    final deck = _optionalDeckId(args, key);
    if (deck == null) {
      throw McpException.invalidParams(
        'Parameter "$key" is required and must be "A" or "B".',
      );
    }
    return deck;
  }

  static String? _optionalDeckId(Map<String, dynamic> args, String key) {
    final raw = _optionalString(args, key);
    if (raw == null) return null;
    final upper = raw.toUpperCase();
    if (upper != 'A' && upper != 'B') {
      throw McpException.invalidParams(
        'Parameter "$key" must be "A" or "B", got "$raw".',
      );
    }
    return upper;
  }

  static String _requireNonEmptyString(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! String || v.trim().isEmpty) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a non-empty string.',
      );
    }
    return v.trim();
  }

  static String? _optionalString(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! String) {
      throw McpException.invalidParams('Parameter "$key" must be a string.');
    }
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _optionalDouble(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be a number.');
    }
    return v.toDouble();
  }

  static int? _optionalInt(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v.toInt();
  }

  static bool? _optionalBool(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! bool) {
      throw McpException.invalidParams('Parameter "$key" must be a boolean.');
    }
    return v;
  }

  static String _extractBaseName(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final fileName = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }
}
