#include <stddef.h>
#include "sma.h"

// Initialize SMA struct with external memory buffer
void sma_init(SMAWindow *sma, double *buffer, int window_size) {
    sma->window = buffer;
    sma->capacity = window_size;
    sma->count = 0; // using it to keep track of the number of N
    sma->head = 0;  // using it to go to the next pointer to store the next trade
    sma->running_sum=0.0;
}

// Insert price into circular buffer
void sma_update(SMAWindow *sma, double price) {
    
    if (sma->count >= sma->capacity) {
        // Window is FULL: Subtract the oldest price leaving the window
        // (which is currently stored at sma->head before we overwrite it)
        sma->running_sum -= sma->window[sma->head];
    } else {
        sma->count++;
    }

    sma->window[sma->head] = price;
    sma->head = (sma->head + 1) % sma->capacity;

    sma->running_sum += price;
}

// Returns 1 when window has N elements
int sma_is_full(const SMAWindow *sma) {
    return sma->count == sma->capacity;
}

// Re-sum clean elements directly from RAM buffer (drift-free)
// time complexity of O(N)
/*

What is N?
    : referring to the window
    : number of consecutive trades in the average
    : group 9 -> short:15 long:100 

    so basically SMA is 
    if SMA is 2:
        price1 + price2 / 2 which is N

*/
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



double sma_calculate_running(const SMAWindow *sma){
    if (!sma_is_full(sma)) {
        return 0.0;
    }
    
    return sma->running_sum / (double)sma->count;


}