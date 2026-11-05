#ifndef SMA_H
#define SMA_H

typedef struct {
    double *window;   // Pointer to price buffer array
    int capacity;     // Window size (e.g. 15 for Short, 100 for Long)
    int count;        // Total elements stored so far
    int head;         // Current insertion index
} SMAWindow;

void sma_init(SMAWindow *sma, double *buffer, int window_size);
void sma_update(SMAWindow *sma, double price);
int sma_is_full(const SMAWindow *sma);
double sma_calculate_naive(const SMAWindow *sma);

#endif /* SMA_H */