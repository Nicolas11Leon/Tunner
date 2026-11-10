import 'port_id.dart';

/// Resultado de la evaluación de políticas de conexión y sinergia.
class SynergyValidationResult {
  final bool isApproved;
  final String? rejectionReason;
  final bool isHyperSynergy;
  final String? pedagogicalNote;

  const SynergyValidationResult.approved({
    this.isHyperSynergy = false,
    this.pedagogicalNote,
  })  : isApproved = true,
        rejectionReason = null;

  const SynergyValidationResult.rejected({
    required this.rejectionReason,
    this.pedagogicalNote,
  })  : isApproved = false,
        isHyperSynergy = false;

  @override
  String toString() => isApproved
      ? 'Aprobada (Hiper-Sinergia: $isHyperSynergy) - $pedagogicalNote'
      : 'Rechazada: $rejectionReason';
}

/// Motor de políticas de interoperabilidad y sinergia acústica de Tunner.
///
/// Evalúa formalmente cualquier enlace propuesto entre puertos de herramientas:
/// 1. Garantiza consistencia física y tipado fuerte de señales.
/// 2. Previene cruces forzados destructivos (ej. Autotune en tests a ciegas).
/// 3. Identifica y cataloga las 6 Grandes Hiper-Sinergias de calibre profesional.
class SynergyPolicyEngine {
  /// Valida si una conexión entre un puerto emisor y un puerto receptor es válida.
  static SynergyValidationResult validateConnection({
    required PortId sourcePort,
    required PortId destinationPort,
  }) {
    // 1. Verificación básica de dirección
    if (sourcePort.direction != PortDirection.output) {
      return const SynergyValidationResult.rejected(
        rejectionReason: 'El puerto de origen debe ser de salida (output).',
      );
    }
    if (destinationPort.direction != PortDirection.input) {
      return const SynergyValidationResult.rejected(
        rejectionReason: 'El puerto de destino debe ser de entrada (input).',
      );
    }

    // 2. Compatibilidad estricta de tipo de señal
    if (sourcePort.signalType != destinationPort.signalType) {
      return SynergyValidationResult.rejected(
        rejectionReason:
            'Incompatibilidad de tipos de señal: no se puede conectar ${sourcePort.signalType.displayName} con ${destinationPort.signalType.displayName}.',
      );
    }

    final srcModule = sourcePort.ownerModuleId.toLowerCase();
    final destModule = destinationPort.ownerModuleId.toLowerCase();

    // 3. Reglas de Incompatibilidad Pedagógica y Cruces Forzados

    // Regla 1: Bloquear Autotune hacia Entrenador a Ciegas (destruye el auto-reconocimiento auditivo)
    if (srcModule.contains('autotune') && destModule.contains('ear_trainer')) {
      return const SynergyValidationResult.rejected(
        rejectionReason:
            'Conflicto pedagógico: El módulo de Oído a Ciegas requiere audio puro sin corrección de afinación artificial.',
        pedagogicalNote:
            'El entrenamiento auditivo a ciegas busca desarrollar el oído interno mediante discriminación de cents puros.',
      );
    }

    // Regla 2: Bloquear audio polifónico directo sobre el afinador estroboscópico monofónico MPM sin split
    if (srcModule.contains('chord_analyzer') && destModule.contains('strobe_tuner')) {
      return const SynergyValidationResult.rejected(
        rejectionReason:
            'Conflicto acústico: El afinador estroboscópico MPM requiere fuentes monofónicas. Un acorde multitonal genera distorsión de fase NSDF.',
        pedagogicalNote:
            'Para analizar la afinación de acordes completos, utilice el visualizador polifónico o aísle cada nota individualmente.',
      );
    }

    // Regla 3: Evitar retroalimentación directa entre el transcriptor y la partitura maestra
    if (srcModule.contains('transcription') && destModule.contains('song_library')) {
      return const SynergyValidationResult.rejected(
        rejectionReason:
            'Conflicto de notación: La transcripción en vivo debe renderizarse en un pentagrama esclavo, no sobrescribir la biblioteca de canciones.',
      );
    }

    // 4. Detección de las 6 Grandes Hiper-Sinergias de Tunner

    // Hiper-Sinergia 1: Lectura en Vuelo con Control Estroboscópico en Vivo
    if ((srcModule.contains('metronome') && destModule.contains('score')) ||
        (srcModule.contains('tuner') && destModule.contains('score')) ||
        (srcModule.contains('metronome') && destModule.contains('lessons'))) {
      return const SynergyValidationResult.approved(
        isHyperSynergy: true,
        pedagogicalNote:
            'Hiper-Sinergia 1: Lectura en Vuelo y Precisión Rítmico-Tonal (Metrónomo + Pentagrama + Afinador + Tutor).',
      );
    }

    // Hiper-Sinergia 2: Suite Vocal Autotune & Grabación Editada
    if ((srcModule.contains('autotune') && destModule.contains('recorder')) ||
        (srcModule.contains('recorder') && destModule.contains('mixer')) ||
        (srcModule.contains('recorder') && destModule.contains('score_editor'))) {
      return const SynergyValidationResult.approved(
        isHyperSynergy: true,
        pedagogicalNote:
            'Hiper-Sinergia 2: Suite Vocal de Monitoreo Cuantizado, Grabación Multitrack y Edición en Pentagrama.',
      );
    }

    // Hiper-Sinergia 3: Afinador Inteligente con Reconocimiento Tímbrico
    if ((srcModule.contains('acoustic_lab') && destModule.contains('instrument')) ||
        (srcModule.contains('instrument') && destModule.contains('tuner')) ||
        (srcModule.contains('instrument') && destModule.contains('synthesizer'))) {
      return const SynergyValidationResult.approved(
        isHyperSynergy: true,
        pedagogicalNote:
            'Hiper-Sinergia 3: Afinador Inteligente con Calibración de Micrófono, Filtros y Diapasón de Timbre Real.',
      );
    }

    // Hiper-Sinergia 4: Descomponedor Minus-One & Acompañamiento SoundFont
    if ((srcModule.contains('decomposer') && destModule.contains('score')) ||
        (srcModule.contains('decomposer') && destModule.contains('mixer')) ||
        (srcModule.contains('synthesizer') && destModule.contains('mixer'))) {
      return const SynergyValidationResult.approved(
        isHyperSynergy: true,
        pedagogicalNote:
            'Hiper-Sinergia 4: Modo Minus-One con Ensamble Virtual SoundFont y Grabación de Solista Sincronizada.',
      );
    }

    // Hiper-Sinergia 5: Afinación por Batimento & Dron Armónico Justo
    if ((srcModule.contains('drone') && destModule.contains('spectrogram')) ||
        (srcModule.contains('drone') && destModule.contains('tuner')) ||
        (srcModule.contains('tuner') && destModule.contains('spectrogram'))) {
      return const SynergyValidationResult.approved(
        isHyperSynergy: true,
        pedagogicalNote:
            'Hiper-Sinergia 5: Afinación Pura por Batimento Armónico y Visualización Espectral FFT de Resonancia.',
      );
    }

    // Hiper-Sinergia 6: Exploración Polifónica y Temperamentos Históricos
    if ((srcModule.contains('keyboard') && destModule.contains('chord')) ||
        (srcModule.contains('keyboard') && destModule.contains('tuner')) ||
        (srcModule.contains('chord') && destModule.contains('spectrogram'))) {
      return const SynergyValidationResult.approved(
        isHyperSynergy: true,
        pedagogicalNote:
            'Hiper-Sinergia 6: Laboratorio Polifónico de Acordes, Serie Armónica H1-H8 y Temperamentos Históricos.',
      );
    }

    // Conexión regular aprobada
    return const SynergyValidationResult.approved(
      isHyperSynergy: false,
      pedagogicalNote: 'Enlace modular estándar verificado.',
    );
  }
}
