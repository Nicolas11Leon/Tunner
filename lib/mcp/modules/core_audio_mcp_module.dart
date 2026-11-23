import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../core/audio/domain/i_studio_audio_device_matrix_service.dart';
import '../../core/audio/domain/i_studio_master_clock_service.dart';
import '../../core/audio/domain/reverb/ir_convolution_processor.dart';
import '../../core/audio/domain/reverb/schroeder_reverb_engine.dart';
import '../../core/audio/domain/spatial/binaural_panner_engine.dart';
import '../../core/audio/infrastructure/studio_master_dsp_chain.dart';
import '../../core/channels/domain/studio_channel_bus.dart';
import '../../core/channels/domain/studio_modular_plug.dart';
import '../../core/channels/domain/studio_patchbay_routing_service.dart';
import '../../core/channels/domain/studio_plug_type.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing Core Audio hardware matrix, Master Clock,
/// SIMD/FFI DSP chain, Schroeder Reverb, 3D Binaural Panner, IR Convolution,
/// and the modular Channel Patchbay.
class CoreAudioMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final IStudioPatchbayRoutingService patchbayService;
  final IrConvolutionProcessor _convolutionProcessor;
  final SchroederReverbEngine _fallbackReverb;
  final BinauralPannerEngine _fallbackBinaural;

  DspBenchmarkResult? _lastBenchmark;

  CoreAudioMcpModule(
    this.facade, {
    IStudioPatchbayRoutingService? patchbayService,
    IrConvolutionProcessor convolutionProcessor = const IrConvolutionProcessor(),
  })  : patchbayService = patchbayService ??
            StudioPatchbayRoutingService.isolated(headless: true),
        _convolutionProcessor = convolutionProcessor,
        _fallbackReverb = SchroederReverbEngine(),
        _fallbackBinaural = BinauralPannerEngine();

  @override
  String get moduleName => 'core_audio';

  IStudioAudioDeviceMatrixService get _matrixService =>
      facade.root.audioMatrixService;

  IStudioMasterClockService get _clockService =>
      facade.root.masterClockService;

  StudioMasterDspChain get _dspChain => facade.root.masterDspChain;

  SchroederReverbEngine get _reverbEngine =>
      facade.root.terminalKernel.reverbEngine ?? _fallbackReverb;

  BinauralPannerEngine get _binauralEngine =>
      facade.root.terminalKernel.spatialEngine ?? _fallbackBinaural;

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ===========================================================================
  // Resources (5)
  // ===========================================================================

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://audio/matrix',
        name: 'Audio Device Matrix',
        description:
            'Hardware audio matrix configuration, 3-band EQ, master compressor, gains, channel routings, and master capture state.',
        mimeType: 'application/json',
        reader: () async {
          final m = _matrixService.matrix;
          final payload = <String, dynamic>{
            ...m.toJson(),
            'latencyMs': m.estimatedBufferLatencyMs,
            'effectiveMasterGain': m.effectiveMasterGain,
            'masterGainDb': m.masterGainDb,
            'availableInputs':
                m.availableInputs.map((d) => d.toJson()).toList(growable: false),
            'availableOutputs': m.availableOutputs
                .map((d) => d.toJson())
                .toList(growable: false),
          };
          return McpResourceContent.json(
            uri: 'tunner://audio/matrix',
            data: payload,
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://audio/clock',
        name: 'Studio Master Clock',
        description:
            'Real-time state of the unified Studio Master Clock and global transport.',
        mimeType: 'application/json',
        reader: () async => McpResourceContent.json(
          uri: 'tunner://audio/clock',
          data: _clockSnapshot(),
        ),
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://audio/meters',
        name: 'Master Stereo Meters',
        description:
            'Latest stereo RMS, peak dBFS, clipping indicator, and dynamics gain reduction telemetry.',
        mimeType: 'application/json',
        reader: () async {
          final meter = _matrixService.masterMeterData;
          final gainReduction = meter.gainReductionDb != 0.0
              ? meter.gainReductionDb
              : _matrixService.dynamicsProcessor.currentGainReductionDb;
          return McpResourceContent.json(
            uri: 'tunner://audio/meters',
            data: {
              'leftRms': meter.leftRms,
              'rightRms': meter.rightRms,
              'leftPeakDb': meter.leftPeakDb,
              'rightPeakDb': meter.rightPeakDb,
              'isClipping': meter.isClipping,
              'gainReductionDb': gainReduction,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://audio/dsp/status',
        name: 'DSP Bridge & Effects Status',
        description:
            'Native FFI/SIMD DSP bridge availability, latest benchmark telemetry, Schroeder reverb, and 3D binaural panner parameters.',
        mimeType: 'application/json',
        reader: () async {
          final bridge = _dspChain.bridge;
          final rev = _reverbEngine;
          final bin = _binauralEngine;
          final bench = _lastBenchmark;
          return McpResourceContent.json(
            uri: 'tunner://audio/dsp/status',
            data: {
              'isNativeAvailable': bridge.isNativeAvailable,
              'engineName': bridge.engineName,
              'lastBenchmark': bench == null
                  ? null
                  : {
                      'engineName': bench.engineName,
                      'isNative': bench.isNative,
                      'iterations': bench.iterations,
                      'blockSize': bench.blockSize,
                      'elapsedMicroseconds': bench.elapsedMicroseconds,
                      'throughputMegaSamplesPerSec':
                          bench.throughputMegaSamplesPerSec,
                    },
              'reverb': {
                'sampleRate': rev.sampleRate,
                'roomSize': rev.roomSize,
                'damping': rev.damping,
                'wetMix': rev.wetMix,
                'dryMix': rev.dryMix,
                'width': rev.width,
              },
              'binaural': {
                'sampleRate': bin.sampleRate,
                'azimuthDegrees': bin.coordinates.azimuthDegrees,
                'elevationDegrees': bin.coordinates.elevationDegrees,
                'distanceMeters': bin.coordinates.distanceMeters,
                'itdMs': bin.itdMs,
                'distanceGain': bin.distanceGain,
              },
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://channels/patchbay',
        name: 'Modular Channel Patchbay',
        description:
            'Complete topology of channel buses, registered modular plugs, active connections, and compiled DSP opcode sequence.',
        mimeType: 'application/json',
        reader: () async => McpResourceContent.json(
          uri: 'tunner://channels/patchbay',
          data: _patchbaySnapshot(),
        ),
      ),
    );
  }

  // ===========================================================================
  // Tools (16)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_audio_set_master_gain',
        description:
            'Sets the master bus gain in linear scale (0.0..1.5) or decibels (-60.0..3.5).',
        inputSchema: {
          'type': 'object',
          'properties': {
            'gainLinear': {'type': 'number', 'minimum': 0.0, 'maximum': 1.5},
            'gainDb': {'type': 'number', 'minimum': -60.0, 'maximum': 3.5},
          },
        },
        handler: (args) async {
          final gainLinear = _optionalDouble(args, 'gainLinear');
          final gainDb = _optionalDouble(args, 'gainDb');
          if (gainLinear == null && gainDb == null) {
            throw const McpException.invalidParams(
              'Provide either "gainLinear" or "gainDb".',
            );
          }
          if (gainLinear != null) {
            _requireRange(gainLinear, 0.0, 1.5, 'gainLinear');
            _matrixService.setMasterGain(gainLinear);
          } else if (gainDb != null) {
            _requireRange(gainDb, -60.0, 3.5, 'gainDb');
            _matrixService.setMasterGainDb(gainDb);
          }

          final m = _matrixService.matrix;
          final data = {
            'masterGain': m.masterGain,
            'effectiveMasterGain': m.effectiveMasterGain,
            'masterGainDb': m.masterGainDb,
          };
          facade.emitIpcEvent('audio.matrix.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_audio_toggle_master_control',
        description:
            'Toggles a master hardware console switch: mute, dim, mono, eq_bypass, or comp_bypass.',
        inputSchema: {
          'type': 'object',
          'required': ['control'],
          'properties': {
            'control': {
              'type': 'string',
              'enum': ['mute', 'dim', 'mono', 'eq_bypass', 'comp_bypass'],
            },
          },
        },
        handler: (args) async {
          final control = _requireNonEmptyString(args, 'control').toLowerCase();
          late final bool active;
          switch (control) {
            case 'mute':
              _matrixService.toggleMute();
              active = _matrixService.matrix.isMuted;
            case 'dim':
              _matrixService.toggleDim();
              active = _matrixService.matrix.isDimmed;
            case 'mono':
              _matrixService.toggleMono();
              active = _matrixService.matrix.isMono;
            case 'eq_bypass':
              _matrixService.toggleEqBypass();
              active = _matrixService.matrix.isEqBypassed;
            case 'comp_bypass':
              _matrixService.toggleCompBypass();
              active = _matrixService.matrix.isCompBypassed;
            default:
              throw McpException.invalidParams(
                'Unsupported control "$control". Expected mute, dim, mono, eq_bypass, or comp_bypass.',
              );
          }

          final data = {'control': control, 'active': active};
          facade.emitIpcEvent('audio.matrix.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_audio_configure_eq',
        description:
            'Configures the 3-band master equalizer gains in dB (-12.0..12.0).',
        inputSchema: {
          'type': 'object',
          'properties': {
            'lowDb': {'type': 'number', 'minimum': -12.0, 'maximum': 12.0},
            'midDb': {'type': 'number', 'minimum': -12.0, 'maximum': 12.0},
            'highDb': {'type': 'number', 'minimum': -12.0, 'maximum': 12.0},
          },
        },
        handler: (args) async {
          final lowDb = _optionalDouble(args, 'lowDb');
          final midDb = _optionalDouble(args, 'midDb');
          final highDb = _optionalDouble(args, 'highDb');
          if (lowDb == null && midDb == null && highDb == null) {
            throw const McpException.invalidParams(
              'Provide at least one of "lowDb", "midDb", or "highDb".',
            );
          }
          if (lowDb != null) {
            _requireRange(lowDb, -12.0, 12.0, 'lowDb');
            _matrixService.setEqLow(lowDb);
          }
          if (midDb != null) {
            _requireRange(midDb, -12.0, 12.0, 'midDb');
            _matrixService.setEqMid(midDb);
          }
          if (highDb != null) {
            _requireRange(highDb, -12.0, 12.0, 'highDb');
            _matrixService.setEqHigh(highDb);
          }

          final m = _matrixService.matrix;
          final data = {
            'eqLowDb': m.eqLowDb,
            'eqMidDb': m.eqMidDb,
            'eqHighDb': m.eqHighDb,
            'isEqBypassed': m.isEqBypassed,
          };
          facade.emitIpcEvent('audio.matrix.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_audio_configure_compressor',
        description:
            'Configures master bus dynamics compressor threshold (-30.0..0.0 dB) and ratio (1.0..20.0).',
        inputSchema: {
          'type': 'object',
          'properties': {
            'thresholdDb': {'type': 'number', 'minimum': -30.0, 'maximum': 0.0},
            'ratio': {'type': 'number', 'minimum': 1.0, 'maximum': 20.0},
          },
        },
        handler: (args) async {
          final thresholdDb = _optionalDouble(args, 'thresholdDb');
          final ratio = _optionalDouble(args, 'ratio');
          if (thresholdDb == null && ratio == null) {
            throw const McpException.invalidParams(
              'Provide at least one of "thresholdDb" or "ratio".',
            );
          }
          if (thresholdDb != null) {
            _requireRange(thresholdDb, -30.0, 0.0, 'thresholdDb');
            _matrixService.setCompThreshold(thresholdDb);
          }
          if (ratio != null) {
            _requireRange(ratio, 1.0, 20.0, 'ratio');
            _matrixService.setCompRatio(ratio);
          }

          final m = _matrixService.matrix;
          final data = {
            'compThresholdDb': m.compThresholdDb,
            'compRatio': m.compRatio,
            'isCompBypassed': m.isCompBypassed,
          };
          facade.emitIpcEvent('audio.matrix.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_audio_select_device',
        description: 'Selects an active audio input or output hardware device.',
        inputSchema: {
          'type': 'object',
          'required': ['direction', 'deviceId'],
          'properties': {
            'direction': {
              'type': 'string',
              'enum': ['input', 'output'],
            },
            'deviceId': {'type': 'string'},
          },
        },
        handler: (args) async {
          final direction =
              _requireNonEmptyString(args, 'direction').toLowerCase();
          final deviceId = _requireNonEmptyString(args, 'deviceId');

          if (direction == 'input') {
            await _matrixService.selectInputDevice(deviceId);
          } else if (direction == 'output') {
            await _matrixService.selectOutputDevice(deviceId);
          } else {
            throw McpException.invalidParams(
              'Invalid direction "$direction". Expected "input" or "output".',
            );
          }

          final activeDevice = direction == 'input'
              ? _matrixService.matrix.activeInputDevice.toJson()
              : _matrixService.matrix.activeOutputDevice.toJson();
          final data = {
            'direction': direction,
            'activeDevice': activeDevice,
          };
          facade.emitIpcEvent('audio.matrix.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_audio_set_buffer_size',
        description:
            'Sets the audio buffer size in samples (128, 256, 512, or 1024) and returns resulting theoretical latency.',
        inputSchema: {
          'type': 'object',
          'required': ['bufferSize'],
          'properties': {
            'bufferSize': {
              'type': 'integer',
              'enum': [128, 256, 512, 1024],
            },
          },
        },
        handler: (args) async {
          final bufferSize = _requireInt(args, 'bufferSize');
          const allowed = {128, 256, 512, 1024};
          if (!allowed.contains(bufferSize)) {
            throw McpException.invalidParams(
              'Invalid bufferSize $bufferSize. Allowed values: 128, 256, 512, 1024.',
            );
          }
          _matrixService.setBufferSize(bufferSize);
          final m = _matrixService.matrix;
          final data = {
            'bufferSize': m.bufferSize,
            'sampleRate': m.sampleRate,
            'latencyMs': m.estimatedBufferLatencyMs,
          };
          facade.emitIpcEvent('audio.matrix.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_audio_route_channel',
        description:
            'Routes a logical audio channel to a destination bus (master, cue, or mute).',
        inputSchema: {
          'type': 'object',
          'required': ['channelId', 'destinationBus'],
          'properties': {
            'channelId': {'type': 'string'},
            'destinationBus': {
              'type': 'string',
              'enum': ['master', 'cue', 'mute'],
            },
          },
        },
        handler: (args) async {
          final channelId = _requireNonEmptyString(args, 'channelId');
          final destinationBus =
              _requireNonEmptyString(args, 'destinationBus').toLowerCase();
          const allowed = {'master', 'cue', 'mute'};
          if (!allowed.contains(destinationBus)) {
            throw McpException.invalidParams(
              'Invalid destinationBus "$destinationBus". Expected master, cue, or mute.',
            );
          }
          _matrixService.setChannelRouting(channelId, destinationBus);
          final data = {
            'channelId': channelId,
            'destinationBus': destinationBus,
          };
          facade.emitIpcEvent('audio.matrix.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_audio_master_capture',
        description:
            'Starts or stops master bus audio capture to a WAV destination inside the workspace sandbox.',
        inputSchema: {
          'type': 'object',
          'required': ['action'],
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['start', 'stop'],
            },
            'destinationPath': {'type': 'string'},
          },
        },
        handler: (args) async {
          final action = _requireNonEmptyString(args, 'action').toLowerCase();
          if (action == 'start') {
            final rawDest = _requireNonEmptyString(args, 'destinationPath');
            final safeDest = _resolveWorkspacePath(rawDest);
            await _matrixService.startMasterRecording(safeDest);
            final data = {
              'isMasterRecording': _matrixService.matrix.isMasterRecording,
              'filePath': safeDest,
            };
            facade.emitIpcEvent('audio.matrix.updated', data);
            return McpToolResult.json(data);
          } else if (action == 'stop') {
            final filePath = await _matrixService.stopMasterRecording();
            final data = {
              'isMasterRecording': _matrixService.matrix.isMasterRecording,
              'filePath': filePath,
            };
            facade.emitIpcEvent('audio.matrix.updated', data);
            return McpToolResult.json(data);
          } else {
            throw McpException.invalidParams(
              'Invalid action "$action". Expected "start" or "stop".',
            );
          }
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_clock_control',
        description:
            'Controls the Studio Master Clock transport (play, pause, stop, toggle, tap), BPM (20..300), and time signature meter.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['play', 'pause', 'stop', 'toggle', 'tap'],
            },
            'bpm': {'type': 'number', 'minimum': 20.0, 'maximum': 300.0},
            'numerator': {'type': 'integer', 'minimum': 1, 'maximum': 16},
            'denominator': {'type': 'integer', 'minimum': 1, 'maximum': 16},
          },
        },
        handler: (args) async {
          final action = _optionalString(args, 'action')?.toLowerCase();
          final bpm = _optionalDouble(args, 'bpm');
          final numerator = _optionalInt(args, 'numerator');
          final denominator = _optionalInt(args, 'denominator');

          if (action == null &&
              bpm == null &&
              numerator == null &&
              denominator == null) {
            throw const McpException.invalidParams(
              'Provide at least one of "action", "bpm", "numerator", or "denominator".',
            );
          }

          if (bpm != null) {
            _requireRange(bpm, 20.0, 300.0, 'bpm');
            _clockService.setBpm(bpm);
          }

          if (numerator != null || denominator != null) {
            final numVal = numerator ?? _clockService.meterNumerator;
            final denVal = denominator ?? _clockService.meterDenominator;
            if (numVal < 1 || numVal > 16) {
              throw McpException.invalidParams(
                'Parameter "numerator" must be between 1 and 16.',
              );
            }
            if (denVal < 1 || denVal > 16) {
              throw McpException.invalidParams(
                'Parameter "denominator" must be between 1 and 16.',
              );
            }
            _clockService.setMeter(numVal, denVal);
          }

          if (action != null) {
            switch (action) {
              case 'play':
                _clockService.startTransport(bpm: bpm);
              case 'pause':
                _clockService.pauseTransport();
              case 'stop':
                _clockService.stopTransport();
              case 'toggle':
                _clockService.togglePlayPause();
              case 'tap':
                _clockService.registerTap();
              default:
                throw McpException.invalidParams(
                  'Invalid clock action "$action". Expected play, pause, stop, toggle, or tap.',
                );
            }
          }

          final data = _clockSnapshot();
          facade.emitIpcEvent('audio.clock.state', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dsp_benchmark',
        description:
            'Runs a deterministic throughput benchmark on the active SIMD/FFI or Pure Dart DSP chain.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'iterations': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 5000,
              'default': 100,
            },
            'blockSize': {
              'type': 'integer',
              'minimum': 128,
              'maximum': 16384,
              'default': 2048,
            },
          },
        },
        handler: (args) async {
          final iterations = _optionalInt(args, 'iterations') ?? 100;
          final blockSize = _optionalInt(args, 'blockSize') ?? 2048;
          if (iterations < 1 || iterations > 5000) {
            throw const McpException.invalidParams(
              'Parameter "iterations" must be between 1 and 5000.',
            );
          }
          if (blockSize < 128 || blockSize > 16384) {
            throw const McpException.invalidParams(
              'Parameter "blockSize" must be between 128 and 16384.',
            );
          }

          final result = _dspChain.runBenchmark(
            iterations: iterations,
            blockSize: blockSize,
          );
          _lastBenchmark = result;

          return McpToolResult.json({
            'engineName': result.engineName,
            'isNative': result.isNative,
            'iterations': result.iterations,
            'blockSize': result.blockSize,
            'elapsedMicroseconds': result.elapsedMicroseconds,
            'throughputMegaSamplesPerSec': result.throughputMegaSamplesPerSec,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dsp_configure_reverb',
        description:
            'Configures Schroeder-Moorer algorithmic stereo reverb parameters (0.0..1.0).',
        inputSchema: {
          'type': 'object',
          'properties': {
            'roomSize': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'damping': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'wetMix': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'dryMix': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'width': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
          },
        },
        handler: (args) async {
          final roomSize = _optionalDouble(args, 'roomSize');
          final damping = _optionalDouble(args, 'damping');
          final wetMix = _optionalDouble(args, 'wetMix');
          final dryMix = _optionalDouble(args, 'dryMix');
          final width = _optionalDouble(args, 'width');

          if (roomSize == null &&
              damping == null &&
              wetMix == null &&
              dryMix == null &&
              width == null) {
            throw const McpException.invalidParams(
              'Provide at least one reverb parameter.',
            );
          }

          final rev = _reverbEngine;
          if (roomSize != null) {
            _requireRange(roomSize, 0.0, 1.0, 'roomSize');
            rev.roomSize = roomSize;
          }
          if (damping != null) {
            _requireRange(damping, 0.0, 1.0, 'damping');
            rev.damping = damping;
          }
          if (wetMix != null) {
            _requireRange(wetMix, 0.0, 1.0, 'wetMix');
            rev.wetMix = wetMix;
          }
          if (dryMix != null) {
            _requireRange(dryMix, 0.0, 1.0, 'dryMix');
            rev.dryMix = dryMix;
          }
          if (width != null) {
            _requireRange(width, 0.0, 1.0, 'width');
            rev.width = width;
          }

          final data = {
            'sampleRate': rev.sampleRate,
            'roomSize': rev.roomSize,
            'damping': rev.damping,
            'wetMix': rev.wetMix,
            'dryMix': rev.dryMix,
            'width': rev.width,
          };
          facade.emitIpcEvent('audio.dsp.reverb.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dsp_configure_binaural',
        description:
            'Configures 3D Woodworth ITD/ILD binaural spatialization coordinates.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'azimuthDegrees': {
              'type': 'number',
              'minimum': -180.0,
              'maximum': 180.0,
            },
            'elevationDegrees': {
              'type': 'number',
              'minimum': -90.0,
              'maximum': 90.0,
            },
            'distanceMeters': {'type': 'number', 'exclusiveMinimum': 0.0},
          },
        },
        handler: (args) async {
          final azimuth = _optionalDouble(args, 'azimuthDegrees');
          final elevation = _optionalDouble(args, 'elevationDegrees');
          final distance = _optionalDouble(args, 'distanceMeters');

          if (azimuth == null && elevation == null && distance == null) {
            throw const McpException.invalidParams(
              'Provide at least one of "azimuthDegrees", "elevationDegrees", or "distanceMeters".',
            );
          }

          final bin = _binauralEngine;
          if (azimuth != null) {
            _requireRange(azimuth, -180.0, 180.0, 'azimuthDegrees');
            bin.setAzimuth(azimuth);
          }
          if (elevation != null) {
            _requireRange(elevation, -90.0, 90.0, 'elevationDegrees');
            bin.setElevation(elevation);
          }
          if (distance != null) {
            if (distance <= 0.0 || distance > 1000.0) {
              throw const McpException.invalidParams(
                'Parameter "distanceMeters" must be > 0.0 and <= 1000.0.',
              );
            }
            bin.setDistance(distance);
          }

          final data = {
            'azimuthDegrees': bin.coordinates.azimuthDegrees,
            'elevationDegrees': bin.coordinates.elevationDegrees,
            'distanceMeters': bin.coordinates.distanceMeters,
            'itdMs': bin.itdMs,
            'distanceGain': bin.distanceGain,
          };
          facade.emitIpcEvent('audio.dsp.binaural.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dsp_render_ir_convolution',
        description:
            'Renders offline stereo IR convolution in a background Isolate from a workspace WAV file and either an IR WAV file or synthetic RT60.',
        inputSchema: {
          'type': 'object',
          'required': ['inputWavPath', 'outputWavPath'],
          'properties': {
            'inputWavPath': {'type': 'string'},
            'irWavPath': {'type': 'string'},
            'syntheticRt60': {
              'type': 'number',
              'minimum': 0.05,
              'maximum': 10.0,
            },
            'outputWavPath': {'type': 'string'},
            'normalize': {'type': 'boolean', 'default': true},
          },
        },
        handler: (args) async {
          final inputRel = _requireNonEmptyString(args, 'inputWavPath');
          final outputRel = _requireNonEmptyString(args, 'outputWavPath');
          final irRel = _optionalString(args, 'irWavPath');
          final syntheticRt60 = _optionalDouble(args, 'syntheticRt60');
          final normalize = (args['normalize'] as bool?) ?? true;

          if (irRel == null && syntheticRt60 == null) {
            throw const McpException.invalidParams(
              'Provide either "irWavPath" or "syntheticRt60".',
            );
          }
          if (syntheticRt60 != null) {
            _requireRange(syntheticRt60, 0.05, 10.0, 'syntheticRt60');
          }

          final inputAbs = _resolveWorkspacePath(inputRel);
          final outputAbs = _resolveWorkspacePath(outputRel);
          final irAbs = irRel != null ? _resolveWorkspacePath(irRel) : null;

          final inputFile = File(inputAbs);
          if (!await inputFile.exists()) {
            throw McpException.fileNotFound(
              'Input WAV file not found: $inputRel',
            );
          }
          final inputBytes = await inputFile.readAsBytes();
          final decodedInput = _decodePcm16Wav(inputBytes, inputRel);

          late final Float32List irSamples;
          if (irAbs != null) {
            final irFile = File(irAbs);
            if (!await irFile.exists()) {
              throw McpException.fileNotFound(
                'Impulse response WAV file not found: $irRel',
              );
            }
            final irBytes = await irFile.readAsBytes();
            final decodedIr = _decodePcm16Wav(irBytes, irRel!);
            irSamples = decodedIr.left;
          } else {
            irSamples = IrConvolutionProcessor.generateSyntheticIr(
              rt60Seconds: syntheticRt60!,
              sampleRate: decodedInput.sampleRate.toDouble(),
            );
          }

          final stopwatch = Stopwatch()..start();
          final convolved = await _runConvolutionInIsolate(
            processor: _convolutionProcessor,
            leftIn: decodedInput.left,
            rightIn: decodedInput.right,
            irSamples: irSamples,
            normalize: normalize,
          );
          stopwatch.stop();

          final wavBytes = _encodePcm16StereoWav(
            convolved[0],
            convolved[1],
            decodedInput.sampleRate,
          );
          final outFile = File(outputAbs);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(wavBytes, flush: true);

          facade.emitIpcEvent('workspace.fs.changed', {
            'action': 'write',
            'relativePath': outputRel,
          });

          return McpToolResult.json({
            'outputWavPath': outputRel,
            'outputSamples': convolved[0].length,
            'sampleRate': decodedInput.sampleRate,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_patchbay_manage_channel',
        description:
            'Creates, renames, removes, sets gain, or toggles mute on a modular patchbay channel bus.',
        inputSchema: {
          'type': 'object',
          'required': ['action'],
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['create', 'rename', 'remove', 'set_gain', 'toggle_mute'],
            },
            'channelId': {'type': 'string'},
            'name': {'type': 'string'},
            'shortCode': {'type': 'string'},
            'colorHex': {'type': 'integer'},
            'gain': {'type': 'number', 'minimum': 0.0, 'maximum': 2.0},
          },
        },
        handler: (args) async {
          final action = _requireNonEmptyString(args, 'action').toLowerCase();
          late final Map<String, dynamic> result;

          switch (action) {
            case 'create':
              final name = _requireNonEmptyString(args, 'name');
              final shortCode = _optionalString(args, 'shortCode');
              final colorHex = _optionalInt(args, 'colorHex');
              final created = patchbayService.createCustomChannel(
                name: name,
                shortCode: shortCode,
                colorHex: colorHex,
              );
              result = {'action': action, 'channel': _channelToJson(created)};
            case 'rename':
              final channelId = _requireNonEmptyString(args, 'channelId');
              final name = _requireNonEmptyString(args, 'name');
              _requireChannelExists(channelId);
              patchbayService.renameChannel(channelId, name);
              result = {
                'action': action,
                'channel': _channelToJson(
                  patchbayService.matrix.channels[channelId]!,
                ),
              };
            case 'remove':
              final channelId = _requireNonEmptyString(args, 'channelId');
              _requireChannelExists(channelId);
              patchbayService.removeCustomChannel(channelId);
              result = {
                'action': action,
                'removedChannelId': channelId,
                'remainingChannels':
                    patchbayService.channels.map((c) => c.id).toList(),
              };
            case 'set_gain':
              final channelId = _requireNonEmptyString(args, 'channelId');
              final gain = _requireDouble(args, 'gain');
              _requireRange(gain, 0.0, 2.0, 'gain');
              _requireChannelExists(channelId);
              patchbayService.setChannelGain(channelId, gain);
              result = {
                'action': action,
                'channel': _channelToJson(
                  patchbayService.matrix.channels[channelId]!,
                ),
              };
            case 'toggle_mute':
              final channelId = _requireNonEmptyString(args, 'channelId');
              _requireChannelExists(channelId);
              patchbayService.toggleChannelMute(channelId);
              result = {
                'action': action,
                'channel': _channelToJson(
                  patchbayService.matrix.channels[channelId]!,
                ),
              };
            default:
              throw McpException.invalidParams(
                'Unsupported patchbay channel action "$action".',
              );
          }

          facade.emitIpcEvent('channels.patchbay.updated', result);
          return McpToolResult.json(result);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_patchbay_connect_plug',
        description:
            'Connects or disconnects a modular plug to/from a patchbay channel bus.',
        inputSchema: {
          'type': 'object',
          'required': ['action', 'plugId'],
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['connect', 'disconnect'],
            },
            'plugId': {'type': 'string'},
            'channelId': {'type': 'string'},
            'label': {'type': 'string'},
            'plugType': {'type': 'string'},
            'toolId': {'type': 'string'},
          },
        },
        handler: (args) async {
          final action = _requireNonEmptyString(args, 'action').toLowerCase();
          final plugId = _requireNonEmptyString(args, 'plugId');

          if (!patchbayService.plugs.containsKey(plugId)) {
            final plugTypeStr = _optionalString(args, 'plugType');
            if (action == 'connect' && plugTypeStr != null) {
              final plugType = _parsePlugType(plugTypeStr);
              patchbayService.registerPlug(
                StudioModularPlug(
                  id: plugId,
                  label: _optionalString(args, 'label') ?? plugId,
                  type: plugType,
                  toolId: _optionalString(args, 'toolId') ?? 'mcp_tool',
                ),
              );
            } else {
              throw McpException.invalidParams(
                'Plug "$plugId" is not registered in patchbay. Provide "plugType" to register it when connecting.',
              );
            }
          }

          if (action == 'connect') {
            final channelId = _requireNonEmptyString(args, 'channelId');
            _requireChannelExists(channelId);
            patchbayService.connectPlugToChannel(plugId, channelId);
          } else if (action == 'disconnect') {
            patchbayService.disconnectPlug(plugId);
          } else {
            throw McpException.invalidParams(
              'Invalid action "$action". Expected "connect" or "disconnect".',
            );
          }

          final updatedPlug = patchbayService.plugs[plugId]!;
          final data = {
            'plugId': updatedPlug.id,
            'connectedChannelId': updatedPlug.connectedChannelId,
          };
          facade.emitIpcEvent('channels.patchbay.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_patchbay_publish_params',
        description:
            'Publishes full-duplex playback parameters (title, BPM, Camelot key, playing state, positionMs) onto a patchbay channel bus.',
        inputSchema: {
          'type': 'object',
          'required': ['channelId'],
          'properties': {
            'channelId': {'type': 'string'},
            'title': {'type': 'string'},
            'bpm': {'type': 'number', 'minimum': 20.0, 'maximum': 300.0},
            'key': {'type': 'string'},
            'isPlaying': {'type': 'boolean'},
            'positionMs': {'type': 'integer', 'minimum': 0},
          },
        },
        handler: (args) async {
          final channelId = _requireNonEmptyString(args, 'channelId');
          _requireChannelExists(channelId);

          final title = _optionalString(args, 'title');
          final bpm = _optionalDouble(args, 'bpm');
          final key = _optionalString(args, 'key');
          final isPlaying = args['isPlaying'] is bool
              ? args['isPlaying'] as bool
              : null;
          final positionMs = _optionalInt(args, 'positionMs');

          if (bpm != null) {
            _requireRange(bpm, 20.0, 300.0, 'bpm');
          }
          if (positionMs != null && positionMs < 0) {
            throw const McpException.invalidParams(
              'Parameter "positionMs" must be >= 0.',
            );
          }

          patchbayService.publishChannelParameters(
            channelId,
            title: title,
            bpm: bpm,
            key: key,
            isPlaying: isPlaying,
            positionMs: positionMs,
          );

          final updated = patchbayService.matrix.channels[channelId]!;
          final data = _channelToJson(updated);
          facade.emitIpcEvent('channels.patchbay.updated', data);
          return McpToolResult.json(data);
        },
      ),
    );
  }

  // ===========================================================================
  // Prompts (3)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_mastering_chain_setup',
        description:
            'Guides the agent to inspect audio matrix and stereo meters, diagnose clipping/headroom, and configure 3-band EQ and dynamics compression for a target genre.',
        arguments: const [
          McpPromptArgument(
            name: 'targetGenre',
            description:
                'Target musical profile (e.g., vocal_academic, club_mix, acoustic_chamber).',
            required: false,
          ),
        ],
        builder: (args) async {
          final genre = args['targetGenre']?.trim().isNotEmpty == true
              ? args['targetGenre']!.trim()
              : 'balanced_studio';
          return McpPromptResult(
            description: 'Mastering chain calibration workflow for $genre.',
            messages: [
              McpPromptMessage.user(
                'Inspect resources tunner://audio/matrix and tunner://audio/meters to audit current master gain, EQ, compressor, and clipping state. '
                'Then configure a clean mastering chain for target genre "$genre" using tunner_audio_configure_eq, tunner_audio_configure_compressor, and tunner_audio_set_master_gain while keeping peak levels below -0.1 dBFS.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_patchbay_routing_wizard',
        description:
            'Guides the agent to inspect tunner://channels/patchbay and construct a loop-free routing topology between Score, DJ, and Modular Rack buses.',
        arguments: const [
          McpPromptArgument(
            name: 'goal',
            description: 'Routing objective (e.g., sync_dj_and_score, vocal_monitoring).',
            required: false,
          ),
        ],
        builder: (args) async {
          final goal = args['goal']?.trim().isNotEmpty == true
              ? args['goal']!.trim()
              : 'sync_score_dj_and_rack';
          return McpPromptResult(
            description: 'Modular patchbay routing workflow for $goal.',
            messages: [
              McpPromptMessage.user(
                'Read tunner://channels/patchbay to inspect existing channel buses, plugs, and compiled DSP opcodes. '
                'Design and apply a loop-free routing topology for goal "$goal" using tunner_patchbay_manage_channel, tunner_patchbay_connect_plug, and tunner_patchbay_publish_params.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_audio_diagnostics_and_latency_audit',
        description:
            'Runs DSP throughput benchmarks and inspects buffer latency and native FFI availability to emit technical audio recommendations.',
        builder: (args) async {
          return const McpPromptResult(
            description: 'Audio engine latency and SIMD/FFI diagnostics audit.',
            messages: [
              McpPromptMessage.user(
                'Execute tunner_dsp_benchmark, read tunner://audio/dsp/status and tunner://audio/matrix, and produce a concise technical audit covering buffer size, theoretical latency in milliseconds (sub-10ms target), and native libtunner_dsp SIMD availability.',
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Snapshots & Helpers
  // ===========================================================================

  Map<String, dynamic> _clockSnapshot() {
    final c = _clockService;
    return {
      'bpm': c.bpm,
      'meter': '${c.meterNumerator}/${c.meterDenominator}',
      'meterNumerator': c.meterNumerator,
      'meterDenominator': c.meterDenominator,
      'status': c.status.name,
      'currentMeasure': c.currentMeasure,
      'currentBeat': c.currentBeat,
      'isDownbeat': c.isDownbeat,
      'beatIntervalMs': c.beatIntervalMs,
      'elapsedMs': c.elapsedDuration.inMilliseconds,
    };
  }

  Map<String, dynamic> _patchbaySnapshot() {
    final matrix = patchbayService.matrix;
    final opcodes = matrix.toDspInstructionSequence();
    return {
      'channels': matrix.channels.values
          .map(_channelToJson)
          .toList(growable: false),
      'plugs': matrix.plugs.values
          .map(
            (p) => {
              'id': p.id,
              'label': p.label,
              'type': p.type.name,
              'toolId': p.toolId,
              'connectedChannelId': p.connectedChannelId,
              'isInput': p.isInput,
              'isOutput': p.isOutput,
              'isConnected': p.isConnected,
            },
          )
          .toList(growable: false),
      'dspOpcodes': opcodes
          .map(
            (op) => {
              'opcode': op.opcode.name,
              'byteCode': op.opcode.byteCode,
              'sourceId': op.sourceId,
              'targetId': op.targetId,
              'parameter': op.parameter,
              'summary': op.toString(),
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, dynamic> _channelToJson(StudioChannelBus c) => {
        'id': c.id,
        'name': c.name,
        'shortCode': c.shortCode,
        'colorHex': c.colorHex,
        'gain': c.gain,
        'isMuted': c.isMuted,
        'isSolo': c.isSolo,
        'activeTrackTitle': c.activeTrackTitle,
        'activeBpm': c.activeBpm,
        'activeCamelotKey': c.activeCamelotKey,
        'isPlaying': c.isPlaying,
        'positionMs': c.positionMs,
      };

  void _requireChannelExists(String channelId) {
    if (!patchbayService.matrix.channels.containsKey(channelId)) {
      throw McpException.invalidParams(
        'Patchbay channel not found: "$channelId".',
      );
    }
  }

  StudioPlugType _parsePlugType(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in StudioPlugType.values) {
      if (value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    switch (normalized) {
      case 'audioin':
      case 'audio_in':
        return StudioPlugType.audioInput;
      case 'audioout':
      case 'audio_out':
        return StudioPlugType.audioOutput;
      case 'midiin':
      case 'midi_in':
        return StudioPlugType.midiInput;
      case 'midiout':
      case 'midi_out':
        return StudioPlugType.midiOutput;
      case 'clockin':
      case 'clock_in':
        return StudioPlugType.clockSyncInput;
      case 'clockout':
      case 'clock_out':
        return StudioPlugType.clockSyncOutput;
    }
    throw McpException.invalidParams(
      'Invalid plugType "$raw". Valid values: ${StudioPlugType.values.map((e) => e.name).join(", ")}.',
    );
  }

  static Future<List<Float32List>> _runConvolutionInIsolate({
    required IrConvolutionProcessor processor,
    required Float32List leftIn,
    required Float32List rightIn,
    required Float32List irSamples,
    required bool normalize,
  }) {
    return Isolate.run(
      () => processor.convolveStereo(
        leftIn,
        rightIn,
        irSamples,
        normalize: normalize,
      ),
    );
  }

  String _resolveWorkspacePath(String rawPath) {
    final normalized = rawPath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) {
      throw const McpException.invalidParams('Path must not be empty.');
    }
    if (normalized.contains('\x00') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
      throw McpException.securityViolation(
        'Path violates workspace sandbox: $rawPath',
      );
    }

    var clean = normalized;
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    final segments = clean.split('/');
    for (final seg in segments) {
      if (seg == '..' || seg == '.') {
        throw McpException.securityViolation(
          'Path traversal sequence rejected: $rawPath',
        );
      }
    }
    final joinedRel = segments.where((s) => s.isNotEmpty).join('/');
    if (joinedRel.isEmpty) {
      throw const McpException.securityViolation(
        'Operating directly on workspace root is not allowed.',
      );
    }

    final rootDir = facade.workspaceDirectory;
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final canonicalRoot = rootDir.resolveSymbolicLinksSync();
    final candidatePath =
        '$canonicalRoot${Platform.pathSeparator}${joinedRel.replaceAll('/', Platform.pathSeparator)}';

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

    if (!canonicalTarget.startsWith('$canonicalRoot${Platform.pathSeparator}')) {
      throw McpException.securityViolation(
        'Resolved path escapes workspace sandbox: $rawPath',
      );
    }
    return canonicalTarget;
  }

  _DecodedWav _decodePcm16Wav(Uint8List bytes, String label) {
    if (bytes.lengthInBytes < 44) {
      throw McpException.acousticError(
        'WAV file "$label" is too short to contain a valid RIFF header.',
      );
    }
    final data = ByteData.sublistView(bytes);
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') {
      throw McpException.acousticError(
        'File "$label" is not a valid RIFF/WAVE container.',
      );
    }

    int offset = 12;
    int numChannels = 1;
    int sampleRate = 44100;
    int bitsPerSample = 16;
    int dataOffset = -1;
    int dataSize = 0;

    while (offset + 8 <= bytes.lengthInBytes) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      if (chunkStart + chunkSize > bytes.lengthInBytes) {
        break;
      }
      if (chunkId == 'fmt ' && chunkSize >= 16) {
        final audioFormat = data.getUint16(chunkStart, Endian.little);
        if (audioFormat != 1) {
          throw McpException.acousticError(
            'Unsupported WAV audio format ($audioFormat) in "$label". Only PCM (1) is supported.',
          );
        }
        numChannels = data.getUint16(chunkStart + 2, Endian.little);
        sampleRate = data.getUint32(chunkStart + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkStart;
        dataSize = chunkSize;
        break;
      }
      offset = chunkStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (dataOffset < 0 || bitsPerSample != 16 || numChannels < 1) {
      throw McpException.acousticError(
        'Unsupported WAV layout in "$label" (requires 16-bit PCM mono or stereo).',
      );
    }

    final frameSize = numChannels * 2;
    final frameCount = dataSize ~/ frameSize;
    final left = Float32List(frameCount);
    final right = Float32List(frameCount);

    for (var i = 0; i < frameCount; i++) {
      final base = dataOffset + (i * frameSize);
      final lSample = data.getInt16(base, Endian.little) / 32768.0;
      left[i] = lSample;
      if (numChannels >= 2) {
        right[i] = data.getInt16(base + 2, Endian.little) / 32768.0;
      } else {
        right[i] = lSample;
      }
    }

    return _DecodedWav(sampleRate: sampleRate, left: left, right: right);
  }

  Uint8List _encodePcm16StereoWav(
    Float32List left,
    Float32List right,
    int sampleRate,
  ) {
    final frames = left.length < right.length ? left.length : right.length;
    const channels = 2;
    const bitsPerSample = 16;
    const bytesPerSample = bitsPerSample ~/ 8;
    final dataSize = frames * channels * bytesPerSample;
    final totalSize = 44 + dataSize;
    final out = Uint8List(totalSize);
    final bd = ByteData.sublistView(out);

    out.setRange(0, 4, 'RIFF'.codeUnits);
    bd.setUint32(4, 36 + dataSize, Endian.little);
    out.setRange(8, 12, 'WAVE'.codeUnits);
    out.setRange(12, 16, 'fmt '.codeUnits);
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
    bd.setUint16(32, channels * bytesPerSample, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);
    out.setRange(36, 40, 'data'.codeUnits);
    bd.setUint32(40, dataSize, Endian.little);

    var writeOffset = 44;
    for (var i = 0; i < frames; i++) {
      final l = (left[i].clamp(-1.0, 1.0) * 32767.0).round();
      final r = (right[i].clamp(-1.0, 1.0) * 32767.0).round();
      bd.setInt16(writeOffset, l, Endian.little);
      bd.setInt16(writeOffset + 2, r, Endian.little);
      writeOffset += 4;
    }
    return out;
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

  static double _requireDouble(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be a number.');
    }
    return v.toDouble();
  }

  static double? _optionalDouble(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be a number.');
    }
    return v.toDouble();
  }

  static int _requireInt(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! int) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v;
  }

  static int? _optionalInt(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! int) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v;
  }

  static void _requireRange(double value, double min, double max, String key) {
    if (value < min || value > max) {
      throw McpException.invalidParams(
        'Parameter "$key" ($value) must be within [$min, $max].',
      );
    }
  }
}

class _DecodedWav {
  final int sampleRate;
  final Float32List left;
  final Float32List right;

  const _DecodedWav({
    required this.sampleRate,
    required this.left,
    required this.right,
  });
}
