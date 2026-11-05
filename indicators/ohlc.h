#ifndef OHLC_H
#define OHLC_H

// --- 1-Second OHLC Bar State ---
typedef struct {
    long long current_second; // Current bar's timestamp in seconds
    double open;              // First trade price in second
    double high;              // Highest trade price in second
    double low;               // Lowest trade price in second
    double close;             // Last trade price in second
    int has_data;             // 1 if bar has trades, 0 if empty
} OHLCState;

void ohlc_init(OHLCState *state);
int ohlc_update(OHLCState *state, long long ts_us, double price, OHLCState *completed_bar);

#endif /* OHLC_H */