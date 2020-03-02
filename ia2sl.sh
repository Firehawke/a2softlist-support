#!/bin/bash
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

# Subroutines defined here.

function generator() {
    # Remove and recreate certain work directories so they're clean.

    rm -rf diskoutput 2>/dev/null
    rm -rf diskstaging 2>/dev/null
    mkdir diskoutput 2>/dev/null
    mkdir diskstaging 2>/dev/null

    case ${2} in
    "WOZADAY")
        echo "Starting WOZ cycle..."
        ;;
    "CLCRACKED")
        echo "Starting ClCracked cycle..."
        ;;
    esac

    # Do the actual search and download.
    # This will depend on which type we're using, of course.
    echo -e "Beginning work on entry [$1].."

    case ${2} in
    "WOZADAY")
        ia search 'collection:wozaday' --parameters="page=$1&rows=1" --sort="publicdate desc" -i >currentitems.txt
        ;;
    "CLCRACKED")
        ia search '@4am subject:"crack"' --parameters="page=$1&rows=1" --sort="publicdate desc" -i >currentitems.txt
        ;;
    esac
    # Output download URLs to currentdls.txt
    ia download -d -i --no-directories --glob '*.zip|*.xml|*.dsk|*.2mg|*.po|*.bin|*.woz|*crack).zip|*.BIN' --itemlist=currentitems.txt >currentdls.txt

    # Let's remove the extras file and certain other unwanted materials
    sed -i '/%20extras%20/d' currentdls.txt
    sed -i '/extras.zip/d' currentdls.txt
    sed -i '/0playable/d' currentdls.txt
    sed -i '/_files.xml/d' currentdls.txt
    sed -i "/demuffin\'d/d" currentdls.txt
    sed -i '/work%20disk/d' currentdls.txt

    # Now we download.
    echo "Downloading..."
    wget -q -i currentdls.txt -nc --show-progress -nd -P ./diskstaging
    # Let's decompress any ZIP files we got, forced lowercase names.
    unzip -n -qq -LL -j "diskstaging/*.zip" -d diskoutput 2>/dev/null
    # Before we go ANY further, let's clean up any .bin files into .2mg ...
    cd diskstaging
    # THIS use of rename is, unfortunately, Debian-specific. If you're using a
    # different distro, you're going to have to modify this.
    rename 's/.bin/.2mg/' *.bin 2>/dev/null
    cd ..

    # Move the meta XML and the disk images to the output folder for processing.
    mv diskstaging/*.woz diskoutput 2>/dev/null
    cp diskstaging/*meta.xml diskoutput 2>/dev/null

    cd diskoutput

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
        echo -e '\t<software name="namehere">' >../xml/disk/disk$1.xml
        echo -e -n '\t\t<description>' >>../xml/disk/disk$1.xml
        xmllint --xpath 'metadata/title/text()' "$filename" | tr -d '\n' >>../xml/disk/disk$1.xml
        echo -e '</description>' >>../xml/disk/disk$1.xml
        echo -e -n '\t\t<year>' >>../xml/disk/disk$1.xml
        xmllint --xpath 'metadata/description/text()' $filename | grep -o '19[0123456789][0123456789]' | tr -d '\n' >>../xml/disk/disk$1.xml
        echo -e '</year>' >>../xml/disk/disk$1.xml
        echo -e -n '\t\t<publisher>' >>../xml/disk/disk$1.xml
        xmllint --xpath 'metadata/description/text()' $filename | grep -o -a -i -F -f ../publishers.txt | tr -d '\n' | sed -e 's/distributed by //g' | sed -e 's/published by //g' | sed -e 's/\&amp;amp;/and/g' >>../xml/disk/disk$1.xml
        echo -e '</publisher>' >>../xml/disk/disk$1.xml
        echo -e -n '\t\t<info name="release" value="' >>../xml/disk/disk$1.xml
        xmllint --xpath 'metadata/publicdate/text()' $filename | awk '{print $1}' | tr -d '\n' >>../xml/disk/disk$1.xml
        echo -e '"/>' >>../xml/disk/disk$1.xml
        # Now, this next step only is done if we're doing WOZADAY where we have actual compatibility data at hand.
        case ${2} in
        "WOZADAY")
            compatdata=$(xmllint --xpath 'metadata/description/text()' $filename | tr -d '\n')
            case $compatdata in

            # Copy Protection compatibility issues section -------------------
            *"It requires an Apple ][ or ][+ with 48K. Due to compatibiltiy issues created by the copy protection, it will not run on later models. Even with a compatible ROM file, this game triggers bugs in several emulators, resulting in crashes or spontaneous reboots."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t\<!-- It requires an Apple II or II+ with 48K.' >>../xml/disk/disk$1.xml
                echo -e '\t\t\Due to compatibility issues created by the copy protection,' >>../xml/disk/disk$1.xml
                echo -e '\t\t\it will not run on later models. Even with a compatible ROM file,' >>../xml/disk/disk$1.xml
                echo -e '\t\t\this game triggers bugs in several emulators,' >>../xml/disk/disk$1.xml
                echo -e '\t\t\resulting in crashes or spontaneous reboots. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+, or an unenhanced Apple //e. Due to compatibility issues caused by the copy protection, it will not run on any later models."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+,' >>../xml/disk/disk$1.xml
                echo -e '\t\tor an unenhanced Apple //e. Due to compatibility' >>../xml/disk/disk$1.xml
                echo -e '\t\tissues caused by the copy protection, it will not' >>../xml/disk/disk$1.xml
                echo -e '\t\trun on any later models. -->' >>../xml/disk/disk$1.xml
                ;;	
            *"It requires a 48K Apple II or ][+. Due to compatibility issues created by the copy protection, it will not run on later models."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+.' >>../xml/disk/disk$1.xml
                echo -e '\t\tDue to compatibility issues caused by the copy protection,' >>../xml/disk/disk$1.xml
                echo -e '\t\tit will not run on any later models. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+. Due to compatibility issues caused by the copy protection, it will not run on any later models."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+.' >>../xml/disk/disk$1.xml
                echo -e '\t\tDue to compatibility issues caused by the copy protection,' >>../xml/disk/disk$1.xml
                echo -e '\t\tit will not run on any later models. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or Apple ][+. Due to compatibility problems created by the copy protection, it will not run on later models"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+.' >>../xml/disk/disk$1.xml
                echo -e '\t\tDue to compatibility issues caused by the copy protection,' >>../xml/disk/disk$1.xml
                echo -e '\t\tit will not run on any later models. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+ or later. It was released with several different copy protections; this version was protected with the E7 bitstream. Game code and data is identical to other protected variants"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later.' >>../xml/disk/disk$1.xml
                echo -e '\t\tThis was released with several different copy protections;' >>../xml/disk/disk$1.xml
                echo -e '\t\tthis version was protected with the E7 bitstream. Game code and data' >>../xml/disk/disk$1.xml
                echo -e '\t\tis identical to other protected variants. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ with 48K. Some emulators may have difficulty emulating this image due to its extreme copy protection methods"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K.' >>../xml/disk/disk$1.xml
                echo -e '\t\tSome emulators may have difficulty emulating this image due to its' >>../xml/disk/disk$1.xml
                echo -e '\t\textreme copy protection methods. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires an Apple ][ or Apple ][+. Due to restrictive copy protection, it will not boot on later models"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires an Apple II or Apple II+.' >>../xml/disk/disk$1.xml
                echo -e '\t\tDue to restrictive copy protection,' >>../xml/disk/disk$1.xml
                echo -e '\t\tit will not boot on later models. --> -->' >>../xml/disk/disk$1.xml
                ;;
            *'It runs on any Apple ][ with 48K. Note: due to subtle emulation bugs and extremely finicky copy protection, this disk may reboot one or more times before loading.'*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K.' >>../xml/disk/disk$1.xml
                echo -e '\t\tNote: due to subtle emulation bugs and extremely finicky copy' >>../xml/disk/disk$1.xml
                echo -e '\t\tprotection, this disk may reboot one or more times before loading. -->' >>../xml/disk/disk$1.xml
                ;;

            # Non-copy protection-related special notes ----------------------
            *"Attempting to run with less than 48K will appear to work, but copies will fail with an UNABLE TO WRITE error."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K.' >>../xml/disk/disk$1.xml
                echo -e '\t\t(Attempting to run with less than 48K will appear to work,' >>../xml/disk/disk$1.xml
                echo -e '\t\tbut copies will fail with an UNABLE TO WRITE error.) -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple II or II+."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ with 48K. The double hi-res version is automatically selected if you have a 128K Apple //e or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K.' >>../xml/disk/disk$1.xml
                echo -e 'The double hi-res version is automatically selected' >>../xml/disk/disk$1.xml
                echo -e 'if you have a 128K Apple //e or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+, //e, //c, or IIgs. Double hi-res mode requires a 128K Apple //e, //c, or IIgs"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple ][+, //e, //c, or IIgs.' >>../xml/disk/disk$1.xml
                echo -e '\t\tDouble hi-res mode requires a 128K Apple //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It uses double hi-res graphics and thus requires a 128K Apple //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It uses double hi-res graphics and thus requires a' >>../xml/disk/disk$1.xml
                echo -e '\t\t128K Apple //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"This version, using double hi-res graphics, requires a 128K Apple //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- This version, using double hi-res graphics,' >>../xml/disk/disk$1.xml
                echo -e '\t\trequires a 128K Apple //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+. It will not run on later models."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple ][ or ][+.' >>../xml/disk/disk$1.xml
                echo -e '\t\tIt will not run on later models. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive but otherwise runs on any Apple II with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive but otherwise' >>../xml/disk/disk$1.xml
                echo -e '\t\truns on any Apple II with 48K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive but otherwise runs on any Apple II with 32K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive but otherwise' >>../xml/disk/disk$1.xml
                echo -e '\t\truns on any Apple II with 32K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive but otherwise runs on any Apple II with 24K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive but otherwise' >>../xml/disk/disk$1.xml
                echo -e '\t\truns on any Apple II with 24K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive but otherwise runs on any Apple II with 16K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive but otherwise' >>../xml/disk/disk$1.xml
                echo -e '\t\truns on any Apple II with 16K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 13-sector drive and a 48K Apple ][+ or later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 13-sector drive and a 48K Apple II+ or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires an original Apple II with 48K and Integer BASIC in ROM."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires an original Apple II with 48K and Integer BASIC' >>../xml/disk/disk$1.xml
                echo -e '\t\tin ROM. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple II and Integer BASIC in ROM"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires an original Apple II with 48K and Integer BASIC' >>../xml/disk/disk$1.xml
                echo -e '\t\tin ROM. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires an original Apple II with 32K and Integer BASIC in ROM."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires an original Apple II with 32K and Integer BASIC' >>../xml/disk/disk$1.xml
                echo -e '\t\tin ROM. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+ or later. Double hi-res graphics are available on 128K Apple //e and later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple ][+ or later.' >>../xml/disk/disk$1.xml
                echo -e '\t\tDouble hi-res graphics are available on 128K Apple //e and later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"This re-release requires a 64K Apple ][+ or later; the optional double hi-res graphics mode requires a 128K Apple //e or later. "*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- This re-release requires a 64K Apple II+ or later;' >>../xml/disk/disk$1.xml
                echo -e '\t\tthe optional double hi-res graphics mode requires a' >>../xml/disk/disk$1.xml
                echo -e '\t\t128K Apple //e or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"The disk label says it requires a 32K Apple II, but under emulation I could not get it to work on less than a 48K Apple II+"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- The disk label says it requires a 32K Apple II, but under' >>../xml/disk/disk$1.xml
                echo -e '\t\temulation I could not get it to work on less than a 48K Apple II+. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires an Apple ][ with an Integer BASIC ROM and at least 32K. Due to the reliance on Integer ROM, it will not run on later models"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires an Apple II with Integer BASIC ROM and at least 32K.' >>../xml/disk/disk$1.xml
                echo -e '\t\tDue to reliance on Integer ROM, it will not run on later models. -->' >>../xml/disk/disk$1.xml
                ;;
            *"Due to its use of double hi-res graphics, it requires a 128K Apple //e or later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- Due to its use of double hi-res graphics,' >>../xml/disk/disk$1.xml
                echo -e '\t\tit requires a 128K Apple //e or later. -->' >>../xml/disk/disk$1.xml
                ;;

            # Normal section -------------------------------------------------
            *"It requires a 64K Apple II+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+, //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+, //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II+, //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on an Apple //e with 128K, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on an Apple //e with 128K, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requirs a 64K Apple ][+ or later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple ][+ or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 64K Apple //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple //e or later"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple //e or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple II."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple II with 64K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 64K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][ or ][+."*)    
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II or II+. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple II with 32K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 32K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ with 32K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 32K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any 48K Apple ][+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any 48K Apple II+, //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It run on any Apple II with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires an Apple II+ with 48K"*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires an Apple II+ with 48K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires an Apple ][+ with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires an Apple II+ with 48K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires an 64K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ model with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple II with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It runs on any Apple ][ with 48K."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 48K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 48K Apple II+ or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires an 64K Apple ][+, //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requirs a 64K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 64K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires 64K Apple ][+ or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple II+ or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 64K Apple //e or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 64K Apple //e or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 128K Apple //e or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 128K Apple //e or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires 128K Apple //e or later."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 128K Apple //e or later. -->' >>../xml/disk/disk$1.xml
                ;;
            *"It requires a 128K Apple //e, //c, or IIgs."*)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It requires a 128K Apple //e, //c, or IIgs. -->' >>../xml/disk/disk$1.xml
                ;;
            *)
                echo -e '\t\t<sharedfeat name="compatibility" value="A2,A2P,A2E,A2EE,A2C,A2GS" />' >>../xml/disk/disk$1.xml
                echo -e '\t\t<!-- It runs on any Apple II with 48K. -->' >>../xml/disk/disk$1.xml
                ;;
            esac

            # Obviously you'll need to hand-configure the compatibility because there's a lot of ways this can be described...
            echo -e -n '\t\t<!--' >>../xml/disk/disk$1.xml
            xmllint --xpath 'metadata/description/text()' $filename | tr -d '\n' >>../xml/disk/disk$1.xml
            echo -e -n '-->\n' >>../xml/disk/disk$1.xml
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
        # use in some places in the XML.
        lfilename=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
        echo -e "Generating disk $disknum with file $lfilename.."
        # Critical: Check for SHA1 dupes.
        # Generate the SHA1 and put it in temp.
        sha1sum $filename | awk '{print $1}' >temp

        # ------------------------ Change this if you're not using WSL ----
        # If we got a dupe, put it in temp2, otherwise leave a 0-byte file.
        # We'll use that a little later.
        grep -a -i -F -n -R -f temp /mnt/c/msys64/src/mame/hash/apple2_flop*.xml >temp2
        if [[ -s temp2 ]]; then
            echo "dupe" >dupecheck
        fi
        # Start outputting disk information.
        echo -e -n '\t\t<part name="flop' >>../xml/disk/disk$1.xml
        echo -e -n $disknum >>../xml/disk/disk$1.xml
        echo -e -n '" interface="' >>../xml/disk/disk$1.xml

        # Now, is this a 5.25" or 3.5"?
        # In the case of a .po it could technicaly be either, but...
        case $lfilename in
        *".po"*)
            echo -e 'floppy_3_5">' >>../xml/disk/disk$1.xml
            ;;
        *".dsk"*)
            echo -e 'floppy_5_25">' >>../xml/disk/disk$1.xml
            ;;
        *".2mg"*)
            echo -e 'floppy_3_5">' >>../xml/disk/disk$1.xml
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
                echo -e 'floppy_3_5">' >>../xml/disk/disk$1.xml
                ;;
            *)
                echo -e 'floppy_5_25">' >>../xml/disk/disk$1.xml
                ;;
            esac
            ;;
        esac

        # Generate side/disk number information.

        case $lfilename in

        # "Disk X - Title" type
        # e.g. "swordthrust (4am crack) disk 1 - the king's testing ground.dsk"
        *"disk 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 3 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 4 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 5 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 6 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 7 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 8 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 9 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 10 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 11 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 11 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 12 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 12 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 13 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 13 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 14 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 14 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 15 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 15 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 16 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 16 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 17 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 17 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 18 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 18 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 19 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 19 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 20 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 20 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 21 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 21 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 22 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 22 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 23 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 23 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 24 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 24 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 25 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 25 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 26 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 26 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 27 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 27 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 28 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 28 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 29 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 29 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 30 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 30 - "/>' >>../xml/disk/disk$1.xml
            ;;

            # "Disk X" type
            # e.g. "read and spell - in the days of knights and castles (4am crack) disk 1.dsk"
        *"disk 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 3."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 4."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 5."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 6."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 7."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 8."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 9."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 10."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10"/>' >>../xml/disk/disk$1.xml
            ;;

            # "Disk X Side X" type
            # e.g. "read n roll (4am crack) disk 2 side a.dsk"
        *"disk 1 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 1 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 2 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 2 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 3 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 3 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 4 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 4 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 5 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 5 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 6 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 6 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 7 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 7 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 8 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 8 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 9 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 9 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 10 side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 10 side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side B"/>' >>../xml/disk/disk$1.xml
            ;;

            # "Disk X" type
        *"disk a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk c."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk d."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk e."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk f."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk g."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk h."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk i."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk j."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk k."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk l."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk m."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk n."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk o."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk p."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk q."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk r."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk s."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk t."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk u."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk v."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk w."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk x."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk y."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk z."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z"/>' >>../xml/disk/disk$1.xml
            ;;

            # "Disk X Side A/B" type
        *"disk a side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk a side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk b side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk b side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk c side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk c side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk d side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk d side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk e side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk e side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk f side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk f side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk g side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk g side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk h side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk h side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk i side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk i side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk j side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk j side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk k side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk k side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk l side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk l side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk m side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk m side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk n side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk n side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk o side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk o side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk p side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk p side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk q side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk q side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk r side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk r side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk s side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk s side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk t side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk t side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk u side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk u side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk v side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk v side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk w side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk w side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk x side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk x side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk y side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk y side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk z side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk z side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side B"/>' >>../xml/disk/disk$1.xml
            ;;

            # "Disk X Side X" type
            # e.g. "the perfect score (4am crack) disk a side 1 - antonyms i.dsk"
        *"disk a side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk a side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk b side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk b side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk c side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk c side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk d side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk d side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk e side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk e side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk f side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk f side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk g side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk g side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk h side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk h side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk i side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk i side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk j side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk j side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk k side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk k side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk l side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk l side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk m side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk m side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk n side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk n side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk o side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk o side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk p side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk p side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk q side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk q side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk r side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk r side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk s side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk s side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk t side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk t side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk u side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk u side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk v side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk v side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk w side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk w side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk x side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk x side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk y side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk y side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk z side 1 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side 1 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk z side 2 -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side 2 - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk a side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk a side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk A Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk b side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk b side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk B Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk c side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk c side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk C Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk d side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk d side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk D Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk e side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk e side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk E Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk f side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk f side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk F Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk g side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk g side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk G Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk h side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk h side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk H Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk i side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk i side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk I Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk j side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk j side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk J Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk k side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk k side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk K Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk l side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk l side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk L Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk m side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk m side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk M Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk n side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk n side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk N Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk o side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk o side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk O Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk p side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk p side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk P Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk q side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk q side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Q Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk r side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk r side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk R Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk s side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk s side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk S Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk t side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk t side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk T Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk u side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk u side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk U Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk v side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk v side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk V Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk w side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk w side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk W Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk x side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk x side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk X Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk y side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk y side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Y Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk z side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk z side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk Z Side 2"/>' >>../xml/disk/disk$1.xml
            ;;

            # "Disk X Side X - Title" type
            # e.g. "superprint (4am crack) disk 1 side a - program.dsk"
        *"disk 1 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 1 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 2 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 2 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 3 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 3 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 4 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 4 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 5 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 5 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 6 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 6 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 7 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 7 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 8 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 8 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 9 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 9 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 10 side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 10 side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side B - "/>' >>../xml/disk/disk$1.xml
            ;;

            # Disk NumberSide.
            # e.g. "voyage of the mimi (4am crack) disk 1a.dsk"
        *"disk 1a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 1b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 1 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 2a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 2b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 2 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 3a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 3b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 3 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 4a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 4b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 4 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 5a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 5b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 5 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 6a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 6b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 6 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 7a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 7b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 7 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 8a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 8b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 8 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 9a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 9b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 9 Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 10a."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"disk 10b."*)
            echo -e '\t\t\t<feature name="part_id" value="Disk 10 Side B"/>' >>../xml/disk/disk$1.xml
            ;;

            # Because case is a fallthrough, it only ever gets here if it fails to match
            # one of the above entries.

            # "Side X - Title" type
            # e.g. "the bard's tale ii (4am and san inc crack) side a - program.dsk"
        *"side a -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side A - "/>' >>../xml/disk/disk$1.xml
            ;;
        *"side b -"*)
            echo -e '\t\t\t<feature name="part_id" value="Side B - "/>' >>../xml/disk/disk$1.xml
            ;;

            # "Side X" type
            # e.g. "reading and me (4am crack) side a.dsk"
        *"side a."*)
            echo -e '\t\t\t<feature name="part_id" value="Side A"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side b."*)
            echo -e '\t\t\t<feature name="part_id" value="Side B"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side c."*)
            echo -e '\t\t\t<feature name="part_id" value="Side C"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side d."*)
            echo -e '\t\t\t<feature name="part_id" value="Side D"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side e."*)
            echo -e '\t\t\t<feature name="part_id" value="Side E"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side f."*)
            echo -e '\t\t\t<feature name="part_id" value="Side F"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side g."*)
            echo -e '\t\t\t<feature name="part_id" value="Side G"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side h."*)
            echo -e '\t\t\t<feature name="part_id" value="Side H"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 1."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 1"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 2."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 2"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 3."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 3"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 4."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 4"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 5."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 5"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 6."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 6"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 7."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 7"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 8."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 8"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 9."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 9"/>' >>../xml/disk/disk$1.xml
            ;;
        *"side 10."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 10"/>' >>../xml/disk/disk$1.xml
            ;;

            # Special cases. Will add as they come up.
        *"side 2 (boot)."*)
            echo -e '\t\t\t<feature name="part_id" value="Side 2 - Boot"/>' >>../xml/disk/disk$1.xml
            ;;
        esac

        # Give us the actual floppy definition, including size.
        echo -e -n '\t\t\t<dataarea name="flop" size="' >>../xml/disk/disk$1.xml
        wc "$filename" | awk '{print $3}' | tr -d '\n' >>../xml/disk/disk$1.xml
        echo -e '">' >>../xml/disk/disk$1.xml
        echo -e -n '\t\t\t\t<rom name="' >>../xml/disk/disk$1.xml
        # BUT! Give us the lowercase filename in the XML definition.
        echo -e -n $lfilename >>../xml/disk/disk$1.xml
        # As always, tools use case of what's there.
        echo -e -n '" size="' >>../xml/disk/disk$1.xml
        wc "$filename" | awk '{print $3}' | tr -d '\n' >>../xml/disk/disk$1.xml
        echo -e -n '" crc="' >>../xml/disk/disk$1.xml
        crc32 $filename | awk '{print $1}' | tr -d '\n' >>../xml/disk/disk$1.xml
        echo -e -n '" sha1="' >>../xml/disk/disk$1.xml
        sha1sum $filename | awk '{print $1}' | tr -d '\n' >>../xml/disk/disk$1.xml
        echo -e '" />' >>../xml/disk/disk$1.xml
        echo -e '\t\t\t</dataarea>' >>../xml/disk/disk$1.xml
        echo -e '\t\t</part>' >>../xml/disk/disk$1.xml
        ((disknum++))
    done
    echo -e '\t</software>\n' >>../xml/disk/disk$1.xml
    # Clean out any wozaday collection tags.
    # Change any crack tags to cleanly cracked.
    sed -i 's/(4am crack)<\/description>/(cleanly cracked)<\/description>/g' ../xml/disk/disk$1.xml
    sed -i 's/(san inc crack)<\/description>/(cleanly cracked)<\/description>/g' ../xml/disk/disk$1.xml
    sed -i 's/(4am and san inc crack)<\/description>/(cleanly cracked)<\/description>/g' ../xml/disk/disk$1.xml
    sed -i 's/ 800K / (800K 3.5") /g' ../xml/disk/disk$1.xml
    sed -i 's/ (woz-a-day collection)<\/description>/<\/description>/g' ../xml/disk/disk$1.xml
    sed -i 's/ 800K / (800K 3.5") /g' ../xml/disk/disk$1.xml
    # Detect if we didn't get a publisher and add a warning notification.
    sed -i 's/<publisher><\/publisher>/<publisher>UNKNOWN<\/publisher>/g' ../xml/disk/disk$1.xml
    # If the dupecheck file above says this already exists in our MAME softlists,
    # then all this work was a waste and we need to delete the XML now.

    if [[ -s dupecheck ]]; then
        echo -e "Duplicated entry. Removing generated XML..."
        rm ../xml/disk/disk$1.xml
        echo -e "------"
        # We found a dupe, so there's no point in continuing.
        # Stop here, do the aggregation, and exit.
        cd ..
        aggregate $worktype
    fi

    # Migrate all non-duplicate disk images to the postsorted folder for later
    # parsing so we can be 100% sure the XML is correct even after mame -valid
    mv *.woz ../postsorted 2>/dev/null
    mv *.dsk ../postsorted 2>/dev/null
    mv *.2mg ../postsorted 2>/dev/null
    mv *.woz ../postsorted 2>/dev/null
    cd ..
    echo -e "------"

}

function aggregate() {
    cd xml/disk
    cat ../../xmlheader.txt >../disk-combined-presort.xml
    cat disk*.xml >>../disk-combined-presort.xml 2>/dev/null
    cat ../../xmlfooter.txt >>../disk-combined-presort.xml
    # This last step sorts the entries to be in release order so you can cut and paste
    # them into the MAME XML as-is.
    case ${1} in
    "WOZADAY")
        xsltproc --novalid --nodtdattr -o ../woz-combined.xml ../../resortxml.xslt ../disk-combined-presort.xml
        ;;
    "CLCRACKED")
        xsltproc --novalid --nodtdattr -o ../cc-combined.xml ../../resortxml.xslt ../disk-combined-presort.xml
        ;;
    esac
    cd ../..
    IFS=$SAVEIFS
    exit 1
}

# Now our main loop.

# First thing's first, make sure we picked a type to work with.
if [ $# -eq 0 ]; then
    echo "No Apple disk type supplied. Please run as either:"
    echo "$0 clcracked"
    echo "or"
    echo "$0 wozaday"
    exit 1
fi

# We save the type of workload in this variable because we'll lose $1
# when we go into the functions that actually do the work
worktype=${1^^}

# Remove and recreate certain work directories so they're clean.
rm -rf xml/disk 2>/dev/null
mkdir xml 2>/dev/null
mkdir xml/disk 2>/dev/null
mkdir postsorted 2>/dev/null

COUNTER=1
# Run to a maximum of 99, end with exit code 1 when we finally hit a dupe.
#while [ $COUNTER -lt 100 ]; do
while [ $COUNTER -lt 6 ]; do
    if ! (generator $COUNTER $worktype); then
        aggregate $worktype
        exit 1
    fi
    let COUNTER=COUNTER+1
done
aggregate $worktype
IFS=$SAVEIFS
exit 1
