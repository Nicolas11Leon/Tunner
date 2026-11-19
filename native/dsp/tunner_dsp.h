#ifndef TUNNER_DSP_H
#define TUNNER_DSP_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32) || defined(_WIN64)
    #define TUNNER_EXPORT __declspec(dllexport)
#else
    #define TUNNER_EXPORT __attribute__((visibility("default")))
#endif

/**
 * Aplica una ganancia lineal uniforme al búfer de audio en punto flotante de 32 bits.
 * Optimizado para vectorización SIMD desenrollando el bucle en bloques de 4 elementos.
 *
 * @param buffer Puntero a las muestras continuas de audio.
 * @param length Numero total de muestras en el bufer.
 * @param gain Factor multiplicador de ganancia lineal.
 */
TUNNER_EXPORT void tunner_apply_gain(float* buffer, int length, float gain);

/**
 * Calcula la suma vectorial lineal de dos senales de audio de 32 bits (out = a + b).
 * Optimizado para vectorización SIMD desenrollando el bucle en bloques de 4 elementos.
 *
 * @param a Puntero al primer bufer de entrada.
 * @param b Puntero al segundo bufer de entrada.
 * @param out Puntero al bufer de salida preasignado.
 * @param length Numero total de elementos a procesar.
 */
TUNNER_EXPORT void tunner_vector_sum(const float* a, const float* b, float* out, int length);

/**
 * Realiza la autocorrelación directa en el dominio temporal para estimación de pitch.
 * Suma acumulada de productos cruzados optimizada para operaciones vectoriales.
 *
 * @param input Puntero a la senal de audio de entrada.
 * @param input_length Tamano del bufer de entrada.
 * @param output Puntero al bufer de salida que almacenara los coeficientes de correlacion.
 * @param output_length Cantidad de retardos (lags) a calcular.
 */
TUNNER_EXPORT void tunner_autocorrelate(const float* input, int input_length, float* output, int output_length);

#ifdef __cplusplus
}
#endif

#endif /* TUNNER_DSP_H */
