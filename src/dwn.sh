#!/usr/bin/env bash
#dwn
#created by: Kurt L. Manion
#on: 3 April 2016
#last modified: 12 March 2016
version="2.9.1"

#patch note: in 2.6.4 fixed bug for -a flag
#patch note: in 2.7.1 added -m flag
#patch note: in 2.8.1 flag command flow was updated to modern bash syntax
#	and project was added to github
#patch note: in 2.9.0 added the -n option

declare r_flg=0
declare l_flg=0
declare m_flg=0
declare num_files=1
declare name="`basename "${0:-dwn}"`"

usage() {
	printf '%s\n%s\n%s\n%s\n%s\n' 										\
		'usage '"$name"' -- open file most recently added to a folder' 	\
		"$name"' [-d directory] [-a application] [-n num_files]' 		\
		"$name"' [-r] [-d directory] [-n num_files]'  					\
		"$name"' [-d directory] [-n num_files] [-l ...literal_commands]'\
		"$name"' [-d directory] [-m destination | -M] [-n num_files]'
	exit 64;
}
version() {
	printf '%s\n' "$name"' version '"$version"''
	exit 64;
}
err() { test -n "$1" && printf "$name"': Err: %s\n' "$1" >&2; exit 65; }

while getopts ":d:a:rlm:Mn:hV" opt "$@"; do
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

dir="${dir:=$HOME/Downloads}" #FIXME: there's a better way to do this

test $m_flg -eq 1 && exec mv "`dwn -rd "$dir"`" "$mv_dest"

filepath_lst="`stat -f "%B%t%SN" "${dir}"/* | sort -rn | head -$num_files | cut -f 2 | tr '\n' '\t'`" &>/dev/null

IFS=$'\t'
read -r -a filepath_arr <<< "$filepath_lst"

for filepath in "${filepath_arr[@]}"; do

	test -z "$filepath" && err 'stat command failed'
	#test -d "$filepath" && open -R -- "$filepath"
	test $r_flg -eq 1 && { echo "$filepath"; continue; }
	test ! -r "$filepath" && err 'most recently downloaded file is unreadable'
	if [ $l_flg -eq 1 ]; then
		test -n "$app_path" && open -a "$app_path" -- "$filepath" \
			|| open "$@" -- "$filepath"
	fi
	test -n "$app_path" && open -a "$app_path" -- "$filepath" \
		|| open -- "$filepath"

done

exit 0;
# vim: set ts=4 sw=4 noexpandtab:
