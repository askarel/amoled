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
WTIME="4"	# Sign wait time for one page
ADDR="1"	# Sign address
SLINE="1"	# Line on the display
FONTTAG="7"	# Use default display font
MYBELL="28"	# Do not ring the bell
#SCOLORTAG="20"	# Use default sign color (usually orange)

# Some data. Output tag on the left, text description on the right.

# Available sign effects
# Tags LMNPQRS are for opening only. (mandatory)
SEFFECT="|help,<FA>|immediate,<FB>|xopen,<FC>|curtainup,<FD>|curtaindown,<FE>|scrollleft,<FF>|scrollright,<FG>|vopen"
SEFFECT="$SEFFECT,<FH>|vclose,<FI>|scrollup,<FJ>|scrolldown,<FK>|hold,<FL>|snow,<FM>|twinkle,<FN>|blockmove"
SEFFECT="$SEFFECT,<FP>|random,<FQ>|penwritehello,<FR>|penwritewelcome,<FS>|penwriteam"
LOSEFFECT=19
LCSEFFECT=12

# Available sign colors
SCOLOR="|help,<CA>|dimred,<CB>|red,<CC>|brightred,<CD>|dimgreen,<CE>|green,<CF>|brightgreen,<CG>|dimorange,<CH>|orange"
SCOLOR="$SCOLOR,<CI>|brightorange,<CJ>|yellow,<CK>|lime,<CL>|inversered,<CM>|inversegreen,<CN>|inverseorange"
SCOLOR="$SCOLOR,<CP>|redongreen,<CQ>|greenonred,<CR>|redyellowgreen,<CS>|rainbow,|"
LSCOLOR=20

# font size (optional)
# A: 5x7 pixels
# B: 6x7 pixels
# C: 4x7 pixels
# D: 7x13 pixels, for displays with > 16 pixels height only
# E: 5x8 pixels, for displays with > 7 pixels height only
SFONT="|help,<AA>|5x7,<AB>|6x7,<AC>|4x7,<AD>|7x13,<AE>|5x8,|"
LSFONT=7

# Wait tags
# A: 0.5 seconds, Z: 25 seconds. (optional, but the sign will wait 0.5 seconds without the tag)
SWTIME="|help,<WA>|0.5,<WB>|1,<WC>|2,<WD>|3,<WE>|4,<WF>|5,<WG>|6,<WH>|7,<WI>|8,<WJ>|9,<WK>|10,<WL>|11,<WM>|12,<WN>|13"
SWTIME="$SWTIME,<WO>|14,<WP>|15,<WQ>|16,<WR>|17,<WS>|18,<WT>|19,<WU>|20,<WV>|21,<WW>|22,<WX>|23,<WY>|24,<WZ>|25"
LSWTIME=27

# Bell tags, by 0.5 seconds increment (optional)
SBELL="|help,<BA>|0.5,<BB>|1,<BC>|1.5,<BD>|2,<BE>|2.5,<BF>|3,<BG>|3.5,<BH>|4,<BI>|4.5,<BJ>|5,<BK>|5.5,<BL>|6,<BM>|6.5"
SBELL="$SBELL,<BN>|7,<BO>|7.5,<BP>|8,<BQ>|8.5,<BR>|9,<BS>|9.5,<BT>|10,<BU>|10.5,<BV>|11,<BW>|11.5,<BX>|12,<BY>|12.5,<BZ>|13,|"
LSBELL=28

# Method tag matrix. Still need to figure out how to calculate the deltas. (mandatory)
# speed		solid	blinking	song1	song2	song3
# fast		<MA>	<MB>		<MC>	<MD>	<ME>
#		<MQ>	<MR>		<MS>	<MT>	<MU>
#		<Ma>	<Mb>		<Mc>	<Md>	<Me>
# slow		<Mq>	<Mr>		<Ms>	<Mt>	<Mu>
SMETHOD="<MA>|,<MB>|,<MC>|,<MD>|,<ME>|,<MQ>|,<MR>|,<MS>|,<MT>|,<MU>|,<Ma>|,<Mb>|,<Mc>|,<Md>|,<Me>|,<Mq>|,<Mr>|,<Ms>|,<Mt>|,<Mu>|"

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

# Skip N columns from left hand side of display. Do nothing if parameter is empty.
skipcolumns ()
{
    test -z "$1" || printf "<N%.2X>" $1
}

# Make a text page. Add the bell, the skip tag, some color and a font before the text.
textpage ()
{
    echo -n "$(gettag $SBELL $MYBELL)$(skipcolumns $SKIPCOL)$(gettag $SCOLOR $SCOLORTAG)$(gettag $SFONT $FONTTAG)$1"
}

#Parameter list:
# 1: <Mn> Display method (bitfield ABCDEQRSTUabcdeqrstu) NEED A REWRITE
# 2: Text data
makepage ()
{
    echo -n "<L$SLINE><P$SPAGE>$(gettag $SEFFECT $INTROTAG)<M$1>$(gettag $SWTIME $WTIME)$(gettag $SEFFECT $OUTTROTAG)$2"
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
    # Note: in Bash, the string start at zero.
    XORSCRATCH="$(printf '%d' "'${1:0:1}")" #' Syntax highlighters choke on that.
    for i in $(seq 1 $(($(echo -n "$1" |wc -m )-1))); 
    do 
	XORSCRATCH=$(( $XORSCRATCH ^ $(printf '%d' "'${1:$i:1}") )) #' Syntax highlighters choke on that.
    done
    if [ "$SERIALPORT" = "-" ]; then
        printf "<ID%.2X>$1%.2X<E>\n" $ADDR $XORSCRATCH; 
    else
        test -e $SERIALPORT || die "Device $SERIALPORT do not exist"
        test -c $SERIALPORT || die "Device $SERIALPORT is not a character device"
	# The sign expect 9600 bauds, 8 bits, no parity, one stop bit (8N1)
        stty -F $SERIALPORT 9600 cs8 -cstopb
        echo $(printf "<ID%.2X>$1%.2X<E>" $ADDR $XORSCRATCH;) > $SERIALPORT
    fi
}

################################################################################
### Everything below that line will need a rewrite at some point.
################################################################################

usage ()
{
 echo "$ME: Small script to update LED signs made by Amplus.
  Usage: echo \"your text\" | $ME [options]
 
 Sign controls and port settings:
    -A N	Sign address (0 is broadcast, default address is $ADDR)
    -D dev	Serial port to use. Default is $SERIALPORT. Use - for stdout.
    -F		Flush sign memory.
    -h		This help screen
    -K AB...	Link pages together for immediate display
    -T		Set the internal clock of the sign using system clock.
 Page data:
    -p N	Page number (A-Z) Mandatory parameter.
    -i anim	Define the opening animation of the page. Random intro if not specified. (use -i help for options)
    -b N	Ring the bell for N seconds (0.5 to 13 seconds with 0.5 seconds increment)
    -w N	wait time, from 0.5 second to 25 seconds. Default is $(gettagtext $SWTIME $WTIME).
    -o anim	Define the closing animation of the page. Random outtro if not specified. (use -o help for options)
    -l N	Line number, default is $SLINE
    -c color	Set text color. Random if not specified (use -c help for options)
    -f font	Font to use. (Use -f help for options)
    -s N	Skip N 1-pixel-wide columns from left side
    -t TEXT	Text to display (NOT WORKING: use the pipe method)
    -g DATA	Graphic block to display (not implemented)
    -k		Insert clock (not implemented)
    -d		Insert date (not implemented)
    -R		Treat input data as raw page message data. (not implemented)
"
 exit 1
}

parse_arguments ()
{
    while getopts ":hA:p:i:w:o:FTRD:l:K:c:f:t:s:b:" OPTION
    do
	case "$OPTION" in
	    A)	ADDR="$OPTARG"		;;	# OK
	    D)	SERIALPORT="$OPTARG"	;;	# OK
	    F)	SCOMMAND="resetsign"	;;	# OK
	    K)	LINKPAGES="$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')"
		SCOMMAND="linkpages"
		;;	# OK
	    T)	SCOMMAND="setsignclock"	;;	# OK
	    p)	SPAGE="$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')";;	# OK
	    i)	INTROTAG="$(gettagindex $SEFFECT $OPTARG $LOSEFFECT)"	;;
	    w)	WTIME="$(gettagindex $SWTIME $OPTARG $LSWTIME)"		;;	# OK
	    o)	OUTTROTAG="$(gettagindex $SEFFECT $OPTARG $LCSEFFECT)"	;;
	    c)	SCOLORTAG="$(gettagindex $SCOLOR $OPTARG $LSCOLOR)"	;;
	    l)	SLINE="$OPTARG"		;;	# OK
	    f)	FONTTAG="$(gettagindex $SFONT $OPTARG $LSFONT)"		;;
	    t)	MYTEXT="$OPTARG"; echo "$OPTARG"	;;
	    R)	echo "-R $OPTARG"	;;
	    s)	SKIPCOL="$OPTARG"	;;
	    b)	MYBELL="$(gettagindex $SBELL $OPTARG $LSBELL)"		;;
	    h|\?|*)	usage		;;
	esac
    done
}

process_arguments ()
{
    if [ "$INTROTAG" = "1" ]; then taghelp -i $SEFFECT $LOSEFFECT; fi
    if [ "$OUTTROTAG" = "1" ]; then taghelp -o $SEFFECT $LCSEFFECT; fi
    if [ "$WTIME" = "1" ]; then taghelp -w $SWTIME $LSWTIME; fi
    if [ "$SCOLORTAG" = "1" ]; then taghelp -c $SCOLOR $LSCOLOR; fi
    if [ "$FONTTAG" = "1" ]; then taghelp -f $SFONT $LSFONT; fi
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
preparedataforsign "$(makepage Q "$(textpage "$REPLY")")"
#preparedataforsign "$(makepage Q "$(textpage "$MYTEXT")")"

#decimal to ascii:    printf "<W\\$(printf '%3o' $(( $1 + 65 )))>"
