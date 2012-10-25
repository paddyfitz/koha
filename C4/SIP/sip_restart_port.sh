#!/bin/bash



target="SIPServer.$1.xml";
PROCPID=$(ps x -o pid,ppid,args --sort ppid | grep "^[^ ]*  *[0-9]*  *1  *.*$target" | grep -v grep | awk '{print $1}');

if [ ! $PROCPID ] ; then
    echo "No processes found for $target";
else
    echo "SIP Processes for this user ($USER):";
    ps x -o pid,ppid,args --sort ppid | grep "$target" | grep -v grep ;
    for x in $PROCPID
    do
        echo "Killing process #$x";
        kill $x;
    done
fi
echo /home/koha/kohaclone/C4/SIP/sip_run.sh ./SIPServer.$1.xml /home/koha/koha-dev/var/log/sip_$1.out /home/koha/koha-dev/var/log/sip_$1.err
/home/koha/kohaclone/C4/SIP/sip_run.sh ./SIPServer.$1.xml /home/koha/koha-dev/var/log/sip_$1.out /home/koha/koha-dev/var/log/sip_$1.err
