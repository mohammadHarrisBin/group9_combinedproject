#include <stdio.h>
#include "fast_reader.h"
#include "vwap.h"
#include "ohlc.h"
#include "sma.h"
#include "signal.h"
#include "timing.h"

/*
    load every trade into a fixed size global 
    array of structs 
*/
 #define MAX_TRADES 1000000

// define a Trade struct
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
    close_trades();

    fprintf(stderr, "Loaded %d trades into RAM. Starting Stage B benchmark...\n", trade_count);

    // Initialize indicator states
    VWAPState vwap; vwap_init(&vwap);
    OHLCState ohlc, completed_bar; ohlc_init(&ohlc);

    double short_buf[15], long_buf[100];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, 15);
    sma_init(&long_sma, long_buf, 100);

    SignalState sig_st; signal_init(&sig_st);

    int buy_signals = 0;
    int sell_signals = 0;

    FILE *out = fopen("plots/signals_stageB.dat", "w");

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

    fprintf(stderr, "\n=========== STAGE B (RAM) | Naive SMA ===============\n");
    fprintf(stderr, "Total Trades Processed : %d\n", trade_count);
    fprintf(stderr, "BUY Signals Raised     : %d\n", buy_signals);
    fprintf(stderr, "SELL Signals Raised    : %d\n", sell_signals);
    fprintf(stderr, "Total Run Time         : %llu ns (%.3f ms)\n", (unsigned long long)elapsed_ns, elapsed_ms);
    fprintf(stderr, "Time Per Trade         : %.2f ns/trade\n", ns_per_trade);
    fprintf(stderr, "Throughput             : %.2f trades/sec\n", trades_per_sec);
    fprintf(stderr, "=======================================================\n");

    return 0;
}