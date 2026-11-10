#include <stdio.h>
#include "led.h"
#include "timing.h"

int main(void) {

    /* 
        N=100,000,000
        unsigned: only No. >= 0
        long long: 64bits to accomadate the sum of N size.
        
        example:
        int: 2.14 x 10^9
        SUM: 50005000 or 5x10^15
        result: overflow if using int.
        
        How to fix?
        Use either INT64 or long long
    */

    unsigned long long N = 0;
    unsigned long long counter = 1;
    unsigned long long sum = 0;
    
    uint64_t start_time, end_time, elapsed_time;

    // enter 100,000,000
    printf("Enter N: ");
    if (scanf("%llu", &N) != 1) {
        printf("Invalid input!\n");
        return 1;
    }

    // track start time
    start_time = now_ns();

    // computing the sum iteratively
    while (counter <= N) {
        sum += counter;
        counter++;
    }

    // track end time
    end_time = now_ns();
    
    // find the duration/elapsed time in ms.
    elapsed_time = end_time - start_time;
    double elapsed_ms = (double)elapsed_time / 1000000.0;

    printf("Sum: %llu\n", sum);
    printf("Elapsed time: %llu ns (%.3f ms)\n", (unsigned long long)elapsed_time, elapsed_ms);

    return 0;
}