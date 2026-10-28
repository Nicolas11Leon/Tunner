# ADR 0030: Motor de Perfiles Pedagógicos Adaptativos y Andamiaje Instruccional Dinámico

## Estado
Aprobado

## Contexto
Tunner comenzó como un afinador y motor de partituras de estudio con rigor acústico de conservatorio. Sin embargo, a medida que la plataforma amplía su impacto educativo, se enfrenta a dos perfiles de usuarios diametralmente opuestos a los músicos profesionales:
1. **Población Infantil:** Niños que requieren exploración sensorial, baja tolerancia a la frustración, andamiaje auditivo (*Audiation* / Gordon) y ausencia de métricas numéricas complejas que saturan su memoria de trabajo sensoriomotriz.
2. **Adultos Principiantes / Autodidactas:** Sujetos a severo juicio interno, miedo al ridículo y parálisis por análisis derivada de una sobreabundancia de datos técnicos (cents, armónicos, FFT). Este grupo demanda explicaciones racionales del error ("por qué desafino"), pautas biomecánicas reconstructivas y una reducción drástica de la carga cognitiva extraña (Sweller, Knowles, Dweck).

La arquitectura existente operaba con tolerancias fijas de conservatorio ($\pm 5\text{ cents}$) y una presentación uniforme que resultaba abrumadora para principiantes o rígida para infantes. Se requería un motor que adaptara dinámicamente las tolerancias acústicas, las reglas de retroalimentación formativa y la densidad visual del sistema sin romper el desacoplamiento de Clean Architecture.

## Decisión
1. **Entidades Inmutables de Dominio en Pure Dart:**
   - Crear `LearnerProfileType` (enum con `childPlayful`, `adultDeliberate`, `conservatoryMastery`, `custom`).
   - Crear `LearnerProfileEntity` con propiedades de tolerancia en cents (`centsTolerance`), estilo de retroalimentación (`FeedbackStyle`), densidad visual (`VisualDensityLevel`) y modo de andamiaje activo.
2. **Motor de Andamiaje Adaptativo (`AdaptiveScaffoldingEngine`):**
   - Servicio puro de dominio que evalúa en tiempo real las desviaciones microtonales y genera diagnósticos pedagógicos calibrados:
     - Para niños: mensajes de aliento y metáforas espaciales/auditivas.
     - Para adultos: pautas biomecánicas directas (apoyo diafragmático, relajación de la mandíbula, apertura de resonadores).
     - Para conservatorio: análisis cuantitativo de cents y estabilidad de armónicos.
3. **Persistencia Local Determinista:**
   - Extender `AppUserSettingsEntity` y `JsonLocalPersistenceService` para almacenar el perfil pedagógico preferido de forma 100% offline.
4. **Capa de Presentación Reactiva:**
   - Diseñar `LearnerProfileSelectorModal` con tarjetas explicativas andragógicas e infantiles.
   - Conectar con `TunerViewModel` para que la aguja estroboscópica, el evaluador de notas y las tarjetas informativas reflejen los umbrales del perfil activo.

## Consecuencias

### Positivas
- Democratización absoluta de la plataforma: un niño de 6 años, un adulto de 45 años y un flautista de orquesta sinfónica encuentran una experiencia diseñada a la medida exacta de su perfil cognitivo.
- Reducción sustancial de la tasa de deserción en adultos mediante retroalimentación no punitiva de Mentalidad de Crecimiento.
- Fomento de la exploración intuitiva en niños sin frustración temprana.
- 0 dependencias externas y 100% testeable en Pure Dart.

### Negativas / Mitigaciones
- Un perfil infantil con tolerancia demasiado amplia ($\pm 25\text{ cents}$) podría consolidar malos hábitos de entonación a largo plazo.
  *Mitigación:* Se implementa un mecanismo de andamiaje progresivo (*scaffolding fade-out*): a medida que el niño acumula aciertos consecutivos, la tolerancia se va reduciendo suavemente hacia $\pm 15\text{ cents}$, guiándolo sin estrés hacia la precisión de conservatorio.
