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

# Some data. Output tag on the left, text description on the right.
# Available sign effects
# Tags LMNPQRS are for opening only.
SEFFECT="<FA>|immediate,<FB>|xopen,<FC>|curtainup,<FD>|curtaindown,<FE>|scrollleft,<FF>|scrollright,<FG>|vopen"
SEFFECT="$SEFFECT,<FH>|vclose,<FI>|scrollup,<FJ>|scrolldown,<FK>|hold,<FL>|snow,<FM>|twinkle,<FN>|blockmove"
SEFFECT="$SEFFECT,<FP>|random,<FQ>|penwritehello,<FR>|penwritewelcome,<FS>|penwriteam"
LOSEFFECT=18
LCSEFFECT=11

# Available sign colors
SCOLOR="<CA>|dimred,<CB>|red,<CC>|brightred,<CD>|dimgreen,<CE>|green,<CF>|brightgreen,<CG>|dimorange,<CH>|orange"
SCOLOR="$SCOLOR,<CI>|brightorange,<CJ>|yellow,<CK>|lime,<CL>|inversered,<CM>|inversegreen,<CN>|inverseorange"
SCOLOR="$SCOLOR,<CP>|redongreen,<CQ>|greenonred,<CR>|redyellowgreen,<CS>|rainbow"
LSCOLOR=18

# font sizes
# A: 5x7 pixels
# B: 6x7 pixels
# C: 4x7 pixels
# D: 7x13 pixels, for displays with > 16 pixels height only
# E: 5x8 pixels, for displays with > 7 pixels height only
SFONT="<AA>|normal,<AB>|bold,<AC>|narrow,<AD>|XL,<AE>|long"
LSFONT=5

ME=$(basename $0)
# some default values
SERIALPORT="/dev/ttyUSB0"
WTIME="4"	# Display wait time
ADDR="1"	# Sign address
SLINE="1"	# Line on the display

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
# 1st: Constant string to use
# 2nd: constant string record size
# output: list of valid human readable options.
taghelp ()
{
    for i in $(seq 1 $2); do
	echo -n "$(gettagtext $1 $i)"
	if [ $i -ne $2 ]; then echo -n ', '; fi
    done

}

#Parameter list:
# 1: <Mn> Display method (bitfield ABCDEQRSTUabcdeqrstu)
# 2: Text data
makepage ()
{
    echo -n "<L$SLINE><P$SPAGE>$(gettag $SEFFECT $INTROTAG)<M$1>$(waittime $WTIME)$(gettag $SEFFECT $OUTTROTAG)$(gettag $SCOLOR $SCOLORTAG)$2"
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
    -w N	wait time, from 0 (0.5 seconds) to 25 seconds. Default is $WTIME
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
}

parse_arguments ()
{
    while getopts ":ha:p:i:w:o:ftRd:l:k:c:" OPTION
    do
	case "$OPTION" in
	    a)	ADDR="$OPTARG"		;;	# OK
	    p)	SPAGE="$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')"	;;	# OK
	    i)	case "$OPTARG" in
		    help)
			die "Valid options for -i: $(taghelp $SEFFECT $LOSEFFECT)"
			;;
		    *)
			INTROTAG="$(gettagindex $SEFFECT $OPTARG $LOSEFFECT)"	;;
		esac
		;;
	    w)	WTIME="$OPTARG"		;;	# OK
	    o)	case "$OPTARG" in
		    help)
			die "Valid options for -o: $(taghelp $SEFFECT $LCSEFFECT)"
			;;
		    *)
			OUTTROTAG="$(gettagindex $SEFFECT $OPTARG $LCSEFFECT)"	;;
		esac
		;;
	    f)	SCOMMAND="resetsign"	;;	# OK
	    t)	SCOMMAND="setsignclock"	;;	# OK
	    d)	SERIALPORT="$OPTARG"	;;	# OK
	    c)	case "$OPTARG" in
		    help)
			die "Valid options for -c: $(taghelp $SCOLOR $LSCOLOR)"
			;;
		    *)
			SCOLORTAG="$(gettagindex $SCOLOR $OPTARG $LSCOLOR)"	;;
		esac
		;;
	    k)	LINKPAGES="$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')"
		SCOMMAND="linkpages"
		;;	# OK
	    l)	SLINE="$OPTARG"		;;	# OK
	    R)	echo "-R $OPTARGS"	;;
	    h|\?|*)
		usage
		exit 1
	    ;;
	esac
    done
}

process_arguments ()
{
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
    # Sanity check: are the tags valid ?
    if [ -z "$INTROTAG" ]; then
	INTROTAG=$(( $RANDOM % 17 + 1 ))
	echo "$ME: Warning: invalid or empty option for -i, using randomly chosen: $(gettagtext $SEFFECT $INTROTAG)"
    fi
    if [ -z "$OUTTROTAG" ]; then
	OUTTROTAG=$(( $RANDOM % 10 + 1 ))
	echo "$ME: Warning: invalid or empty option for -o, using randomly chosen: $(gettagtext $SEFFECT $OUTTROTAG)"
    fi
    if [ -z "$SCOLORTAG" ]; then
	SCOLORTAG=$(( $RANDOM % 17 + 1 ))
	echo "$ME: Warning: invalid or empty option for -c, using randomly chosen: $(gettagtext $SCOLOR $SCOLORTAG)"
    fi
}

parse_arguments $@
process_arguments

read -r
preparedataforsign "$(makepage Q "$REPLY")"
