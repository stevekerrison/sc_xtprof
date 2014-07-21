======
XTProf
======

:Maintainer: https://github.com/stevekerrison
:Description: Thread activity monitoring across an XMOS system (using XScope)
 
Description
===========

This module allows code to be instrumented non-invasively to monitor
the activity of threads in a system. The PC/SR registers shadowed into the
switches are used to achieve this.

A thread per tile is required at start, but only one tile needs to keep
a monitor thread running, the rest can handover to the main program. Two
chanends are used per tile as well as two timers on the monitor.

Related Documentation
---------------------
XS1-L System Specification: http://www.xmos.com/en/published/xsysteml .


