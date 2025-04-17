#include "MemoryPool.h"

#include "StreamOutput.h"

#include <mri.h>
#include <cstdio>

// this catches all usages of delete blah. The object's destructor is called before we get here
// it first checks if the deleted object is part of a pool, and uses free otherwise.
void operator delete(void *p)
{
    MemoryPool *m = MemoryPool::first;
    while (m) {
        if (m->has(p)) {
            m->dealloc(p);
            return;
        }
        m = m->next;
    }

    free(p);
}

#define offset(x) ((uint32_t)(((uint8_t *)x) - ((uint8_t *)this->base)))

typedef struct __attribute__((packed)) {
    uint32_t next : 31;
    uint32_t used : 1;

    uint8_t data[];
} _poolregion;

MemoryPool *MemoryPool::first = NULL;

MemoryPool::MemoryPool(void *base, uint16_t size)
{
    this->base = base;
    this->size = size;

    ((_poolregion *)base)->used = 0;
    ((_poolregion *)base)->next = size;

    // insert ourselves into head of LL
    next = first;
    first = this;
}

MemoryPool::~MemoryPool()
{

    // remove ourselves from the LL
    if (first == this) { // special case: we're first
        first = this->next;
        return;
    }

    // otherwise search the LL for the previous pool
    MemoryPool *m = first;
    while (m) {
        if (m->next == this) {
            m->next = next;
            return;
        }
        m = m->next;
    }
}

void *MemoryPool::alloc(size_t nbytes)
{
    // nbytes = ceil(nbytes / 4) * 4
    if (nbytes & 3)
        nbytes += 4 - (nbytes & 3);

    // start at the start
    _poolregion *p = ((_poolregion *)base);

    // find the allocation size including our metadata
    uint16_t nsize = nbytes + sizeof(_poolregion);

    // now we walk the list, looking for a sufficiently large free block
    do {
        if ((p->used == 0) && (p->next >= nsize)) { // we found a free space that's big enough
            // mark it as used
            p->used = 1;

            // if there's free space at the end of this block
            // Ensure there's enough space for a new header plus minimal data (e.g., 4 bytes aligned)
            if (p->next >= (nsize + sizeof(_poolregion) + 4)) // Check if remaining space is usable
            {
                // q points to the start of the remaining free space
                _poolregion *q = (_poolregion *)(((uint8_t *)p) + nsize);

                // write a new block header into q
                q->used = 0;
                q->next = p->next - nsize; // Size of the new free block

                // Update the size of the newly allocated block
                p->next = nsize;

                // sanity check
                if (offset(q) >= size) {
                    // captain, we have a problem!
                    // this can only happen if something has corrupted our heap, since we should simply fail to find a free block if it's full
                    __debugbreak();
                }
            } // else: remaining space is too small to create a new block, so the allocated block takes it all (p->next remains unchanged)

            void *__alloc_ret_ptr = &p->data; // preserve pointer for asm & return

            // Instructions to allow GDB to capture memory allocation
            asm volatile("mov  r1,%0        \n"
                         "mov  r0,%1        \n"
                         ".global memorypool_alloc_return_point \n"
                         "memorypool_alloc_return_point:      \n" ::"r"(nbytes),
                         "r"(__alloc_ret_ptr)
                         : "r0", "r1");

            // then return the data region for the block
            return __alloc_ret_ptr;
        }

        // Check if we've reached the end of the pool without finding a suitable block
        if (offset(p) + p->next >= size) {
            break; // Reached the end of the pool structure
        }

        // p = p->next
        _poolregion *next_p = (_poolregion *)(((uint8_t *)p) + p->next);

        // Safety check: avoid infinite loop or invalid pointers if pool metadata is corrupted
        if (next_p >= (_poolregion *)(((uint8_t *)base) + size) || next_p <= p || next_p->next == 0) {
            // Consider logging an error or handling corruption
            break; // Exit loop if metadata seems corrupt
        }
        p = next_p;

    } while (1);

    // fell off the end of the region or couldn't find a block!
    return NULL;
}

void MemoryPool::dealloc(void *d)
{
    // Check for null pointer deallocation
    if (d == nullptr) {
        return;
    }

    // Check if the pointer is within the pool's bounds before calculating header address
    if (!has(d)) {
        // Optionally, could call ::free(d) here if that's the desired fallback, but risky.
        // Or trigger an error/assert.
        return;
    }

    _poolregion *p = (_poolregion *)(((uint8_t *)d) - sizeof(_poolregion));

    size_t payload = p->next - sizeof(_poolregion);

    // Instructions to allow GDB to capture memory deallocation
    asm volatile("mov  r0,%0        \n"
                 "mov  r1,%1        \n"
                 ".global memorypool_free_hook \n"
                 "memorypool_free_hook:   \n" ::"r"(d),
                 "r"(payload)
                 : "r0", "r1");

    // Sanity check: Ensure calculated header is within bounds and looks plausible
    if (((uint8_t *)p < (uint8_t *)base) || ((uint8_t *)p >= ((uint8_t *)base + size))) {
        __debugbreak(); // Likely memory corruption
        return;
    }

    // Check if the block is already marked as free (double free)
    if (p->used == 0) {
        // __debugbreak(); // Optional: break on double free
        return;
    }

    p->used = 0;

    // --- Coalesce with the next block ---
    _poolregion *q_next = (_poolregion *)(((uint8_t *)p) + p->next);

    // Check if q_next is within the pool boundary before accessing its members
    if (q_next < (_poolregion *)(((uint8_t *)base) + size)) {
        // Now safe to check if the next block is free
        if (q_next->used == 0) {
            // Sanity check before merging
            if ((offset(p) + p->next + q_next->next) > size) {
                __debugbreak(); // Heap corruption likely
            }
            else {
                p->next += q_next->next; // Merge: increase current block's size
            }
        }
    }
    else {
    }

    // --- Coalesce with the previous block ---
    // Walk the list to find the block *before* p
    _poolregion *q_prev = (_poolregion *)base;
    while (q_prev < p) { // Iterate until we find the block whose 'next' points to p
        _poolregion *potential_next = (_poolregion *)(((uint8_t *)q_prev) + q_prev->next);

        if (potential_next == p) {   // Found the previous block (q_prev)
            if (q_prev->used == 0) { // If the previous block is free

                // Sanity check before merging
                if ((offset(q_prev) + q_prev->next + p->next) > size) {
                    __debugbreak(); // Heap corruption likely
                }
                else {
                    q_prev->next += p->next; // Merge: increase previous block's size
                    // p is now merged into q_prev, no further action needed for p
                }
            }
            // Whether merged or not, we found the previous block and are done.
            return;
        }

        // Check for end condition or corruption before advancing q_prev
        if (offset(q_prev) + q_prev->next >= size || q_prev->next <= sizeof(_poolregion)) {
            return; // Stop if we hit the end or see a bad size
        }

        // Move to the next block in the list
        q_prev = potential_next;

        // Additional safety check for infinite loops
        if (q_prev >= (_poolregion *)(((uint8_t *)base) + size) || q_prev->next == 0) {
            return;
        }
    }
    // If loop finishes without returning, it means p was the first block, so no previous to merge with.
}

void MemoryPool::debug(StreamOutput *str)
{
    _poolregion *p = (_poolregion *)base;
    uint32_t total_used = 0;
    uint32_t total_fragmented_free = 0;
    uint32_t unallocated_at_end = 0; // Size of the last block if it's free and touches the end
    str->printf("Start: %u MemoryPool at %p\n", size, p);

    do {
        str->printf("\tChunk at %p (%4lu): %s, %lu bytes\n", p, offset(p), (p->used ? "used" : "free"), p->next);

        bool is_last_block = (offset(p) + p->next >= size);

        if (p->used) {
            total_used += p->next;
        }
        else {
            // If this free block is the very last one in the pool
            if (is_last_block) {
                unallocated_at_end = p->next; // Attributing the final free block correctly
            }
            else {
                total_fragmented_free += p->next; // It's a free fragment somewhere in the middle
            }
        }

        // Check loop termination condition
        if (is_last_block || p->next <= sizeof(_poolregion)) {
            break; // Reached end or invalid block size
        }

        // Move to the next block
        _poolregion *next_p = (_poolregion *)(((uint8_t *)p) + p->next);

        // Safety check: avoid infinite loop or going past end if pool metadata is corrupted
        // Check if next_p is beyond the pool, not pointing forward, or has zero size
        if (next_p >= (_poolregion *)(((uint8_t *)base) + size) || next_p <= p || next_p->next == 0) {
            str->printf("WARNING: Pool metadata might be corrupted or inconsistent at block %p. Aborting debug walk.\n",
                        p);
            // Reset calculated values as they might be unreliable
            total_used = 0;
            total_fragmented_free = 0;
            unallocated_at_end = 0;
            break;
        }
        p = next_p;

    } while (1);

    uint32_t total_free_calculated = total_fragmented_free + unallocated_at_end;

    // Verify consistency check using the ->free() method which independently walks the list
    uint32_t total_free_verified = this->free();
    if (total_used + total_free_calculated != size &&
        (total_used != 0 || total_fragmented_free != 0 || unallocated_at_end != 0)) {
        str->printf("WARNING: Pool sizes calculated by debug walk don't add up! Used(%lu) + FragmentedFree(%lu) + "
                    "Unallocated(%lu) != Size(%u)\n",
                    total_used, total_fragmented_free, unallocated_at_end, size);
        str->printf("         Using verified Total Free: %lu\n", total_free_verified);
        // If inconsistent, trust the dedicated free() calculation unless it also mismatches
        if (total_used + total_free_verified != size) {
            str->printf("ERROR: Severe pool corruption suspected. Used + Verified Free != Size.\n");
            // Keep calculated values but flag the severe error
        }
        else {
            // If verified free makes sense with used, adjust reported free components proportionally (or just report the verified total)
            // For simplicity, just report the verified total free when inconsistent
            total_fragmented_free = 0;                   // Mark as unknown due to inconsistency
            unallocated_at_end = 0;                      // Mark as unknown due to inconsistency
            total_free_calculated = total_free_verified; // Trust the verified total
        }
    }
    else if (total_free_calculated != total_free_verified) {
        // This case means (used + calculated_free == size) but (calculated_free != verified_free)
        // This also indicates an inconsistency, likely in the debug walk logic vs free() logic.
        str->printf("WARNING: Discrepancy between debug walk free count (%lu) and verified free count (%lu). Using "
                    "verified count.\n",
                    total_free_calculated, total_free_verified);
        total_fragmented_free = 0;                   // Mark as unknown due to inconsistency
        unallocated_at_end = 0;                      // Mark as unknown due to inconsistency
        total_free_calculated = total_free_verified; // Trust the verified total
    }

    str->printf("End: Pool Size %u, Used %lu, Fragmented Free %lu, Unallocated %lu, Total Free %lu\n", size, total_used,
                total_fragmented_free, unallocated_at_end, total_free_calculated);
}

bool MemoryPool::has(void *p)
{
    return ((p >= base) && (p < (void *)(((uint8_t *)base) + size)));
}

// Calculates total free space by walking the list
uint32_t MemoryPool::free()
{
    uint32_t free_bytes = 0;
    _poolregion *p = (_poolregion *)base;

    do {
        if (p->used == 0) {
            free_bytes += p->next; // Add the size of the free block
        }

        // Check for end condition or corruption before advancing p
        if (offset(p) + p->next >= size || p->next <= sizeof(_poolregion)) {
            break; // Reached end or invalid block size
        }

        _poolregion *next_p = (_poolregion *)(((uint8_t *)p) + p->next);

        // Safety check for corruption
        if (next_p >= (_poolregion *)(((uint8_t *)base) + size) || next_p <= p || next_p->next == 0) {
            // Log error if possible, but return calculated free so far
            break;
        }
        p = next_p;

    } while (1);

    return free_bytes;
}
