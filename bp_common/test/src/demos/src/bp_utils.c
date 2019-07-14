#include <stdint.h>
#include "bp_utils.h"

void barrier_end(volatile uint64_t * barrier_num, uint64_t total_num_cores) {
    uint64_t atomic_inc = 1;
    uint64_t atomic_result;
    
    __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) 
                                            : "r"(barrier_num), "r"(atomic_inc)
                                            :);
    while(*barrier_num < total_num_cores) {

    }
    
}

void lock_init(volatile bp_lock_t * lock) {
    lock -> locked = 0;
}

void lock_spinlock(volatile bp_lock_t * lock) {
    uint64_t swap_value = 1;

    do {
        __asm__ volatile("amoswap.d %0, %2, (%1)": "=r"(swap_value) 
                                                 : "r"(&(lock->locked)), "r"(swap_value)
                                                 :);
    } while (swap_value != 0);
}

void unlock_spinlock(volatile bp_lock_t *lock) {
    uint64_t swap_value = 0;
    __asm__ volatile("amoswap.d %0, %2, (%1)": "=r"(swap_value) 
                                                 : "r"(&(lock->locked)), "r"(swap_value)
                                                 :);
}
