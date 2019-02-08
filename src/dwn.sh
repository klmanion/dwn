#!/usr/bin/env bash
#dwn
# created by: Kurt L. Manion
# on: 3 April 2016
# last modified: 10 Nov. 2018
version="3.6.0"

# Variable declarations {{{1
declare cmd="echo"
declare cmd_flgs=""
declare cmd_post=""

declare print_delim=""

declare dir=""
declare num_files=1

declare skip_expr=""

declare -a rng_arr

declare pat_flg=0
declare pat_len
declare neg_flg=0
declare dash_flg=0

declare -a regex_arr
declare regex_arr_len=0

declare -a excl_arr
declare excl_arr_len=0

declare grep_flgs=""

declare name="`basename "${0:-dwn}"`"

# Function declarations {{{1
usage() {
	printf '%s%s\n%s%s\n\t%s\n' 				\
		'usage: '"$name"' -- return path of file most recently '\
			'added to a folder' 				\
		"$name"' [-r | -o | -m destination | -M] '		\
			'[-d directory] [-f flags] [-n num_files] '	\
			'[-S skip_expr | -s skip_num] [-g grep_flag] [-e regex]'
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

# Skip expression {{{2
parse_skip_expr() {
	local saved suf hi lo

	let "pat_flg = neg_flg = dash_flg = 0"

	for (( i=0; i<${#skip_expr}; ++i )); do
		case "${skip_expr:i:1}" in
		(:)
			pat_flg=1
			test $num_files -eq 1 && num_files=0
			;;
		(^)
			neg_flg=1
			test $num_files -eq 1 && num_files=0
			;;
		(-)
			dash_flg=1
			saved=$i
			break
			;;
		(*)
			saved=$i
			break
			;;
		esac
	done

	# prefixed control characters accounted for;
	# now, examine the index's in-/ex-clusion in the given ranges
	suf="`echo "${skip_expr:saved}" | sed -e 's/ //g'`"

	local IFS=','
	read -r -a rng_arr <<< "$suf"

	if [ $pat_flg -eq 1 ]; then
		local _dash_flg=$dash_flg

		for rng in ${rng_arr[@]}; do
			if [ $_dash_flg -eq 1 ]; then
				lo=1
				hi="${rng:1}"
				_dash_flg=0
	
				test -n "`echo "$hi" | sed -e 's/[0-9\$]*//'`" \
					&& err 'invalid bound for range'
			elif [[ $rng =~ [0-9]+-[0-9\$]* ]]; then
				lo="${rng%-*}"
				hi="${rng#*-}"
			elif [[ $rng =~ [0-9]+ ]]; then
				let "hi = lo = rng"
			else
				err 'bad expression passed to `-S'\'' opt'
			fi
	
			test -z "$hi" -o $hi -eq 0 && hi="\$"
	
			if [ x"$hi" = x"\$" ]; then
				pat_flg=0
				break
			elif [ -z "$pat_len" ]; then
				pat_len=$hi
			elif [ $pat_len -lt $hi ]; then
				pat_len=$hi
			fi
		done
	fi

	return 0;
}

# returns arithmetic boolean
skip_dex() {
	local dex hi lo

	test -z "$skip_expr" && return 0;
	
	let "dex = $1 + 1"

	test $pat_flg -eq 1 && let "dex %= pat_len"

	local _dash_flg=$dash_flg

	for rng in ${rng_arr[@]}; do
		# error checking already done for this in parse_skip_expr()
		if [ $_dash_flg -eq 1 ]; then
			lo=1
			hi="${rng:1}"
			_dash_flg=0
		elif [[ $rng =~ [0-9]+-[0-9\$]* ]]; then
			lo="${rng%-*}"
			hi="${rng#*-}"
		elif [[ $rng =~ [0-9]+ ]]; then
			let "hi = lo = rng"
		fi

		if [ ! "$hi" = "\$" ]; then
			if [ -z "$hi" ] || [ $hi -eq 0 ]; then
				hi="\$"
			fi
		fi

		if [ $pat_flg -eq 1 ]; then
			let "lo %= pat_len"
			let "hi %= pat_len"
		fi

		if [[ $dex -ge $lo && ($hi = \$ || $dex -le $hi) ]]; then
			return $((! neg_flg));
		fi
	done

	return $neg_flg;
}

# Main script {{{1

# Option parsing {{{2
declare optstr=":-:d:rR:n:fom:MS:s:e:x:g:hV" 
while getopts $optstr opt "$@"; do
	if [ x"$opt" = x"-" ]; then
		case "$OPTARG" in
		(directory=*)
		(directory)
			opt="d"
			;;

		(return)
			opt="r"
			;;

		(print-delim=*)
		(print-delim)
			opt="R"
			;;

		(repetitions=*)
		(repetitions)
			opt="n"
			;;

		(flags=*)
		(flags)
			opt="f"
			;;

		(open)
			opt="o"
			;;

		(move=*)
		(move)
			opt="m"
			;;

		(move-here)
			opt="M"
			;;

		(skip-expr=*)
		(skip-expr)
			opt="S"
			;;

		(skip-num=*)
		(skip-num)
			opt="s"
			;;

		(regex=*)
		(regex)
			opt="e"
			;;

		(exclude=*)
		(exclude)
			opt="x"
			;;

		(grep-flags=*)
		(grep-flags)
			opt="g"
			;;

		(help)
			opt="h"
			;;

		(version)
			opt="V"
			;;

		(*=*)
			err '--'"${OPTARG%%=*}"' does not take an argument'
			;;
		(*)
			err 'unknown option --'"${OPTARG%%=*}"''
			;;
		esac

		if [ -n `expr $optstr : ".*\($opt:\)"` ]; then
			if [ -n "${OPTARG#*=}" ]; then
				OPTARG="${OPTARG#*=}"
			else
				shift
				OPTARG="$1"
			fi
		fi
	fi

	case "$opt" in
	(d)
		if [[ ${OPTARG:0:1} == \~ ]]; then
			dir="$HOME${OPTARG:1}"
		elif [[ ${OPTARG:0:1} =~ \. ]]; then
			dir="$PWD/$OPTARG"
		else
			dir="$OPTARG"
		fi
		dir="`echo "$dir" | sed -e 's/\*$//; s/\/$//'`"
		test ! -d "$dir" && err 'directory does not exist'
		;;
	(r)
		cmd="echo"
		cmd_flgs="$cmd_flgs -n"
		cmd_post=""

		test -z "$print_delim" && print_delim=" "
		;;
	(R)
		cmd="echo"
		cmd_flgs="$cmd_flgs -n"
		cmd_post=""

		print_delim="$OPTARG"
		;;
	(n)
		num_files="$OPTARG"
		test -n "`echo "$num_files" | sed -e 's/[0-9]*//'`" \
			&& err '-n takes only numeric arguments'
		test "$num_files" -lt 0 \
			&& err 'number of files must be set to at least 0' 
		;;
	(f)
		cmd_flgs="$cmd_flgs $OPTARG"
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
	(m)
		cmd="mv"

		cmd_flgs="$cmd_flgs -n"

		cmd_post="$OPTARG"
		;;
	(M)
		cmd="mv"

		cmd_flgs="$cmd_flgs -n"

		cmd_post="$PWD"
		;;
	(S)
		skip_expr="$OPTARG"
		;;
	(s)
		test -n "`echo "$OPTARG" | sed -e 's/[0-9]*//'`" \
			&& err '-s takes only numeric arguments'
		skip_expr="-$OPTARG"
		;;
	(e)
		regex_arr[$regex_arr_len]="$OPTARG"
		let "++regex_arr_len"
		;;
	(x)
		excl_arr[$excl_arr_len]="$OPTARG"
		let "++excl_arr_len"
		;;
	(g)
		if [[ ${OPTARG:0:1} == - ]]; then
			grep_flgs="$grep_flgs $OPTARG"
		else
			grep_flgs="$grep_flgs -$OPTARG"
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

cmd_flgs="${cmd_flgs## }"

parse_skip_expr

: ${dir:="${DOWNLOAD_DIR:-"$HOME/Downloads"}"}
# }}}2

# the first is Darwin, the second is GNU stat
stat --version &>/dev/null \
	&& stat_cmd='stat --printf "%B\t%n\n" "${dir}"/*' \
	|| stat_cmd='stat -f "%B%t%N" "${dir}"/*'

stat_fp_lst="`eval "$stat_cmd" | sort -rn | cut -d $'\t' -f 2`" &>/dev/null

filtered_fp_lst="$stat_fp_lst"
for (( i=0; i<excl_arr_len; ++i )); do
	filtered_fp_lst="`echo "$filtered_fp_lst" \
		| eval grep $grep_flags --invert-match -e\'"${excl_arr[$i]}"\'`"
done

if [ $regex_arr_len -eq 0 ]; then
	filepath_lst="$filtered_fp_lst"
else
	filepath_lst=""
	for (( i=0; i<regex_arr_len; ++i )); do
		append="`echo "$filtered_fp_lst" \
			| eval grep $grep_flgs -e"${regex_arr[$i]}"`"

		if [ -z $filepath_lst ]; then
			filepath_lst="$append"
		else
			filepath_lst="$filepath_lst"$'\n'"$append"
		fi
	done
fi

filepath_lst="`echo "$filepath_lst" | tr '\n' '\t'`"

IFS=$'\t'
read -r -a filepath_arr <<< "$filepath_lst"

len=${#filepath_arr[@]}
for (( dex=0,ct=0; dex<len && (num_files==0 || ct<num_files); ++dex )); do
	filepath="${filepath_arr[$dex]}"

	test -z "$filepath" && err 'stat command failed'

	skip_dex $dex
	if [ ! $? -eq 1 ]; then
		let "++ct"

		eval $cmd $cmd_flgs \'"$filepath"\' $cmd_post

		test -n "$print_delim" && echo -n "$print_delim"
	fi
done

exit 0;
# }}}1

# vi: set ts=8 sw=8 noexpandtab tw=79:
