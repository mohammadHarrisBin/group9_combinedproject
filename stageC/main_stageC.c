#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "fast_reader.h"
#include "vwap.h"
#include "ohlc.h"
#include "sma.h"
#include "signal.h"
#include "timing.h"
#include "led.h"

#define MAX_TRADES 1000000

typedef struct {
    long long ts;
    double price;
    double qty;
    int is_buy;
} Trade;

// Structure to evaluate Rival Bot P&L for a given reaction time limit R (in ns)
typedef struct {
    double r_ns;
    double total_buy_cost;
    double total_sell_revenue;
    int holding;
    int bot_wins;
    int rival_wins;
} RivalBot;

int main(int argc, char *argv[]) {
    double replay_speed = 1000.0;
    if (argc > 1) {
        replay_speed = atof(argv[1]);
        if (replay_speed <= 0.0) replay_speed = 1000.0;
    }

    fprintf(stderr, "=== STAGE C: REAL-TIME REPLAY & RIVAL BOT SWEEP ===\n");
    fprintf(stderr, "Replay Speed Target: %.0fx\n", replay_speed);

    if (!open_data(DEV)) {
        fprintf(stderr, "Error: Could not open DEV dataset.\n");
        return 1;
    }

    Trade *trades = (Trade *)malloc(MAX_TRADES * sizeof(Trade));
    if (trades == NULL) {
        fprintf(stderr, "Error: Failed to allocate memory for %d trades.\n", MAX_TRADES);
        close_trades();
        return 1;
    }

    int trade_count = 0;
    long long raw_ts;
    double raw_price, raw_qty;
    int raw_buy;

    while (trade_count < MAX_TRADES && read_trade(&raw_ts, &raw_price, &raw_qty, &raw_buy)) {
        trades[trade_count].ts = raw_ts;
        trades[trade_count].price = raw_price;
        trades[trade_count].qty = raw_qty;
        trades[trade_count].is_buy = raw_buy;
        trade_count++;
    }
    close_trades();

    fprintf(stderr, "Loaded %d trades into Heap Memory. Starting Replay...\n\n", trade_count);

    led_init();

    double short_buf[15];
    double long_buf[100];
    SMAWindow short_sma, long_sma;
    sma_init(&short_sma, short_buf, 15);
    sma_init(&long_sma, long_buf, 100);

    SignalState sig_st;
    signal_init(&sig_st);

    // Setup Rival Bot Sweep values (0.1us to 100us)
    double r_values_us[] = {0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0};
    int num_r = sizeof(r_values_us) / sizeof(r_values_us[0]);
    RivalBot bots[9];

    for (int k = 0; k < num_r; k++) {
        bots[k].r_ns = r_values_us[k] * 1000.0; // convert us to ns
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

    long long first_trade_ts = trades[0].ts;
    uint64_t replay_start_wall_ns = now_ns();

    for (int i = 0; i < trade_count; i++) {
        // --- Replay Timing Control ---
        long long dataset_elapsed_us = trades[i].ts - first_trade_ts;
        double target_elapsed_ns = ((double)dataset_elapsed_us * 1000.0) / replay_speed;

        uint64_t current_wall_ns = now_ns() - replay_start_wall_ns;
        if (target_elapsed_ns > (double)current_wall_ns) {
            double wait_ms = (target_elapsed_ns - (double)current_wall_ns) / 1000000.0;
            if (wait_ms >= 1.0) {
                sleep_ms((int)wait_ms);
            }
        }

        // --- Processing Latency Timing ---
        uint64_t proc_start = now_ns();

        double p = trades[i].price;
        sma_update(&short_sma, p);
        sma_update(&long_sma, p);

        double s_val = 0.0;
        int short_ready = sma_is_full(&short_sma);
        if (short_ready) s_val = sma_calculate_running(&short_sma);

        double l_val = 0.0;
        int long_ready = sma_is_full(&long_sma);
        if (long_ready) l_val = sma_calculate_running(&long_sma);

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

        // --- Signal Handling & Multi-Rival Evaluation ---
        if (signal == SIGNAL_BUY) {
            buy_signals++;
            led_on(LED_GREEN);
            printf("\033[1;32m[BUY SIGNAL #%d] Trade #%d | Price: %.2f | Latency: %llu ns\033[0m\n",
                   buy_signals, i + 1, p, (unsigned long long)trade_latency);

            for (int k = 0; k < num_r; k++) {
                if (!bots[k].holding) {
                    if ((double)trade_latency <= bots[k].r_ns) {
                        bots[k].total_buy_cost += p;
                        bots[k].bot_wins++;
                    } else {
                        double fill_price = (i + 1 < trade_count) ? trades[i + 1].price : p;
                        bots[k].total_buy_cost += fill_price;
                        bots[k].rival_wins++;
                    }
                    bots[k].holding = 1;
                }
            }
            led_off(LED_GREEN);
        } else if (signal == SIGNAL_SELL) {
            sell_signals++;
            led_on(LED_RED);
            printf("\033[1;31m[SELL SIGNAL #%d] Trade #%d | Price: %.2f | Latency: %llu ns\033[0m\n",
                   sell_signals, i + 1, p, (unsigned long long)trade_latency);

            for (int k = 0; k < num_r; k++) {
                if (bots[k].holding) {
                    if ((double)trade_latency <= bots[k].r_ns) {
                        bots[k].total_sell_revenue += p;
                        bots[k].bot_wins++;
                    } else {
                        double fill_price = (i + 1 < trade_count) ? trades[i + 1].price : p;
                        bots[k].total_sell_revenue += fill_price;
                        bots[k].rival_wins++;
                    }
                    bots[k].holding = 0;
                }
            }
            led_off(LED_RED);
        }
    }

    led_cleanup();
    free(trades);

    double avg_latency_ns = (double)total_latency_ns / (double)trade_count;

    fprintf(stderr, "\n==================== STAGE C SUMMARY RESULTS ====================\n");
    fprintf(stderr, "Total Trades Processed : %d\n", trade_count);
    fprintf(stderr, "BUY / SELL Signals     : %d BUY / %d SELL\n", buy_signals, sell_signals);
    fprintf(stderr, "Average Trade Latency  : %.2f ns\n", avg_latency_ns);
    fprintf(stderr, "Worst-Case Latency     : %llu ns (%.3f us)\n",
            (unsigned long long)worst_latency_ns, (double)worst_latency_ns / 1000.0);
    fprintf(stderr, "==================================================================\n");

    // Write Rival Sweep results to file for plotting
    FILE *sweep_out = fopen("plots/rival_sweep.dat", "w");
    if (sweep_out) {
        fprintf(stderr, "\n--- RIVAL BOT SWEEP RESULTS (plots/rival_sweep.dat) ---\n");
        fprintf(stderr, "R_us\t\tP&L (USDT)\tWins\tLosses\n");
        for (int k = 0; k < num_r; k++) {
            double pnl = bots[k].total_sell_revenue - bots[k].total_buy_cost;
            fprintf(stderr, "%.1f us\t\t%.2f\t\t%d\t%d\n",
                    r_values_us[k], pnl, bots[k].bot_wins, bots[k].rival_wins);
            fprintf(sweep_out, "%.1f %.2f %d %d\n",
                    r_values_us[k], pnl, bots[k].bot_wins, bots[k].rival_wins);
        }
        fclose(sweep_out);
    }

    return 0;
}