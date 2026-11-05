#include <stdio.h>
#include "led.h"
#include "timing.h"

int main(void) {
    unsigned long long N = 0;
    unsigned long long counter = 1;
    unsigned long long sum = 0;
    
    uint64_t start_time, end_time, elapsed_time;

    printf("Enter N: ");
    if (scanf("%llu", &N) != 1) {
        printf("Invalid input!\n");
        return 1;
    }

    start_time = now_ns();

    while (counter <= N) {
        sum += counter;
        counter++;
    }

    end_time = now_ns();
    elapsed_time = end_time - start_time;
    double elapsed_ms = (double)elapsed_time / 1000000.0;

    printf("Sum: %llu\n", sum);
    printf("Elapsed time: %llu ns (%.3f ms)\n", (unsigned long long)elapsed_time, elapsed_ms);

    return 0;
}