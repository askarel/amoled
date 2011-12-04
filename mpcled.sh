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
    RPAGE=1
    while [ -n "$(echo $RADIO | cut -d '-' -f $RPAGE)" ]; do
	SPAGE=$(( $SPAGE + 1 ))
	echo "$(echo $RADIO|cut -d '-' -f $RPAGE |sed -e 's/ *$//g'|sed -e 's/^ *//g')"|(bash ./amoled.sh -a 1 -i scrollleft -o scrollleft -w 2 -p $(echo $ALPHA|cut -c $SPAGE) -d $SPORT -c red)
	RPAGE=$(( $RPAGE + 1 ))
    done
    # Break down track ID
    TPAGE=1
    while [ -n "$(echo $TRACK | cut -d '-' -f $TPAGE)" ]; do
	SPAGE=$(( $SPAGE + 1 ))
	echo "$(echo $TRACK|cut -d '-' -f $TPAGE |sed -e 's/ *$//g'|sed -e 's/^ *//g')"|(bash ./amoled.sh -a 1 -i scrollleft -o scrollleft -w 2 -p $(echo $ALPHA|cut -c $SPAGE) -d $SPORT -c yellow)
	TPAGE=$(( $TPAGE + 1 ))
    done
    bash ./amoled.sh -k $(echo $ALPHA|cut -c 1-$SPAGE)
    
    sleep 20
done
