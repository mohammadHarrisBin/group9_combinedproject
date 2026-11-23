#include "timing.h"
#include <stdio.h>

// using loops iteratively
unsigned long long iter_func(unsigned long long N) {
    unsigned long long sum = 0;
    for (unsigned long long i = 1; i <= N; i++) {
        sum += i;
    }
    return sum;
}

// using recursive functions
unsigned long long recurr_func(unsigned long long N) {
    if (N <= 1) {
        return N;
    }
    return N + recurr_func(N - 1);
}

struct RoundResult {
    double iterative_ns;
    double recursive_ns;
};

int main(void) {
    enum { ROUNDS = 5, RUNS = 25, REPEATS = 10000 };
    _Static_assert(ROUNDS > 0 && RUNS > 0, "ROUNDS and RUNS must be positive");
    static struct RoundResult results[ROUNDS];

    // Read N on every call so the compiler cannot reuse a constant result.
    volatile unsigned long long N = 10000;
    volatile unsigned long long iter_sum = 0;
    volatile unsigned long long recurr_sum = 0;

    for (int round = 0; round < ROUNDS; round++) {
        double iter_total_time = 0;
        double recurr_total_time = 0;

        for (int run = 0; run < RUNS; run++) {
            // Iterative Benchmark
            uint64_t start_time = now_ns();
            for (int i = 0; i < REPEATS; i++) {
                iter_sum = iter_func(N);
            }
            uint64_t iter_elapsed_time = now_ns() - start_time;
            iter_total_time += (double)iter_elapsed_time;

            // Recursive Benchmark
            start_time = now_ns();
            for (int i = 0; i < REPEATS; i++) {
                recurr_sum = recurr_func(N);
            }
            uint64_t recurr_elapsed_time = now_ns() - start_time;
            recurr_total_time += (double)recurr_elapsed_time;
        }

        results[round].iterative_ns = iter_total_time / RUNS;
        results[round].recursive_ns = recurr_total_time / RUNS;
    }

    (void)iter_sum;
    (void)recurr_sum;

    printf("%d\t%d\n", ROUNDS, RUNS);
    for (int round = 0; round < ROUNDS; round++) {
        double iter_average = results[round].iterative_ns;
        double recurr_average = results[round].recursive_ns;
        printf("%d\t%.1f ns (%.3f ms)\t%.1f ns (%.3f ms)\n",
               round + 1, iter_average, iter_average / 1e6,
               recurr_average, recurr_average / 1e6);
    }

    return 0;
}
