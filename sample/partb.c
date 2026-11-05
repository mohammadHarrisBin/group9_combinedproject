#include <stdio.h>
#include "led.h"
#include "timing.h"

// function prototype
unsigned long long iter_func(unsigned long long N);
unsigned long long recurr_func(unsigned long long N);

// iterative function
unsigned long long iter_func(unsigned long long N){
    unsigned long long sum = 0;
    for (unsigned long long i = 1; i <= N; i++ ){
        sum+=i;
    }
    return sum;
}

// recursive function
unsigned long long recurr_func(unsigned long long N){
    if(N <= 1){
        return N;
    } 
    return N + recurr_func(N - 1);
}

int main(){
    led_init();
    unsigned long long N = 10000; 
    int REPEATS = 10000; // Repeat 10,000 times for accurate timing

    unsigned long long iter_sum = 0, recurr_sum = 0; 
    uint64_t start_time, end_time, iter_elapsed_time, recurr_elapsed_time; // now_ns returns a uint64_t in timings.h

    // printf("Enter N: ");
    // if (scanf("%llu", &N) != 1) {
    //     printf("Invalid input!\n");
    //     return 1;
    // }


    // -----------------------------------------------------------//
    // 1. getting the sum and duration of the process 
    // during iteration function
    // -----------------------------------------------------------//
    led_on(LED_GREEN);
    start_time = now_ns();
    
    for(int i = 0; i < REPEATS; i++){
        iter_sum = iter_func(N);
    }
    end_time = now_ns();
    led_off(LED_GREEN);

    iter_elapsed_time = end_time - start_time;
    // printf("%lu ns \n", iter_elapsed_time);


    // -----------------------------------------------------------//
    // 2. getting the sum and duration of the process during 
    // recurring function
    // ----------------------------------------------------------//
    led_on(LED_GREEN);
    start_time = now_ns();
    for(int i = 0; i < REPEATS; i++){
        recurr_sum = recurr_func(N);
    }
    end_time = now_ns();
    led_off(LED_GREEN);
    recurr_elapsed_time = end_time - start_time;
    // printf("%lu ns \n", iter_elapsed_time);




    // -----------------------------------------------------------//
    // 3. Print Results
    // -----------------------------------------------------------//
    printf("Iterative Sum: %llu | Time: %lu ns (%.3f ms)\n", 
        iter_sum, iter_elapsed_time, (double)iter_elapsed_time / 1e6);

    printf("Recursive Sum: %llu | Time: %lu ns (%.3f ms)\n", 
        recurr_sum, recurr_elapsed_time, (double)recurr_elapsed_time / 1e6);
    
    led_cleanup();
    return 0;

    
}