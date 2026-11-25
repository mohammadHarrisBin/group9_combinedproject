#include <stdio.h>
#include <stdint.h>
#include "fast_reader.h"
#include "sma.h"
#include "signal.h"
#include "timing.h"

// Default window sizes if -D flags aren't passed during make
#ifndef SHORT_N
#define SHORT_N 15
#endif

#ifndef LONG_N
#define LONG_N 100
#endif

// Tracks one rival bot at a fixed reaction threshold R (in ns)
typedef struct {
    double r_ns;
    double total_buy_cost;
    double total_sell_revenue;
    int holding;     // 0 = flat/looking to buy, 1 = holding/looking to sell
    int bot_wins;    // Reacted within R -> got current trade price p
    int rival_wins;  // Slower than R -> slipped to next trade price
} RivalBot;

int main(void) {
    // Skipped Stage C v0 originally, so using STRESS directly here for our baseline run
    if (!open_data(STRESS)) {
        fprintf(stderr, "Error: Could not open STRESS dataset.\n");
        return 1;
    }

    fprintf(stderr, "=== STAGE C v0 (NAIVE SMA + RIVAL BOT SWEEP) ===\n");
    fprintf(stderr, "Streaming STRESS with Naive SMA (SHORT_N=%d, LONG_N=%d, no malloc)...\n\n",
            SHORT_N, LONG_N);

    double short_buf[SHORT_N];
    double long_buf[LONG_N];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, SHORT_N);
    sma_init(&long_sma, long_buf, LONG_N);

    SignalState sig_st;
    signal_init(&sig_st);

    // Zero-slippage reference P&L (assumes we always get current trade price with no rival beating us)
    double ideal_buy_cost = 0.0;
    double ideal_sell_revenue = 0.0;
    int ideal_holding = 0;

    // Sweep rival reaction times from 0.1 us up to 100 us
    double r_values_us[] = {0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0};
    int num_r = sizeof(r_values_us) / sizeof(r_values_us[0]);
    RivalBot bots[9];

    for (int k = 0; k < num_r; k++) {
        bots[k].r_ns = r_values_us[k] * 1000.0;
        bots[k].total_buy_cost = 0.0;
        bots[k].total_sell_revenue = 0.0;
        bots[k].holding = 0;
        bots[k].bot_wins = 0;
        bots[k].rival_wins = 0;
    }

    uint64_t total_latency_ns = 0;
    uint64_t worst_latency_ns = 0;
    int buy_signals = 0;
    int sell_signals = 0;
    int trade_count = 0;

    // Keep a 1-trade lookahead buffer so if we lose a race on trade i, we can fill at trade i+1's price
    // without allocating a giant array on the heap
    long long cur_ts, next_ts;
    double cur_price, next_price;
    double cur_qty, next_qty;
    int cur_buy, next_buy;

    int has_cur = read_trade(&cur_ts, &cur_price, &cur_qty, &cur_buy);
    int has_next = has_cur ? read_trade(&next_ts, &next_price, &next_qty, &next_buy) : 0;

    // No sleep/replay pacing, LEDs, VWAP, or OHLC here — keeping it focused on naive SMA + bot race
    while (has_cur) {
        trade_count++;

        uint64_t proc_start = now_ns();

        double p = cur_price;
        sma_update(&short_sma, p);
        sma_update(&long_sma, p);

        // Intentionally calling naive SMA instead of running-sum so we see O(N) window cost
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

        uint64_t proc_end = now_ns();
        uint64_t trade_latency = proc_end - proc_start;

        total_latency_ns += trade_latency;
        if (trade_latency > worst_latency_ns) {
            worst_latency_ns = trade_latency;
        }

        // If we miss R, slip to next trade's price if one exists; otherwise fall back to p
        double slip_price = has_next ? next_price : p;

        if (signal == SIGNAL_BUY) {
            buy_signals++;

            // Update baseline P&L only when flat so buys and sells stay paired
            if (!ideal_holding) {
                ideal_buy_cost += p;
                ideal_holding = 1;
            }

            for (int k = 0; k < num_r; k++) {
                if (!bots[k].holding) {
                    if ((double)trade_latency <= bots[k].r_ns) {
                        // Fast enough: fill at current price p
                        bots[k].total_buy_cost += p;
                        bots[k].bot_wins++;
                    } else {
                        // Too slow: rival beats us and we slip to next trade's price
                        bots[k].total_buy_cost += slip_price;
                        bots[k].rival_wins++;
                    }
                    bots[k].holding = 1;
                }
            }
        } else if (signal == SIGNAL_SELL) {
            sell_signals++;

            if (ideal_holding) {
                ideal_sell_revenue += p;
                ideal_holding = 0;
            }

            for (int k = 0; k < num_r; k++) {
                if (bots[k].holding) {
                    if ((double)trade_latency <= bots[k].r_ns) {
                        bots[k].total_sell_revenue += p;
                        bots[k].bot_wins++;
                    } else {
                        bots[k].total_sell_revenue += slip_price;
                        bots[k].rival_wins++;
                    }
                    bots[k].holding = 0;
                }
            }
        }

        // Shift lookahead window forward by 1 trade
        cur_ts = next_ts;
        cur_price = next_price;
        cur_qty = next_qty;
        cur_buy = next_buy;
        has_cur = has_next;
        has_next = has_cur ? read_trade(&next_ts, &next_price, &next_qty, &next_buy) : 0;
    }

    close_trades();

    double avg_latency_ns = (trade_count > 0) ? ((double)total_latency_ns / (double)trade_count) : 0.0;
    double ideal_pnl = ideal_sell_revenue - ideal_buy_cost;

    fprintf(stderr, "==================== STAGE C v0 SUMMARY ====================\n");
    fprintf(stderr, "Total Trades Processed : %d\n", trade_count);
    fprintf(stderr, "BUY / SELL Signals     : %d BUY / %d SELL\n", buy_signals, sell_signals);
    fprintf(stderr, "Ideal Naive SMA P&L    : %.2f USDT\n", ideal_pnl);
    fprintf(stderr, "Average Trade Latency  : %.2f ns\n", avg_latency_ns);
    fprintf(stderr, "Worst-Case Latency     : %llu ns (%.3f us)\n",
            (unsigned long long)worst_latency_ns, (double)worst_latency_ns / 1000.0);
    fprintf(stderr, "============================================================\n");

    // Dump sweep table for gnuplot / report comparison
    FILE *sweep_out = fopen("plots/rival_sweep_v0.dat", "w");
    if (sweep_out) {
        fprintf(stderr, "\n--- RIVAL BOT SWEEP RESULTS (plots/rival_sweep_v0.dat) ---\n");
        fprintf(stderr, "%-10s %-16s %-10s %-10s\n", "R_us", "P&L (USDT)", "Wins", "Losses");
        fprintf(stderr, "-----------------------------------------------------\n");

        for (int k = 0; k < num_r; k++) {
            char r_str[16];
            snprintf(r_str, sizeof(r_str), "%.1f us", r_values_us[k]);

            fprintf(stderr, "%-10s %-16.2f %-10d %-10d\n",
                    r_str,
                    bots[k].total_sell_revenue - bots[k].total_buy_cost,
                    bots[k].bot_wins,
                    bots[k].rival_wins);

            fprintf(sweep_out, "%.1f %.2f %d %d\n",
                    r_values_us[k],
                    bots[k].total_sell_revenue - bots[k].total_buy_cost,
                    bots[k].bot_wins,
                    bots[k].rival_wins);
        }
        fclose(sweep_out);
    }

    return 0;
}