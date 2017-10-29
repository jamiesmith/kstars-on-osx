#/bin/bash

# This script has four goals:
# 1) Run the Fix-libraries script to get all frameworks into the App
# 2) Prepare files to create a dmg
# 3) Make the dmg look nice
# 4) Generate checksums

#This gets the current folder this script resides in.  It is needed to run other scripts.
	DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	
#This will print the options and quit if the script is run separate from build-kstars and no option is specified
function dieUsage
{
    echo $*
cat <<EOF
options:
	    -c Generate DMG for cmake (ONLY one of -c , -x, or -e can be used)
	    -e Generate DMG for craft (ONLY one of -c , -x, or -e can be used)
	    -x Generate DMG for xcode (ONLY one of -c , -x, or -e can be used)
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

#This function makes the dmg look nice.
	function set_bundle_display_options() {
		osascript <<-EOF
			tell application "Finder"
				set f to POSIX file ("${1}" as string) as alias
				tell folder f
					open
					tell container window
						set toolbar visible to false
						set statusbar visible to false
						set current view to icon view
						delay 1 -- sync
						set the bounds to {20, 50, 300, 400}
					end tell
					delay 1 -- sync
					set icon size of the icon view options of container window to 64
					set arrangement of the icon view options of container window to not arranged
					set position of item "QuickStart.pdf" to {100, 50}
					set position of item "CopyrightInfoAndSourcecode.pdf" to {100, 150}
					set position of item "Applications" to {340, 50}
					set position of item "KStars.app" to {340, 150}
					set background picture of the icon view options of container window to file "background.jpg" of folder "Pictures"
					set the bounds of the container window to {0, 0, 440, 270}
					update without registering applications
					delay 5 -- sync
					close
				end tell
				delay 5 -- sync
			end tell
		EOF
	}
	
#########################################################################
#This is where the main part of the script starts!!
#
	
set +e

#The Fix Libraries Script Copies library files into the app and runs otool on them.
	source ${DIR}/fix-libraries.sh


#This code should only run if the user is running the generate-dmg script without running the build-kstars script
	if [ -z "${ASTRO_ROOT}" ]
	then
		source ${DIR}/build-env.sh
		processDMGOptions $@
	fi

#This should stop the script so that it doesn't run if these paths are blank.
#That way it doesn't try to edit /Applications instead of ${CRAFT_DIR}/Applications for example
	if [ -z "${DIR}" ] || [ -z "${DMG_DIR}" ]
	then
		echo "directory error! aborting DMG"
		exit 9
	fi



#This copies the documentation that will be placed into the dmg.
	announce "Copying Documentation"
	cp -f ${DIR}/CopyrightInfoAndSourcecode.pdf ${DMG_DIR}
	cp -f ${DIR}/QuickStart.pdf ${DMG_DIR}

#This deletes any previous dmg stuff so a new one can be made.
	announce "Removing any previous DMG, checksums, and unnecessary files"
	rm -r ${DMG_DIR}/kglobalaccel5.app
	rm ${DMG_DIR}/kstars-latest.dmg
	rm ${DMG_DIR}/kstars-latest.md5
	rm ${DMG_DIR}/kstars-latest.sha256

###########################################
announce "Building DMG"
cd ${DMG_DIR}
macdeployqt KStars.app -executable=${KSTARS_APP}/Contents/MacOS/kioslave -executable=${KSTARS_APP}/Contents/MacOS/dbus-daemon -qmldir=${KSTARS_APP}/Contents/Resources/data/tools/whatsinteresting/qml/

#Setting up some short paths
	UNCOMPRESSED_DMG=${DMG_DIR}/KStarsUncompressed.dmg

#Create and attach DMG
	hdiutil create -srcfolder ${DMG_DIR} -size 300m -fs HFS+ -format UDRW -volname KStars ${UNCOMPRESSED_DMG}
	hdiutil attach ${UNCOMPRESSED_DMG}

# Obtain device information
	DEVS=$(hdiutil attach ${UNCOMPRESSED_DMG} | cut -f 1)
	DEV=$(echo $DEVS | cut -f 1 -d ' ')
	VOLUME=$(mount |grep ${DEV} | cut -f 3 -d ' ')

# copy in and set volume icon
	cp -f ${DIR}/DMGIcon.icns ${VOLUME}/DMGIcon.icns
	mv -f ${VOLUME}/DMGIcon.icns ${VOLUME}/.VolumeIcon.icns
	SetFile -c icnC ${VOLUME}/.VolumeIcon.icns
	SetFile -a C ${VOLUME}

# copy in background image
	mkdir -p ${VOLUME}/Pictures
	cp -f ${KSTARS_APP}/Contents/Resources/data/kstars.png ${VOLUME}/Pictures/background.jpg

# symlink Applications folder, arrange icons, set background image, set folder attributes, hide pictures folder
	ln -s /Applications/ ${VOLUME}/Applications
	set_bundle_display_options ${VOLUME}
	mv -f ${VOLUME}/Pictures ${VOLUME}/.Pictures

# Unmount the disk image
	hdiutil detach $DEV

# Convert the disk image to read-only
	hdiutil convert ${UNCOMPRESSED_DMG} -format UDBZ -o ${DMG_DIR}/kstars-latest.dmg

# Remove the Read Write DMG
	rm ${UNCOMPRESSED_DMG}

# Generate Checksums
	md5 ${DMG_DIR}/kstars-latest.dmg > ${DMG_DIR}/kstars-latest.md5
	shasum -a 256 ${DMG_DIR}/kstars-latest.dmg > ${DMG_DIR}/kstars-latest.sha256
