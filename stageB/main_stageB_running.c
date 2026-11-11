#include <stdio.h>
#include <string.h>
#include "fast_reader.h"
#include "vwap.h"
#include "ohlc.h"
#include "sma.h"
#include "signal.h"
#include "timing.h"

#define MAX_TRADES 1000000

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

static Trade trades[MAX_TRADES];

int main(void) {
    if (!open_data(DEV)) {
        fprintf(stderr, "Error: Could not open DEV dataset.\n");
        return 1;
    }

    // 1. UNTIMED INGESTION into RAM
    int trade_count = 0;
    while (trade_count < MAX_TRADES && 
           read_trade(&trades[trade_count].ts, 
                      &trades[trade_count].price, 
                      &trades[trade_count].qty, 
                      &trades[trade_count].is_buy)) {
        trade_count++;
    }
    close_trades();

    fprintf(stderr, "Loaded %d trades into RAM. Starting Stage B Running-Sum benchmark...\n", trade_count);

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

    // Open plot file for writing trades 10,000 to 12,000
    FILE *out = fopen("plots/signals_stageB_running.dat", "w");

    // TIMED BENCHMARK: Process trades directly out of RAM (Pure CPU timing)
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
        double l_val = 0.0;
        int signal = SIGNAL_NONE;

        // Only compute SMA and update signal when both windows are full
        if (sma_is_full(&long_sma)) {
            s_val = sma_calculate_running(&short_sma);
            l_val = sma_calculate_running(&long_sma);

            signal = signal_update(&sig_st, s_val, l_val);

            if (signal == SIGNAL_BUY)  buy_signals++;
            if (signal == SIGNAL_SELL) sell_signals++;
        }

        // Write trades 10,000 to 12,000 to plot file
        if (out && (i + 1) >= 10000 && (i + 1) <= 12000) {
            fprintf(out, "%d %.8f %.8f %.8f %d\n", i + 1, price, s_val, l_val, signal);
        }
    }

    uint64_t end_time = now_ns();
    if (out) fclose(out);

    uint64_t elapsed_ns = end_time - start_time;
    double elapsed_ms = (double)elapsed_ns / 1000000.0;
    double ns_per_trade = (double)elapsed_ns / (double)trade_count;
    double trades_per_sec = (double)trade_count / ((double)elapsed_ns / 1e9);

    fprintf(stderr, "\n=========== STAGE B (RAM | Running SMA) =============\n");
    fprintf(stderr, "Total Trades Processed : %d\n", trade_count);
    fprintf(stderr, "BUY Signals Raised     : %d\n", buy_signals);
    fprintf(stderr, "SELL Signals Raised    : %d\n", sell_signals);
    fprintf(stderr, "Total Run Time         : %llu ns (%.3f ms)\n", (unsigned long long)elapsed_ns, elapsed_ms);
    fprintf(stderr, "Time Per Trade         : %.2f ns/trade\n", ns_per_trade);
    fprintf(stderr, "Throughput             : %.2f trades/sec\n", trades_per_sec);
    fprintf(stderr, "=======================================================\n");

    return 0;
}