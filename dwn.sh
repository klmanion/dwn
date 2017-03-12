#!/usr/bin/env bash
#dwn
#created by: Kurt L. Manion
#on: 3 April 2016
#last modified: 17 May 2016
#version: 2.7.4

#patch note: in 2.6.4 fixed bug for -a flag
#patch note: in 2.7.1 added -m flag
err() { printf 'Err: %s\n' "$1" >&2; exit 64; }

(($# >= 1)) && [[ ${1:0:1} != - ]] && err 'dwn only takes flag arguments'
if [[ "$1" =~ ^-m$ ]]; then
	if (($# != 2)); then
		err '-m takes one argument'
	fi
	exec mv "`dwn -r`" "$2"
fi
if [[ "$1" =~ ^-[rd][rd]$ ]]; then
  (($# == 2)) && exec dwn -d "$2" -r || err 'only one argument follows -rd'
fi
while (($# >= 2)) && [[ x$1 != x-l ]]; do
  case "$1" in
    (-d) 
      if [[ x${2:0:1} == x"~" ]]; then
        dir=$HOME"${2:1}"
      elif [[ ${2:0:1} =~ \.\/ ]]; then
        dir=`pwd`/"$2"
      else
        dir="$2"
      fi
      dir="`echo "$dir" | sed -e 's/\*$//; s/\/$//'`"
      test ! -d "$dir" && err 'directory does not exist'
      ;;
    (-a)
      app_path="`echo "$2" | sed -e '\
        /^[~\.\/]/ !s/^/&\/Applications\//
        /\.app$/ !s/$/\.app/'`"
      test ! -x "$app_path" && err 'specified application is not executable'
      ;;
  esac
  shift; shift
done
filepath=`stat -f "%B%t%SN" "${dir:-"$HOME"/Downloads}"/* | sort -rn | head -1 | cut -f 2` &>/dev/null
test -z "$filepath" && err 'stat command failed'
test ! -r "$filepath" && err 'most recently downloaded file is unreadable'
test -d "$filepath" && exec open -R -- "$filepath"
if (($# >= 1)); then
  test x"$1" = x"-r" && { echo "$filepath"; exit 0; }
  test x"$1" = x"-l" && exec open "${@:2}" -- "$filepath"
fi
test "$app_path" && exec open -a "$app_path" -- "$filepath" || exec open -- "$filepath"

# vim: set ts=4 sw=4 noexpandtab:
