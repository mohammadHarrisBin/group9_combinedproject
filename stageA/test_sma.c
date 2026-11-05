#include <stdio.h>
#include "trade_io.h"
#include "sma.h"

int main(void) {
    if (!open_data(TEST20)) {
        printf("Error: Could not open TEST20 dataset.\n");
        return 1;
    }

    // Allocate stack buffers for N=3 and N=5
    double short_buf[3];
    double long_buf[5];

    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, 3);
    sma_init(&long_sma, long_buf, 5);

    printf("Testing Naive Circular SMA (Short=3, Long=5) on TEST20 dataset...\n");
    printf("----------------------------------------------------------------------------------------\n");
    printf("%-8s | %-12s | %-16s | %-16s\n", "Trade #", "Price", "Short SMA (3)", "Long SMA (5)");
    printf("----------------------------------------------------------------------------------------\n");

    int count = 0;

    while (next_trade()) {
        count++;
        double price = trade_price();

        sma_update(&short_sma, price);
        sma_update(&long_sma, price);

        double s_val = sma_is_full(&short_sma) ? sma_calculate_naive(&short_sma) : 0.0;
        double l_val = sma_is_full(&long_sma) ? sma_calculate_naive(&long_sma) : 0.0;

        printf("%-8d | %-12.2f | %-16.4f | %-16.4f\n", count, price, s_val, l_val);
    }

    close_trades();
    printf("----------------------------------------------------------------------------------------\n");
    return 0;
}