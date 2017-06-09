#/bin/bash

# This script has three goals:
# 1) identify programs that use libraries outside of the package (that meet certain criteria)
# 2) copy those libraries to the blah/Frameworks dir
# 3) Update those programs to know where to look for said libraries
#

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}/build-env.sh" > /dev/null

FILES_TO_COPY=()
FRAMEWORKS_DIR="${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/Frameworks"
INDI_DIR="${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/MacOS/indi"
XPLANET_DIR="${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/MacOS/xplanet/bin"
ASTROMETRY_DIR="${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/MacOS/astrometry/bin"
GPHOTO_IOLIBS_DIR="${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/PlugIns/libgphoto2_port"
GPHOTO_CAMLIBS_DIR="${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/PlugIns/libgphoto2"
KIO_DIR="${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/PlugIns/kf5/kio"
DRY_RUN_ONLY=""

IGNORED_OTOOL_OUTPUT="/Qt|qt5|${CRAFT_DIR}/Applications/KDE/KStars.app/|/usr/lib/|/System/"

statusBanner "Replacing the Frameworks Directory"
rm - r "${FRAMEWORKS_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"

function dieUsage
{
    # I really wish that getopt supported the long args.
    #
    echo $*
cat <<EOF
options:
    -d Dry run only (just show what you are going to do)
EOF
exit 9
}

function addFileToCopy
{
	for e in "${FILES_TO_COPY[@]}"
    do 
        if [ "$e" == "$1" ]
        then
            return 0
        fi
    done
	
	FILES_TO_COPY+=($1)
}

function processTarget
{
	target=$1

	entries=$(otool -L $target | sed '1d' | awk '{print $1}' | egrep -v "$IGNORED_OTOOL_OUTPUT")
    echo "Processing $target"
    
    relativeRoot="${CRAFT_DIR}/Applications/KDE/KStars.app/Contents"
    
    pathDiff=${target#${relativeRoot}*}

    # Need to calculate the path to the frameworks dir
    #
    if [[ "$pathDiff" == /Frameworks/* ]]
    then
        pathToFrameworks=""
    else        
        pathToFrameworks=$(echo $(dirname "${pathDiff}") | awk -F/ '{for (i = 1; i < NF ; i++) {printf("../")} }')
        pathToFrameworks="${pathToFrameworks}Frameworks/"
    fi
        
	for entry in $entries
	do
		baseEntry=$(basename $entry)
		newname=""

        # the pathToFrameworks should end in a slash
        #
        # if [[ "$entry" == @rpath* ]]
        # then
        #     newname="@rpath/${pathToFrameworks}Frameworks/${baseEntry}"
        # else
        #     newname="@executable_path/${pathToFrameworks}Frameworks/${baseEntry}"
        # fi
        
        # Now I think that the @rpaths need to change to @executable_path
        #
		newname="@loader_path/${pathToFrameworks}${baseEntry}"
		
        echo "    change $entry -> $newname"
        # echo "          install_name_tool -change \\"
        # echo "              $entry \\"
        # echo "              $newname \\"
        # echo "              $target"
        
        if [ -z "${DRY_RUN_ONLY}" ]
        then
            install_name_tool -change \
                $entry \
                $newname \
                $target

        else
            echo "        install_name_tool -change \\"
            echo "            $entry \\"
            echo "            $newname \\"
            echo "            $target"
        fi            

		addFileToCopy "$entry"
	done
    echo ""
    echo "   otool for $target after"
    otool -L $target | egrep -v "$IGNORED_OTOOL_OUTPUT" | awk '{printf("\t%s\n", $0)}'
    
}

function copyFilesToFrameworks
{
    for libFile in "${FILES_TO_COPY[@]}"
    do
        # if it starts with a / then easy.
        #
        base=$(basename $libFile)

        if [[ $libFile == /* ]]
        then
            filename=$libFile
        else
            # see if I can find it, NOTE:  I had to add the last part and the echo because the find produced multiple results breaking the file copy into frameworks.
            filename=$(echo $(find /usr/local -name "${base}")| cut -d" " -f1)
        fi    

        if [ ! -f "${FRAMEWORKS_DIR}/${base}" ]
        then
        	echo "HAVE TO COPY [$base] from [${filename}] to Frameworks"
            [ -z "${DRY_RUN_ONLY}" ] && cp -fL "${filename}" "${FRAMEWORKS_DIR}"
            
            # Seem to need this for the macqtdeploy
            #
            [ -z "${DRY_RUN_ONLY}" ] && chmod +w "${FRAMEWORKS_DIR}/${base}"


        	#echo "HAVE TO COPY [$base] from [${filename}] to Indi"
            #[ -z "${DRY_RUN_ONLY}" ] && cp "${filename}" "${INDI_DIR}"
            
            # Seem to need this for the macqtdeploy
            #
            #[ -z "${DRY_RUN_ONLY}" ] && chmod +w "${INDI_DIR}/${base}"			
			
        else
            echo ""
        	echo "Skipping Copy: $libFile already in Frameworks "
        fi
    done
}


while getopts "d" option
do
    case $option in
        d)
            DRY_RUN_ONLY="yep"
            ;;
        *)
            dieUsage "Unsupported option $option"
            ;;
    esac
done
shift $((${OPTIND} - 1))

cd ${CRAFT_DIR}

statusBanner "Processing kstars executable"
processTarget "${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/MacOS/kstars"

statusBanner "Processing kioslave executable"
processTarget "${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/MacOS/kioslave"

statusBanner "Processing dbus programs"
processTarget "${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/MacOS/dbus-daemon"
processTarget "${CRAFT_DIR}/Applications/KDE/KStars.app/Contents/MacOS/dbus-send"

# Also cheat, and add libindidriver.1.dylib to the list
#
addFileToCopy "libindidriver.1.dylib"

statusBanner "Copying first round of files"
copyFilesToFrameworks

statusBanner "Processing libindidriver library"

# need to process libindidriver.1.dylib
#
processTarget ${FRAMEWORKS_DIR}/libindidriver.1.dylib

statusBanner "Processing all of the files in the indi dir"

# Then do all of the files in the indi Dir
#
FILES_TO_COPY=()
for file in ${INDI_DIR}/*
do
    base=$(basename $file)
    
    if [ -x $file ]
    then
        statusBanner "Processing indi file $base"
        processTarget $file
    else
        echo ""
        echo ""
        echo "Skipping $base, not executable"
    fi
done

statusBanner "Copying second round of files for indi"
copyFilesToFrameworks

statusBanner "Processing all of the files in the xplanet dir"

# Then do all of the files in the xplanet Dir
#
FILES_TO_COPY=()
for file in ${XPLANET_DIR}/*
do
    base=$(basename $file)
    
    if [ -x $file ]
    then
        statusBanner "Processing xplanet file $base"
        processTarget $file
    else
        echo ""
        echo ""
        echo "Skipping $base, not executable"
    fi
done

statusBanner "Copying third round of files for xplanet"
copyFilesToFrameworks

statusBanner "Processing all of the files in the astrometry dir"

# Then do all of the files in the astrometry Dir
#
FILES_TO_COPY=()
for file in ${ASTROMETRY_DIR}/*
do
    base=$(basename $file)
    
    if [ -x $file ]
    then
        statusBanner "Processing astrometry file $base"
        processTarget $file
    else
        echo ""
        echo ""
        echo "Skipping $base, not executable"
    fi
done

statusBanner "Copying fourth round of files for astrometry"
copyFilesToFrameworks

statusBanner "Processing all of the files in the plugins/kf5/kio dir"

# Then do all of the files in the kio Dir
#
FILES_TO_COPY=()
for file in ${KIO_DIR}/*
do
    base=$(basename $file)

    statusBanner "Processing kio file $base"
    processTarget $file

done

statusBanner "Copying fifth round of files for kio plugins/image downloads"
copyFilesToFrameworks

statusBanner "Processing all of the files in the GPhoto IOLIBS plugins dir"

# Then do all of the files in the plugins/libgphoto2_port Dir
#
FILES_TO_COPY=()
for file in ${GPHOTO_IOLIBS_DIR}/*
do
    base=$(basename $file)
    
    statusBanner "Processing gphoto IOLIB Plugin file $base"
    processTarget $file
    
done

statusBanner "Copying sixth round of files for GPhoto IOLIBS plugins dir"
copyFilesToFrameworks

statusBanner "Processing all of the files in the GPhoto CAMLIBS plugins dir"

# Then do all of the files in the plugins/libgphoto2 Dir
#
FILES_TO_COPY=()
for file in ${GPHOTO_CAMLIBS_DIR}/*
do
    base=$(basename $file)
    
    statusBanner "Processing gphoto CAMLIB Plugin file $base"
    processTarget $file
    
done

statusBanner "Copying seventh round of files for GPhoto CAMLIBS plugins dir"
copyFilesToFrameworks

statusBanner "Processing all of the files in the Frameworks dir"

# Then do all of the files in the Frameworks Dir
#
FILES_TO_COPY=()
for file in ${FRAMEWORKS_DIR}/*
do
    base=$(basename $file)
    
	statusBanner "Processing Frameworks file $base"
    processTarget $file
    
done

statusBanner "Copying eighth round of files for Frameworks"
copyFilesToFrameworks

statusBanner "The following files are now in Frameworks:"
ls -lF ${FRAMEWORKS_DIR}

