#!/usr/bin/env bash
#install.sh
# install dwn and its manpage

if [ ! -d "$PWD/src/" ]; then
	printf 'this script must be run in the top-level directory' >&2
	exit 1;
fi

if [ $(id -u) -ne 0 ]; then
	printf 'this script must be run as root\n' >&2
	exec sudo "$0" $*
fi

install -dv '/usr/local/bin/'
install -Cv "$PWD/src/dwn.sh" '/usr/local/bin/dwn'
install -dv '/usr/local/share/man/man1/'
install -Cv "$PWD/share/man/man1/dwn.1" '/usr/local/share/man/man1/dwn.1'
exit $?

# vi: set ts=8 sw=8 noexpandtab tw=79:
