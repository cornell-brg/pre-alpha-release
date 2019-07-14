#include "histogram_data.h"
#include "bp_utils.h"

#ifndef NUM_CORES
#define NUM_CORES 2
#endif

#define ELEMENTS_PER_CORE NUM_POINTS/NUM_CORES

volatile uint64_t start_barrier_mem = 0;
volatile uint64_t end_barrier_count = 0;


volatile uint64_t result_bins[NUM_BINS];
volatile bp_lock_t bin_locks[NUM_BINS];

int check_result() {
    uint64_t i;
    for(i = 0; i < NUM_BINS; i++) {
        if (result_bins[i] != ref_bins[i]) {
            return 1;
        }
    }
    return 0;
}

void dummy_loop() {
    while(1) { 
        int dummy_read = start_barrier_mem;
    }
}

uint64_t calculate_start_index (uint64_t elements_per_core, uint64_t core_id) {
    uint64_t i;
    uint64_t accumulate = 0;
    for (i = 0; i < core_id; i++) {
        accumulate += elements_per_core;
    }
    return accumulate;
}

void thread_main(uint64_t core_id) {
    uint64_t start_index = calculate_start_index(ELEMENTS_PER_CORE, core_id); 
    uint64_t i;
    uint64_t index;

    for (i = 0; i < ELEMENTS_PER_CORE; i++) {
        index = data_array[i + start_index] >> BIN_INDEX_SHIFT;
        lock_spinlock(bin_locks + index);
        result_bins[index] += 1;
        unlock_spinlock(bin_locks + index);

    }


}

int main(uint64_t argc, char * argv[]) {
    uint64_t i;
    uint64_t core_id;
    int result;
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);
   
    // only core 0 intializes data structures
    if (core_id == 0) {
        // initialize results array to zero
        for (i = 0; i < NUM_BINS; i++) {
            result_bins[i] = 0;
        }
        // initialize locks
        for (i = 0; i< NUM_BINS; i++) {
            lock_init(bin_locks + i);
        }
        
        start_barrier_mem = 0xdeadbeef;
    }
    else {
        while (start_barrier_mem != 0xdeadbeef) { }
    }

    thread_main(core_id);
  
    barrier_end(&end_barrier_count, NUM_CORES);
    // all cores are checking result right now
    result = check_result();

    return result;
}
