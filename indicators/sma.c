#include <stddef.h>
#include "sma.h"

// Initialize SMA struct with external memory buffer
void sma_init(SMAWindow *sma, double *buffer, int window_size) {
    sma->window = buffer;
    sma->capacity = window_size;
    sma->count = 0;
    sma->head = 0;
}

// Insert price into circular buffer
void sma_update(SMAWindow *sma, double price) {
    sma->window[sma->head] = price;
    sma->head = (sma->head + 1) % sma->capacity;

    if (sma->count < sma->capacity) {
        sma->count++;
    }
}

// Returns 1 when window has N elements
int sma_is_full(const SMAWindow *sma) {
    return sma->count == sma->capacity;
}

// Re-sum clean elements directly from RAM buffer (drift-free)
double sma_calculate_naive(const SMAWindow *sma) {
    if (!sma_is_full(sma)) {
        return 0.0;
    }

    double sum = 0.0;
    for (int i = 0; i < sma->capacity; i++) {
        sum += sma->window[i];
    }
    return sum / sma->capacity;
}