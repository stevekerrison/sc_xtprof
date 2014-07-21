/*
 * xtprof_example - Demonstration of xtprof in use
 * 
 * Copyright (C) 2014 Steve Kerrison <github@stevekerrison.com>
 *
 * This software is freely distributable under a derivative of the
 * University of Illinois/NCSA Open Source License posted in
 * LICENSE.txt and at <http://github.xcore.com/>
 */

#include <platform.h>
#include <xtprof.h>
#include <xscope.h>

/*
 * Just some useless pipeline to demonstrate activity monitoring.
 * In theory, pipea-pipen and pipen-pipez should be active together about the
 * same amount, but pipea-pipez less so, as they both contend for comms with
 * pipen
 */
 

void pipea(chanend c) {
    int values[1000];
    for (int i = 0; i < 1; i += 1) {
        values[i] += 1;
    }
    while (1) {
        for (int i = 0; i < 1000; i += 20) {
            master {
                for (int j = i; j < i + 20; j += 1) {
                    c <: values[i];
                }
            }
        }
    }
}

void pipen(chanend cin, chanend cout) {
    int values[20];
    while (1) {
        slave {
            for (int i = 0; i < 20; i += 1) {
                cin :> values[i];
                //values[i] << 1;
            }
        }
        master {
            for (int i = 0; i < 20; i += 1) {
                cout <: values[i];
            }
        }
    }
}

void pipez(chanend c) {
    while (1) {
        slave {
            for (int i = 0; i < 20; i += 1) {
                c :> int _;
            }
        }
    }
}

int main(void) {
    // Spcial XTProf channel declaration
    XTPROF_CHAN_DECL(2);
    // Normal program channel declarations
    chan pipeline[2];
    par {
        // Special XTProf master declaration (note that the otherwise unused
        // tile[1] is the target here
        XTPROF_REGISTER_MASTER(1,2,100000,0);
        // XScope can be registered, but some extra macros help you to ensure
        // that XTProf can also utilise xscope registration
        // TODO: How would a user_func registration work?
        on tile[1]: {
            xscope_register(0 + XTPROF_PROBES, XTPROF_XSCOPE_REGISTER() );
            xscope_config_io(XSCOPE_IO_BASIC);
        }
        // Normal program instantiation
        on tile[0]: par {
            {
                // Stick XTProf the slave registration before normal program
                // call to avoid wasting a thread.
                XTPROF_REGISTER_SLAVE(0,1,2);
                pipea(pipeline[0]);
            }
            pipen(pipeline[0], pipeline[1]);
            pipez(pipeline[1]);
        }
    }
    return 0;
}

