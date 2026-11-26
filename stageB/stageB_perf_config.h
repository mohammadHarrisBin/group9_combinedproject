#ifndef STAGEB_PERF_CONFIG_H
#define STAGEB_PERF_CONFIG_H
#include "fast_reader.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Change this line to STRESS for the full dataset. */
#define DATASET STRESS
#if DATASET == TEST20
#define DATASET_NAME "TEST20"
#define MAX_TRADES 20
#define SHORT_N 3
#define LONG_N 5
#elif DATASET == DEV
#define DATASET_NAME "DEV"
#define MAX_TRADES 1000000
#define SHORT_N 15
#define LONG_N 100
#elif DATASET == STRESS
#define DATASET_NAME "STRESS"
#define MAX_TRADES 9000000
#define SHORT_N 15
#define LONG_N 100
#else
#error Unsupported DATASET
#endif

enum { ROUNDS = 5, RUNS_PER_ROUND = 3 };
typedef struct { uint64_t elapsed_ns; int trades, buys, sells; } TrialMetrics;
static int measure_trial(TrialMetrics *metrics);
static int measure_round(int round) {
    TrialMetrics first = {0}, trial;
    uint64_t elapsed_ns = 0;
    for (int pass = 1; pass <= RUNS_PER_ROUND; pass++) {
        fprintf(stderr, "[Stage B %s] Round %d of %d, pass %d of %d.\n", DATASET_NAME, round, ROUNDS, pass, RUNS_PER_ROUND);
        if (!measure_trial(&trial)) return 0;
        if (pass == 1) first = trial;
        if (trial.trades != first.trades || trial.buys != first.buys || trial.sells != first.sells) {
            fprintf(stderr, "Error: Trade or signal counts changed within round %d.\n", round);
            return 0;
        }
        elapsed_ns += trial.elapsed_ns;
    }
    printf("stageB_perf\t%d\t%d\t%d\t%d\t%.1f\n", round, first.trades, first.buys, first.sells, (double)elapsed_ns / RUNS_PER_ROUND);
    return 1;
}
int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--config") == 0) {
        printf("%s\t%d\t%d\t%d\t%d\n", DATASET_NAME, ROUNDS, RUNS_PER_ROUND, SHORT_N, LONG_N);
        return 0;
    }
    if (argc == 3 && strcmp(argv[1], "--round") == 0) {
        char *end;
        long round = strtol(argv[2], &end, 10);
        if (end != argv[2] && *end == '\0' && round >= 1 && round <= ROUNDS)
            return measure_round((int)round) ? 0 : 1;
    }
    fprintf(stderr, "Usage: %s --config | --round N\n", argv[0]);
    return 1;
}
#endif
