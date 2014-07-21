/*
 * xtprof - Thread (logical core) activity profiling for XMOS XCores
 * 
 * Copyright (C) 2014 Steve Kerrison <github@stevekerrison.com>
 *
 * This software is freely distributable under a derivative of the
 * University of Illinois/NCSA Open Source License posted in
 * LICENSE.txt and at <http://github.xcore.com/>
 */
 
#ifndef _XTPROF_H

#ifndef XTPROF_DIRECTORY_SIZE
#define XTPROF_DIRECTORY_SIZE 2
#endif

#define XTPROF_PROBES 2

typedef struct {
    unsigned tt[8][8];
} xtprof_stats;

typedef struct {
    unsigned pc[8];
    unsigned sr[8];
} xtprof_t;

#define XTPROF_CHAN_DECL(n_tiles) chan _xtpc[n_tiles]

#define XTPROF_REGISTER_MASTER(id, n_tiles, interval, xscope_probes)        \
    on tile[id]: xtprof_register(id, _xtpc[id], _xtpc[ (id+1) % n_tiles ],  \
        id, interval, xscope_probes)

#define XTPROF_REGISTER_SLAVE(myid, master_id, n_tiles)                     \
    xtprof_register(myid, _xtpc[myid], _xtpc[ (myid+1) % n_tiles ],         \
        master_id, 0, 0)

#define XTPROF_REGISTER(master_node, n_tiles, interval, xscope_probes)      \
    par (int i = 0; i < n_tiles; i += 1) {                                  \
        on tile[i]: xtprof_register(i, _xtpc[i], _xtpc[ (i+1) % n_tiles ],  \
            master_node, interval, xscope_probes);                          \
    }
    
#define XTPROF_XSCOPE_REGISTER()                                            \
            XSCOPE_CONTINUOUS, "XTProf PCs", XSCOPE_UINT, "arb",               \
            XSCOPE_CONTINUOUS, "XTProf SRs", XSCOPE_UINT, "arb"                \
            
void xtprof_register(unsigned myid, chanend cin, chanend cout, unsigned mst,
    unsigned interval, unsigned xscope_offset);

#endif //_XTPROF_H
