#include "vwap.h"

// Initialize running sums to 0.0
void vwap_init(VWAPState *state) {
    state->sum_price_qty = 0.0;
    state->sum_qty = 0.0;
}

// Accumulate price * qty and total qty for each trade
void vwap_update(VWAPState *state, double price, double qty) {
    state->sum_price_qty += (price * qty); //[cite: 10]
    state->sum_qty += qty;                 //[cite: 10]
}

// Compute current VWAP
double vwap_get(const VWAPState *state) {
    if (state->sum_qty == 0.0) {
        return 0.0; // Avoid division by zero
    }
    return state->sum_price_qty / state->sum_qty; //[cite: 10]
}