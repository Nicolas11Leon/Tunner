import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Arquitectura Clean: Auditoria de Pureza de Dominio (US-8.1)', () {
    const targetDomainDirs = <String>[
      'lib/features/mixer/domain',
      'lib/features/pedagogy/domain',
      'lib/core/channels/domain',
    ];

    final forbiddenImportPattern = RegExp(
      r'''^\s*import\s+['"](package:flutter/material\.dart|dart:io)['"]''',
      multiLine: true,
    );

    test(
      'lib/features/mixer/domain/, lib/features/pedagogy/domain/ y lib/core/channels/domain/ no importan flutter/material.dart ni dart:io',
      () {
        final violations = <String>[];

        for (final dirPath in targetDomainDirs) {
          final dir = Directory(dirPath);
          expect(
            dir.existsSync(),
            isTrue,
            reason: 'El directorio de dominio $dirPath debe existir.',
          );

          final dartFiles = dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .toList();

          expect(
            dartFiles,
            isNotEmpty,
            reason: 'Se esperaban archivos Dart en $dirPath.',
          );

          for (final file in dartFiles) {
            final content = file.readAsStringSync();
            for (final match in forbiddenImportPattern.allMatches(content)) {
              violations.add('${file.path}: ${match.group(0)?.trim()}');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Se detectaron imports prohibidos en capas de dominio puro:\n${violations.join('\n')}',
        );
      },
    );

    test(
      'PedagogicalCertificatePdfGenerator reside en infrastructure/ y no en domain/',
      () {
        expect(
          File('lib/features/pedagogy/domain/pedagogical_certificate_pdf_generator.dart')
              .existsSync(),
          isFalse,
        );
        expect(
          File('lib/features/pedagogy/infrastructure/pedagogical_certificate_pdf_generator.dart')
              .existsSync(),
          isTrue,
        );
      },
    );
  });
}
