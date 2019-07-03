#!/usr/bin/env bash
#dwn
# created by: Kurt L. Manion
# on: 3 April 2016
# last modified: 17 Feb. 2019
version="3.8.1"

# Variable declarations {{{1
declare cmd="echo"
declare cmd_flgs=""
declare add_flgs=""
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

declare grep_flgs="-s"

declare name="`basename "${0:-dwn}"`"

# Function declarations {{{1
usage() {
	printf '%s%s\n%s\t%s\n\t%s\n\t%s\n\t%s\n' \
		'usage: '"$name"' -- return path of file most recently ' \
			'added to a directory' \
		"$name" '[-r | -o | -m destination | -M]' \
			'[-d directory] [-f flags] [-n num_files]' \
			'[-S skip_expr | -s skip_num]' \
			'[-g grep_flag] [-e regex] [-x regex]'
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
	suf="`sed -e's/ //g' <<<${skip_expr:-$saved}`"

	local IFS=','
	read -r -a rng_arr <<<${suf}

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
declare optstr=":-:d:hrR:n:f:om:MS:s:e:x:g:hV" 
while getopts $optstr opt "$@"; do
	if [ x"$opt" = x"-" ]; then
		test -z "$OPTARG" && break

		case "$OPTARG" in
		(directory=*)
		(directory)
			opt='d'
			;;

		(here)
			opt='h'
			;;

		(return)
			opt='r'
			;;

		(print-delim=*)
		(print-delim)
			opt='R'
			;;

		(repetitions=*)
		(repetitions)
			opt='n'
			;;

		(flags=*)
		(flags)
			opt='f'
			;;

		(open)
			opt='o'
			;;

		(move=*)
		(move)
			opt='m'
			;;

		(move-here)
			opt='M'
			;;

		(skip-expr=*)
		(skip-expr)
			opt='S'
			;;

		(skip-num=*)
		(skip-num)
			opt='s'
			;;

		(filter=*)
		(filter)
			opt='e'
			;;

		(exclude=*)
		(exclude)
			opt='x'
			;;

		(grep-flags=*)
		(grep-flags)
			opt='g'
			;;

		(help)
			opt='h'
			;;

		(version)
			opt='V'
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
		dir="`sed -e's/\*$//; s/\/$//' <<<${OPTARG}`"
		;;

	(h)
		dir="$PWD"
		;;

	(r)
		cmd="echo"
		cmd_flgs="$cmd_flgs -n"
		cmd_post=""

		test -z "$print_delim" && print_delim=' '
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
		add_flgs="$add_flgs $OPTARG"
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

	(m | M)
		cmd="mv"

		cmd_flgs="$cmd_flgs -n"

		if [ $opt = "m" ]; then
			cmd_post="$OPTARG"
		else
			cmd_post="$PWD"
		fi

		cmd_post="`sed -e's/[|&;()<> ]./\\\&/g' <<<"${cmd_post}"`"
		;;

	(S)
		skip_expr="$OPTARG"
		;;

	(s)
		test -n "`sed -e's/[0-9]*//' <<<${OPTARG}`" \
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

cmd_flgs="$cmd_flgs $add_flgs"

parse_skip_expr

: ${dir:="${DWN_DIR-"${DOWNLOAD_DIR-"${DOWNLOADS}"}"}"}
: ${dir:="$HOME/Downloads"}
eval dir="$dir"
test ! -d "$dir" && err 'specified directory '"$dir"' not found'
# }}}2

# the first is BSD stat, the second is GNU stat
stat --version &>/dev/null \
	&& stat_cmd='stat -printf "%B\t%n\n" "${dir}"/*' \
	|| stat_cmd='stat -f "%B%t%N" "${dir}"/*'

stat_fp_lst="`eval $stat_cmd | sort -rn | cut -d $'\t' -f 2`"

filtered_fp_lst="`sed -e'/\/$/ s_/$__' -e's_^.*/__' <<<${stat_fp_lst}`"

for (( i=0; i<excl_arr_len; ++i )); do
	filtered_fp_lst="`eval grep $grep_flags --invert-match \
		-e"'${excl_arr[$i]}'" \
		<<<${filtered_fp_lst}`"
done

if [ $regex_arr_len -eq 0 ]; then
	filepath_lst="$filtered_fp_lst"
else
	filepath_lst=""
	for (( i=0; i<regex_arr_len; ++i )); do
		filepath_lst="${filepath_lst}`eval grep $grep_flgs \
			-e"'${regex_arr[$i]}'" \
			<<<${filtered_fp_lst}`"
	done
fi

filepath_lst="`tr '\n' '\t' <<<${filepath_lst}`"

IFS=$'\t'
read -r -a filepath_arr <<<${filepath_lst}

len=${#filepath_arr[@]}
for (( dex=0,ct=0; dex<len && (num_files==0 || ct<num_files); ++dex )); do
	filepath="${filepath_arr[$dex]}"

	test -z "$filepath" && err 'stat command failed'

	skip_dex $dex; test $? -eq 1 && continue

	let "++ct"
	escaped_fp="`sed -e's/[|&;()<> ]./\\\&/g' <<<"${filepath}"`"
	eval $cmd $cmd_flgs "$dir/$escaped_fp" $cmd_post
	test -n "$print_delim" && echo -n "$print_delim"
done

exit 0;
# }}}1

# vi: set ts=2 sw=2 noexpandtab tw=79:
