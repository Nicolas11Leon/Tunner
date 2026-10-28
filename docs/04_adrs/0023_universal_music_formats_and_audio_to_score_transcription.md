# ADR 0023: Centro Universal de Formatos Musicales & Transcripción de Audio a Partitura

- **Estado:** Approved
- **Fecha:** 2026-10-27
- **Fase:** Fase 8

---

## 1. Contexto

La plataforma Tunner contaba con decodificadores para MusicXML plano y MIDI estándar, así como exportadores a MusicXML y MIDI. Sin embargo, los flujos de trabajo de conservatorio y producción musical contemporáneos requieren:
1. Capacidad de abrir partituras en **Compressed MusicXML (`.mxl`)**, el estándar más común de distribución de partituras en bibliotecas digitales como IMSLP.
2. Soporte para **ABC Notation (`.abc`)**, formato estándar en comunidades folk, barrocas y pedagógicas por su extrema ligereza y legibilidad humana.
3. Posibilidad de **convertir archivos de audio digital (WAV/PCM) directamente a partituras estructuradas** de forma totalmente offline, democratizando la transcripción sin depender de servicios en la nube privativos.

---

## 2. Decisión Arquitectónica

1. **Descompresión en Memoria con `archive`:**
   Integrar el paquete puramente Dart `archive` para inspeccionar y descomprimir archivos `.mxl` en memoria sin almacenar archivos temporales en disco. El parser extrae la ruta indicada en `META-INF/container.xml` y la reenvía a `MusicXmlScoreParser`.
2. **Parser y Exportador ABC Notation en Dominio Puro:**
   Construir `AbcScoreParser` y `CanonicalAbcExporter` en `lib/features/universal_importer/` como componentes puros sin dependencias de Flutter, con mapeo exacto de armaduras, octavas y figuras métricas.
3. **Motor de Transcripción de Audio Offline (`AudioToScoreTranscriptionEngine`):**
   Aprovechar la implementación de `McleodPitchMethod` (MPM) con ventana deslizante de 2048 muestras y salto de 512 muestras. Se cuantizan las duraciones en milisegundos mediante `RhythmicQuantizer` para producir compases y notas normalizadas `HierarchicalScore`.
4. **Patrón Strategy y Chain of Responsibility en `UniversalScoreImporterService`:**
   El servicio orquestador inspecciona extensiones y firmas mágicas (PK para ZIP/MXL, MThd para MIDI, XML tags para MusicXML, cabeceras X:/T:/K: para ABC, RIFF para audio) despachando al decodificador óptimo.

---

## 3. Consecuencias

### Positivas
- Soporte para los formatos de notación más extendidos del mundo (MusicXML, MXL, MIDI, ABC).
- Transcripción bidireccional completa: Partitura a Audio (Síntesis) y Audio a Partitura (Transcripción offline MPM).
- Rendimiento determinista 100% offline sin telemetría ni latencia de red.

### Negativas / Mitigaciones
- La transcripción monofónica por MPM puede producir errores si el audio contiene polifonía compleja o acompañamiento denso. Mitigación: se aplica umbral estricto de claridad armónica ($NSDF \ge 0.65$) y compuerta de ruido RMS.
