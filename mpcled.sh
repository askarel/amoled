#!/bin/bash

# Some constants
MPDHOST="192.168.3.5"
SPORT="-"
ALPHA="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
SPAGE=1

(bash ./amoled.sh -D $SPORT -T)
echo "<KT>"|(bash ./amoled.sh -D $SPORT -A 1 -i immediate -o immediate -p $(echo $ALPHA|cut -c $SPAGE)  -c green )
#(bash ./amoled.sh -D $SPORT -A 1 -i immediate -o immediate -p $(echo $ALPHA|cut -c $SPAGE)  -c green -t "<KT>")


while true; do
    MPC="$(mpc --host=$MPDHOST current|tr -s ' ' ' ')"
    SPAGE=1
    RADIO="$(echo $MPC | cut -d ':' -f 1)"
    TRACK="$(echo $MPC | cut -d ':' -f 2-)"
    # Break down 'radio' ID
    RPAGE=1
    while [ -n "$(echo $RADIO | cut -d '-' -f $RPAGE)" ]; do
	SPAGE=$(( $SPAGE + 1 ))
#	bash ./amoled.sh -D $SPORT -A 1 -i scrollleft -o scrollleft -w 2 -p $(echo $ALPHA|cut -c $SPAGE) -c red -t "$(echo $RADIO|cut -d '-' -f $RPAGE)"
	echo "$(echo $RADIO|cut -d '-' -f $RPAGE |sed -e 's/ *$//g'|sed -e 's/^ *//g')" |(bash ./amoled.sh -D $SPORT -A 1 -i scrollleft -o scrollleft -w 2 -p $(echo $ALPHA|cut -c $SPAGE) -c red )
	RPAGE=$(( $RPAGE + 1 ))
    done
    # Break down track ID
    TPAGE=1
    while [ -n "$(echo $TRACK | cut -d '-' -f $TPAGE)" ]; do
	SPAGE=$(( $SPAGE + 1 ))
	echo "$(echo $TRACK|cut -d '-' -f $TPAGE |sed -e 's/ *$//g'|sed -e 's/^ *//g')" |(bash ./amoled.sh -D $SPORT -A 1 -i scrollleft -o scrollleft -w 2 -p $(echo $ALPHA|cut -c $SPAGE) -c yellow )
#	bash ./amoled.sh -D $SPORT -A 1 -i scrollleft -o scrollleft -w 2 -p $(echo $ALPHA|cut -c $SPAGE) -c yellow -t "$(echo $TRACK|cut -d '-' -f $TPAGE)"

	TPAGE=$(( $TPAGE + 1 ))
    done
    bash ./amoled.sh -D $SPORT -K $(echo $ALPHA|cut -c 1-$SPAGE)
    
    sleep 20
done
