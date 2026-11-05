#include <stdio.h>
#include "trade_io.h"
#include "ohlc.h"

int main(void) {
    if (!open_data(TEST20)) {
        printf("Error: Could not open TEST20 dataset.\n");
        return 1;
    }

    OHLCState ohlc, completed;
    ohlc_init(&ohlc);

    printf("Testing 1-Second OHLC Bars on TEST20 dataset...\n");
    printf("----------------------------------------------------------------------------------------\n");
    printf("%-16s | %-10s | %-10s | %-10s | %-10s\n", "Second (s)", "Open", "High", "Low", "Close");
    printf("----------------------------------------------------------------------------------------\n");

    int bar_count = 0;

    while (next_trade()) {
        long long ts = trade_time();
        double price = trade_price();

        if (ohlc_update(&ohlc, ts, price, &completed)) {
            bar_count++;
            printf("%-16lld | %-10.2f | %-10.2f | %-10.2f | %-10.2f\n", 
                   completed.current_second, completed.open, completed.high, completed.low, completed.close);
        }
    }

    // Output the final in-progress bar
    if (ohlc.has_data) {
        bar_count++;
        printf("%-16lld | %-10.2f | %-10.2f | %-10.2f | %-10.2f (Final Bar)\n", 
               ohlc.current_second, ohlc.open, ohlc.high, ohlc.low, ohlc.close);
    }

    close_trades();

    printf("----------------------------------------------------------------------------------------\n");
    printf("Finished! Total 1-second OHLC bars created: %d\n", bar_count);

    return 0;
}