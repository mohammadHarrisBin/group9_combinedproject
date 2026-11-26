#include "timing.h"
#include "stageB_perf_config.h"
#include <stdio.h>
#include "fast_reader.h"
#include "vwap.h"
#include "ohlc.h"
#include "sma.h"
#include "signal.h"


#ifndef SHORT_N
#define SHORT_N 15
#endif

#ifndef LONG_N
#define LONG_N 100
#endif


/*
    load every trade into a fixed size global 
    array of structs 
*/

// define a Trade struct
typedef struct {
    long long ts;
    double price;
    double qty;
    int is_buy;
} Trade;

static Trade trades[MAX_TRADES];

static int measure_trial(TrialMetrics *metrics) {
    if (!open_data(DATASET)) {
        fprintf(stderr, "Error: Could not open selected dataset.\n");
        return 0;
    }

    // 1. UNTIMED INGESTION: Read CSV into RAM array before timing
    int trade_count = 0;

    // Its just updating the empty properties where 
    // fast_reader read_trade() provides
    while (trade_count < MAX_TRADES && 
           read_trade(&trades[trade_count].ts, 
                      &trades[trade_count].price, 
                      &trades[trade_count].qty, 
                      &trades[trade_count].is_buy)) {
        trade_count++; // move on to the next trade
    }
    if (trade_count == MAX_TRADES) {
        long long extra_ts; double extra_price, extra_qty; int extra_buy;
        if (read_trade(&extra_ts, &extra_price, &extra_qty, &extra_buy)) {
            fprintf(stderr, "Error: Dataset exceeds capacity of %d trades.\n", MAX_TRADES);
            close_trades(); return 0;
        }
    }
    close_trades();
    if (!trade_count) { fprintf(stderr, "Error: Dataset contains no trades.\n"); return 0; }

    fprintf(stderr, "Loaded %d trades into RAM. Starting Stage B benchmark...\n", trade_count);

    // Initialize indicator states
    VWAPState vwap; vwap_init(&vwap);
    OHLCState ohlc, completed_bar; ohlc_init(&ohlc);

    double short_buf[SHORT_N], long_buf[LONG_N];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, SHORT_N);
    sma_init(&long_sma, long_buf, LONG_N);

    SignalState sig_st; signal_init(&sig_st);

    int buy_signals = 0;
    int sell_signals = 0;


    // TIMED BENCHMARK: Process trades directly out of RAM
    uint64_t start_time = now_ns();

    for (int i = 0; i < trade_count; i++) {
        long long ts = trades[i].ts;
        double price = trades[i].price;
        double qty = trades[i].qty;

        vwap_update(&vwap, price, qty);
        ohlc_update(&ohlc, ts, price, &completed_bar);

        sma_update(&short_sma, price);
        sma_update(&long_sma, price);

        double s_val = 0.0;
        int short_ready = sma_is_full(&short_sma);
        if (short_ready) s_val = sma_calculate_naive(&short_sma);

        double l_val = 0.0;
        int long_ready = sma_is_full(&long_sma);
        if (long_ready) l_val = sma_calculate_naive(&long_sma);

        int signal = SIGNAL_NONE;
        if (short_ready && long_ready) {
            signal = signal_update(&sig_st, s_val, l_val);
        }

        if (signal == SIGNAL_BUY)  buy_signals++;
        if (signal == SIGNAL_SELL) sell_signals++;

    }

    uint64_t end_time = now_ns();

    metrics->elapsed_ns = end_time - start_time;
    metrics->trades = trade_count;
    metrics->buys = buy_signals;
    metrics->sells = sell_signals;
    return 1;
}
