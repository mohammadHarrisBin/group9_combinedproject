#include "timing.h"
#include <limits.h>
#include "stageB_perf_config.h"
#include <stdio.h>
#include <stdlib.h>
#include "fast_reader.h"
#include "vwap.h"
#include "ohlc.h"
#include "sma.h"
#include "signal.h"

// Macro defaults for Group 09 window parameters (can be overridden via Makefile compiler flags -D)
#ifndef SHORT_N
#define SHORT_N 15
#endif

#ifndef LONG_N
#define LONG_N 100
#endif

typedef struct {
    long long ts;
    double price;
    double qty;
    int is_buy;
} Trade;

static int measure_trial(TrialMetrics *metrics) {
    if (!open_data(DATASET)) {
        fprintf(stderr, "Error: Could not open selected dataset.\n");
        return 0;
    }

    // =========================================================================
    // 1. DYNAMIC MEMORY ALLOCATION (Exact-Fit Heap Allocation)
    // First, scan the CSV file with a fast byte-buffer to count exact newlines.
    // This avoids over-allocating unused RAM or hitting hard-coded limits.
    // =========================================================================
    char folder[400], path[512];
    const char *base = DATA_FOLDER;
    if (base[0] == '~') {
        const char *home = getenv("HOME");
        if (!home) home = getenv("USERPROFILE");
        if (!home) home = "";
        snprintf(folder, sizeof folder, "%s%s", home, base + 1);
    } else snprintf(folder, sizeof folder, "%s", base);
#if DATASET == TEST20
    snprintf(path, sizeof path, "%s/%s/test20.csv", folder, GROUP_FOLDER);
#elif DATASET == DEV
    snprintf(path, sizeof path, "%s/%s/dev_1M.csv", folder, GROUP_FOLDER);
#else
    snprintf(path, sizeof path, "%s/stress_full.csv", folder);
#endif
    FILE *fp_count = fopen(path, "rb");
    if (!fp_count) { fprintf(stderr, "Error: Cannot count %s.\n", path); close_trades(); return 0; }
    size_t line_count = 0;
    char count_buf[65536];
    size_t bytes_read;
    int first = -1, last = -1;
    while ((bytes_read = fread(count_buf, 1, sizeof(count_buf), fp_count)) > 0) {
        if (first == -1) first = (unsigned char)count_buf[0];
        last = (unsigned char)count_buf[bytes_read - 1];
        for (size_t i = 0; i < bytes_read; i++) {
            if (count_buf[i] == '\n') line_count++;
        }
    }
    if (ferror(fp_count)) { fprintf(stderr, "Error: Cannot count %s.\n", path); fclose(fp_count); close_trades(); return 0; }
    fclose(fp_count);
    if (last != -1 && last != '\n') line_count++;
    if (first != -1 && (first < '0' || first > '9')) line_count--;
    if (line_count == 0 || line_count > INT_MAX || line_count > SIZE_MAX / sizeof(Trade)) {
        fprintf(stderr, "Error: Invalid trade count in %s.\n", path); close_trades(); return 0;
    }

    // Allocate heap memory for the EXACT number of trades in the dataset
    Trade *trades = (Trade *)malloc(line_count * sizeof(Trade));
    if (trades == NULL) {
        fprintf(stderr, "Error: Failed to allocate heap memory for %zu trades.\n", line_count);
        close_trades();
        return 0;
    }

    // UNTIMED: Read CSV into Heap Array
    int trade_count = 0;
    long long raw_ts;
    double raw_price, raw_qty;
    int raw_buy;

    while (trade_count < (int)line_count && read_trade(&raw_ts, &raw_price, &raw_qty, &raw_buy)) {
        trades[trade_count].ts = raw_ts;
        trades[trade_count].price = raw_price;
        trades[trade_count].qty = raw_qty;
        trades[trade_count].is_buy = raw_buy;
        trade_count++;
    }
    if (trade_count == (int)line_count && read_trade(&raw_ts, &raw_price, &raw_qty, &raw_buy)) {
        fprintf(stderr, "Error: Dataset exceeds counted capacity.\n");
        close_trades(); free(trades); return 0;
    }
    close_trades();
    if (trade_count != (int)line_count) { fprintf(stderr, "Error: Dataset count changed or contains unreadable records.\n"); free(trades); return 0; }

    fprintf(stderr, "Loaded %d trades into Heap Memory (Exact malloc: %zu bytes). Starting benchmark...\n", 
            trade_count, line_count * sizeof(Trade));

    // Dynamic buffers for SMA windows (using SHORT_N and LONG_N macros)
    double short_buf[SHORT_N];
    double long_buf[LONG_N];

    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, SHORT_N);
    sma_init(&long_sma, long_buf, LONG_N);

    // Initialize indicator states
    VWAPState vwap; vwap_init(&vwap);
    OHLCState ohlc, completed_bar; ohlc_init(&ohlc);

    SignalState sig_st;
    signal_init(&sig_st);

    int buy_signals = 0;
    int sell_signals = 0;


    // 2. TIMED BENCHMARK: Process trades from Heap Memory
    uint64_t start_time = now_ns();

    for (int i = 0; i < trade_count; i++) {
        long long ts = trades[i].ts;
        double p = trades[i].price;
        double q = trades[i].qty;

        vwap_update(&vwap, p, q);
        ohlc_update(&ohlc, ts, p, &completed_bar);

        sma_update(&short_sma, p);
        sma_update(&long_sma, p);

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

    // Free dynamically allocated heap memory
    free(trades);

    metrics->elapsed_ns = end_time - start_time;
    metrics->trades = trade_count;
    metrics->buys = buy_signals;
    metrics->sells = sell_signals;
    return 1;
}
