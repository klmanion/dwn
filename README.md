# dwn

dwn -- Shell script to open file most recently downloaded to a folder

The intention is to preform actions on the file most recently added to the ~/Downloads folder, but dwn can be used on any folder specified with the -d flag.

The options include moving, opening, returning the path, and other file related operations.

# Installation
Eventualy there will be an install script, but for now make dwn.sh executable, move it into your PATH, and move dwn.1 into your manpage directory.
```
chmod +x ./dwn.sh
sudo cp ./dwn.sh /usr/local/bin/dwn
sudo cp ./dwn.1 /usr/share/man/man1/
```
