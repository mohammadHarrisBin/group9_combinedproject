#include <stdio.h>
#include "led.h"
#include "timing.h"


int main(){
    /*

    Write a loop that adds up the numbers 1 to N, where N is typed in by the user. 
    Start with N = 100,000,000. Time it with the provided now_ns() function at -O0, 
    -O1, -O2 and -O3, and record the speedups.
    
    */
    
    unsigned long long N, counter=1, sum=0; // 100,000,000 is a big number for normal int to handle
    uint64_t start_time, end_time, elapsed_time; // now_ns returns a uint64_t in timings.h

    printf("Enter N: ");
    if (scanf("%llu", &N) != 1) {
        printf("Invalid input!\n");
        return 1;
    }

    start_time = now_ns();

    while(counter <= N){
        sum+=counter;
        counter++;
    }

    end_time = now_ns();
    elapsed_time = end_time - start_time;
    double elapsed_ms = (double)elapsed_time / 1000000.0;

    // printf("Start time: %d\n", start_time);
    // printf("Start time: %d\n", end_time);
    printf("Sum: %llu\n", sum); // long long unsigned
    printf("Elapsed time: %lu ns (%.3f ms)\n", elapsed_time, elapsed_ms);
    
    // printf("Elapsed time: %lu ns\n", elapsed_time); // uint64 is == unsigned long
    // // convert to ms as well cause ns is so unreadable
    return 0;
    
}

