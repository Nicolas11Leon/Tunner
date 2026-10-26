# ADR-0007: Adaptive Aesthetic Theming Engine and User Customization Model

---

## Metadatos del Registro

- **ID del Registro:** `ADR-0007`
- **Título:** `Motor de Estéticas Adaptables y Modelo Abierto de Personalización de Usuario`
- **Estado:** `Approved`
- **Fecha de Decisión:** `2026-10-26`
- **Fase Asociada:** `Fase 2 & Global`
- **Autor / Arquitecto:** `Nicolas Leon (Mantenedor Principal)`
- **Casos de Uso Relacionados:** `docs/02_use_cases/11_uc_adaptive_aesthetic_theming_and_user_customization.md`

---

## 1. Contexto y Problemática

El diseño visual de una herramienta de práctica musical y afinación crítica tiene un impacto directo sobre la ergonomía visual del músico, la fatiga ocular durante sesiones prolongadas y la legibilidad en diversos entornos físicos:
1. **Entornos Físicos Variables:** Mientras que un fondo oscuro/negro es ideal para estudios de grabación acústica o escenarios oscuros, un ambiente exterior o aula de conservatorio con luz solar directa requiere un modo claro de alta luminosidad y contraste nítido (*Nordic Frost / Daylight*).
2. **Preferencias Sensoriales Diversas:** Los usuarios aprecian profundamente el acabado negro actual (*Obsidian Studio* y *OLED Pure Black*), pero demandan paletas para todos los gustos: acústicas tipo madera de luthier, clásico pergamino de archivo, zafiro orquestal o sintetizador neón.
3. **Rigidez Previa de la Arquitectura:** Los temas estaban acoplados a un `enum TunnerThemeMode` estático cerrado con 4 valores inmutables. El usuario no contaba con un modelo que le permitiese crear, personalizar, clonar, exportar o importar temas propios.
4. **Falla de Contraste en Componentes Visuales:** Widgets clave como `StrobeTunerWidget`, `RealSheetMusicPainter` y modales utilizaban colores estáticos fijos (`Colors.white`, `Colors.white24`), que se volvían ilegibles en temas con fondos claros o pergamino.

---

## 2. Decisión Arquitectónica

Se aprueba la reestructuración completa del sistema de tematización estética hacia una arquitectura modular abierta:

1. **Evolución del Dominio (`lib/core/theme/`):**
   - **`TunnerThemePalette` como Modelo de Entidad Dinámica:**
     - Identificador único (`String id`), nombre descriptivo (`String displayName`), indicador de personalización (`bool isCustom`) y luminosidad (`Brightness brightness`).
     - Tokens semánticos completos para el lienzo musical (`staffBackground`, `staffLinesColor`, `musicalSymbolsColor`, `playheadColor`), afinador (`correctPitchColor`, `warningPitchColor`, `errorPitchColor`), tarjetas y tipografías (`textColor`, `textMutedColor`).
     - Getters de contraste semántico (`surfaceBorderColor`, `surfaceHighlightColor`, `onPrimaryColor`).
     - Serialización/Deserialización completa en JSON (`toJson()`, `fromJson()`) para permitir el intercambio de temas entre usuarios.
   - **Colección Curada de Presets Maestros (7 Estéticas):**
     1. `Obsidian Studio` (Grafito oscuro, esmeralda y oro acústico).
     2. `OLED Pure Black` (Negro $0\times000000$ absoluto para pantallas AMOLED).
     3. `Royal Symphony` (Azul marino orquestal de medianoche, zafiro brillante y oro regio).
     4. `Acoustic Wood` (Madera de luthier en palisandro y nogal cálido, cedro ámbar).
     5. `Cyberpunk Synthwave` (Índigo profundo con magenta eléctrico y cian neón).
     6. `Vintage Conservatory Parchment` (Pergamino sepia clásico con tinta carbón).
     7. `Nordic Frost` (Modo claro minimalista para exteriores y luz solar intensa).

2. **Gestión de Estado en `TunerViewModel`:**
   - Exposición de `currentPalette` y lista de paletas disponibles `availablePalettes` (presets + temas creados por el usuario).
   - Métodos atómicos: `setPalette()`, `addCustomPalette()`, `updateCustomPalette()`, `deleteCustomPalette()`, `importPaletteFromJson()`.
   - Compatibilidad retroactiva total con el getter `themeMode` y el método `setThemeMode()`.

3. **Módulo de UI "Theme Customization Studio":**
   - Modal de selección visual con previsualización cromática en tiempo real de los swatches principales.
   - Diálogo interactivo "Theme Studio": Permite al usuario crear un tema desde cero o basado en un preset, editar nombre, elegir base de contraste (OLED, Oscuro, Madera, Claro), elegir acento de color de una paleta armónica, y previsualizar en vivo el afinador y el pentagrama antes de guardar.
   - Exportador/Importador JSON integrado para compartir paletas fácilmente.

4. **Eliminación de Colores Estáticos en Componentes:**
   - Migración de `Colors.white` o `Colors.white24` en `StrobeTunerWidget` y `RealSheetMusicPainter` hacia los tokens semánticos de `TunnerThemePalette`, garantizando legibilidad perfecta en cualquier tema claro u oscuro.

---

## 3. Consecuencias y Beneficios

### Positivas:
- **Autonomía del Usuario:** Los usuarios pueden diseñar y editar temas con total facilidad sin tocar una sola línea de código fuente.
- **Portabilidad:** Los temas se pueden exportar e importar instantáneamente mediante cadenas JSON.
- **Calidad Visual de Nivel de Conservatorio:** Se preserva el amor por los fondos negros profundos a la vez que se provee soporte impecable para luz diurna e identidades estéticas alternativas.
- **Cero Regresiones:** 100% retrocompatible con tests unitarios y llamadas existentes a `TunnerThemeMode`.
- **Rendimiento Óptimo:** La conmutación de paletas no destruye ni recrea el estado del Isolate de audio ni del metrónomo, operando en menos de un fotograma ($<16\text{ ms}$).
