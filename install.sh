#!/usr/bin/env bash
#install.sh
#install dwn and its manpage

if [ $(id -u) -ne 0 ]; then
	printf 'this script must be run as root\n' >&2
	exec sudo "$0" $*
fi

if [ ! -d "/usr/local/bin/" ]; then
	mkdir -p "/usr/local/bin/"
	test $? -ne 0 && exit 1;
fi

if [ ! -d "/usr/local/share/man/man1/" ]; then
	mkdir -p "/usr/local/share/man/man1/"
	test $? -ne 0 && exit 1;
fi

chmod +x "./src/dwn.sh"
cp "./src/dwn.sh" "/usr/local/bin/dwn"
cp "./share/man/man1/dwn.1" "/usr/local/share/man/man1/"
exit $?;

# vim: set ts=4 sw=4 noexpandtab:
