#!/bin/bash
# koha@hpl:~/kohaclone/C4/SIP$ for x in 10 11 12 13 14 15 16 17 18 19
for x in 10 11 12 13 14 15 16 17 18 19
do
    echo $x
    cat SIPServer.6003.xml | sed "s/6003/60$x/" > SIPServer.60$x.xml
    grep "6003" sip_run_all.sh | sed "s/6003/60$x/g" >> sip_run_all.sh
done
