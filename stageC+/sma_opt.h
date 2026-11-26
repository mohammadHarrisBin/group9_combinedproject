#ifndef SMA_OPT_H
#define SMA_OPT_H

typedef struct {
    double *window;   // The memory array (holds the price data, e.g. short_buf or long_buf)
    int capacity;     // Window size (e.g. 15 for Short, 100 for Long)
    int count;        // Total elements stored so far
    int head;         // Current insertion index
    double running_sum;  // sum of elements in the window 
} SMAWindow;

static inline void sma_store_price(SMAWindow *sma, double price) {
    sma->window[sma->head] = price;
    if (++sma->head == sma->capacity) {
        sma->head = 0;
    }
    sma->running_sum += price;
}

// Use once the window is full.
static inline void sma_update_full(SMAWindow *sma, double price) {
    sma->running_sum -= sma->window[sma->head];
    sma_store_price(sma, price);
}

void sma_init(SMAWindow *sma, double *buffer, int window_size);
void sma_update(SMAWindow *sma, double price);
int sma_is_full(const SMAWindow *sma);
double sma_calculate_naive(const SMAWindow *sma); 
double sma_calculate_running(const SMAWindow *sma); // STAGE B SMA comparisons

#endif /* SMA_OPT_H */