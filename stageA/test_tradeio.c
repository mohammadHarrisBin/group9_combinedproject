#include <stdio.h>
#include "../common/trade_io.h"

int main(void) {
    // Uses DATA_FOLDER and GROUP_FOLDER from trade_io.h
    if (!open_data(TEST20)) {
        printf("Error: Failed to open TEST20 dataset.\n");
        return 1;
    }

    printf("Successfully opened dataset using open_data(TEST20)!\n");
    printf("----------------------------------------------------------------------------------------\n");
    printf("%-8s | %-16s | %-12s | %-10s | %-8s\n", "Trade #", "Timestamp (us)", "Price", "Qty", "Side");
    printf("----------------------------------------------------------------------------------------\n");

    int count = 0;

    while (next_trade()) {
        count++;

        long long ts = trade_time();
        double price = trade_price();
        double qty = trade_qty();
        int is_buy_trade = trade_is_buy(); // 1 = BUY, 0 = SELL

        printf("%-8d | %-16lld | %-12.2f | %-10.4f | %-8s\n", 
               count, ts, price, qty, is_buy_trade ? "BUY" : "SELL");
    }

    close_trades();

    printf("----------------------------------------------------------------------------------------\n");
    printf("Finished reading! Total trades read: %d\n", count);

    return 0;
}