# ADR-0022: Motor de Tap Tempo Determinista con Filtrado de Jitter y Diagnóstico de Precisión Métrica

- **Estado:** Approved
- **Fecha:** 2026-10-27
- **Fase:** Fase 7.5 (Vanguardia Acústica y Conservatorio)
- **Autor:** Antigravity / Nicolas Leon

---

## 1. Contexto

La capacidad de fijar el tempo de un metrónomo marcando el pulso con el dedo ("Tap Tempo") es una herramienta estándar en metrónomos digitales profesionales y estaciones de trabajo de audio (DAWs).

Sin embargo, los algoritmos convencionales de Tap Tempo adolecen de:
1. **Inestabilidad por jitter humano:** La motricidad humana introduce fluctuaciones naturales de entre $10\text{ ms}$ y $50\text{ ms}$ entre pulsaciones consecutivas. Un promedio simple sobre pocos toques produce saltos bruscos en el BPM.
2. **Falta de retroalimentación pedagógica:** No informan al instrumentista sobre su regularidad rítmica interna, desperdiciando una valiosa oportunidad pedagógica para estudiantes de conservatorio.
3. **Persistencia de búfer indefinida:** Si el usuario pulsa un botón una vez y vuelve a tocarlo 10 segundos después, muchos afinadores calculan un intervalo erróneo de 10 segundos en lugar de reiniciar la sesión.

---

## 2. Decisión

Implementar un motor determinista en el Dominio puro (`TapTempoEngine`):
1. **Ventana Móvil Ponderada Linealmente (Weighted Moving Average):**
   - Mantiene los últimos $K \le 8$ intervalos inter-pulsación ($\Delta t_i$).
   - Asigna pesos crecientes $w_i = i + 1$ para dar mayor relevancia a las pulsaciones más recientes:
     $$\overline{\Delta t} = \frac{\sum_{i=1}^{M} w_i \cdot \Delta t_i}{\sum_{i=1}^{M} w_i}$$
     $$\text{BPM} = \text{round}\left(\frac{60000}{\overline{\Delta t}}\right)$$
2. **Evaluación de Jitter y Estabilidad Rítmica:**
   - Calcula la desviación estándar muestral en milisegundos:
     $$\sigma = \sqrt{\frac{1}{M-1} \sum_{i=1}^M (\Delta t_i - \overline{\Delta t})^2}$$
   - Clasifica la regularidad del usuario en cuatro niveles pedagógicos:
     - $\sigma \le 15\text{ ms}$: "Metronómico"
     - $\sigma \le 35\text{ ms}$: "Excelente"
     - $\sigma \le 60\text{ ms}$: "Regular"
     - $\sigma > 60\text{ ms}$: "Fluctuante"
3. **Reinicio por Inactividad (Auto-Reset Timeout):**
   - Si transcurren más de $2500\text{ ms}$ entre dos toques sucesivos, el búfer de intervalos se limpia de forma determinista y transparente.
4. **Sincronización Inmediata con el Metrónomo:**
   - Cada toque válido a partir del segundo ajusta instantáneamente el oscilador del metrónomo sin detener la reproducción.

---

## 3. Consecuencias

### Positivas
- Calibración rápida de tempo con un promedio suave y libre de brincos erráticos.
- Valioso diagnóstico cuantitativo de regularidad rítmica para estudiantes de conservatorio.
- Cero fugas de memoria o procesos asíncronos en espera ocupada.
- Cumplimiento de la Definición de Hecho (DoD) de la Fase 7.5.

### Negativas / Mitigaciones
- La desviación estándar requiere al menos 3 pulsaciones para ser estadísticamente significativa: mitigado mostrando "Calibrando..." durante los dos primeros toques.
