#/bin/bash

# This script has three goals:
# 1) identify programs that use libraries outside of the package (that meet certain criteria)
# 2) copy those libraries to the blah/Frameworks dir
# 3) Update those programs to know where to look for said libraries
#

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}/build-env.sh" > /dev/null

FILES_TO_COPY=()
FRAMEWORKS_DIR="${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Frameworks"
INDI_DIR="${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi"
DRY_RUN_ONLY=""

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

	entries=$(otool -L $target | sed '1d' | awk '{print $1}' | egrep -v "qt5|${KSTARS_DIR}|^/usr/lib/|^/System/")
    echo "Processing $target"
    
    relativeRoot="${KSTARS_DIR}/Applications/KDE/kstars.app/Contents"
    
    pathDiff=${target#${relativeRoot}*}
    # Need to calculate the path to the frameworks dir
    #
    pathToFrameworks=$(echo $(dirname "${pathDiff}") | awk -F/ '{for (i = 1; i < NF ; i++) {printf("../")} }')
    
	for entry in $entries
	do
		baseEntry=$(basename $entry)
		newname=""

        # the pathToFrameworks should end in a slash
        #
		if [[ "$entry" == @rpath* ]]
		then
			newname="@rpath/${pathToFrameworks}Frameworks/${baseEntry}"
		else
			newname="@executable_path/${pathToFrameworks}Frameworks/${baseEntry}"
		fi
        echo "     change $entry -> $newname"
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
            echo "    install_name_tool -change \\"
            echo "        $entry \\"
            echo "        $newname \\"
            echo "        $target"
        fi            

		addFileToCopy "$entry"
	done
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
            # see if I can find it
            filename=$(find /usr/local -name "${base}")
        fi    

        if [ ! -f "${FRAMEWORKS_DIR}/${base}" ]
        then
        	echo "HAVE TO COPY [$libFile] from [${filename}] to Frameworks"
            [ -z "${DRY_RUN_ONLY}" ] && cp "${filename}" "${FRAMEWORKS_DIR}"
            
            # Seem to need this for the macqtdeploy
            #
            [ -z "${DRY_RUN_ONLY}" ] && chmod +w "${FRAMEWORKS_DIR}/${base}"
        else
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

cd ${KSTARS_DIR}

statusBanner "Processing kstars executable"
processTarget "${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/kstars"

# Also cheat, and add libindidriver.1.dylib to the list
#
addFileToCopy "libindidriver.1.dylib"

statusBanner "Copying first round of files"
copyFilesToFrameworks

statusBanner "Processing libindidriver library"

# Also need to process libindidriver.1.dylib
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
        echo "Skipping $base, not executable"
    fi
done

statusBanner "Copying second round of files"
copyFilesToFrameworks

statusBanner "The following files are now in frameworks:"
ls -lF ${FRAMEWORKS_DIR}

