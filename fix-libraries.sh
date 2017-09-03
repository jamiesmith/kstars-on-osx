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
		
		for entry in $entries
		do
			baseEntry=$(basename $entry)
			newname=""

			newname="@loader_path/${pathToFrameworks}${baseEntry}"
		
			echo "    change $entry -> $newname" 

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

#This sets the locations of various folders in the app that will need to be scanned
#All programs in these folders will need to make sure their frameworks are in the app bundle.
	FILES_TO_COPY=()
	FRAMEWORKS_DIR="${KSTARS_APP}/Contents/Frameworks"
	INDI_DIR="${KSTARS_APP}/Contents/MacOS/indi"
	XPLANET_DIR="${KSTARS_APP}/MacOS/xplanet/bin"
	ASTROMETRY_DIR="${KSTARS_APP}/Contents/MacOS/astrometry/bin"
	GPHOTO_IOLIBS_DIR="${KSTARS_APP}/Contents/PlugIns/libgphoto2_port"
	GPHOTO_CAMLIBS_DIR="${KSTARS_APP}/Contents/PlugIns/libgphoto2"
	KIO_DIR="${KSTARS_APP}/Contents/PlugIns/kf5/kio"

#Files in these locations do not need to be copied into the Frameworks folder.
	IGNORED_OTOOL_OUTPUT="/Qt|qt5|${KSTARS_APP}/|/usr/lib/|/System/"

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

