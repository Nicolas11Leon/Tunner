#include "tunner_dsp.h"
#include <stddef.h>

void tunner_apply_gain(float* buffer, int length, float gain) {
    if (buffer == NULL || length <= 0) {
        return;
    }

    int i = 0;
    /* Desenrollado de bucle para habilitar vectorizacion SIMD (SSE/AVX/NEON) */
    for (; i + 3 < length; i += 4) {
        buffer[i]     *= gain;
        buffer[i + 1] *= gain;
        buffer[i + 2] *= gain;
        buffer[i + 3] *= gain;
    }

    /* Muestras remanentes del bufer */
    for (; i < length; i++) {
        buffer[i] *= gain;
    }
}

void tunner_vector_sum(const float* a, const float* b, float* out, int length) {
    if (a == NULL || b == NULL || out == NULL || length <= 0) {
        return;
    }

    int i = 0;
    /* Desenrollado de bucle para optimizacion de sumas vectoriales en paralelo */
    for (; i + 3 < length; i += 4) {
        out[i]     = a[i]     + b[i];
        out[i + 1] = a[i + 1] + b[i + 1];
        out[i + 2] = a[i + 2] + b[i + 2];
        out[i + 3] = a[i + 3] + b[i + 3];
    }

    /* Muestras remanentes */
    for (; i < length; i++) {
        out[i] = a[i] + b[i];
    }
}

void tunner_autocorrelate(const float* input, int input_length, float* output, int output_length) {
    if (input == NULL || output == NULL || input_length <= 0 || output_length <= 0) {
        return;
    }

    for (int lag = 0; lag < output_length; lag++) {
        if (lag >= input_length) {
            output[lag] = 0.0f;
            continue;
        }

        double sum = 0.0;
        int limit = input_length - lag;
        int i = 0;

        /* Desenrollado de bucle para multiplicacion y acumulacion vectorial (FMA) en doble precision */
        for (; i + 3 < limit; i += 4) {
            sum += (double)input[i]     * (double)input[i + lag]
                 + (double)input[i + 1] * (double)input[i + 1 + lag]
                 + (double)input[i + 2] * (double)input[i + 2 + lag]
                 + (double)input[i + 3] * (double)input[i + 3 + lag];
        }

        /* Muestras remanentes del calculo de lag */
        for (; i < limit; i++) {
            sum += (double)input[i] * (double)input[i + lag];
        }

        output[lag] = (float)sum;
    }
}
