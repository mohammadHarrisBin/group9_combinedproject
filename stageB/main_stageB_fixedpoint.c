#include <stdio.h>
#include "fast_reader.h"
#include "vwap.h"
#include "ohlc.h"
#include "signal.h"
#include "timing.h"

#define MAX_TRADES 1000000
#define SCALE_FACTOR 100000000LL

typedef struct {
    long long ts;
    long long price_fp;
    long long qty_fp;
    int is_buy;
} TradeFP;

static TradeFP trades_fp[MAX_TRADES];

typedef struct {
    long long window[100];
    int capacity;
    int count;
    int head;
    long long running_sum;
} SMAWindowFP;

void sma_fp_init(SMAWindowFP *sma, int capacity) {
    sma->capacity = capacity;
    sma->count = 0;
    sma->head = 0;
    sma->running_sum = 0LL;
}

void sma_fp_update(SMAWindowFP *sma, long long price_fp) {
    if (sma->count < sma->capacity) {
        sma->window[sma->head] = price_fp;
        sma->running_sum += price_fp;
        sma->count++;
    } else {
        sma->running_sum = sma->running_sum - sma->window[sma->head] + price_fp;
        sma->window[sma->head] = price_fp;
    }
    sma->head = (sma->head + 1) % sma->capacity;
}

int sma_fp_is_full(const SMAWindowFP *sma) {
    return sma->count == sma->capacity;
}

// Simple, exact signal check matching your signal.c
static inline int signal_update_fp_exact(SignalState *st, long long sum15, long long sum100) {
    // Cross-multiply: (sum15 / 15) - (sum100 / 100) ==> (100 * sum15 - 15 * sum100)
    double curr_diff = (double)(sum15 * 100LL - sum100 * 15LL) / (1500.0 * (double)SCALE_FACTOR);
    int sig = SIGNAL_NONE;

    if (!st->initialized) {
        st->prev_diff = curr_diff;
        st->initialized = 1;
        return SIGNAL_NONE;
    }

    if (st->prev_diff <= 0.0 && curr_diff > 0.0) {
        sig = SIGNAL_BUY;
    } 
    else if (st->prev_diff >= 0.0 && curr_diff < 0.0) {
        sig = SIGNAL_SELL;
    }

    st->prev_diff = curr_diff;
    return sig;
}

int main(void) {
    if (!open_data(DEV)) {
        fprintf(stderr, "Error: Could not open DEV dataset.\n");
        return 1;
    }

    int trade_count = 0;
    long long raw_ts;
    double raw_price, raw_qty;
    int raw_buy;

    while (trade_count < MAX_TRADES && read_trade(&raw_ts, &raw_price, &raw_qty, &raw_buy)) {
        trades_fp[trade_count].ts = raw_ts;
        trades_fp[trade_count].price_fp = (long long)(raw_price * (double)SCALE_FACTOR + 0.5);
        trades_fp[trade_count].qty_fp = (long long)(raw_qty * (double)SCALE_FACTOR + 0.5);
        trades_fp[trade_count].is_buy = raw_buy;
        trade_count++;
    }
    close_trades();

    fprintf(stderr, "Loaded %d trades into Fixed-Point RAM. Starting benchmark...\n", trade_count);

    SMAWindowFP short_sma, long_sma;
    sma_fp_init(&short_sma, 15);
    sma_fp_init(&long_sma, 100);

    SignalState sig_st; 
    signal_init(&sig_st);

    int buy_signals = 0;
    int sell_signals = 0;

    FILE *out = fopen("plots/signals_stageB_fp.dat", "w");

    uint64_t start_time = now_ns();

    for (int i = 0; i < trade_count; i++) {
        long long p_fp = trades_fp[i].price_fp;

        sma_fp_update(&short_sma, p_fp);
        sma_fp_update(&long_sma, p_fp);

        int short_ready = sma_fp_is_full(&short_sma);
        int long_ready = sma_fp_is_full(&long_sma);

        int signal = SIGNAL_NONE;
        if (short_ready && long_ready) {
            signal = signal_update_fp_exact(&sig_st, short_sma.running_sum, long_sma.running_sum);
        }

        if (signal == SIGNAL_BUY)  buy_signals++;
        if (signal == SIGNAL_SELL) sell_signals++;

        if (out && (i + 1) >= 10000 && (i + 1) <= 12000) {
            double price = (double)p_fp / (double)SCALE_FACTOR;
            double s_val = (double)short_sma.running_sum / (15.0 * (double)SCALE_FACTOR);
            double l_val = (double)long_sma.running_sum / (100.0 * (double)SCALE_FACTOR);
            fprintf(out, "%d %.8f %.8f %.8f %d\n", i + 1, price, s_val, l_val, signal);
        }
    }

    uint64_t end_time = now_ns();
    if (out) fclose(out);

    uint64_t elapsed_ns = end_time - start_time;
    double elapsed_ms = (double)elapsed_ns / 1000000.0;
    double ns_per_trade = (double)elapsed_ns / (double)trade_count;
    double trades_per_sec = (double)trade_count / ((double)elapsed_ns / 1e9);

    fprintf(stderr, "\n==================== STAGE B (FIXED-POINT LONG LONG) ====================\n");
    fprintf(stderr, "Total Trades Processed : %d\n", trade_count);
    fprintf(stderr, "BUY Signals Raised     : %d\n", buy_signals);
    fprintf(stderr, "SELL Signals Raised    : %d\n", sell_signals);
    fprintf(stderr, "Total Run Time         : %llu ns (%.3f ms)\n", (unsigned long long)elapsed_ns, elapsed_ms);
    fprintf(stderr, "Time Per Trade         : %.2f ns/trade\n", ns_per_trade);
    fprintf(stderr, "Throughput             : %.2f trades/sec\n", trades_per_sec);
    fprintf(stderr, "=========================================================================\n");

    return 0;
}