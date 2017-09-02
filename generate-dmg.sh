#/bin/bash

# This script has four goals:
# 1) Run the Fix-libraries script to get all frameworks into the App
# 2) Prepare files to create a dmg
# 3) Make the dmg look nice
# 4) Generate checksums

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
#source "${DIR}/build-env.sh" > /dev/null

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

	set +e

	#The Fix Libraries Script Copies library files into the app and runs otool on them.
    announce "Running Fix Libraries Script"
    source ${DIR}/fix-libraries.sh
    
    announce "Copying Documentation"
    cp -f ${DIR}/CopyrightInfoAndSourcecode.pdf ${CRAFT_DIR}/Applications/KDE/
    cp -f ${DIR}/QuickStart.pdf ${CRAFT_DIR}/Applications/KDE/
    
    annnounce "Removing any previous DMG, checksums, and unnecessary files"
    rm -r ${CRAFT_DIR}/Applications/KDE/kglobalaccel5.app
    rm ${CRAFT_DIR}/Applications/KDE/kstars-latest.dmg
    rm ${CRAFT_DIR}/Applications/KDE/kstars-latest.md5
    rm ${CRAFT_DIR}/Applications/KDE/kstars-latest.sha256
    
    ###########################################
    announce "Building DMG"
    cd ${CRAFT_DIR}/Applications/KDE
    macdeployqt KStars.app -executable=${KSTARS_APP}/Contents/MacOS/kioslave -executable=${KSTARS_APP}/Contents/MacOS/dbus-daemon -qmldir=${KSTARS_APP}/Contents/Resources/data/tools/whatsinteresting/qml/
    
   	#Setting up some short paths
    UNCOMPRESSED_DMG=${CRAFT_DIR}/Applications/KDE/KStarsUncompressed.dmg
    
	#Create and attach DMG
    hdiutil create -srcfolder ${KSTARS_APP}/../ -size 190m -fs HFS+ -format UDRW -volname KStars ${UNCOMPRESSED_DMG}
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
	cp -f ${CRAFT_DIR}/share/kstars/kstars.png ${VOLUME}/Pictures/background.jpg
	
	# symlink Applications folder, arrange icons, set background image, set folder attributes, hide pictures folder
	ln -s /Applications/ ${VOLUME}/Applications
	set_bundle_display_options ${VOLUME}
	mv -f ${VOLUME}/Pictures ${VOLUME}/.Pictures
 
	# Unmount the disk image
	hdiutil detach $DEV
 
	# Convert the disk image to read-only
	hdiutil convert ${UNCOMPRESSED_DMG} -format UDBZ -o ${CRAFT_DIR}/Applications/KDE/kstars-latest.dmg
	
	# Remove the Read Write DMG
	rm ${UNCOMPRESSED_DMG}
	
	# Generate Checksums
	md5 ${CRAFT_DIR}/Applications/KDE/kstars-latest.dmg > ${CRAFT_DIR}/Applications/KDE/kstars-latest.md5
	shasum -a 256 ${CRAFT_DIR}/Applications/KDE/kstars-latest.dmg > ${CRAFT_DIR}/Applications/KDE/kstars-latest.sha256
