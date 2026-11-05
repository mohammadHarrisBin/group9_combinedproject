#include <stdio.h>
#include "trade_io.h"
#include "vwap.h"

int main(void) {
    // Open TEST20 dataset using trade_io[cite: 4, 24]
    if (!open_data(TEST20)) {
        printf("Error: Could not open TEST20 dataset.\n");
        return 1;
    }

    // out vwap state
    VWAPState vwap;
    vwap_init(&vwap);

    printf("Testing VWAP Indicator on TEST20 dataset...\n");
    printf("----------------------------------------------------------------------------------------\n");
    printf("%-8s | %-12s | %-12s | %-16s\n", "Trade #", "Price", "Qty", "Running VWAP");
    printf("----------------------------------------------------------------------------------------\n");

    int count = 0;

    // Stream trades line by line[cite: 8]
    while (next_trade()) {
        count++;

        double price = trade_price();
        double qty = trade_qty();

        // Update VWAP state[cite: 8, 10]
        vwap_update(&vwap, price, qty);

        printf("%-8d | %-12.2f | %-12.4f | %-16.4f\n", 
               count, price, qty, vwap_get(&vwap));
    }

    close_trades();

    printf("----------------------------------------------------------------------------------------\n");
    printf("Finished! Processed %d trades. Final VWAP: %.4f\n", count, vwap_get(&vwap));

    return 0;
}