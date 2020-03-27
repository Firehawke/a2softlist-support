#/bin/bash

# Basic softlist sanity checks:

# Did we leave any "disk ~" in any of the XMLs? If so, panic!
echo "Did we leave any 'disk ~' entries?"
grep "disk ~" /mnt/c/msys64/src/mame/hash/apple2_flop*.xml
