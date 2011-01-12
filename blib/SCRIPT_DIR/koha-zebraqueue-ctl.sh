#!/bin/bash
USER=koha
GROUP=koha
DBNAME=koha
NAME=koha-zebraqueue-ctl-$DBNAME
LOGDIR=/home/koha/koha-dev/var/log
PERL5LIB=/home/koha/kohaclone
KOHA_CONF=/home/koha/koha-dev/etc/koha-conf.xml
ERRLOG=$LOGDIR/koha-zebraqueue.err
STDOUT=$LOGDIR/koha-zebraqueue.log
OUTPUT=$LOGDIR/koha-zebraqueue-output.log
export KOHA_CONF
export PERL5LIB
ZEBRAQUEUE=/home/koha/koha-dev/bin/zebraqueue_daemon.pl

test -f $ZEBRAQUEUE || exit 0

OTHERUSER=''
if [[ $EUID -eq 0 ]]; then
    OTHERUSER="--user=$USER.$GROUP"
fi

case "$1" in
    start)
      echo "Starting Zebraqueue Daemon"
      daemon --name=$NAME --errlog=$ERRLOG --stdout=$STDOUT --output=$OUTPUT --verbose=1 --respawn --delay=30 $OTHERUSER -- perl -I $PERL5LIB $ZEBRAQUEUE -f $KOHA_CONF 
      ;;
    stop)
      echo "Stopping Zebraqueue Daemon"
      daemon --name=$NAME --errlog=$ERRLOG --stdout=$STDOUT --output=$OUTPUT --verbose=1 --respawn --delay=30 $OTHERUSER --stop -- perl -I $PERL5LIB $ZEBRAQUEUE -f $KOHA_CONF 
      ;;
    restart)
      echo "Restarting the Zebraqueue Daemon"
      daemon --name=$NAME --errlog=$ERRLOG --stdout=$STDOUT --output=$OUTPUT --verbose=1 --respawn --delay=30 $OTHERUSER --restart -- perl -I $PERL5LIB $ZEBRAQUEUE -f $KOHA_CONF 
      ;;
    *)
      echo "Usage: /etc/init.d/$NAME {start|stop|restart}"
      exit 1
      ;;
esac
