# a2softlist-support
 Support scripts and hacks for pulling data from IA for generating MAME softlist data

## What is this?
 This script, in combination with a few external tools, can pull data from IA to generate MAME softlist data for Apple II disk dumps. It's not expected to be terribly useful to most people:

 * The code quality is less crap than before, but still not great.
 * It does exactly what I need it to do.
 * It's relatively easy to read and to modify as needed.
 * The results are pretty solid and require relatively less cleanup than previous efforts did.
 * It's really only useful for someone specifically trying to pull metadata from IA to put into MAME.

# publishers.txt?
 Yeah, this is the part that's going to probably see the most updates over time. The script pulls a grep against the publishers.txt file to try to autodetect who the publisher is, and adding new publishers to the list will cause them to be automagically handled.

# How to use?

 The previous multi-script setup has been replaced with a brand new refactored `ia2sl.sh` script. This script grabs from the end of the IA archives working backwards to progressively older releases until it either finds a duplicate or gets to 99 entries. This prevents the script from running out of control.

 Use `ia2sl.sh clcracked` to generate just Cleanly Cracked data into `xml/cc-combined.xml`.
 Likewise, `ia2sl.sh wozaday` generates just the Woz-a-day data into `xml/woz-combined.xml`.
 Lastly, `ia2sl.sh both` will run both concurrently, saving time on the build process.

 These output XMLs are in correct order (newest at bottom, oldest at top) for direct copy-paste into the MAME softlist xml files. You will need to adjust some of the output.

 In particular, the script tries to parse the publisher from data in the `publisher.txt` file, but this isn't always possible (e.g. a new publisher shows up) and you'll see UNKNOWN for the publisher. You'll have to correct that by hand, then add the new publisher data to the `publisher.txt` file.

 Cleanly cracked does not have compatibility data because the copy protection (or lack thereof) can in many cases directly affect whether a given Apple II machine can run the program. There are a number of entries in the woz-a-day archives that will not run on machines newer than an Apple II+, but will run on any machine with the copy protection removed.

 It will copy the metadata 4am has left in the entries to a comment in each softlist entry. This should be removed after you validate that any compatibility line in the softlist matches up to what 4am has posted in his metadata. See existing entries in `apple2_flop_orig.xml` and the `ia2sl.sh` script itself to see how this data should look and how it is generated.

## Warnings

 Disk images will be moved to the postsorted directory on completion for ALL scripts included herein. This is to make it significantly easier to just point ROMVault (which does run in mono on *nix environments and has, as of March 2020, a prototype command-line tool for scripting the zip builds) or clrmamepro at the postsorted directory and have it do the final sorting into individual zip files.

 At no point should the output from this ever be directly trusted without an eyeball pass. There will ALWAYS be special cases that no script, no matter how finely-tuned, can deal with.

 You WILL need to doublecheck all output.

 You WILL need to add a shortname in the definition's first line.

 You WILL need to add disk/side tags where appropriate (see existing softlist entries for examples). The script now can autodetect many common filename patterns for disk numbers and side numbers, but some oddly named disks will still fall through the cracks.

 You WILL occasionally see dates that appear like `19901985` -- this happens when a program gets a rerelease. In this example, the program originally came out in 1985, but was rereleased in 1990. You'll need to hand edit the date in this case after reading the comment line to figure out what the exact situation is. In this example case you'd use 1990 because even if the software is the same as the 1985 version, you'd need to differentiate between a possible (now or later in the future) dump of the older version.

 You also will need to make small adjustments to match the formatting used in the MAME softlist files; the comment line that gets output by the script containing the complete description (suitable for doublechecking the work) can be converted to a blank line once you're ready to sign off on the file and that'll get you in line with the usual formatting for Apple softlists.

 So, yeah, this does leave you with a bit of work, but it's still considerably better than hand-editing.


## Chopgen
 
 Also included is my multi-purpose non-IA tool, chopgen. Chopgen will generate quick and dirty metadata for softlist entries from various disk images you have in the chopgen directory when running the script. It, like the other scripts, will move the disk images to the postsorted folder when completed for later clrmamepro pass.

 This script will probably be modified in the near future to just chop up whatever is in the chopgen folder as opposed to just disk images, making it easier to work with cartridge images of various file extensions.

 Future plans include considering ways to have chopgen pull data from the disk images themselves where possible.

 Note as of March 2020: Now that I've finished rebuilding the original toolkit, my next task will be to rebuild chopgen in the near future.

## Prerequisites for use

 As I run Debian from a laptop and also as a WSL add-on to Windows 10, the packages will be described in that way.

`sudo apt-get install python3-pip libarchive-zip-perl unzip libxml2-utils wget xsltproc`

`sudo pip3 install internetarchive`

You will need to change a grep line in each script: they're set to check the Apple softlists in the default install location of the MAME compilation tools via WSL path. Look for `/mnt/c/msys64/src/MAME/mame-softlists/hash/apple*_flop*.xml` in the script and change accordingly (or set up a mount to redirect those to wherever your MAME hash folder actually is).
