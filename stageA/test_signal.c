#include <stdio.h>
#include "trade_io.h"
#include "sma.h"
#include "signal.h"

int main(void) {
    if (!open_data(TEST20)) {
        printf("Error: Could not open TEST20 dataset.\n");
        return 1;
    }

    double short_buf[3], long_buf[5];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, 3);
    sma_init(&long_sma, long_buf, 5);

    SignalState sig_st;
    signal_init(&sig_st);

    printf("Testing Signal Crossover on TEST20 dataset...\n");
    printf("----------------------------------------------------------------------------------------\n");
    printf("%-8s | %-12s | %-14s | %-14s | %-10s\n", "Trade #", "Price", "Short SMA(3)", "Long SMA(5)", "Signal");
    printf("----------------------------------------------------------------------------------------\n");

    int count = 0;

    while (next_trade()) {
        count++;
        double price = trade_price();

        sma_update(&short_sma, price);
        sma_update(&long_sma, price);

        double s_val = 0.0, l_val = 0.0;
        int sig = SIGNAL_NONE;

        if (sma_is_full(&long_sma)) {
            s_val = sma_calculate_naive(&short_sma);
            l_val = sma_calculate_naive(&long_sma);
            sig = signal_update(&sig_st, s_val, l_val);
        }

        char *sig_str = "NONE (0)";
        if (sig == SIGNAL_BUY)  sig_str = "BUY (+1)";
        if (sig == SIGNAL_SELL) sig_str = "SELL (-1)";

        printf("%-8d | %-12.2f | %-14.4f | %-14.4f | %-10s\n", count, price, s_val, l_val, sig_str);
    }

    close_trades();
    printf("----------------------------------------------------------------------------------------\n");
    return 0;
}