import 'instrument_profile_entity.dart';
import 'universal_instrument_definition.dart';
import 'universal_instrument_taxonomy.dart';

/// Puente bidireccional en Pure Dart que unifica el catalogo universal
/// `UniversalInstrumentDefinition.masterCatalog` con los perfiles clasicos
/// `InstrumentProfileEntity.standardInstruments`, exponiendo serializacion JSON
/// canonica para el servidor MCP.
class InstrumentCatalogBridge {
  const InstrumentCatalogBridge();

  static const Map<String, String> _legacyToUniversalId = {
    'flute': 'aerophone.woodwind.flute_concert_c',
    'piccolo': 'aerophone.woodwind.piccolo_c',
    'oboe': 'aerophone.woodwind.oboe_c',
    'english_horn': 'aerophone.woodwind.english_horn_f',
    'bb_clarinet': 'aerophone.woodwind.clarinet_bb',
    'bassoon': 'aerophone.woodwind.bassoon_c',
    'soprano_sax': 'aerophone.woodwind.sax_soprano_bb',
    'eb_alto_sax': 'aerophone.woodwind.sax_alto_eb',
    'bb_tenor_sax': 'aerophone.woodwind.sax_tenor_bb',
    'eb_baritone_sax': 'aerophone.woodwind.sax_baritone_eb',
    'bb_trumpet': 'aerophone.brass.trumpet_bb',
    'f_horn': 'aerophone.brass.french_horn_f',
    'trombone': 'aerophone.brass.trombone_tenor',
    'tuba': 'aerophone.brass.tuba_c',
    'violin': 'chordophone.bowed_strings.violin_acoustic',
    'viola': 'chordophone.bowed_strings.viola_acoustic',
    'cello': 'chordophone.bowed_strings.cello_acoustic',
    'double_bass': 'chordophone.bowed_strings.double_bass_acoustic',
    'guitar': 'chordophone.plucked_strings.guitar_classical',
    'electric_guitar': 'chordophone.plucked_strings.guitar_electric',
    'electric_bass': 'chordophone.plucked_strings.bass_electric_4str',
    'ukulele': 'chordophone.plucked_strings.ukulele_soprano',
    'grand_piano': 'chordophone.keyboard.piano_grand_acoustic',
    'harpsichord': 'chordophone.keyboard.harpsichord_baroque',
    'concert_marimba': 'idiophone.pitched_percussion.marimba_concert',
    'vibraphone': 'idiophone.pitched_percussion.vibraphone_jazz',
    'glockenspiel': 'idiophone.pitched_percussion.glockenspiel_orchestral',
    'acoustic_drum_kit': 'membranophone.acoustic_drums.standard_kit',
    'snare_drum': 'membranophone.acoustic_drums.snare_drum',
    'orchestral_timpani': 'membranophone.acoustic_drums.timpani_orchestral',
    'congas': 'membranophone.latin_percussion.congas_set',
    'voice_soprano': 'vocal.human.voice_soprano',
    'voice_bass': 'vocal.human.voice_bass',
    'synth_lead': 'electrophone.synthesizer.lead_sawtooth',
    'kora': 'chordophone.plucked_strings.kora_west_african',
    'sitar': 'chordophone.plucked_strings.sitar_indian',
    'shakuhachi': 'aerophone.woodwind.shakuhachi_japan',
    'charango': 'chordophone.plucked_strings.charango_andean',
    'cuatro': 'chordophone.plucked_strings.cuatro_venezuelan',
  };

  static final Map<String, String> _universalToLegacyId = {
    for (final entry in _legacyToUniversalId.entries) entry.value: entry.key,
  };

  /// Retorna el `universalId` asociado a un `legacyProfileId`, o `null` si no existe.
  static String? universalIdForLegacyId(String legacyProfileId) =>
      _legacyToUniversalId[legacyProfileId];

  /// Retorna el `legacyProfileId` asociado a un `universalId`, o `null` si no existe.
  static String? legacyIdForUniversalId(String universalId) =>
      _universalToLegacyId[universalId];

  /// Busca una definicion universal a partir de su `universalId` o de su `legacyProfileId`.
  static UniversalInstrumentDefinition? findUniversalByAnyId(String id) {
    final direct = UniversalInstrumentDefinition.findById(id);
    if (direct != null) return direct;
    final mappedUniversalId = _legacyToUniversalId[id];
    if (mappedUniversalId == null) return null;
    return UniversalInstrumentDefinition.findById(mappedUniversalId);
  }

  /// Busca un perfil clasico a partir de su `legacyProfileId` o de su `universalId`.
  static InstrumentProfileEntity? findProfileByAnyId(String id) {
    for (final profile in InstrumentProfileEntity.standardInstruments) {
      if (profile.id == id) return profile;
    }
    final mappedLegacyId = _universalToLegacyId[id];
    if (mappedLegacyId != null) {
      for (final profile in InstrumentProfileEntity.standardInstruments) {
        if (profile.id == mappedLegacyId) return profile;
      }
    }
    final universal = UniversalInstrumentDefinition.findById(id);
    if (universal != null) {
      return toProfile(universal);
    }
    return null;
  }

  /// Convierte un `UniversalInstrumentDefinition` en su `InstrumentProfileEntity`
  /// equivalente (retornando la instancia canonica si existe o sintetizando una compatible).
  static InstrumentProfileEntity toProfile(UniversalInstrumentDefinition definition) {
    final legacyId = _universalToLegacyId[definition.universalId];
    if (legacyId != null) {
      for (final profile in InstrumentProfileEntity.standardInstruments) {
        if (profile.id == legacyId) return profile;
      }
    }

    return InstrumentProfileEntity(
      id: legacyId ?? definition.universalId,
      name: definition.displayName,
      family: _mapToLegacyFamily(definition.category, definition.subfamily),
      key: definition.tuningKey,
      clef: definition.notationClef,
      transpositionSemitones: definition.transpositionSemitones,
      minFrequencyHz: definition.acousticRange.minFrequencyHz,
      maxFrequencyHz: definition.acousticRange.maxFrequencyHz,
    );
  }

  /// Convierte un `InstrumentProfileEntity` a su `UniversalInstrumentDefinition`
  /// canonico cuando exista correspondencia directa en `masterCatalog`.
  static UniversalInstrumentDefinition? toUniversal(InstrumentProfileEntity profile) {
    return findUniversalByAnyId(profile.id);
  }

  static InstrumentFamily _mapToLegacyFamily(
    HornbostelSachsCategory category,
    InstrumentSubfamily subfamily,
  ) {
    if (category == HornbostelSachsCategory.vocal) {
      return InstrumentFamily.vocals;
    }
    if (subfamily == InstrumentSubfamily.brass) {
      return InstrumentFamily.brass;
    }
    if (category == HornbostelSachsCategory.aerophone) {
      return InstrumentFamily.woodwinds;
    }
    if (category == HornbostelSachsCategory.chordophone &&
        subfamily != InstrumentSubfamily.keyboardChordophone) {
      return InstrumentFamily.strings;
    }
    return InstrumentFamily.percussion;
  }

  /// Serializa un `UniversalInstrumentDefinition` en JSON canonico MCP.
  static Map<String, dynamic> universalToJson(UniversalInstrumentDefinition def) {
    return {
      'universalId': def.universalId,
      'legacyProfileId': legacyIdForUniversalId(def.universalId),
      'displayName': def.displayName,
      'searchKeywords': List<String>.from(def.searchKeywords),
      'category': def.category.name,
      'categoryCode': def.category.code,
      'subfamily': def.subfamily.name,
      'subfamilyCode': def.subfamily.code,
      'tuningKey': def.tuningKey.name,
      'notationClef': def.notationClef.name,
      'transpositionSemitones': def.transpositionSemitones,
      'isTransposing': def.isTransposing,
      'generalMidiNumber': def.generalMidiNumber,
      'isDrumMapPercussion': def.isDrumMapPercussion,
      'acousticRange': {
        'minFrequencyHz': def.acousticRange.minFrequencyHz,
        'maxFrequencyHz': def.acousticRange.maxFrequencyHz,
        'minMidiNote': def.acousticRange.minMidiNote,
        'maxMidiNote': def.acousticRange.maxMidiNote,
        'standardTuningFrequencies': List<double>.from(def.acousticRange.standardTuningFrequencies),
        'standardTuningNoteNames': List<String>.from(def.acousticRange.standardTuningNoteNames),
      },
      'timbralProfile': {
        'adsr': {
          'attackMs': def.timbralProfile.adsr.attackMs,
          'decayMs': def.timbralProfile.adsr.decayMs,
          'sustainLevel': def.timbralProfile.adsr.sustainLevel,
          'releaseMs': def.timbralProfile.adsr.releaseMs,
        },
        'harmonicOvertoneAmplitudes': List<double>.from(def.timbralProfile.harmonicOvertoneAmplitudes),
        'noiseTransientRatio': def.timbralProfile.noiseTransientRatio,
        'resonanceFactor': def.timbralProfile.resonanceFactor,
      },
      'visualRendererType': def.visualProfile.rendererType.name,
    };
  }

  /// Serializa un `InstrumentProfileEntity` en JSON canonico MCP.
  static Map<String, dynamic> profileToJson(InstrumentProfileEntity profile) {
    return {
      'id': profile.id,
      'universalId': universalIdForLegacyId(profile.id),
      'name': profile.name,
      'family': profile.family.name,
      'key': profile.key.name,
      'clef': profile.clef.name,
      'transpositionSemitones': profile.transpositionSemitones,
      'isTransposing': profile.isTransposing,
      'minFrequencyHz': profile.minFrequencyHz,
      'maxFrequencyHz': profile.maxFrequencyHz,
    };
  }

  /// Serializa el catalogo unificado completo listo para `tunner://catalog/instruments`.
  Map<String, dynamic> toJson() {
    final universalItems = UniversalInstrumentDefinition.masterCatalog
        .map(universalToJson)
        .toList();
    final legacyOnlyProfiles = InstrumentProfileEntity.standardInstruments
        .where((p) => !_legacyToUniversalId.containsKey(p.id))
        .map(profileToJson)
        .toList();

    return {
      'count': universalItems.length,
      'legacyCount': InstrumentProfileEntity.standardInstruments.length,
      'instruments': universalItems,
      'legacyOnlyProfiles': legacyOnlyProfiles,
    };
  }
}
