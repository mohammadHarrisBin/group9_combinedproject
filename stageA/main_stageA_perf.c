#include "timing.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "trade_io.h"
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

#define DATASET STRESS
enum { ROUNDS = 5, RUNS_PER_ROUND = 5 };

typedef struct {
    uint64_t elapsed_ns;
} TrialMetrics;

// Keep signal counting observable without writing plots during a trial.
static volatile uint64_t buy_signals_observed;
static volatile uint64_t sell_signals_observed;

static int measure_trial(TrialMetrics *metrics) {
    if (!open_data(DATASET)) {
        fprintf(stderr, "Error: Could not open the STRESS dataset.\n");
        return 0;
    }

    VWAPState vwap;
    vwap_init(&vwap);
    OHLCState ohlc, completed_bar;
    ohlc_init(&ohlc);

    double short_buf[SHORT_N], long_buf[LONG_N];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, SHORT_N);
    sma_init(&long_sma, long_buf, LONG_N);

    SignalState sig_st;
    signal_init(&sig_st);
    uint64_t buy_signals = 0;
    uint64_t sell_signals = 0;

    uint64_t start_time = now_ns();
    while (next_trade()) {
        long long ts = trade_time();
        double price = trade_price();
        double qty = trade_qty();

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

        if (short_ready && long_ready) {
            int signal = signal_update(&sig_st, s_val, l_val);
            if (signal == SIGNAL_BUY)  buy_signals++;
            if (signal == SIGNAL_SELL) sell_signals++;
        }
    }
    metrics->elapsed_ns = now_ns() - start_time;

    long long trades = trade_number();
    close_trades();
    if (trades == 0) {
        fprintf(stderr, "Error: The STRESS dataset contains no readable trades.\n");
        return 0;
    }
    buy_signals_observed = buy_signals;
    sell_signals_observed = sell_signals;
    return 1;
}

static int measure_round(int round) {
    TrialMetrics total = {0};
    for (int run = 0; run < RUNS_PER_ROUND; run++) {
#ifdef BENCHMARK_PROGRESS
        fprintf(stderr, "[Stage A] Round %d of %d, dataset pass %d of %d.\n",
                round, ROUNDS, run + 1, RUNS_PER_ROUND);
        fflush(stderr);
#endif
        TrialMetrics metrics;
        if (!measure_trial(&metrics)) return 0;
        total.elapsed_ns += metrics.elapsed_ns;
    }

    double average_ns = (double)total.elapsed_ns / RUNS_PER_ROUND;
    printf("stageA_perf\t%d\t%.1f ns (%.3f ms)\n",
           round, average_ns, average_ns / 1e6);
    return 1;
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--config") == 0) {
        printf("%d\t%d\n", ROUNDS, RUNS_PER_ROUND);
        return 0;
    }

    if (argc == 3 && strcmp(argv[1], "--round") == 0) {
        char *end;
        errno = 0;
        long round = strtol(argv[2], &end, 10);
        if (errno || *end || round < 1 || round > ROUNDS) {
            fprintf(stderr, "Error: Invalid benchmark round.\n");
            return 1;
        }
        return measure_round((int)round) ? 0 : 1;
    }

    if (argc != 1) {
        fprintf(stderr, "Usage: %s [--config | --round N]\n", argv[0]);
        return 1;
    }

    printf("stageA_perf\t%d\t%d\telapsed time\n", ROUNDS, RUNS_PER_ROUND);
    for (int round = 1; round <= ROUNDS; round++) {
        if (!measure_round(round)) return 1;
    }
    return 0;
}
