#include <stdio.h>
#include "trade_io.h"
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
    // Opening the dataset using the trade_io.c
    if (!open_data(DEV)) {
        fprintf(stderr, "Error: Could not open DEV dataset.\n");
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
        the buffer is based on our group 9 s
        short=15 long=100
    */

    // refer to the top
    double short_buf[SHORT_N], long_buf[LONG_N];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, SHORT_N);
    sma_init(&long_sma, long_buf, LONG_N);

    // initialise the signal state
    SignalState sig_st; signal_init(&sig_st);

    int count = 0;
    int buy_signals = 0;
    int sell_signals = 0;

    uint64_t start_time = now_ns();

    // Inside the trade_io.c
    /*
    
    what's happening in the background:
        for each iteration where next_trade() is invoked,
        the program reaches into the csv file
        and grab one single line of trade
        and stores it in the static memory

    How is the data stored then?
        under next_trade() function.
        Realise that is uses "sscanf" to
        1. automatically parses the string
        2. convert to the datatype based on the specifier
        3. store in the variable e.e.,g cur_time, cur_price
    
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

        // updating our respective SMA's 
        sma_update(&short_sma, price);
        sma_update(&long_sma, price);

        // continuosly check if the SMA is full
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

        // update each trade iteration inside the .dat file
        // for GNU plotting later
        if (out && count >= 10000 && count <= 12000) {
            fprintf(out, "%d %.8f %.8f %.8f %d\n", count, price, s_val, l_val, signal);
        }
    }
    
    uint64_t end_time = now_ns();
    if (out) fclose(out);
    close_trades();

    uint64_t elapsed_ns = end_time - start_time;
    double elapsed_ms = (double)elapsed_ns / 1000000.0;
    double ns_per_trade = (double)elapsed_ns / (double)count; 
    double trades_per_sec = (double)count / ((double)elapsed_ns / 1e9);

    fprintf(stderr, "\n==================== STAGE A (STREAMING) ====================\n");
    fprintf(stderr, "Total Trades Processed : %d\n", count);
    fprintf(stderr, "BUY Signals Raised     : %d\n", buy_signals);
    fprintf(stderr, "SELL Signals Raised    : %d\n", sell_signals);
    fprintf(stderr, "Total Run Time         : %llu ns (%.3f ms)\n", (unsigned long long)elapsed_ns, elapsed_ms);
    fprintf(stderr, "Time Per Trade         : %.2f ns/trade\n", ns_per_trade);
    fprintf(stderr, "Throughput             : %.2f trades/sec\n", trades_per_sec);
    fprintf(stderr, "=============================================================\n");

    return 0;
}