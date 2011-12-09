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
# WARNING: because the script use mathematical expressions and string
# WARNING: manipulations, it will run only with bash or busybox ash.

ME=$(basename $0)
# some default values
SERIALPORT="/dev/ttyUSB0"
WTIME="4"	# Display wait time
ADDR="1"	# Sign address
SLINE="1"	# Line on the display

# Some data. Output tag on the left, text description on the right.
# Available sign effects
# Tags LMNPQRS are for opening only.
SEFFECT="|help,<FA>|immediate,<FB>|xopen,<FC>|curtainup,<FD>|curtaindown,<FE>|scrollleft,<FF>|scrollright,<FG>|vopen"
SEFFECT="$SEFFECT,<FH>|vclose,<FI>|scrollup,<FJ>|scrolldown,<FK>|hold,<FL>|snow,<FM>|twinkle,<FN>|blockmove"
SEFFECT="$SEFFECT,<FP>|random,<FQ>|penwritehello,<FR>|penwritewelcome,<FS>|penwriteam"
LOSEFFECT=19
LCSEFFECT=12

# Available sign colors
SCOLOR="|help,<CA>|dimred,<CB>|red,<CC>|brightred,<CD>|dimgreen,<CE>|green,<CF>|brightgreen,<CG>|dimorange,<CH>|orange"
SCOLOR="$SCOLOR,<CI>|brightorange,<CJ>|yellow,<CK>|lime,<CL>|inversered,<CM>|inversegreen,<CN>|inverseorange"
SCOLOR="$SCOLOR,<CP>|redongreen,<CQ>|greenonred,<CR>|redyellowgreen,<CS>|rainbow"
LSCOLOR=18

# font sizes
# A: 5x7 pixels
# B: 6x7 pixels
# C: 4x7 pixels
# D: 7x13 pixels, for displays with > 16 pixels height only
# E: 5x8 pixels, for displays with > 7 pixels height only
SFONT="|help,<AA>|5x7,<AB>|6x7,<AC>|4x7,<AD>|7x13,<AE>|5x8"
LSFONT=5

# Wait tags
# A: 0.5 seconds, Z: 25 seconds.
SWTIME="|help,<WA>|0.5,<WB>|1,<WC>|2,<WD>|3,<WE>|4,<WF>|5,<WG>|6,<WH>|7,<WI>|8,<WJ>|9,<WK>|10,<WL>|11,<WM>|12,<WN>|13"
SWTIME="$SWTIME,<WO>|14,<WP>|15,<WQ>|16,<WR>|17,<WS>|18,<WT>|19,<WU>|20,<WV>|21,<WW>|22,<WX>|23,<WY>|24,<WZ>|25"
LSWTIME=27

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

# gettag function
# Parameters:
# 1st: Constant string to use
# 2nd: index in the string
# output: the tag for the display
gettag ()
{
    echo -n "$1" | cut -d ',' -f $2 | cut -d '|' -f 1
}

# gettagtext function
# Parameters:
# 1st: Constant string to use
# 2nd: index in the string
# output: the tag description for the user
gettagtext ()
{
    echo -n "$1" | cut -d ',' -f $2 | cut -d '|' -f 2
}

# gettagindex function
# Parameters:
# 1st: Constant string to use
# 2nd: tag description
# 3rd: constant string record size
# output: tag index. return empty string if tag not found
gettagindex ()
{
    for i in $(seq 1 $3); do
    if [ "$(gettagtext $1 $i)" = "$2" ]; then echo "$i"; fi
    done
}

# This function display a list of valid tag descriptions
# Parameters:
# 1st: switch to describe
# 2nd: Constant string to use
# 3rd: constant string record size
# output: list of valid human readable options.
taghelp ()
{
    echo -n "$ME: Valid options for option $1: "
    for i in $(seq 1 $3); do
	echo -n "$(gettagtext $2 $i)"
	if [ $i -ne $3 ]; then echo -n ', '; fi
    done
    echo ""
    exit 1
}

#Parameter list:
# 1: <Mn> Display method (bitfield ABCDEQRSTUabcdeqrstu) NEED A REWRITE
# 2: Text data
makepage ()
{
    echo -n "<L$SLINE><P$SPAGE>$(gettag $SEFFECT $INTROTAG)<M$1>$(gettag $SWTIME $WTIME)$(gettag $SEFFECT $OUTTROTAG)$(gettag $SCOLOR $SCOLORTAG)$2"
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
    if [ "$SERIALPORT" = "-" ]; then
        printf "<ID%.2X>$1%X<E>\n" $ADDR $XORSCRATCH; 
    else
        test -e $SERIALPORT || die "Device $SERIALPORT do not exist"
        test -c $SERIALPORT || die "Device $SERIALPORT is not a character device"
	# The sign expect 9600 bauds, 8 bits, no parity, one stop bit (8N1)
        stty -F $SERIALPORT 9600 cs8 -cstopb
        echo $(printf "<ID%.2X>$1%X<E>" $ADDR $XORSCRATCH;) > $SERIALPORT
    fi
}

################################################################################
### Everything below that line will need a rewrite at some point.
################################################################################

usage ()
{
 echo "$ME: Small script to update LED signs made by Amplus.
  Usage: echo \"your text\" | $ME [options]
 
    -a N	Sign address (0 is broadcast, default address is $ADDR)
    -p N	Page number (A-Z) Mandatory parameter.
    -i anim	Define the opening animation of the page. Random intro if not specified. (use -i help for options)
    -w N	wait time, from 0 (0.5 seconds) to 25 seconds. Default is $(gettagtext $SWTIME $WTIME)
    -o anim	Define the closing animation of the page. Random outtro if not specified. (use -o help for options)
    -f		Flush sign memory.
    -t		Set the internal clock of the sign using system clock.
    -d dev	Serial port to use. Default is $SERIALPORT. Use - for stdout.
    -k AB...	Link pages together for immediate display
    -l N	Line number, default is $SLINE
    -h		This help screen
    -c color	Set text color. Random if not specified (use -c help for options)
    -R		Treat input data as raw page message data.
"
 exit 1
}

parse_arguments ()
{
    while getopts ":ha:p:i:w:o:ftRd:l:k:c:" OPTION
    do
	case "$OPTION" in
	    a)	ADDR="$OPTARG"		;;	# OK
	    p)	SPAGE="$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')"	;;	# OK
	    i)	INTROTAG="$(gettagindex $SEFFECT $OPTARG $LOSEFFECT)"	;;
	    w)	WTIME="$(gettagindex $SWTIME $OPTARG $LSWTIME)"		;;	# OK
	    o)	OUTTROTAG="$(gettagindex $SEFFECT $OPTARG $LCSEFFECT)"	;;
	    f)	SCOMMAND="resetsign"	;;	# OK
	    t)	SCOMMAND="setsignclock"	;;	# OK
	    d)	SERIALPORT="$OPTARG"	;;	# OK
	    c)	SCOLORTAG="$(gettagindex $SCOLOR $OPTARG $LSCOLOR)"	;;
	    k)	LINKPAGES="$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')"
		SCOMMAND="linkpages"
		;;	# OK
	    l)	SLINE="$OPTARG"		;;	# OK
	    R)	echo "-R $OPTARGS"	;;
	    h|\?|*)	usage		;;
	esac
    done
}

process_arguments ()
{
    if [ "$INTROTAG" = "1" ]; then taghelp -i $SEFFECT $LOSEFFECT; fi
    if [ "$OUTTROTAG" = "1" ]; then taghelp -i $SEFFECT $LCSEFFECT; fi
    if [ "$WTIME" = "1" ]; then taghelp -i $SWTIME $LSWTIME; fi
    if [ "$SCOLORTAG" = "1" ]; then taghelp -i $SCOLOR $LSCOLOR; fi
    case "$SCOMMAND" in
	linkpages)
		preparedataforsign $(linkpages $LINKPAGES)
		exit 0
	;;
	resetsign)
		preparedataforsign $(resetsign)
		exit 0
	;;
	setsignclock)
		preparedataforsign $(setsignclock)
		exit 0
	;;
	*)
	test -z "$SPAGE" && die "You must choose a page on the display with the -p parameter"
	;;
    esac
    # Sanity checks: are the tags valid ?
    if [ -z "$INTROTAG" ]; then
	INTROTAG=$(( $RANDOM % $LOSEFFECT + 2 ))
	echo "$ME: Warning: invalid or empty option for -i, using randomly chosen: $(gettagtext $SEFFECT $INTROTAG)"
    fi
    if [ -z "$OUTTROTAG" ]; then
	OUTTROTAG=$(( $RANDOM % $LCSEFFECT + 2 ))
	echo "$ME: Warning: invalid or empty option for -o, using randomly chosen: $(gettagtext $SEFFECT $OUTTROTAG)"
    fi
    if [ -z "$SCOLORTAG" ]; then
	SCOLORTAG=$(( $RANDOM % $LSCOLOR + 2 ))
	echo "$ME: Warning: invalid or empty option for -c, using randomly chosen: $(gettagtext $SCOLOR $SCOLORTAG)"
    fi
}

parse_arguments $@
process_arguments


read -r
preparedataforsign "$(makepage Q "$REPLY")"

#decimal to ascii:    printf "<W\\$(printf '%3o' $(( $1 + 65 )))>"
