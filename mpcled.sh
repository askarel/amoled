#!/bin/bash

# Some constants
MPDHOST="192.168.4.3"
SPORT="/dev/ttyUSB0"
ALPHA="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
SPAGE=1

(bash ./amoled.sh -t)
echo "<KT>"|(bash ./amoled.sh -a 1 -i immediate -o immediate -p $(echo $ALPHA|cut -c $SPAGE) -d $SPORT -c green)


while true; do
    MPC="$(mpc --host=$MPDHOST current|tr -s ' ' ' ')"
    SPAGE=1
    RADIO="$(echo $MPC | cut -d ':' -f 1)"
    TRACK="$(echo $MPC | cut -d ':' -f 2-)"
    # Break down 'radio' ID
    SPAGE=2
    echo $RADIO|cut -d '-' -f 1|sed -e 's/ *$//g'|(bash ./amoled.sh -a 1 -i curtainup -o curtainup -p $(echo $ALPHA|cut -c $SPAGE) -d $SPORT -c red)
    SPAGE=3
    echo $RADIO|cut -d '-' -f 2|(bash ./amoled.sh -a 1 -i scrollleft -o scrollleft -p C -d $SPORT -c red)
    SPAGE=4
    echo \"$TRACK\"
    echo $TRACK|(bash ./amoled.sh -a 1 -i scrollleft -o scrollleft -p $(echo $ALPHA|cut -c $SPAGE) -d $SPORT -c yellow)
    
    sleep 20
done
