#!/usr/bin/env bash
#dwn
#created by: Kurt L. Manion
#on: 3 April 2016
#last modified: 12 March 2016
version="2.8.1"

#patch note: in 2.6.4 fixed bug for -a flag
#patch note: in 2.7.1 added -m flag
#patch note: in 2.8.1 flag command flow was updated to modern bash syntax
#	and project was added to github

declare r_flg=0
declare l_flg=0
declare m_flg=0

usage() {
	printf '%s\n%s\n%s\n%s\n%s\n' 											\
		'usage '`basename "${1:-dwn}"`' -- open file most recently added to a folder' 	\
		'dwn [-d directory] [-a application]' 								\
		'dwn [-r] -[d directory]' 											\
		'dwn [-d directory] [-l ...literal_commands]'						\
		'dwn [-d directory] [-m destination]'								
	exit 64;
}
version() {
	printf '%s\n' 'dwn version '"$version"''
	exit 64;
}
err() { test -n "$1" && printf 'Err: %s\n' "$1" >&2; exit 65; }

while getopts ":d:a:rlmM:hV" opt "$@"; do
	case "$opt" in
		(d)
			if [[ ${OPTARG:0:1} == "~" ]]; then
				dir="$HOME""${OPTARG:1}"
			elif [[ ${OPTARG:0:1} =~ \.\/ ]]; then
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
			mv_dest='.'
			m_flg=1
			;;
		(h)
			usage
			;;
		(V)
			version
			;;
	esac
done
shift $((OPTIND-1))

test "$#" -gt 0 -a $l_flg -eq 0 && err 'extraneous arguments'

dir=${dir:="~/Downloads"}

test $m_flg -eq 1 && exec mv "`dwn -rd $dir`" "$mv_dest"

filepath=`stat -f "%B%t%SN" "${dir:-"$HOME"/Downloads}"/* | sort -rn | head -1 | cut -f 2` &>/dev/null
test -z "$filepath" && err 'stat command failed'
test ! -r "$filepath" && err 'most recently downloaded file is unreadable'
test -d "$filepath" && exec open -R -- "$filepath"
test $r_flg -eq 1 && { echo "$filepath"; exit 0; }
test $l_flg -eq 1 && exec open "$@" -- "$filepath"
test "$app_path" && exec open -a "$app_path" -- "$filepath" || exec open -- "$filepath"

# vim: set ts=4 sw=4 noexpandtab:
