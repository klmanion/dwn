# dwn

dwn -- Shell script to manipulate file or files most recently downloaded to a directory

The intention is to preform actions on the file most recently added to the ~/Downloads folder, but dwn can be used on any folder specified with the -d flag.

The options include moving, opening, returning the path, and other file related operations.

## Installation
Just run the install script as root, and dwn will be automatically downloaded into your /usr/local/bin/ and the manpage will be downloaded into /usr/share/man/man1/
```
sudo ./install.sh
```

If for some reason the installation fails, try executing <code>chmod +x ./install.sh</code>
and rerunning the script.
