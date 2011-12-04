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
# WARNING: because the script use arrays, mathematical expressions and string
# WARNING: manipulations, it will run only with bash or busybox ash.

# Some data. Output tag on the left, text description on the right.
# Available sign effects
SEFFECT[1]="<FA>|immediate"
SEFFECT[2]="<FB>|xopen"
SEFFECT[3]="<FC>|curtainup"
SEFFECT[4]="<FD>|curtaindown"
SEFFECT[5]="<FE>|scrollleft"
SEFFECT[6]="<FF>|scrollright"
SEFFECT[7]="<FG>|vopen"
SEFFECT[8]="<FH>|vclose"
SEFFECT[9]="<FI>|scrollup"
SEFFECT[10]="<FJ>|scrolldown"
SEFFECT[11]="<FK>|hold"
SEFFECT[12]="<FL>|snow"			# open only
SEFFECT[13]="<FM>|twinkle"		# open only
SEFFECT[14]="<FN>|blockmove"		# open only
SEFFECT[15]="<FP>|random"		# open only
SEFFECT[16]="<FQ>|penwritehello"	# open only
SEFFECT[17]="<FR>|penwritewelcome"	# open only
SEFFECT[18]="<FS>|penwriteam"		# open only

# Available sign colors
SCOLOR[1]="<CA>|dimred"
SCOLOR[2]="<CB>|red"
SCOLOR[3]="<CC>|brightred"
SCOLOR[4]="<CD>|dimgreen"
SCOLOR[5]="<CE>|green"
SCOLOR[6]="<CF>|brightgreen"
SCOLOR[7]="<CG>|dimorange"
SCOLOR[8]="<CH>|orange"
SCOLOR[9]="<CI>|brightorange"
SCOLOR[10]="<CJ>|yellow"
SCOLOR[11]="<CK>|lime"
SCOLOR[12]="<CL>|inversered"
SCOLOR[13]="<CM>|inversegreen"
SCOLOR[14]="<CN>|inverseorange"
SCOLOR[15]="<CP>|redongreen"
SCOLOR[16]="<CQ>|greenonred"
SCOLOR[17]="<CR>|redyellowgreen"
SCOLOR[18]="<CS>|rainbow"

# font sizes
SFONT[1]="<AA>|normal"	# 5x7 pixels
SFONT[2]="<AB>|bold"	# 6x7 pixels
SFONT[3]="<AC>|narrow"	# 4x7 pixels
SFONT[4]="<AD>|XL"	# 7x13 pixels, for displays with > 16 pixels height only
SFONT[5]="<AE>|long"	# 5x8 pixels, for displays with > 7 pixels height only

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

# For how long should the page stay ? 
# A=0.5 second, Z=25 seconds.
# We will cheat the user and use 0 to mean 0.5 :-)
waittime ()
{
    printf "<W\\$(printf '%3o' $(( $1 + 65 )))>"
}

gettag ()
{
    echo -n "$1"|cut -d '|' -f 1
}

gettagtext ()
{
    echo -n "$1"|cut -d '|' -f 2
}

#Parameter list:
# 1: <Mn> Display method (bitfield ABCDEQRSTUabcdeqrstu)
# 2: Text
makepage ()
{
    echo -n "<L$SLINE><P$SPAGE>$INTROTAG<M$1>$(waittime $WTIME)$OUTTROTAG$2"
}

linkpages ()
{
    echo -n "<TA>00010100009912302359$1" # 30 ou 31 décembre ?
}

# Build the final string: set target sign address, insert data, calculate 
# data checksum and insert end tag. At this point, the data is ready to be 
# sent to the display.
preparedataforsign ()
{
    XORSCRATCH="$(printf '%d' "'${1:0:1}")"
    for i in $(seq 1 $(($(echo -n "$1" |wc -m )-1))); 
    do 
	XORSCRATCH=$(( $XORSCRATCH ^ $(printf '%d' "'${1:$i:1}") ))
    done
    printf "<ID%.2X>$1%X<E>" $ADDR $XORSCRATCH; 
}

# The sign expect 9600 bauds, 8 bits, no parity, one stop bit (8N1)
serialoutput ()
{
    if [ "$SERIALPORT" = "-" ]; then
	echo "$1"
    else
        stty -F $SERIALPORT 9600 cs8 -cstopb
	echo $1 > $SERIALPORT
    fi
}

usage ()
{
 echo "$ME: Small script to update LED signs made by Amplus.
  Usage: echo \"your text\" | $ME [options]
 
    -a		Sign address (0 is broadcast, default address is $ADDR)
    -p		Page number (A-Z) Mandatory parameter.
    -i		Define the opening animation of the page. Random intro if not specified. (use -i help for options)
    -w		wait time, from 0 (0.5 seconds) to 25 seconds. Default is $WTIME
    -o		Define the closing animation of the page. Random outtro if not specified. (use -o help for options)
    -f		Flush sign memory.
    -c		Set the internal clock of the sign using system clock.
    -d		Serial port to use. Default is $SERIALPORT. Use - for stdout.
    -k		Link pages together for immediate display
    -l		Line number, default is $SLINE
    -h		This help screen
"
}

parse_arguments ()
{
    while getopts ":ha:p:i:w:o:fcd:l:k:" OPTION
    do
	case "$OPTION" in
	    a)	ADDR="$OPTARG"		;;
	    p)	SPAGE="$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')"	;;
	    i)	INTROTAG="$OPTARG"	;;
	    w)	WTIME="$OPTARG"		;;
	    o)	OUTTROTAG="$OPTARG"	;;
	    f)	SCOMMAND="resetsign"	;;
	    c)	SCOMMAND="setsignclock"	;;
	    d)	SERIALPORT="$OPTARG"	;;
	    k)	LINKPAGES="$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')"
		SCOMMAND="linkpages"
		;;
	    l)	SLINE="$OPTARG"	;;
	    h|\?|*)
		usage
		exit 1
	    ;;
	    :)
		die "Option $OPTARG requires an argument"
	    ;;
	esac
    done
}

sanitize_arguments ()
{
    case "$SCOMMAND" in
	linkpages)
		serialoutput $(preparedataforsign $(linkpages $LINKPAGES))
		exit 0
	;;
	resetsign)
		preparedataforsign $(resetsign)
		exit 0
	;;
	setsignclock)
		serialoutput $(preparedataforsign $(setsignclock))
		exit 0
	;;
	*)
	test -z "$SPAGE" && die "You must choose a page on the display with the -p parameter"
	;;
    esac
}

# some default values
SERIALPORT="/dev/ttyUSB0"
WTIME="4"
ADDR="1"
SLINE="1"
RNDTAG=$(( $RANDOM % 17 + 1 ))
INTROTAG=$(gettag "${SEFFECT[$RNDTAG]}")
RNDTAG=$(( $RANDOM % 14 + 1 ))
OUTTROTAG=$(gettag "${SEFFECT[$RNDTAG]}")

parse_arguments $@
sanitize_arguments

echo "serial port=$SERIALPORT"
echo "wait time=$WTIME"
echo "sign address=$ADDR"
echo "sign page=$SPAGE"
echo "introtag=$INTROTAG"
echo "outtrotag=$OUTTROTAG"
echo "linkpages=$LINKPAGES"
echo "Line=$SLINE"
echo "SEFFECT size=${#SEFFECT[@]}"

preparedataforsign $(makepage A mouh)

echo

