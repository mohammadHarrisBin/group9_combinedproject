#include <stddef.h>
#include "signal.h"

void signal_init(SignalState *st) {
    st->prev_diff = 0.0; // dₜ₋₁
    st->initialized = 0;
}


int signal_update(SignalState *st, double short_sma, double long_sma) {
    
    /*
        Take the difference between the short and 
        long averages at each trade.
    */

    // dₜ
    double curr_diff = short_sma - long_sma;

    // float noise around exact ties (tick size is 0.01)

    // fixed the running_sma different buy sell signal
    // 2292 buy / 2285 -> 2286 now
    
    // if (curr_diff < 1e-9 && curr_diff > -1e-9) curr_diff = 0.0; 
    if (curr_diff < 1e-6 && curr_diff > -1e-6) curr_diff = 0.0;
    int sig = SIGNAL_NONE;

    if (!st->initialized) {
        st->prev_diff = curr_diff;
        st->initialized = 1;
        return SIGNAL_NONE;
    }

    /*
        BUY at trade t when     
        dₜ₋₁ ≤ 0 and dₜ > 0 
        
        (the short average has just risen above the 
        long one). 
    */
    if (st->prev_diff <= 0.0 && curr_diff > 0.0) {
        sig = SIGNAL_BUY;
    } 
    /*
        SELL at trade t when 
        dₜ₋₁ ≥ 0 and dₜ < 0 
        
        (the short average has just fallen below the 
        long one).
    */
    else if (st->prev_diff >= 0.0 && curr_diff < 0.0) {
        sig = SIGNAL_SELL;
    }

    // to prevent duplicated signals.
    // and only compare it with the next bar
    st->prev_diff = curr_diff;

    // returns either
    // SIGNAL_BUY 
    // SIGNAL_SELL  
    // SIGNAL_NONE
    return sig;
}