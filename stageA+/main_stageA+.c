#include <stdio.h>
#include "fast_reader.h"
#include "vwap.h"
#include "ohlc.h"
#include "sma.h"
#include "signal.h"
#include "timing.h"

#ifndef SHORT_N
#define SHORT_N 15
#endif

#ifndef LONG_N
#define LONG_N 100
#endif


int main(void) {
    if (!open_data(DEV)) {
        fprintf(stderr, "Error: Could not open DEV dataset.\n");
        return 1;
    }

    FILE *out = fopen("plots/signals_stageA_plus.dat", "w");
    if (!out) {
        fprintf(stderr, "Error: Could not open plots/signals.dat for writing.\n");
        close_trades();
        return 1;
    }

    long long ts;
    double price, qty;
    int is_buy;

    VWAPState vwap; vwap_init(&vwap);
    OHLCState ohlc, completed_bar; ohlc_init(&ohlc);

    double short_buf[SHORT_N], long_buf[LONG_N];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, SHORT_N);
    sma_init(&long_sma, long_buf, LONG_N);

    SignalState sig_st; signal_init(&sig_st);

    int count = 0;
    int buy_signals = 0;
    int sell_signals = 0;

    uint64_t start_time = now_ns();

    while (read_trade(&ts, &price, &qty, &is_buy)) {
        count++;

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

        if (out && count >= 10000 && count <= 12000) {
            fprintf(out, "%d %.8f %.8f %.8f %d\n", count, price, s_val, l_val, signal);
        }
    }

    uint64_t end_time = now_ns();
    if (out) fclose(out);

    // using close_trades() to close the file
    close_trades();

    uint64_t elapsed_ns = end_time - start_time;
    double elapsed_ms = (double)elapsed_ns / 1000000.0;
    double ns_per_trade = (double)elapsed_ns / (double)count; 
    double trades_per_sec = (double)count / ((double)elapsed_ns / 1e9);

    fprintf(stderr, "\n==================== STAGE A+ (FAST READER) ====================\n");
    fprintf(stderr, "Total Trades Processed : %d\n", count);
    fprintf(stderr, "BUY Signals Raised     : %d\n", buy_signals);
    fprintf(stderr, "SELL Signals Raised    : %d\n", sell_signals);
    fprintf(stderr, "Total Run Time         : %llu ns (%.3f ms)\n", (unsigned long long)elapsed_ns, elapsed_ms);
    fprintf(stderr, "Time Per Trade         : %.2f ns/trade\n", ns_per_trade);
    fprintf(stderr, "Throughput             : %.2f trades/sec\n", trades_per_sec);
    fprintf(stderr, "================================================================\n");

    return 0;
}