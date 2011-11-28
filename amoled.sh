#!/bin/bash
#
#	Amoled - Script to update AM03127-compatible LED signs
#
#    Copyright (C) 2011  Frederic Pasteleurs <frederic@askarel.be>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

ME=$(basename $0)
# Function to call when we bail out
die ()
{
    echo "$ME: $1" 
    if [ "_$2" = "_" ]; then
	exit 1
	else
	exit $2
    fi
}


# The *nix date command can format its output to match what the
# sign expect. Use it. :-)
# Make sure your clock is NTP-synced.
setsignclock ()
{
    echo -n "<SC>$(date '+%y0%u%m%d%H%M%S')"
}

# Clear the sign memory
resetsign ()
{
    echo -n '<D*>'
}

introtag ()
{
    case $1 in
	immediate)
	    echo -n "<FA>"
	    ;;
	xopen)
	    echo -n "<FB>"
	    ;;
	curtainup)
	    echo -n "<FC>"
	    ;;
	curtaindown)
	    echo -n "<FD>"
	    ;;
	scrollleft)
	    echo -n "<FE>"
	    ;;
	scrollright)
	    echo -n "<FF>"
	    ;;
	vopen)
	    echo -n "<FG>"
	    ;;
	vclose)
	    echo -n "<FH>"
	    ;;
	scrollup)
	    echo -n "<FI>"
	    ;;
	scrolldown)
	    echo -n "<FJ>"
	    ;;
	hold)
	    echo -n "<FK>"
	    ;;
	snow)
	    echo -n "<FL>"
	    ;;
	twinkle)
	    echo -n "<FM>"
	    ;;
	blockmove)
	    echo -n "<FN>"
	    ;;
	random)
	    echo -n "<FP>"
	    ;;
	penwritehello)
	    echo -n "<FQ>"
	    ;;
	penwritewelcome)
	    echo -n "<FR>"
	    ;;
	penwriteam)
	    echo -n "<FS>"
	    ;;
	    O)
	    die "Tag <FO> is invalid intro tag according to doc."
	    ;;
	[A-S])
	    echo -n "<F$1>"
	    ;;
	*)
	    die "Valid intro commands: immediate, xopen, curtainup, curtaindown, scrollleft, 
	    scrollright, vopen, vclose, scrollup, scrolldown, hold, snow, twinkle, blockmove, 
	    random, penwritehelllo, penwritewelcome, penwriteam "
	    ;;  
    esac
}


outtrotag ()
{
    case $1 in
	immediate)
	    echo -n "<FA>"
	    ;;
	xopen)
	    echo -n "<FB>"
	    ;;
	curtainup)
	    echo -n "<FC>"
	    ;;
	curtaindown)
	    echo -n "<FD>"
	    ;;
	scrollleft)
	    echo -n "<FE>"
	    ;;
	scrollright)
	    echo -n "<FF>"
	    ;;
	vopen)
	    echo -n "<FG>"
	    ;;
	vclose)
	    echo -n "<FH>"
	    ;;
	scrollup)
	    echo -n "<FI>"
	    ;;
	scrolldown)
	    echo -n "<FJ>"
	    ;;
	hold)
	    echo -n "<FK>"
	    ;;
	[A-K])
	    echo -n "<F$1>"
	    ;;
	*)
	    die "Valid outtro commands: immediate, xopen, curtainup, curtaindown, scrollleft, 
	    scrollright, vopen, vclose, scrollup, scrolldown, hold"
	    ;;  
    esac
}

waittime ()
{
    printf "<W\\$(printf '%3o' $(( $1 + 65 )))>"
}
#Parameter list:
# 1: <Ln> line number (1-9)
# 2: <Pn> Page number (A-Z)
# 3: <Fn> Intro type (A-S without O)
# 4: <Mn> Display method (bitfield ABCDEQRSTUabcdeqrstu)
# 5: <Wn> Wait time (A-Z, 0,5-25 sec)
# 6: <Fn> Outtro type (A-K)

makepage ()
{
    echo
}


# Build the final string: set target sign address, insert data, calculate 
# data checksum and insert end tag. At this point, the data is ready to be 
# sent to the display.
preparedataforsign ()
{
    XORSCRATCH="$(printf '%d' "'${2:0:1}")"
    for i in $(seq 1 $(($(echo -n "$2" |wc -m )-1))); 
    do 
	XORSCRATCH=$(( $XORSCRATCH ^ $(printf '%d' "'${2:$i:1}") ))
    done
    printf "<ID%.2X>$2%X<E>" $1 $XORSCRATCH; 
}

# The sign expect 9600 bauds, 8 bits, no parity, one stop bit (8N1)
serialoutput ()
{
    stty -F $1 9600 cs8 -stopb
    echo $2 > $1
}

waittime $2
preparedataforsign "$1" "$(waittime $2) $3"
echo


