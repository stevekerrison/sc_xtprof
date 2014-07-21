/*
 * xtprof - Thread (logical core) activity profiling for XMOS XCores
 * 
 * Copyright (C) 2014 Steve Kerrison <github@stevekerrison.com>
 *
 * This software is freely distributable under a derivative of the
 * University of Illinois/NCSA Open Source License posted in
 * LICENSE.txt and at <http://github.xcore.com/>
 */

#include <assert.h>
#include <xs1.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <xscope.h>
#include "xtprof.h"

struct xtprof_directory_entry {
    unsigned l; // Logical ID
    unsigned n; // Network ID
};

struct xtprof_directory {
    struct xtprof_directory_entry e[XTPROF_DIRECTORY_SIZE];
    unsigned entries;
};

void xtprof_sample_tile(unsigned tileid, xtprof_t &xtprof_data);
unsigned xtprof_thread_running(unsigned sr, unsigned pc);
void xtprof_run(chanend cid, struct xtprof_directory &dir, unsigned interval,
    unsigned xscope_offset);
void xtprof_sample_tiles(unsigned tile[num_tiles],
    xtprof_t xtprof_data[num_tiles], unsigned num_tiles);

unsigned xtprof_thread_running(unsigned sr, unsigned pc) {
    // Check fastmode or not waiting
    // TODO: Better way of checking allocated threads?
    return ( pc != 0x1008a ) && ( (sr & 0x80) || ( (sr & 0x40) == 0) );
}

/*
 * Samples PCs and SRs, trying to determine which threads run together.
 * Sampling period is (obviously) lower than core clock, so it is
 * IMPRECISE. The sampling rate is configurable. Faster sampling rates
 * will generate more network activity, but the packets are fairly small.
 * TODO: Maybe add some noise to the sampling period and/or loop to avoid
 * pathalogical mis-sampling?
 */
void xtprof_run(chanend cid, struct xtprof_directory &dir, unsigned interval,
    unsigned xscope_offset) {
    timer t1,t2;
    unsigned tv, ptv;
    xtprof_t xtp[XTPROF_DIRECTORY_SIZE];
    xtprof_stats xts[XTPROF_DIRECTORY_SIZE];
    unsigned total_samples = 0;
    // Let's not be too aggressive
    interval = interval < 1000 ? 1000 : interval;
    memset(xts, 0, sizeof(xts));
    t1 :> tv;
    t2 :> ptv;
    ptv = (ptv + 100000000);
    while (1) {
        total_samples += 1;
        for (int i = 0; i < dir.entries; i += 1) {
            xtprof_sample_tile(dir.e[i].n, xtp[i]);
        }
        for (int i = 0; i < dir.entries; i += 1) {
            for (int j = 0; j < 8; j +=1 ) {
                unsigned xscope_data = (dir.e[i].l << 25) | (j << 21);
                xscope_int(xscope_offset,
                    xscope_data | (xtp[i].pc[j] & 0x000fffff) );
                xscope_int(xscope_offset + 1,
                    0x0010000 | xscope_data | (xtp[i].sr[j] & 0x000fffff) );
                for (int k = j; k < 8; k += 1) {
                    xts[i].tt[j][k] +=
                        xtprof_thread_running(xtp[i].sr[j], xtp[i].pc[j]) &&
                        xtprof_thread_running(xtp[i].sr[k], xtp[i].pc[k]);
                }
            }
        }
        select {
            case t2 when timerafter(ptv) :> ptv:
                ptv += 100000000;
                for (int i = 0; i < dir.entries; i += 1) {
                    for (int j = 0; j < 8; j +=1 ) {
                        for (int k = j; k < 8; k += 1) {
                            if (xts[i].tt[j][k] && j != k) {
                                printf("%u,%u,%u,%u\n",
                                    dir.e[i].l, j, k, xts[i].tt[j][k]);
                            }
                        }
                    }
                }
                printf("%u\n",total_samples);
                break;
            case t1 when timerafter(tv + interval) :> tv:
                break;
         }
    }
    return;
}

/*
 * We pass some values around to map XC tile[] IDs to node IDs so we can
 * probe all nodes from a single thread on one node.
 * TODO: Consider a fan-out channel setup instead of ring to save on chanends.
 */
void xtprof_register(unsigned myid, chanend cin, chanend cout, unsigned mst,
    unsigned interval, unsigned xscope_offset) {
    struct xtprof_directory dir;
    unsigned nid = get_local_tile_id();
    unsigned lcl;
    __asm__ __volatile__("testlcl %0,res[%1]":"=r"(lcl):"r"(cin));
    if (lcl) {
        // Single core system
        assert(mst == myid);
        dir.entries = 1;
        dir.e[0].l = myid;
        dir.e[0].n = nid;
        xtprof_run(cin, dir, interval, xscope_offset);
    }
    if (mst == myid) {
        dir.entries = 1;
        dir.e[0].l = myid;
        dir.e[0].n = nid;
        cout <: dir;
        cin :> dir;
        xtprof_run(cin, dir, interval, xscope_offset);
    } else {
        cin :> dir;
        assert(dir.entries < XTPROF_DIRECTORY_SIZE);
        dir.e[dir.entries].l = myid;
        dir.e[dir.entries].n = nid;
        dir.entries += 1;
        cout <: dir;
    }
}

void xtprof_sample_tile(unsigned tileid, xtprof_t &xtprof_data) {
    for (int i = 0; i < 8; i += 1) {
        assert(read_pswitch_reg(tileid, 0x40 + i, xtprof_data.pc[i]));
        assert(read_pswitch_reg(tileid, 0x60 + i, xtprof_data.sr[i]));
    }
    return;
}

void xtprof_sample_tiles(unsigned tile[num_tiles],
    xtprof_t xtprof_data[num_tiles], unsigned num_tiles) {
    for (int i = 0; i < num_tiles; i += 1) {
        xtprof_sample_tile(tile[i], xtprof_data[i]);
    }
}
