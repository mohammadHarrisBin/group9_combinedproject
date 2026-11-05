#include <stddef.h>
#include "signal.h"

void signal_init(SignalState *st) {
    st->prev_diff = 0.0;
    st->initialized = 0;
}

int signal_update(SignalState *st, double short_sma, double long_sma) {
    double curr_diff = short_sma - long_sma;
    int sig = SIGNAL_NONE;

    if (!st->initialized) {
        st->prev_diff = curr_diff;
        st->initialized = 1;
        return SIGNAL_NONE;
    }

    if (st->prev_diff <= 0.0 && curr_diff > 0.0) {
        sig = SIGNAL_BUY;
    } 
    else if (st->prev_diff >= 0.0 && curr_diff < 0.0) {
        sig = SIGNAL_SELL;
    }

    st->prev_diff = curr_diff;
    return sig;
}