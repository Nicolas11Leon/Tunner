import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/ffi/native_dsp_bridge_fallback.dart';
import 'package:tunner/core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart';

void main() {
  group('Wave 6: Multiplatform Packaging, Entitlements & Final Gate Tests', () {
    test('Dead dependency pitch_detector_dart is completely purged from pubspec.yaml', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      final content = pubspecFile.readAsStringSync();
      expect(content.contains('pitch_detector_dart'), isFalse);
    });

    test('macOS Runner Info.plist contains NSMicrophoneUsageDescription', () {
      final plistFile = File('macos/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue);
      final content = plistFile.readAsStringSync();
      expect(content.contains('<key>NSMicrophoneUsageDescription</key>'), isTrue);
      expect(
        content.contains('Tunner Studio requiere acceso al microfono'),
        isTrue,
      );
    });

    test('macOS entitlements contain audio-input and file-access permissions', () {
      final debugEntitlements = File('macos/Runner/DebugProfile.entitlements');
      final releaseEntitlements = File('macos/Runner/Release.entitlements');

      expect(debugEntitlements.existsSync(), isTrue);
      expect(releaseEntitlements.existsSync(), isTrue);

      final debugContent = debugEntitlements.readAsStringSync();
      final releaseContent = releaseEntitlements.readAsStringSync();

      expect(debugContent.contains('com.apple.security.device.audio-input'), isTrue);
      expect(
        debugContent.contains('com.apple.security.files.user-selected.read-write'),
        isTrue,
      );

      expect(releaseContent.contains('com.apple.security.device.audio-input'), isTrue);
      expect(
        releaseContent.contains('com.apple.security.files.user-selected.read-write'),
        isTrue,
      );
    });

    test('Linux CMakeLists.txt packages tunner_dsp and defines canonical APPLICATION_ID', () {
      final cmakeFile = File('linux/CMakeLists.txt');
      expect(cmakeFile.existsSync(), isTrue);
      final content = cmakeFile.readAsStringSync();

      expect(content.contains('set(APPLICATION_ID "org.tunner.studio")'), isTrue);
      expect(content.contains(r'add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../native/dsp"'), isTrue);
      expect(content.contains('install(TARGETS tunner_dsp LIBRARY DESTINATION'), isTrue);
    });

    test('Windows CMakeLists.txt packages tunner_dsp and Runner.rc defines canonical ID', () {
      final cmakeFile = File('windows/CMakeLists.txt');
      expect(cmakeFile.existsSync(), isTrue);
      final content = cmakeFile.readAsStringSync();

      expect(content.contains(r'add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../native/dsp"'), isTrue);
      expect(content.contains('install(TARGETS tunner_dsp RUNTIME DESTINATION'), isTrue);

      final rcFile = File('windows/runner/Runner.rc');
      expect(rcFile.existsSync(), isTrue);
      final rcContent = rcFile.readAsStringSync();
      expect(rcContent.contains('"CompanyName", "org.tunner.studio"'), isTrue);
      expect(rcContent.contains('"ProductName", "Tunner Studio"'), isTrue);
    });

    test('Android and macOS configuration define canonical org.tunner.studio identity', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);
      final gradleContent = gradleFile.readAsStringSync();
      expect(gradleContent.contains('applicationId = "org.tunner.studio"'), isTrue);
      expect(gradleContent.contains('path = file("../../native/dsp/CMakeLists.txt")'), isTrue);

      final appInfoFile = File('macos/Runner/Configs/AppInfo.xcconfig');
      expect(appInfoFile.existsSync(), isTrue);
      final appInfoContent = appInfoFile.readAsStringSync();
      expect(appInfoContent.contains('PRODUCT_BUNDLE_IDENTIFIER = org.tunner.studio'), isTrue);
    });

    test('Web manifest.json defines professional Tunner Studio workstation identity', () {
      final manifestFile = File('web/manifest.json');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();

      expect(content.contains('"name": "Tunner Studio"'), isTrue);
      expect(content.contains('"id": "org.tunner.studio"'), isTrue);
      expect(content.contains('Professional acoustic workstation'), isTrue);
    });

    test('NativeDspFfiBridge gracefully executes DSP fallback with SIMD and deterministic math', () {
      final bridge = NativeDspFfiBridge();
      expect(bridge.engineName, isNotEmpty);

      // Verify mathematical identity of gain operation
      final buffer = Float32List.fromList([1.0, -0.5, 0.25, 0.0, -1.0]);
      bridge.applyGain(buffer, 2.0);
      expect(buffer[0], closeTo(2.0, 1e-5));
      expect(buffer[1], closeTo(-1.0, 1e-5));
      expect(buffer[2], closeTo(0.5, 1e-5));
      expect(buffer[3], closeTo(0.0, 1e-5));
      expect(buffer[4], closeTo(-2.0, 1e-5));

      // Verify vector sum
      final a = Float32List.fromList([0.1, 0.2, 0.3, 0.4]);
      final b = Float32List.fromList([0.9, 0.8, 0.7, 0.6]);
      final out = Float32List(4);
      bridge.vectorSum(a, b, out);
      expect(out[0], closeTo(1.0, 1e-5));
      expect(out[1], closeTo(1.0, 1e-5));
      expect(out[2], closeTo(1.0, 1e-5));
      expect(out[3], closeTo(1.0, 1e-5));

      // Verify autocorrelation
      final signal = Float32List.fromList([1.0, 0.5, -0.5, -1.0, -0.5, 0.5, 1.0]);
      final corr = Float32List(3);
      bridge.autoCorrelate(signal, corr);
      expect(corr[0], greaterThan(0.0));

      bridge.dispose();
      expect(bridge.isNativeAvailable, isFalse);
    });

    test('NativeDspBridgeFallback provides 100% deterministic pure Dart fallback', () {
      const fallback = NativeDspBridgeFallback();
      expect(fallback.isNativeAvailable, isFalse);
      expect(fallback.engineName, contains('Pure Dart SIMD'));

      final buffer = Float32List.fromList([0.5, -0.5, 1.0]);
      fallback.applyGain(buffer, 0.5);
      expect(buffer[0], closeTo(0.25, 1e-5));
      expect(buffer[1], closeTo(-0.25, 1e-5));
      expect(buffer[2], closeTo(0.5, 1e-5));
    });
  });
}
