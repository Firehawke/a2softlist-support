# a2softlist-support
 Support scripts and hacks for pulling data from IA for generating MAME softlist data

## What is this?
 This script, in combination with a few external tools, can pull data from IA to generate MAME softlist data for Apple II disk dumps. It's not expected to be terribly useful to most people:
 
 * The code quality is crap.
 * It does exactly what I need it to do
 * It's relatively easy to read and to modify as needed.
 * The results are pretty solid and require relatively less cleanup than previous efforts did.
 * It's really only useful for someone specifically trying to pull metadata from IA to put into MAME.

# publishers.txt?
 Yeah, this is the part that's going to probably see the most updates over time. The script pulls a grep against the publishers.txt file to try to autodetect who the publisher is, and adding new publishers to the list will cause them to be automagically handled.

## Prereq packages
 As I run Debian from a laptop and as a WSL add-on to Windows 10, the packages will be described in that way.

`sudo apt-get install python3-pip libarchive-zip-perl unzip libxml2-utils`
`sudo pip3 install internetarchive`
