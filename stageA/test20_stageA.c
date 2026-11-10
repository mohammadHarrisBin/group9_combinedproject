#include <stdio.h>
#include "trade_io.h"
#include "vwap.h"
#include "ohlc.h"
#include "sma.h"
#include "signal.h"
#include "timing.h"

int main(void) {
    // Opening the dataset using trade_io.c (using TEST20 dataset)
    if (!open_data(TEST20)) {
        fprintf(stderr, "Error: Could not open TEST20 dataset.\n");
        return 1;
    }

    // .DAT plotting file for GNU to plot.
    /* 
    if not found, 
    a new file(.dat) will be created.
    */
    FILE *out = fopen("plots/signals_stageA.dat", "w");
    if (!out) {
        fprintf(stderr, "Error: Could not open plots/signals_stageA.dat for writing.\n");
        close_trades();
        return 1;
    }

    // initialise the vwap
    VWAPState vwap; vwap_init(&vwap);
    
    // initialise the ohlc
    OHLCState ohlc, completed_bar; ohlc_init(&ohlc);

    /*
    inside the SMA indicator header
        sma->window = buffer;
        For TEST20 dataset: short=3, long=5 (as per spec for test20.csv verification)
    */
    double short_buf[3], long_buf[5];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, 3);
    sma_init(&long_sma, long_buf, 5);

    // initialise the signal state
    SignalState sig_st; signal_init(&sig_st);

    int count = 0;
    int buy_signals = 0;
    int sell_signals = 0;

    uint64_t start_time = now_ns();

    // Print table header for TEST20 verification output
    printf("Executing Full Stage A Engine on TEST20 dataset...\n");
    printf("---------------------------------------------------------------------------------------------------------\n");
    printf("%-5s | %-10s | %-8s | %-14s | %-14s | %-14s | %-6s\n", 
           "Trade", "Price", "Qty", "VWAP", "SMA(3)", "SMA(5)", "Signal");
    printf("---------------------------------------------------------------------------------------------------------\n");

    // Inside trade_io.c
    /*
    what's happening in the background:
        for each iteration where next_trade() is invoked,
        the program reaches into the csv file
        and grabs one single line of trade
        and stores it in static memory

    How is the data stored then?
        under next_trade() function.
        Realise that it uses "sscanf" to:
        1. automatically parse the string
        2. convert to datatype based on specifier
        3. store in variable e.g. cur_time, cur_price
    */
    while (next_trade()) {
        count++;

        // datatype used is based on the helper file
        // get the properties of the trade
        long long ts = trade_time();
        double price = trade_price();
        double qty = trade_qty();

        /*
        For each iteration:
        
        Update our indicators with the retrieved
        properties
        */
        vwap_update(&vwap, price, qty);

        // Returns 1 when a 1-second bar completes (moves to a new second), 0 otherwise
        ohlc_update(&ohlc, ts, price, &completed_bar);

        // updating our respective SMAs
        sma_update(&short_sma, price);
        sma_update(&long_sma, price);

        // continuously check if the SMA is full
        // window->count == window->capacity
        // if SMA is full/ready, get the SMA price.

        double s_val = 0.0;
        // capacity full?
        int short_ready = sma_is_full(&short_sma);
        if (short_ready) s_val = sma_calculate_naive(&short_sma);

        double l_val = 0.0;
        int long_ready = sma_is_full(&long_sma);
        if (long_ready) l_val = sma_calculate_naive(&long_sma);

        // if SMA is full/ready, update the signal
        int signal = SIGNAL_NONE;
        if (short_ready && long_ready) {
            signal = signal_update(&sig_st, s_val, l_val);
        }

        if (signal == SIGNAL_BUY)  buy_signals++;
        if (signal == SIGNAL_SELL) sell_signals++;

        // Format SMA strings (print "-" if window not full yet)
        char s_str[32] = "-", l_str[32] = "-";
        if (short_ready) snprintf(s_str, sizeof(s_str), "%.8f", s_val);
        if (long_ready)  snprintf(l_str, sizeof(l_str), "%.8f", l_val);

        // Signal text
        const char *sig_str = "";
        if (signal == SIGNAL_BUY)  sig_str = "BUY";
        if (signal == SIGNAL_SELL) sig_str = "SELL";

        // Call vwap_get() from your vwap module
        double cur_vwap = vwap_get(&vwap);

        // Print formatted line to terminal matching test20_expected.txt format
        printf("%-5d | %-10.2f | %-8.4f | %-14.8f | %-14s | %-14s | %-6s\n",
               count, price, qty, cur_vwap, s_str, l_str, sig_str);

        // update each trade iteration inside the .dat file for GNU plotting later (writes all 20 trades for TEST20)
        if (out && count >= 1 && count <= 20) {
            fprintf(out, "%d %.8f %.8f %.8f %d\n", count, price, s_val, l_val, signal);
        }
    }
    
    uint64_t end_time = now_ns();
    if (out) fclose(out);
    close_trades();

    printf("---------------------------------------------------------------------------------------------------------\n");
    printf("Final VWAP: %.8f\n", vwap_get(&vwap));
    printf("Signals: %d BUY, %d SELL\n\n", buy_signals, sell_signals);

    // Print OHLC summary using ohlc.current_second and trade count
    printf("One-second OHLC bars (second = time / 1,000,000)\n");
    printf("%-12s %-16s %-16s %-16s %-16s %-6s\n", "second", "open", "high", "low", "close", "trades");
    printf("%-12lld %-16.8f %-16.8f %-16.8f %-16.8f %-6d\n",
           ohlc.current_second, ohlc.open, ohlc.high, 
           ohlc.low, ohlc.close, count);

    uint64_t elapsed_ns = end_time - start_time;
    double elapsed_ms = (double)elapsed_ns / 1000000.0;
    double ns_per_trade = (double)elapsed_ns / (double)count; 
    double trades_per_sec = (double)count / ((double)elapsed_ns / 1e9);

    fprintf(stderr, "\n==================== STAGE A (STREAMING - TEST20) ====================\n");
    fprintf(stderr, "Total Trades Processed : %d\n", count);
    fprintf(stderr, "BUY Signals Raised     : %d\n", buy_signals);
    fprintf(stderr, "SELL Signals Raised    : %d\n", sell_signals);
    fprintf(stderr, "Total Run Time         : %llu ns (%.3f ms)\n", (unsigned long long)elapsed_ns, elapsed_ms);
    fprintf(stderr, "Time Per Trade         : %.2f ns/trade\n", ns_per_trade);
    fprintf(stderr, "Throughput             : %.2f trades/sec\n", trades_per_sec);
    fprintf(stderr, "=============================================================\n");

    return 0;
}