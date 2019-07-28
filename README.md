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

 `newccgen` will count from the end of the 4AM cleanly cracked disk archive. Running `newccgen 1` will get you the latest release and generate the XML data accordingly. Running `newccgen 100` will do the 100th release back, and so forth. MAME softlist-compatible XML output will be put in `xml/cc/cc#.xml`, with `newccgen 1` giving you `cc1.xml` and `newccgen 100` giving you `cc100.xml`-- in all cases, this WILL overwrite what's in the file, allowing you to re-run in case of error or if you need to modify publishers.txt or whatever.

 `newwozgen` is likewise set up to count from the end of the 4AM WOZ-a-day archives. Running `newwozgen 1` will grab the latest single release in that collection and generate MAME softlist-compatible XML as `xml/woz/woz1.xml` overwriting whatever is in that file on creation. Running `newwozgen 100` will go back 100 releases from latest and generate a `woz100.xml` file (and again overwriting what's there).

 When run, you may get output that looks like:

 `/mnt/c/msys64/src/mame/hash/apple2_flop_clcracked.xml:22105: <rom name="repton (4am crack).dsk" size="143360" crc="eb5a3f65" sha1="8efc7bf1b2bf004de51d7de9c4d0675626d3b0ff" />`

 That's your official warning that the script found this exact SHA1 already in the described softlist and that you shouldn't proceed further without making sure you're not adding a duplicate. This WILL NOT save you from duplicates that don't have the same SHA1, however, such as from a different crack source.

## Warnings

 At no point should the output from this ever be directly trusted without an eyeball pass. There will ALWAYS be special cases that no script, no matter how finely-tuned, can deal with.

 You WILL need to doublecheck all output.

 You WILL need to add a shortname in the definition's first line.

 You WILL need to add disk/side tags where appropriate (see existing softlist entries for examples). The script now can autodetect many common filename patterns for disk numbers and side numbers, but things will still fall through the cracks.

 You also will need to make small adjustments to match the formatting used in the MAME softlist files; the comment line that gets output by the script containing the complete description (suitable for doublechecking the work) can be converted to a blank line once you're ready to sign off on the file and that'll get you in line with the usual formatting for Apple softlists.

 So, yeah, this does leave you with a bit of work, but it's still considerably better than hand-editing.

## Prerequisites for use

 As I run Debian from a laptop and also as a WSL add-on to Windows 10, the packages will be described in that way.

`sudo apt-get install python3-pip libarchive-zip-perl unzip libxml2-utils`

`sudo pip3 install internetarchive`

You will need to change a grep line in each script: they're set to check the Apple softlists in the default install location of the MAME compilation tools via WSL path. Look for `/mnt/c/msys64/src/mame/hash/apple2_flop*.xml` in the script and change accordingly.
