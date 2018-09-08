#!/usr/bin/env bash
#dwn
#created by: Kurt L. Manion
#on: 3 April 2016
#last modified: 13 June 2018
version="3.0.2"

#patch note: in 2.6.4 fixed bug for -a flag
#patch note: in 2.7.1 added -m flag
#patch note: in 2.8.1 flag command flow was updated to modern bash syntax
#	and project was added to github
#patch note: in 2.9.0 added the -n option
#patch note: in 3.0 -r becomes the default behavior, and -o is introduced

#on kali linux the stat version's first line is
#stat (GNU coreutils) 8.25

declare cmd=""
declare cmd_flgs=""
declare cmd_post=""

declare num_files=1

declare name="`basename "${0:-dwn}"`"

usage() {
	printf '%s%s\n%s\n%s%s\n%s%s\n' 				\
		'usage: '"$name"' -- return path of file most recently '\
			'added to a folder' 				\
		"$name"' [-r] [-d directory] [-n num_files]'  		\
		"$name"' [-d directory] [-o application] [-f flags] '	\
			'[-n num_files]'				\
		"$name"' [-d directory] [-m destination | -M] '		\
			'[-f flags] [-n num_files]'
	exit 64;
}

version() {
	printf '%s\n' "$name"' version '"$version"''
	exit 64;
}

err() {
	test -n "$1" \
		&& printf "$name"': Err: %s\n' "$1" >&2 \
		|| printf "$name"': Err\n' >&2
	exit 65;
}

while getopts ":d:rn:fm:MohV" opt "$@"; do
	case "$opt" in
	(d)
		if [[ x${OPTARG:0:1} == x"~" ]]; then
			dir="$HOME""${OPTARG:1}"
		elif [[ x${OPTARG:0:1} =~ x"\." ]]; then
			dir=`pwd`/"$OPTARG"
		else
			dir="$OPTARG"
		fi
		dir="`echo "$dir" | sed -e 's/\*$//; s/\/$//'`"
		test ! -d "$dir" && err 'directory does not exist'
		;;
	(r)
		cmd=""
		cmd_flgs=""
		cmd_post=""
		;;
	(n)
		num_files="$OPTARG"
		test -n "`echo "$num_files" | sed -e 's/[0-9]*//'`" && \
			err '-n takes only numeric arguments'
		test "$num_files" -lt 1 && \
			err 'number of files must be set to at least 1' 
		;;
	(f)
		cmd_flgs="$cmd_flgs $OPTARG"
		;;
	(m)
		cmd="mv"

		cmd_post="$OPTARG"
		;;
	(M)
		cmd="mv"

		cmd_flgs="$cmd_flgs -n"

		cmd_post="$PWD"
		;;
	(o)
		if [[ x"$OSTYPE" == x"linux-gnu" ]]; then
			cmd="xdg-open"
		elif [[ x"$OSTYPE" == x"darwin*" ]]; then
			cmd="open"
		else
			cmd="open"
		fi
		;;
	(h)
		usage
		;;
	(V)
		version
		;;
	(\?)
		err 'unknown argument '"$OPTARG"''
		;;
	esac
done
shift $((OPTIND-1))

test $# -gt 0 && err 'extraneous arguments'

: ${dir:="$HOME/Downloads"}

#the first is Darwin, and the second is GNU stat
stat --version &>/dev/null \
	&& stat_cmd='stat --printf "%B\t%n\n" "${dir}"/*' \
	|| stat_cmd='stat -f "%B%t%N" "${dir}"/*'

filepath_lst="`eval "$stat_cmd" | sort -rn | head -$num_files \
	| cut -d $'\t' -f 2 | tr '\n' '\t'`" &>/dev/null

IFS=$'\t'
read -r -a filepath_arr <<< "$filepath_lst"

for filepath in "${filepath_arr[@]}"; do
	test -z "$filepath" && err 'stat command failed'

	test -z "$cmd" \
		&& echo "$filepath" \
		|| $cmd "$cmd_flgs" "$filepath" "$cmd_post"
done

exit 0;

# vim: set ts=8 sw=8 noexpandtab tw=79:
