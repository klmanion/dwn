#!/usr/bin/env bash
#dwn
# created by: Kurt L. Manion
# on: 3 April 2016
# last modified: 17 Feb. 2019
version="3.10.0"

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
declare pat_len=1
declare neg_flg=0
declare dash_flg=0
declare num_flg=0

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
	local prf suf hi lo

	test -z "$skip_expr" && return;

	prf="`sed -e's_^\([:^]*\).*_\1_' <<<"${skip_expr}"`"
	suf="`sed -e's_^[:^]*\(.*\)_\1_' <<<"${skip_expr}"`"

	if [ -n "`sed -e's_[-0-9\$, ]__g' <<<"${suf}"`" ]; then
		err 'Invalid character(s) in skip expression'
	fi

	for (( i=0; i<${#prf}; ++i )); do
		case "${prf:i:1}" in
			(:)
				pat_flg=1
#				test $num_files -eq 1 && num_files=0
				;;
			(^)
				neg_flg=1
#				test $num_files -eq 1 && num_files=0
				;;
		esac
	done

	test $num_files -eq 1 && num_files=0

	# DEBUG
	if [ $pat_flg -eq 1 ]; then
		echo "pattern flag enabled"
	else
		echo "pattern flag disabled"
	fi

	if [ $neg_flg -eq 1 ]; then
		echo "negation flag enabled"
	else
		echo "negation flag disabled"
	fi

	printf 'fnum:\t%s\n' $num_files

	local IFS=', '
	read -r -a rng_arr <<<"${suf}"

	# sanitize ranges
	# and find highest upper bound
	for (( i=0; i<${#rng_arr[@]}; ++i )); do
		rng=${rng_arr[i]}

		if [[ $rng =~ [0-9]+-[0-9\$]* ]]; then
			lo="${rng%-*}"
			hi="${rng#*-}"
			test -z $hi && hi=0
		elif [[ $rng =~ -[0-9]+ ]]; then
			lo=1
			hi="${rng#*-}"
		elif [[ $rng =~ [0-9]+ ]]; then
			let "hi = lo = rng"
		else	# shouldn't happen
			err 'bad expression passed to `-S'\'
		fi

		test $lo -eq 0 && err 'cannot set 0 as lower bound'
		test x"$hi" = x"\$" && hi=0

		if [ $pat_len -ne 0 ]; then
			if [ $hi -eq 0 ]; then
				pat_len=0
			else
				test $hi -gt $pat_len && pat_len=$hi
			fi
		fi

		rng_arr[i]="$lo-$hi"
		#DEBUG
		echo "inserting ${rng_arr[i]} at $i"
	done
}

skip_dex() {
	local dex hi lo

	test -z "$skip_expr" && return 0;

	dex=$1
	if [[ $pat_flg -eq 1 && $pat_len -gt 0 ]]; then
		let "dex %= pat_len"
	fi
	let "dex += 1"

	for rng in ${rng_arr[@]}; do
		lo="${rng%-*}"
		hi="${rng#*-}"

		#DEBUG
		echo "rng:"$'\t'"$rng"
		echo "lo:"$'\t'"$lo"
		echo "hi:"$'\t'"$hi"

		test -z $lo && lo=0
		test -z $hi && hi=0

		if [ $hi -eq 0 ]; then
			if [ $dex -ge $lo ]; then
				echo "$lo <= $dex <= $hi -> $((! neg_flg))"
				echo
				return $((! neg_flg));
			fi
		elif [[ $lo -le $dex && $dex -le $hi ]]; then
			#DEBUG
			echo "$lo <= $dex <= $hi -> $((! neg_flg))"
			echo
			return $((! neg_flg));
		fi
	done

	#DEBUG
	echo "$lo <= $dex <= $hi -> $neg_flg"
	echo
	return $neg_flg;
}

# Skip expression {{{2
__retired__parse_skip_expr() {
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
	suf="`sed -e's/ //g' <<<"${skip_expr:-$saved}"`"

	local IFS=','
	read -r -a rng_arr <<<"${suf}"

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
__retired__skip_dex() {
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
declare optstr=":-:d:hrR:n:Nf:om:MS:s:e:x:g:hV" 
while getopts $optstr opt "$@"; do
	if [ x"$opt" = x"-" ]; then
		test -z "$OPTARG" && break

		case "$OPTARG" in
		(directory=*) ;&
		(directory)
			opt='d'
			;;

		(return)
			opt='r'
			;;

		(print-delim=*) ;&
		(print-delim)
			opt='R'
			;;

		(repetitions=*) ;&
		(repetitions)
			opt='n'
			;;

		(number) ;&
		(number-files)
			opt='N'
			;;

		(flags=*) ;&
		(flags)
			opt='f'
			;;

		(open)
			opt='o'
			;;

		(move=*) ;&
		(move)
			opt='m'
			;;

		(move-here)
			opt='M'
			;;

		(skip-expr=*) ;&
		(skip-expr)
			opt='S'
			;;

		(skip-num=*) ;&
		(skip-num)
			opt='s'
			;;

		(filter=*) ;&
		(filter)
			opt='e'
			;;

		(exclude=*) ;&
		(exclude)
			opt='x'
			;;

		(grep-flags=*) ;&
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
			if [[ $OPTARG =~ .*=.* ]]; then
				OPTARG="${OPTARG#*=}"
			else
				shift
				OPTARG="$1"
			fi
		fi
	fi

	case "$opt" in
	(d)
		dir="`sed -e's/\*$//; s/\/$//' <<<"${OPTARG}"`"
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

	(N)
		num_flg=1
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
		test -n "`sed -e's/[0-9]*//' <<<"${OPTARG}"`" \
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

filtered_fp_lst="`sed -n \
	-e'/\/$/ s_/$__' \
	-e's_[^/]*/__g; P' \
	<<<"${stat_fp_lst}"`"

for (( i=0; i<excl_arr_len; ++i )); do
	filtered_fp_lst="`eval grep $grep_flags --invert-match \
		-e"'${excl_arr[$i]}'" \
		<<<"${filtered_fp_lst}"`"
done

if [ $regex_arr_len -eq 0 ]; then
	filepath_lst="$filtered_fp_lst"
else
	filepath_lst=""
	for (( i=0; i<regex_arr_len; ++i )); do
		filepath_lst="${filepath_lst}`eval grep $grep_flgs \
			-e"'${regex_arr[$i]}'" \
			<<<"${filtered_fp_lst}"`"
	done
fi

IFS=$'\t'
filepath_lst="`tr '\n' '\t' <<<"${filepath_lst}"`"
read -r -a filepath_arr <<<"${filepath_lst}"

len=${#filepath_arr[@]}
printf 'num:\t%s\n\n' $num_files #DEBUG
for (( dex=0,ct=0; dex<len && (num_files==0 || ct<num_files); ++dex )); do
	filepath="${filepath_arr[$dex]}"
	#DEBUG
	echo "dex:"$'\t'"$dex"
	echo "ct:"$'\t'"$ct"

	test -z "$filepath" && err 'stat command failed'

	skip_dex $dex; test $? -eq 1 && continue

	escaped_fp="`sed -e's/[|&;()<> '\'']/\\\&/g' <<<"${filepath}"`"

	filename="$dir/$escaped_fp"
	test $num_flg -eq 1 && filename="$ct $filename"

	eval $cmd $cmd_flgs "$filename" $cmd_post
	test -n "$print_delim" && echo -n "$print_delim"
	echo #DEBUG

	let "++ct"
done

exit 0;
# }}}1

# vi: set ts=2 sw=2 noexpandtab tw=79:
