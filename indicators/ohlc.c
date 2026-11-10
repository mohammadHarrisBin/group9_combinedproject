#include "ohlc.h"
#include <stddef.h>  // Defines NULL

void ohlc_init(OHLCState *state) {
    state->current_second = -1;
    state->open = 0.0;
    state->high = 0.0;
    state->low = 0.0;
    state->close = 0.0;
    state->has_data = 0;
}

// Returns 1 when a 1-second bar completes (moves to a new second), 0 otherwise
int ohlc_update(OHLCState *state, long long ts_us, double price, OHLCState *completed_bar) {
    // Convert microseconds to whole seconds[cite: 6]
    long long sec = ts_us / 1000000LL; 

    // First trade processed
    if (state->current_second == -1) {
        state->current_second = sec;
        state->open = price;
        state->high = price;
        state->low = price;
        state->close = price;
        state->has_data = 1;
        // means the bar is still incomplete
        // not 1 second yet
        return 0;
    }

    // New second detected -> complete previous bar
    if (sec != state->current_second) {
        if (completed_bar != NULL) {
            *completed_bar = *state; // Copy completed bar out
        }

        // Start new bar for the new second
        state->current_second = sec;
        state->open = price;
        state->high = price;
        state->low = price;
        state->close = price;
        state->has_data = 1;
        return 1; // Signal bar completion
    }

    // Same second -> update high, low, close
    if (price > state->high) state->high = price;
    if (price < state->low)  state->low = price;
    state->close = price;

    return 0;
}