#!/bin/bash
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

# Subroutines defined here.

function startcycle() {
    local worktype=${1^^}
    # We use $1 instead of $worktype because BOTH can also be passed through
    # worktype and that'll cause this to break. Instead we take what the caller
    # gives us in $1
    COUNTER=1
    # Run to a maximum of 99, end with exit code 1 when we finally hit a dupe.
    while [ $COUNTER -lt 100 ]; do
        if ! (generator $COUNTER $1); then
            aggregate $1
            return 1
        fi
        let COUNTER=COUNTER+1
    done
    aggregate $1
}

function generator() {
    # Remove and recreate certain work directories so they're clean.

    rm -rf "$worktype"diskoutput 2>/dev/null
    rm -rf "$worktype"diskstaging 2>/dev/null
    mkdir "$worktype"diskoutput 2>/dev/null
    mkdir "$worktype"diskstaging 2>/dev/null

    # Do the actual search and download.
    # This will depend on which type we're using, of course.
    echo -e "$worktype: Beginning work on entry [$1].."

    case ${2} in
    "WOZADAY")
        ia search 'collection:wozaday' --parameters="page=$1&rows=1" --sort="publicdate desc" -i >"$worktype"currentitems.txt
        ;;
    "CLCRACKED")
        ia search '@4am subject:"crack"' --parameters="page=$1&rows=1" --sort="publicdate desc" -i >"$worktype"currentitems.txt
        ;;
    esac
    # Output download URLs to currentdls.txt
    ia download -d -i --no-directories --glob '*.zip|*.xml|*.dsk|*.2mg|*.po|*.bin|*.woz|*crack).zip|*.BIN' --itemlist="$worktype"currentitems.txt >"$worktype"currentdls.txt

    # Let's remove the extras file and certain other unwanted materials
    sed -i '/%20extras%20/d' "$worktype"currentdls.txt
    sed -i '/extras.zip/d' "$worktype"currentdls.txt
    sed -i '/0playable/d' "$worktype"currentdls.txt
    sed -i '/_files.xml/d' "$worktype"currentdls.txt
    sed -i "/demuffin\'d/d" "$worktype"currentdls.txt
    sed -i '/work%20disk/d' "$worktype"currentdls.txt

    # Now we download.
    echo "$worktype: Downloading..."
    wget -q -i "$worktype"currentdls.txt -nc -nv -nd -P ./"$worktype"diskstaging
    # Let's decompress any ZIP files we got, forced lowercase names.
    unzip -n -qq -LL -j "$worktype"'diskstaging/*.zip' -d "$worktype"diskoutput 2>/dev/null
    # Before we go ANY further, let's clean up any .bin files into .2mg ...
    cd "$worktype"diskstaging || exit
    # Find all .bin files and rename them to 2mg. This should be Distro-agnostic,
    # as opposed to the previous Debian-specific variation.
    find . -name "*.bin" -exec sh -c 'mv "$1" "${1%.bin}.2mg"' _ {} \; 2>/dev/null
    cd ..

    # Move the meta XML and the disk images to the output folder for processing.
    mv "$worktype"diskstaging/*.woz "$worktype"diskoutput 2>/dev/null
    cp "$worktype"diskstaging/*meta.xml "$worktype"diskoutput 2>/dev/null

    cd "$worktype"diskoutput || exit

    # Remove stuff we don't want. We don't want to parse the playable.dsk because
    # that's an exact copy of the properly named disk. We don't want pictures and
    # videos in this case either.
    rm 00playable.dsk 2>/dev/null
    rm 00playable.2mg 2>/dev/null
    rm 00playable.woz 2>/dev/null
    rm 00playable2.dsk 2>/dev/null
    rm playable.dsk 2>/dev/null
    rm playable.2mg 2>/dev/null
    rm playable.woz 2>/dev/null
    rm *.a2r 2>/dev/null
    rm *.png 2>/dev/null
    rm *.mp4 2>/dev/null
    rm *.jpg 2>/dev/null
    rm *fastdsk\ rip\* 2>/dev/null
    # These next two files seem to pop up a lot with MP4 files, which we don't want.
    rm ProjFileList.xml 2>/dev/null
    rm project.xml 2>/dev/null
    # 4AM sometimes leaves his work disk in the package. We don't want to keep that.
    rm *work\ disk* 2>/dev/null
    rm *demuffin\'d\ only* 2>/dev/null
    # Now, we parse the XML file(s), and there should only be one to parse.

    for filename in *.xml; do
        [ -e "$filename" ] || continue
        # We'll have to handcraft the shortname ourselves.
        echo -e '\t<software name="namehere">' >../xml/"$worktype"disk/disk$1.xml
        echo -e -n '\t\t<description>' >>../xml/"$worktype"disk/disk$1.xml
        xmllint --xpath 'metadata/title/text()' "$filename" | tr -d '\n' >>../xml/"$worktype"disk/disk$1.xml
        echo -e '</description>' >>../xml/"$worktype"disk/disk$1.xml
        echo -e -n '\t\t<year>' >>../xml/"$worktype"disk/disk$1.xml
        xmllint --xpath 'metadata/description/text()' $filename | grep -o '19[0123456789][0123456789]' | tr -d '\n' >>../xml/"$worktype"disk/disk$1.xml
        echo -e '</year>' >>../xml/"$worktype"disk/disk$1.xml
        echo -e -n '\t\t<publisher>' >>../xml/"$worktype"disk/disk$1.xml
        xmllint --xpath 'metadata/description/text()' $filename | grep -o -a -i -F -f ../publishers.txt | tr -d '\n' | sed -e 's/distributed by //g' | sed -e 's/published by //g' | sed -e 's/\&amp;amp;/and/g' >>../xml/"$worktype"disk/disk$1.xml
        echo -e '</publisher>' >>../xml/"$worktype"disk/disk$1.xml
        echo -e -n '\t\t<info name="release" value="' >>../xml/"$worktype"disk/disk$1.xml
        xmllint --xpath 'metadata/publicdate/text()' $filename | awk '{print $1}' | tr -d '\n' >>../xml/"$worktype"disk/disk$1.xml
        echo -e '"/>' >>../xml/"$worktype"disk/disk$1.xml
        # Now, this next step only is done if we're doing WOZADAY where we have actual compatibility data at hand.
        case ${2} in
        "WOZADAY")
            compatdata=$(xmllint --xpath 'metadata/description/text()' $filename | tr -d '\n')
            case $compatdata in

            # Copy Protection compatibility issues section -------------------
            *"It requires an Apple ][ or ][+ with 48K. Due to compatibiltiy issues created by the copy protection, it will not run on later models. Even with a compatible ROM file, this game triggers bugs in several emulators, resulting in crashes or spontaneous reboots."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t\<!-- It requires an Apple II or II+ with 48K.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t\Due to compatibility issues created by the copy protection,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t\it will not run on later models. Even with a compatible ROM file,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t\this game triggers bugs in several emulators,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t\resulting in crashes or spontaneous reboots. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+, or an unenhanced Apple //e. Due to compatibility issues caused by the copy protection, it will not run on any later models."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tor an unenhanced Apple //e. Due to compatibility' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tissues caused by the copy protection, it will not' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\trun on any later models. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple II or ][+. Due to compatibility issues created by the copy protection, it will not run on later models."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tDue to compatibility issues caused by the copy protection,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tit will not run on any later models. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+. Due to compatibility issues caused by the copy protection, it will not run on any later models."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tDue to compatibility issues caused by the copy protection,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tit will not run on any later models. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or Apple ][+. Due to compatibility problems created by the copy protection, it will not run on later models"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tDue to compatibility issues caused by the copy protection,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tit will not run on any later models. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+ or later. It was released with several different copy protections; this version was protected with the E7 bitstream. Game code and data is identical to other protected variants"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tThis was released with several different copy protections;' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tthis version was protected with the E7 bitstream. Game code and data' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tis identical to other protected variants. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ with 48K. Some emulators may have difficulty emulating this image due to its extreme copy protection methods"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tSome emulators may have difficulty emulating this image due to its' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\textreme copy protection methods. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires an Apple ][ or Apple ][+. Due to restrictive copy protection, it will not boot on later models"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires an Apple II or Apple II+.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tDue to restrictive copy protection,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tit will not boot on later models. --> -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *'It runs on any Apple ][ with 48K. Note: due to subtle emulation bugs and extremely finicky copy protection, this disk may reboot one or more times before loading.'*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tNote: due to subtle emulation bugs and extremely finicky copy' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tprotection, this disk may reboot one or more times before loading. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;

                # Non-copy protection-related special notes ----------------------
            *"Attempting to run with less than 48K will appear to work, but copies will fail with an UNABLE TO WRITE error."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t(Attempting to run with less than 48K will appear to work,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tbut copies will fail with an UNABLE TO WRITE error.) -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple II or II+."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ with 48K. The double hi-res version is automatically selected if you have a 128K Apple //e or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e 'The double hi-res version is automatically selected' >>../xml/"$worktype"disk/disk$1.xml
                echo -e 'if you have a 128K Apple //e or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+, //e, //c, or IIgs. Double hi-res mode requires a 128K Apple //e, //c, or IIgs"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple ][+, //e, //c, or IIgs.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tDouble hi-res mode requires a 128K Apple //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It uses double hi-res graphics and thus requires a 128K Apple //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It uses double hi-res graphics and thus requires a' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t128K Apple //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"This version, using double hi-res graphics, requires a 128K Apple //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- This version, using double hi-res graphics,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\trequires a 128K Apple //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+. It will not run on later models."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple ][ or ][+.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tIt will not run on later models. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive but otherwise runs on any Apple II with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive but otherwise' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\truns on any Apple II with 48K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive but otherwise runs on any Apple II with 32K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive but otherwise' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\truns on any Apple II with 32K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive but otherwise runs on any Apple II with 24K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive but otherwise' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\truns on any Apple II with 24K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive but otherwise runs on any Apple II with 16K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive but otherwise' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\truns on any Apple II with 16K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive and a 48K Apple ][+ or later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive and a 48K Apple II+ or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires an original Apple II with 48K and Integer BASIC in ROM."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires an original Apple II with 48K and Integer BASIC' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tin ROM. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple II and Integer BASIC in ROM"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires an original Apple II with 48K and Integer BASIC' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tin ROM. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires an original Apple II with 32K and Integer BASIC in ROM."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires an original Apple II with 32K and Integer BASIC' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tin ROM. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+ or later. Double hi-res graphics are available on 128K Apple //e and later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple ][+ or later.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tDouble hi-res graphics are available on 128K Apple //e and later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"This re-release requires a 64K Apple ][+ or later; the optional double hi-res graphics mode requires a 128K Apple //e or later. "*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- This re-release requires a 64K Apple II+ or later;' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tthe optional double hi-res graphics mode requires a' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t128K Apple //e or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"The disk label says it requires a 32K Apple II, but under emulation I could not get it to work on less than a 48K Apple II+"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- The disk label says it requires a 32K Apple II, but under' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\temulation I could not get it to work on less than a 48K Apple II+. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires an Apple ][ with an Integer BASIC ROM and at least 32K. Due to the reliance on Integer ROM, it will not run on later models"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires an Apple II with Integer BASIC ROM and at least 32K.' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tDue to reliance on Integer ROM, it will not run on later models. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"Due to its use of double hi-res graphics, it requires a 128K Apple //e or later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- Due to its use of double hi-res graphics,' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\tit requires a 128K Apple //e or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;

                # Normal section -------------------------------------------------
            *"It requires a 64K Apple II+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+, //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+, //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II+, //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on an Apple //e with 128K, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on an Apple //e with 128K, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requirs a 64K Apple ][+ or later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple ][+ or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 64K Apple //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple //e or later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple //e or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple II."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple II with 64K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 64K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple II with 32K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 32K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ with 32K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 32K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any 48K Apple ][+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any 48K Apple II+, //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It run on any Apple II with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires an Apple II+ with 48K"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires an Apple II+ with 48K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires an Apple ][+ with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires an Apple II+ with 48K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires an 64K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ model with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple II with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II+ or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires an 64K Apple ][+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requirs a 64K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires 64K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 64K Apple //e or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple //e or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 128K Apple //e or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 128K Apple //e or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires 128K Apple //e or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 128K Apple //e or later. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *"It requires a 128K Apple //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 128K Apple //e, //c, or IIgs. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/"$worktype"disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            esac

            # Obviously you'll need to hand-configure the compatibility because there's a lot of ways this can be described...
            echo -e -n '\t\t<!--' >>../xml/"$worktype"disk/disk$1.xml
            xmllint --xpath 'metadata/description/text()' $filename | tr -d '\n' >>../xml/"$worktype"disk/disk$1.xml
            echo -e -n '-->\n' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        esac
    done

    # Now we start working on the disk images. Here's where things get a Little
    # hairy. We need both the proper (possibly bad)-cased filename for tools, but
    # we need a forced lowercase for the XML.
    # clrmamepro/romcenter will rename files automagically so the the files are
    # fine as-is; we won't be renaming.

    disknum=1
    for filename in *.woz *.po *.dsk *.2mg; do
        [ -e "$filename" ] || continue
        # Here we're generating a forced lowercase version of the name which we'll
        # use in some places in the XML. We also strip invalid characters as well
        # as double spaces.
        lfilename=$(echo "$filename" | tr '[:upper:]' '[:lower:]' | sed 's/\!/ /g' | sed 's/\  / /g' | sed 's/\&/and/g')
        echo -e "$worktype: Generating disk $disknum with file $lfilename.."
        # Critical: Check for SHA1 dupes.
        # Generate the SHA1 and put it in temp.
        sha1sum $filename | awk '{print $1}' >temp

        # If we got a dupe, put it in temp2, otherwise leave a 0-byte file.
        # We'll use that a little later.
        grep -a -i -F -n -R -f temp /mnt/c/msys64/src/mame/hash/apple2_flop*.xml >temp2
        if [[ -s temp2 ]]; then
            echo "dupe" >dupecheck
        fi
        # Start outputting disk information.
        echo -e -n '\t\t<part name="flop' >>../xml/"$worktype"disk/disk$1.xml
        echo -e -n $disknum >>../xml/"$worktype"disk/disk$1.xml
        echo -e -n '" interface="' >>../xml/"$worktype"disk/disk$1.xml

        # Now, is this a 5.25" or 3.5"?
        # In the case of a .po it could technicaly be either, but...
        case $lfilename in
        *".po"*)
            echo -e 'floppy_3_5">' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *".dsk"*)
            echo -e 'floppy_5_25">' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *".2mg"*)
            echo -e 'floppy_3_5">' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *".woz"*)
            # WOZ can be either. We need to pull the data from the WOZ itself.
            # According to the WOZ 2.0 spec, certain info is always hard-set
            # location-wise to help lower-end emulators.
            # The disk type should ALWAYS be at offset 21, and
            # should be "1" for 5.25" and "2" for 3.5" disks.
            disktype=$((16#$(xxd -e -p -l1 -s 21 "$filename")))
            case $disktype in
            *"2"*)
                echo -e 'floppy_3_5">' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            *)
                echo -e 'floppy_5_25">' >>../xml/"$worktype"disk/disk$1.xml
                ;;
            esac
            ;;
        esac

        # Generate side/disk number information.

        case $lfilename in

        # "Disk X - Title" type
        # e.g. "swordthrust (4am crack) disk 1 - the king's testing ground.dsk"
        *"disk 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 11 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 11 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 12 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 12 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 13 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 13 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 14 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 14 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 15 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 15 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 16 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 16 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 17 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 17 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 18 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 18 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 19 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 19 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 20 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 20 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 21 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 21 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 22 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 22 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 23 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 23 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 24 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 24 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 25 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 25 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 26 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 26 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 27 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 27 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 28 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 28 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 29 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 29 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 30 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 30 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # "Disk X" type
            # e.g. "read and spell - in the days of knights and castles (4am crack) disk 1.dsk"
        *"disk 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # "Disk X Side X" type
            # e.g. "read n roll (4am crack) disk 2 side a.dsk"
        *"disk 1 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 1 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # "Disk X" type
        *"disk a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk c."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk d."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk e."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk f."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk g."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk h."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk i."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk j."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk k."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk l."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk m."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk n."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk o."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk p."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk q."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk r."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk s."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk t."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk u."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk v."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk w."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk x."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk y."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk z."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # "Disk X Side A/B" type
        *"disk a side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk a side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk b side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk b side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk c side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk c side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk d side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk d side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk e side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk e side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk f side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk f side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk g side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk g side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk h side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk h side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk i side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk i side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk j side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk j side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk k side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk k side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk l side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk l side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk m side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk m side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk n side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk n side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk o side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk o side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk p side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk p side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk q side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk q side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk r side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk r side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk s side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk s side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk t side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk t side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk u side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk u side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk v side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk v side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk w side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk w side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk x side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk x side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk y side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk y side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk z side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk z side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # "Disk X Side X" type
            # e.g. "the perfect score (4am crack) disk a side 1 - antonyms i.dsk"
        *"disk a side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk a side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk b side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk b side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk c side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk c side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk d side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk d side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk e side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk e side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk f side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk f side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk g side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk g side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk h side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk h side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk i side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk i side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk j side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk j side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk k side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk k side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk l side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk l side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk m side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk m side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk n side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk n side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk o side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk o side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk p side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk p side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk q side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk q side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk r side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk r side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk s side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk s side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk t side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk t side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk u side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk u side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk v side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk v side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk w side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk w side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk x side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk x side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk y side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk y side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk z side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side 1 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk z side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side 2 - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk a side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk a side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk b side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk b side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk c side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk c side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk d side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk d side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk e side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk e side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk f side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk f side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk g side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk g side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk h side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk h side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk i side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk i side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk j side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk j side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk k side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk k side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk l side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk l side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk m side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk m side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk n side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk n side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk o side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk o side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk p side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk p side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk q side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk q side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk r side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk r side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk s side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk s side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk t side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk t side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk u side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk u side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk v side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk v side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk w side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk w side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk x side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk x side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk y side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk y side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk z side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk z side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # "Disk X Side X - Title" type
            # e.g. "superprint (4am crack) disk 1 side a - program.dsk"
        *"disk 1 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 1 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # Disk NumberSide.
            # e.g. "voyage of the mimi (4am crack) disk 1a.dsk"
        *"disk 1a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 1b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 1, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 1, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 2, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 3, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 4, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 5, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 6, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 7, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 8, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 9, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10, side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"disk 10, side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # Because case is a fallthrough, it only ever gets here if it fails to match
            # one of the above entries.

            # "Side X - Title" type
            # e.g. "the bard's tale ii (4am and san inc crack) side a - program.dsk"
        *"side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side A - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side B - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side c -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side C - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side d -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side D - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side e -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side E - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side f -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side F - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side g -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side G - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side h -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side H - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side i -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side I - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side j -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side J - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side k -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side K - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side l -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side L - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side m -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side M - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side n -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side N - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side o -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side O - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side p -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side P - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side q -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side Q - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side r -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side R - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side s -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side S - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side t -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side T - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side u -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side U - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side v -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side V - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side w -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side W - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side x -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side X - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side y -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side Y - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side z -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side Z - "/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # "Side X" type
            # e.g. "reading and me (4am crack) side a.dsk"
        *"side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Side A"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Side B"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side c."*)
            echo -e '\t\t\t<feature name="part_id" value="Side C"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side d."*)
            echo -e '\t\t\t<feature name="part_id" value="Side D"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side e."*)
            echo -e '\t\t\t<feature name="part_id" value="Side E"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side f."*)
            echo -e '\t\t\t<feature name="part_id" value="Side F"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side g."*)
            echo -e '\t\t\t<feature name="part_id" value="Side G"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side h."*)
            echo -e '\t\t\t<feature name="part_id" value="Side H"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side i."*)
            echo -e '\t\t\t<feature name="part_id" value="Side I"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side j."*)
            echo -e '\t\t\t<feature name="part_id" value="Side J"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side k."*)
            echo -e '\t\t\t<feature name="part_id" value="Side K"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side l."*)
            echo -e '\t\t\t<feature name="part_id" value="Side L"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side m."*)
            echo -e '\t\t\t<feature name="part_id" value="Side M"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side n."*)
            echo -e '\t\t\t<feature name="part_id" value="Side N"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side o."*)
            echo -e '\t\t\t<feature name="part_id" value="Side O"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side p."*)
            echo -e '\t\t\t<feature name="part_id" value="Side P"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side q."*)
            echo -e '\t\t\t<feature name="part_id" value="Side Q"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side r."*)
            echo -e '\t\t\t<feature name="part_id" value="Side R"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side s."*)
            echo -e '\t\t\t<feature name="part_id" value="Side S"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side t."*)
            echo -e '\t\t\t<feature name="part_id" value="Side T"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side u."*)
            echo -e '\t\t\t<feature name="part_id" value="Side U"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side v."*)
            echo -e '\t\t\t<feature name="part_id" value="Side V"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side w."*)
            echo -e '\t\t\t<feature name="part_id" value="Side W"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side x."*)
            echo -e '\t\t\t<feature name="part_id" value="Side X"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side y."*)
            echo -e '\t\t\t<feature name="part_id" value="Side Y"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side z."*)
            echo -e '\t\t\t<feature name="part_id" value="Side Z"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 1"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 2"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 3."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 3"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 4."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 4"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 5."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 5"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 6."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 6"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 7."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 7"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 8."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 8"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 9."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 9"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side 10."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 10"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;

            # Special cases. Will add as they come up.
        *"side 2 (boot)."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 2 - Boot"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side a - master scenario disk."*)
            echo -e '\t\t\t<feature name="part_id" value="Side A - Master scenario disk"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side b - boot."*)
            echo -e '\t\t\t<feature name="part_id" value="Side B - Boot disk"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side a - master disk."*)
            echo -e '\t\t\t<feature name="part_id" value="Side A - Master disk"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"side b - scenario disk."*)
            echo -e '\t\t\t<feature name="part_id" value="Side B - Boot disk"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
            # These two don't get a disk number because we don't know for sure what it should be.
            # Instead, we use ~ so I can have my build scripts abort if I miss fixing this in the XML.
        *"- program disk."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk ~ - Program disk"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        *"- player disk."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk ~ - Player disk"/>' >>../xml/"$worktype"disk/disk$1.xml
            ;;
        esac

        # Give us the actual floppy definition, including size.
        echo -e -n '\t\t\t<dataarea name="flop" size="' >>../xml/"$worktype"disk/disk$1.xml
        wc "$filename" | awk '{print $3}' | tr -d '\n' >>../xml/"$worktype"disk/disk$1.xml
        echo -e '">' >>../xml/"$worktype"disk/disk$1.xml
        echo -e -n '\t\t\t\t<rom name="' >>../xml/"$worktype"disk/disk$1.xml
        # BUT! Give us the lowercase filename in the XML definition.
        echo -e -n $lfilename >>../xml/"$worktype"disk/disk$1.xml
        # As always, tools use case of what's there.
        echo -e -n '" size="' >>../xml/"$worktype"disk/disk$1.xml
        wc "$filename" | awk '{print $3}' | tr -d '\n' >>../xml/"$worktype"disk/disk$1.xml
        echo -e -n '" crc="' >>../xml/"$worktype"disk/disk$1.xml
        crc32 $filename | awk '{print $1}' | tr -d '\n' >>../xml/"$worktype"disk/disk$1.xml
        echo -e -n '" sha1="' >>../xml/"$worktype"disk/disk$1.xml
        sha1sum $filename | awk '{print $1}' | tr -d '\n' >>../xml/"$worktype"disk/disk$1.xml
        echo -e '" />' >>../xml/"$worktype"disk/disk$1.xml
        echo -e '\t\t\t</dataarea>' >>../xml/"$worktype"disk/disk$1.xml
        echo -e '\t\t</part>' >>../xml/"$worktype"disk/disk$1.xml
        ((disknum++))
        # One more sanity check to do. If there is a cracker tag that's not
        # solo 4am, then we need to put up a warning so we notice and give
        # proper credit.
        if grep -q "(4am and san inc crack)" ../xml/"$worktype"disk/disk$1.xml; then
            echo -e '\t\t<!-- !!!!!!!!!! 4am and San crack  !!!!!!!!!! -->' >>../xml/"$worktype"disk/disk$1.xml
        fi
        if grep -q "(logo crack)" ../xml/"$worktype"disk/disk$1.xml; then
            echo -e '\t\t<!-- !!!!!!!!!!  LoGo crack  !!!!!!!!!! -->' >>../xml/"$worktype"disk/disk$1.xml
        fi
    done
    echo -e '\t</software>\n' >>../xml/"$worktype"disk/disk$1.xml
    # Clean out any wozaday collection tags.
    # Change any crack tags to cleanly cracked.
    sed -i 's/(4am crack)<\/description>/(cleanly cracked)<\/description>/g' ../xml/"$worktype"disk/disk$1.xml
    sed -i 's/(san inc crack)<\/description>/(cleanly cracked)<\/description>/g' ../xml/"$worktype"disk/disk$1.xml
    sed -i 's/(4am and san inc crack)<\/description>/(cleanly cracked)<\/description>/g' ../xml/"$worktype"disk/disk$1.xml
    sed -i 's/ 800K / (800K 3.5") /g' ../xml/"$worktype"disk/disk$1.xml
    sed -i 's/ (woz-a-day collection)<\/description>/<\/description>/g' ../xml/"$worktype"disk/disk$1.xml
    sed -i 's/ 800K / (800K 3.5") /g' ../xml/"$worktype"disk/disk$1.xml
    # Detect if we didn't get a publisher and add a warning notification.
    sed -i 's/<publisher><\/publisher>/<publisher>UNKNOWN<\/publisher>/g' ../xml/"$worktype"disk/disk$1.xml
    # If the dupecheck file above says this already exists in our MAME softlists,
    # then all this work was a waste and we need to delete the XML now.

    if [[ -s dupecheck ]]; then
        echo -e "$worktype: Duplicated entry. Removing generated XML..."
        rm ../xml/"$worktype"disk/disk$1.xml
        # We found a dupe, so there's no point in continuing.
        cd .. || exit
        return 1
    fi

    # Migrate all non-duplicate disk images to the postsorted folder for later
    # parsing so we can be 100% sure the XML is correct even after mame -valid
    mv *.woz ../postsorted 2>/dev/null
    mv *.dsk ../postsorted 2>/dev/null
    mv *.2mg ../postsorted 2>/dev/null
    mv *.woz ../postsorted 2>/dev/null
    cd .. || exit
}

function aggregate() {
    echo "$worktype: Generating final XML..."
    cd xml/"$worktype"disk || exit
    cat ../../xmlheader.txt >../"$worktype"disk-combined-presort.xml
    cat disk*.xml >>../"$worktype"disk-combined-presort.xml 2>/dev/null

    cat ../../xmlfooter.txt >>../"$worktype"disk-combined-presort.xml
    # This last step sorts the entries to be in release order so you can cut and paste
    # them into the MAME XML as-is.
    # Because the xsltproc process malforms the XML slightly, we'll use sed to fix.
    case ${1} in
    "WOZADAY")
        xsltproc --novalid --nodtdattr -o ../woz-combined.xml ../../resortxml.xslt ../"$worktype"disk-combined-presort.xml
        sed -i 's/<software name="namehere">/\t<software name="namehere">/g' ../woz-combined.xml
        ;;
    "CLCRACKED")
        xsltproc --novalid --nodtdattr -o ../cc-combined.xml ../../resortxml.xslt ../"$worktype"disk-combined-presort.xml
        sed -i 's/<software name="namehere">/\t<software name="namehere">/g' ../cc-combined.xml
        ;;
    esac
    cd ../.. || exit
    IFS=$SAVEIFS
    echo "$worktype: Process complete..."
    return 1
}

# Now our main loop.

# First thing's first, make sure we picked a type to work with.
if [ $# -eq 0 ]; then
    echo "No Apple disk type supplied. Please run as either:"
    echo "$0 clcracked"
    echo "$0 wozaday"
    echo "or"
    echo "$0 both (this parallelizes both)"
    exit 1
fi

# We save the type of workload in this variable because we'll lose $1
# when we go into the functions that actually do the work
worktype=${1^^}

# Remove and recreate certain work directories so they're clean.
case ${worktype} in
"BOTH")
    mkdir postsorted 2>/dev/null
    rm -rf xml/WOZADAYdisk 2>/dev/null
    mkdir xml 2>/dev/null
    mkdir xml/WOZADAYdisk 2>/dev/null
    rm -rf xml/CLCRACKEDdisk 2>/dev/null
    mkdir xml 2>/dev/null
    mkdir xml/CLCRACKEDdisk 2>/dev/null
    ;;
"WOZADAY")
    # fall through to clcracked since both use same logic.
    ;&
"CLCRACKED")
    rm -rf xml/"$worktype"disk 2>/dev/null
    mkdir xml 2>/dev/null
    mkdir xml/"$worktype"disk 2>/dev/null
    mkdir postsorted 2>/dev/null
    ;;
esac

# While I could have this in the case above, it's separated so that the
# logic is obviously separate to the eyes.

# Do cleanup of workspace first.
mkdir postsorted 2>/dev/null
rm -rf xml/WOZADAYdisk 2>/dev/null
mkdir xml 2>/dev/null
mkdir xml/WOZADAYdisk 2>/dev/null
rm -rf xml/CLCRACKEDdisk 2>/dev/null
mkdir xml 2>/dev/null
mkdir xml/CLCRACKEDdisk 2>/dev/null

# Depending on which type we do, the loop needs to be changed; singles
# run as usual, both needs parallelization.
case ${worktype} in
"BOTH")
    startcycle WOZADAY &
    startcycle CLCRACKED &
    wait
    ;;
"WOZADAY")
    # fall through to clcracked since both use same logic.
    ;&
"CLCRACKED")
    # Because we're using a single type, we can pass $worktype
    startcycle $worktype
    ;;
esac

IFS=$SAVEIFS
exit 1
