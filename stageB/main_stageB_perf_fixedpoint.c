#include "timing.h"
#include "stageB_perf_config.h"
#include <stdio.h>
#include "fast_reader.h"
#include "vwap.h"
#include "ohlc.h"
#include "signal.h"

#define SCALE_FACTOR 100000000LL

#ifndef SHORT_N
#define SHORT_N 15
#endif

#ifndef LONG_N
#define LONG_N 100
#endif

typedef struct {
    long long ts;
    long long price_fp;
    long long qty_fp;
    int is_buy;
} TradeFP;

static TradeFP trades_fp[MAX_TRADES];

typedef struct {
    long long window[100];
    int capacity;
    int count;
    int head;
    long long running_sum;
} SMAWindowFP;

void sma_fp_init(SMAWindowFP *sma, int capacity) {
    sma->capacity = capacity;
    sma->count = 0;
    sma->head = 0;
    sma->running_sum = 0LL;
}

void sma_fp_update(SMAWindowFP *sma, long long price_fp) {
    if (sma->count < sma->capacity) {
        sma->window[sma->head] = price_fp;
        sma->running_sum += price_fp;
        sma->count++;
    } else {
        sma->running_sum = sma->running_sum - sma->window[sma->head] + price_fp;
        sma->window[sma->head] = price_fp;
    }
    sma->head = (sma->head + 1) % sma->capacity;
}

int sma_fp_is_full(const SMAWindowFP *sma) {
    return sma->count == sma->capacity;
}

// Pure integer cross-multiplication crossover comparison
static inline int signal_update_fp_exact(SignalState *st, long long sum_short, long long sum_long) {
    long long d = (sum_short * (long long)LONG_N) - (sum_long * (long long)SHORT_N);
    
    int sig = SIGNAL_NONE;
    if (!st->initialized) {
        st->prev_diff = (double)d;
        st->initialized = 1;
        return SIGNAL_NONE;
    }

    if (st->prev_diff <= 0.0 && d > 0) sig = SIGNAL_BUY;
    else if (st->prev_diff >= 0.0 && d < 0) sig = SIGNAL_SELL;

    st->prev_diff = (double)d;
    return sig;
}


static int measure_trial(TrialMetrics *metrics) {
    if (!open_data(DATASET)) {
        fprintf(stderr, "Error: Could not open selected dataset.\n");
        return 0;
    }

    int trade_count = 0;
    long long raw_ts;
    double raw_price, raw_qty;
    int raw_buy;

    while (trade_count < MAX_TRADES && read_trade(&raw_ts, &raw_price, &raw_qty, &raw_buy)) {
        trades_fp[trade_count].ts = raw_ts;
        trades_fp[trade_count].price_fp = (long long)(raw_price * (double)SCALE_FACTOR + 0.5);
        trades_fp[trade_count].qty_fp = (long long)(raw_qty * (double)SCALE_FACTOR + 0.5);
        trades_fp[trade_count].is_buy = raw_buy;
        trade_count++;
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

    fprintf(stderr, "Loaded %d trades into Fixed-Point RAM. Starting benchmark...\n", trade_count);

    SMAWindowFP short_sma, long_sma;
    sma_fp_init(&short_sma, SHORT_N);
    sma_fp_init(&long_sma, LONG_N);

    // Initialize indicator states
    VWAPState vwap; vwap_init(&vwap);
    OHLCState ohlc, completed_bar; ohlc_init(&ohlc);

    SignalState sig_st; 
    signal_init(&sig_st);

    int buy_signals = 0;
    int sell_signals = 0;


    uint64_t start_time = now_ns();

    for (int i = 0; i < trade_count; i++) {
        long long p_fp = trades_fp[i].price_fp;
        long long q_fp = trades_fp[i].qty_fp;
        long long ts   = trades_fp[i].ts;

        // Convert back to double for VWAP/OHLC tracking so all rungs do equal work
        vwap_update(&vwap, (double)p_fp / (double)SCALE_FACTOR, (double)q_fp / (double)SCALE_FACTOR);
        ohlc_update(&ohlc, ts, (double)p_fp / (double)SCALE_FACTOR, &completed_bar);

        sma_fp_update(&short_sma, p_fp);
        sma_fp_update(&long_sma, p_fp);

        int short_ready = sma_fp_is_full(&short_sma);
        int long_ready = sma_fp_is_full(&long_sma);

        int signal = SIGNAL_NONE;
        if (short_ready && long_ready) {
            signal = signal_update_fp_exact(&sig_st, short_sma.running_sum, long_sma.running_sum);
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
