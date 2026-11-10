#include <stdio.h>
#include "led.h"
#include "timing.h"

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



int main(void) {
    // initialise the LED
    led_init();

    unsigned long long N = 10000; 
    int REPEATS = 10000;

    // Use volatile so compiler doesn't optimize away repeated calls at -O2/-O3
    volatile unsigned long long iter_sum = 0;
    volatile unsigned long long recurr_sum = 0;
    
    uint64_t start_time, end_time;
    uint64_t iter_elapsed_time, recurr_elapsed_time;

    // Iterative Benchmark 
    led_on(LED_GREEN);
    start_time = now_ns();
    for (int i = 0; i < REPEATS; i++) {
        iter_sum = iter_func(N);
    }
    end_time = now_ns();
    led_off(LED_GREEN);
    iter_elapsed_time = end_time - start_time;

    // Recursive Benchmark
    led_on(LED_GREEN);
    start_time = now_ns();
    for (int i = 0; i < REPEATS; i++) {
        recurr_sum = recurr_func(N);
    }
    end_time = now_ns();
    led_off(LED_GREEN);
    recurr_elapsed_time = end_time - start_time;

    // Iterative loops vs Recursive functions Results
    printf("Iterative Sum: %llu | Time: %llu ns (%.3f ms)\n", 
           (unsigned long long)iter_sum, 
           (unsigned long long)iter_elapsed_time, 
           (double)iter_elapsed_time / 1e6);

    printf("Recursive Sum: %llu | Time: %llu ns (%.3f ms)\n", 
           (unsigned long long)recurr_sum, 
           (unsigned long long)recurr_elapsed_time, 
           (double)recurr_elapsed_time / 1e6);

    // back to LED defaults
    led_cleanup();
    return 0;
}