# ADR 0104: Biblioteca Canónica de Scripts Declarativos Tunner DSL (.tun) y Catálogo de Dominio

**Estado:** Aprobado  
**Fecha:** 2026-11-18  
**Contexto Técnico:** Issue #50 (Comunidad - Good First Issue)  
**Autoridad:** Mantenedor Principal (@Nicolas11Leon)  

---

## 1. Contexto

Tras la consolidación del motor declarativo Tunner DSL en la Fase 6, el entorno requería un conjunto de scripts canónicos de referencia que validaran y demostraran las capacidades del lenguaje: modulación de reverberación Schroeder-Moorer, posicionamiento en audio espacial binaural 3D, líneas de bajo ácido de alta velocidad con envolventes sintetizadas cortas, y progresiones modales para entrenamiento pedagógico vocal.

Se evaluaron dos alternativas para almacenar y exponer estas plantillas:
1. **Archivos de activos aislados en disco (`assets/dsl/*.tun`):** Requieren llamadas asíncronas dependientes del framework Flutter (`rootBundle.loadString`) para ser consumidas, impidiendo su uso directo en pruebas puras de Dominio en Dart y en entornos headless sin contexto de Flutter.
2. **Arquitectura Híbrida Dominio/Activo:** Un catálogo inmutable de Dominio en Dart puro (`TunnerDslTemplateCatalog` y entidad `TunnerDslTemplate`) que contiene los scripts canónicos con acceso síncrono y determinista, complementado con archivos `.tun` en `assets/dsl/` para inspección de usuario, edición externa y consumo en la aplicación Flutter.

---

## 2. Decisión

Se adopta la **Arquitectura Híbrida Dominio/Activo**:
1. Se define en la capa de Dominio puro (`lib/core/dsl/domain/tunner_dsl_template_catalog.dart`) el catálogo estático `TunnerDslTemplateCatalog`, garantizando disponibilidad offline, cero dependencias de Flutter UI, y ejecución determinista en pruebas unitarias.
2. Se crean los archivos de script correspondientes en `assets/dsl/`:
   - `assets/dsl/ambient_chords.tun`: Modulación de reverberación Schroeder-Moorer espacial y acordes modales polifónicos.
   - `assets/dsl/acid_bassline.tun`: Tempo a 135 BPM, envolventes ADSR ultrarrápidas y patrones en bucle.
   - `assets/dsl/vocal_warmup_routine.tun`: Rutina de vocalización diatónica con transposición ascendente.
3. Se integran los comandos `dsl list`, `dsl templates` y `dsl load <id>` en el kernel de la terminal `TunnerOsKernel`.
4. Se registra el directorio `assets/dsl/` en `pubspec.yaml`.

---

## 3. Consecuencias

### Consecuencias Positivas
- **Independencia de Framework:** El catálogo puede ser instanciado y evaluado en pruebas unitarias puras de Dart sin depender de inicializaciones de Flutter (`rootBundle`).
- **Usabilidad Inmediata en CLI:** Cualquier usuario o desarrollador puede explorar y disparar las configuraciones canónicas escribiendo un comando conciso en la terminal integrada.
- **Validación Sintáctica Integral:** Los scripts canónicos forman parte de la suite de pruebas unitarias continuas, impidiendo cualquier regresión sintáctica futura en el parser o lexer de Tunner DSL.

### Consecuencias Negativas / Mitigaciones
- **Duplicación de Texto de Scripts:** El código DSL vive tanto en el catálogo de Dominio como en los archivos `.tun` en `assets/`.
  - *Mitigación:* Se implementa una prueba unitaria de regresión que verifica la estricta correspondencia entre el contenido de `assets/dsl/` y las plantillas provistas por `TunnerDslTemplateCatalog`.
