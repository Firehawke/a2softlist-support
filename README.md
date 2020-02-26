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

# How to use?

 Both scripts are now set up to count from the END of their respective archives, as I've finally caught up.

 Instead of directly using the `newccgen` and `newwozgen` tools described below, I suggest you read the next paragraph:

 Included in the set are `wozrange` and `ccrange`, scripts that automate the workflow a bit further. They will start from the newest entry and work their way back towards the 100th entry, stopping as soon as they hit any kind of duplicated material. They will then call the `ccgenxml`/`wozgenxml` scripts to condense the output to a single file for quicker editing pass. They will be in reverse order compared to the release list, so you'll need to copy them from bottom to top, then do the necessary final adjustments as you usually would.

 `newccgen` will count from the end of the 4AM cleanly cracked disk archive. Running `newccgen 1` will get you the latest release and generate the XML data accordingly. Running `newccgen 100` will do the 100th release back, and so forth. MAME softlist-compatible XML output will be put in `xml/cc/cc#.xml`, with `newccgen 1` giving you `cc1.xml` and `newccgen 100` giving you `cc100.xml`-- in all cases, this WILL overwrite what's in the file, allowing you to re-run in case of error or if you need to modify publishers.txt or whatever.

 `newwozgen` is likewise set up to count from the end of the 4AM WOZ-a-day archives. Running `newwozgen 1` will grab the latest single release in that collection and generate MAME softlist-compatible XML as `xml/woz/woz1.xml` overwriting whatever is in that file on creation. Running `newwozgen 100` will go back 100 releases from latest and generate a `woz100.xml` file (and again overwriting what's there).

 When run, you will eventually get output that looks like:

 `Duplicated entry. Removing generated XML...`

 That's your official notification that the script eventually got to material already in the softlist and stopped.

## Warnings

 Disk images will be moved to the postsorted directory on completion for ALL scripts included herein. This is to make it significantly easier to just point clrmamepro at the postsorted directory and have it do the final sorting into individual zip files.

 At no point should the output from this ever be directly trusted without an eyeball pass. There will ALWAYS be special cases that no script, no matter how finely-tuned, can deal with.

 You WILL need to doublecheck all output.

 You WILL need to add a shortname in the definition's first line.

 You WILL need to add disk/side tags where appropriate (see existing softlist entries for examples). The script now can autodetect many common filename patterns for disk numbers and side numbers, but some oddly named disks will still fall through the cracks.

 You also will need to make small adjustments to match the formatting used in the MAME softlist files; the comment line that gets output by the script containing the complete description (suitable for doublechecking the work) can be converted to a blank line once you're ready to sign off on the file and that'll get you in line with the usual formatting for Apple softlists.

 So, yeah, this does leave you with a bit of work, but it's still considerably better than hand-editing.

 As of November 19th, 2019, the scripts were updated to use xslt to re-sort the order to make it easier to copy and paste right into the softlist XML file. At the same time, blank publisher entries (meaning autodetection failed) have been changed to output UNKNOWN for those. Keep an eye out for those and fix them (add to publishers.txt as well!) as needed.

 Do keep an eye out for dates that appear like `19901985` -- this happens when a program gets a rerelease. In this example, the program originally came out in 1985, but was rereleased in 1990. You'll need to hand edit the date in this case.

## Chopgen

 Also included is my multi-purpose non-IA tool, chopgen. Chopgen will generate quick and dirty metadata for softlist entries from various disk images you have in the chopgen directory when running the script. It, like the other scripts, will move the disk images to the postsorted folder when completed for later clrmamepro pass.

 This script will probably be modified in the near future to just chop up whatever is in the chopgen folder as opposed to just disk images, making it easier to work with cartridge images of various file extensions.

 Future plans include considering ways to have chopgen pull data from the disk images themselves where possible.

## Prerequisites for use

 As I run Debian from a laptop and also as a WSL add-on to Windows 10, the packages will be described in that way.

`sudo apt-get install python3-pip libarchive-zip-perl unzip libxml2-utils wget xsltproc`

`sudo pip3 install internetarchive`

You will need to change a grep line in each script: they're set to check the Apple softlists in the default install location of the MAME compilation tools via WSL path. Look for `/mnt/c/msys64/src/mame/hash/apple2_flop*.xml` in the script and change accordingly (or set up a mount to redirect those to wherever your MAME hash folder actually is).
