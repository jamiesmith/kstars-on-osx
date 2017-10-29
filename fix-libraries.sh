#/bin/bash

# This script has three goals:
# 1) It makes sure the DMG folder is set up, KStars is copied there, and the variables aree correct.
# 2) identify programs that use libraries outside of the package (that meet certain criteria)
# 3) copy those libraries to the blah/Frameworks dir
# 4) Update those programs to know where to look for said libraries

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#This will print the options and quit if the script is run separate from build-kstars and no option is specified
function dieUsage
{
    echo $*
cat <<EOF
options:
	    -c Fix Libraries via cmake (ONLY one of -c , -x, or -e can be used)
	    -e Fix Libraries for craft (ONLY one of -c , -x, or -e can be used)
	    -x Fix Libraries for xcode (ONLY one of -c , -x, or -e can be used)
EOF
exit 9
}

#This function gets called from below if this script is run separate from the build-kstars script
#It will tell this script which kstars build to turn into a dmg.
	function processDMGOptions
	{
		while getopts "acex" option
		do
			case $option in
				a)
					ANNOUNCE="Yep"
					;;
				c)
					KSTARS_BUILD_TYPE="CMAKE"
					;;
				e)
					KSTARS_BUILD_TYPE="CRAFT"
					;;
				x)
					KSTARS_BUILD_TYPE="XCODE"
					;;    	            
				*)
					dieUsage "Unsupported option $option"
					;;
			esac
		done
		shift $((${OPTIND} - 1))

		echo ""
		echo "ANNOUNCE            = ${ANNOUNCE:-Nope}"
		echo "BUILDING_KSTARS     = ${BUILDING_KSTARS:-Nope}"
		echo "KSTARS_CMAKE  = ${BUILD_KSTARS_CMAKE:-Nope}"
		echo "XCODE  		  = ${BUILD_XCODE:-Nope}"
		echo "KSTARS_CRAFT = ${BUILD_KSTARS_CRAFT:-Nope}"
	}

#This adds a file to the list so it can be copied to Frameworks
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

#This Function processes a given file using otool to see what files it is using
#Then it uses install_name_tool to change that target to be a file in Frameworks
#Finally, it adds the file that it changed to the list of files to copy there.
	function processTarget
	{
		target=$1

		entries=$(otool -L $target | sed '1d' | awk '{print $1}' | egrep -v "$IGNORED_OTOOL_OUTPUT")
		echo "Processing $target"
	
		relativeRoot="${KSTARS_APP}/Contents"
	
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
		
		if [[ $pathToFrameworks == "" ]]
		then
			newname="@loader_path/$(basename $target)"		
			echo "    This is a Framework, change its own id $target -> $newname" 
			
			install_name_tool -id \
			$newname \
			$target 
		fi
		
		for entry in $entries
		do
			baseEntry=$(basename $entry)
			newname=""

			newname="@loader_path/${pathToFrameworks}${baseEntry}"
		
			echo "    change reference $entry -> $newname" 

			install_name_tool -change \
			$entry \
			$newname \
			$target        

			addFileToCopy "$entry"
		done
		echo ""
		echo "   otool for $target after"
		otool -L $target | egrep -v "$IGNORED_OTOOL_OUTPUT" | awk '{printf("\t%s\n", $0)}'
	
	}

#This copies all of the files in the list into Frameworks
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
				cp -fL "${filename}" "${FRAMEWORKS_DIR}"
			
				# Seem to need this for the macqtdeploy
				#
				chmod +w "${FRAMEWORKS_DIR}/${base}"
		
			
			else
				echo ""
				echo "Skipping Copy: $libFile already in Frameworks "
			fi
		done
	}
	
	function processDirectory
	{
		directoryName=$1
		directory=$2
		statusBanner "Processing all of the $directoryName files in $directory"
		FILES_TO_COPY=()
		for file in ${directory}/*
		do
    		base=$(basename $file)

        	statusBanner "Processing $directoryName file $base"
        	processTarget $file
		done

		statusBanner "Copying required files for $directoryName into frameworks"
		copyFilesToFrameworks
	}
	
	
	
#########################################################################
#This is where the main part of the script starts!!
#

#This code should only run if the user is running the fix-libraries script without running build-kstars or generate-dmg
if [ -z "${ASTRO_ROOT}" ]
then
	source ${DIR}/build-env.sh
	processDMGOptions $@
fi

#This code should make sure the KStars app and the DMG Directory are set correctly.
#In the case of the CMAKE and XCode builds, it also creates the dmg directory and copies in the app
	if [ "$KSTARS_BUILD_TYPE" == "CRAFT" ]
	then
		if [ ! -e ${CRAFT_DIR} ]
		then
			dieUsage "KStars Craft directory does not exist.  You have to build KStars with Craft first. Use build-kstars.sh"
		fi
		DMG_DIR="${CRAFT_DIR}/Applications/KDE/"
	elif [ "$KSTARS_BUILD_TYPE" == "XCODE" ]
	then
		if [ ! -e ${KSTARS_XCODE_DIR} ]
		then
			dieUsage "KStars XCode directory does not exist.  You have to build KStars with XCode first. Use build-kstars.sh"
		fi
		DMG_DIR="${KSTARS_XCODE_DIR}/Applications/KDE/"
		mkdir -p $DMG_DIR
		cp -Rf ${KSTARS_XCODE_DIR}/kstars-build/kstars/Debug/KStars.app $DMG_DIR
	elif [ "$KSTARS_BUILD_TYPE" == "CMAKE" ]
	then
		if [ ! -e ${KSTARS_CMAKE_DIR} ]
		then
			dieUsage "KStars CMake directory does not exist.  You have to build KStars with CMake first. Use build-kstars.sh"
		fi
		DMG_DIR="${KSTARS_CMAKE_DIR}/Applications/KDE/"
		mkdir -p $DMG_DIR
		cp -Rf ${KSTARS_CMAKE_DIR}/kstars-build/kstars/KStars.app $DMG_DIR
	else
		dieUsage "You must state which KStars type to make into a DMG with an option."
	fi
	
	KSTARS_APP="$DMG_DIR/KStars.app"

#This should stop the script so that it doesn't run if these paths are blank.
#That way it doesn't try to edit /Applications instead of ${CRAFT_DIR}/Applications for example
	if [ -z "${DIR}" ] || [ -z "${DMG_DIR}" ] || [ -z "${KSTARS_APP}" ]
	then
		echo "directory error! aborting Libraries script!"
		exit 9
	fi
	

announce "Running Fix Libraries Script"

	FILES_TO_COPY=()
	FRAMEWORKS_DIR="${KSTARS_APP}/Contents/Frameworks"

#Files in these locations do not need to be copied into the Frameworks folder.
	IGNORED_OTOOL_OUTPUT="/Qt|${KSTARS_APP}/|/usr/lib/|/System/"

#This deletes and replaces the former Frameworks folder so you can start fresh.  This is needed if it ran before.
	statusBanner "Replacing the Frameworks Directory"
	rm - r "${FRAMEWORKS_DIR}"
	mkdir -p "${FRAMEWORKS_DIR}"

cd ${DMG_DIR}

statusBanner "Processing kstars executable"
processTarget "${KSTARS_APP}/Contents/MacOS/kstars"

statusBanner "Processing kioslave executable"
processTarget "${KSTARS_APP}/Contents/MacOS/kioslave"

statusBanner "Processing dbus programs"
processTarget "${KSTARS_APP}/Contents/MacOS/dbus-daemon"
processTarget "${KSTARS_APP}/Contents/MacOS/dbus-send"

statusBanner "Processing Phonon backend"
processTarget "${KSTARS_APP}/Contents/Plugins/phonon4qt5_backend/phonon_vlc.so"

# Also cheat, and add libindidriver.1.dylib to the list
#
addFileToCopy "libindidriver.1.dylib"

statusBanner "Copying first round of files"
copyFilesToFrameworks

statusBanner "Processing libindidriver library"

# need to process libindidriver.1.dylib
#
processTarget "${FRAMEWORKS_DIR}/libindidriver.1.dylib"
processDirectory indi "${KSTARS_APP}/Contents/MacOS/indi"
processDirectory xplanet "${KSTARS_APP}/MacOS/xplanet/bin"
processDirectory astrometry "${KSTARS_APP}/Contents/MacOS/astrometry/bin"
processDirectory kio "${KSTARS_APP}/Contents/PlugIns/kf5/kio"

processDirectory GPHOTO_IOLIBS "${KSTARS_APP}/Contents/PlugIns/libgphoto2_port"
processDirectory GPHOTO_CAMLIBS "${KSTARS_APP}/Contents/PlugIns/libgphoto2"

processDirectory VLC_ACCESS "${KSTARS_APP}/Contents/PlugIns/vlc/access"
processDirectory VLC_AUDIO_OUTPUT "${KSTARS_APP}/Contents/PlugIns/vlc/audio_output"
processDirectory VLC_CODEC "${KSTARS_APP}/Contents/PlugIns/vlc/codec"

processDirectory Frameworks "${FRAMEWORKS_DIR}"


statusBanner "The following files are now in Frameworks:"
ls -lF ${FRAMEWORKS_DIR}

