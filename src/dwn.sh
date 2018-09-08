#!/usr/bin/env bash
#dwn
#created by: Kurt L. Manion
#on: 3 April 2016
#last modified: 13 June 2018
version="3.0.1"

#patch note: in 2.6.4 fixed bug for -a flag
#patch note: in 2.7.1 added -m flag
#patch note: in 2.8.1 flag command flow was updated to modern bash syntax
#	and project was added to github
#patch note: in 2.9.0 added the -n option
#patch note: in 3.0 -r becomes the default behavior, and -o is introduced

#on kali linux the stat version's first line is
#stat (GNU coreutils) 8.25

declare r_flg=0
declare l_flg=0
declare m_flg=0
declare mv_flgs="-n"
declare num_files=1
declare name="`basename "${0:-dwn}"`"

usage() {
	printf '%s%s\n%s\n%s%s\n%s%s\n' 					\
		'usage: '"$name"' -- return path of file most recently '	\
			'added to a folder' 				\
		"$name"' [-r] [-d directory] [-n num_files]'  		\
		"$name"' [-r] [-d directory] [-o application] '		\
			'[-f flags] [-n num_files]'			\
		"$name"' [-r] [-d directory] [-m destination | -M] '	\
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

while getopts ":d:a:rlm:Mfin:hV" opt "$@"; do
	case "$opt" in
		(d)
			if [[ ${OPTARG:0:1} == "~" ]]; then
				dir="$HOME""${OPTARG:1}"
			elif [[ ${OPTARG:0:1} =~ "\." ]]; then
				dir=`pwd`/"$OPTARG"
			else
				dir="$OPTARG"
			fi
			dir="`echo "$dir" | sed -e 's/\*$//; s/\/$//'`"
			test ! -d "$dir" && err 'directory does not exist'
			;;
		(a)
			app_path="`echo "$2" | sed -e '\
				/^[~\.\/]/ !s/^/&\/Applications\//
				/\.app$/ !s/$/\.app/'`"
			test ! -x "$app_path" && err 'specified application is not executable'
			;;
		(r)
			r_flg=1
			;;
		(l)
			l_flg=1
			break;
			;;
		(m)
			mv_dest="$OPTARG"
			m_flg=1
			;;
		(M)
			mv_dest="$PWD"
			m_flg=1
			;;
		(f)
			mv_flgs="-f"
			;;
		(i)
			mv_flgs="-i"
			;;
		(n)
			num_files="$OPTARG"
			test -n "`echo "$num_files" | sed -e 's/[0-9]*//'`" && \
				err '-n takes only numeric arguments'
			test "$num_files" -lt 1 && \
				err 'number of files must be set to at least 1' 
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

test $# -gt 0 -a $l_flg -eq 0 && err 'extraneous arguments'

: ${dir:="$HOME/Downloads"}

#the first is Darwin, and the second is GNU stat
stat --version &>/dev/null \
	&& stat_cmd='stat --printf "%B\t%n\n" "${dir}"/*' \
	|| stat_cmd='stat -f "%B%t%N" "${dir}"/*'

filepath_lst="`eval "$stat_cmd" | sort -rn | head -$num_files \
	| cut -d $'\t' -f 2 | tr '\n' '\t'`" &>/dev/null

IFS=$'\t'
read -r -a filepath_arr <<< "$filepath_lst"

if [[ x"$OSTYPE" == x"linux-gnu" ]]; then
	open_cmd="xdg-open"
elif [[ x"$OSTYPE" == x"darwin*" ]]; then
	open_cmd="open"
else
	open_cmd="open"
fi

for filepath in "${filepath_arr[@]}"; do
	test -z "$filepath" && err 'stat command failed'
	#test -d "$filepath" && $open_cmd -R "$filepath"
	test $m_flg -eq 1 && { mv "$filepath" "$mv_dest"; continue; }
	test $r_flg -eq 1 && { echo "$filepath"; continue; }
	test ! -r "$filepath" && err 'most recently downloaded file is unreadable'

	if [ $l_flg -eq 1 ]; then
		test -n "$app_path" \
			&& $open_cmd -a "$app_path" "$filepath" \
			|| $open_cmd "$@" "$filepath"
	elif [ $m_flg -eq 1 ]; then
		mv "$mv_flgs" "`dwn -rd $dir`" "$mv_dest"
	else
		test -n "$app_path" \
			&& $open_cmd -a "$app_path" "$filepath" \
			|| $open_cmd "$filepath"
	fi
done

exit 0;

# vim: set ts=8 sw=8 noexpandtab tw=79:
