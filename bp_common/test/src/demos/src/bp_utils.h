#ifndef BP_UTILS_H
#define BP_UTILS_H
#include <stdint.h>

typedef struct bp_lock {
    uint64_t locked;
} bp_lock_t;

void barrier_end(volatile uint64_t * barrier_num, uint64_t total_num_cores);
void lock_init(volatile bp_lock_t * lock);
void lock_spinlock(volatile bp_lock_t * lock);
void unlock_spinlock(volatile bp_lock_t * lock);

#endif
