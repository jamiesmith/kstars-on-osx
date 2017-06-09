#!/bin/bash

# This is an attempt to automate the stuff- YMMV.  Do not be surprised if you
# run in to a gsl error.

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}/build-env.sh"

BUILD_3RDPARTY=""
ANNOUNCE=""
INDI_ONLY=""
SKIP_BREW=""
BUILD_INDI=""
BUILD_KSTARS_CMAKE=""
BUILD_XCODE=""
BUILD_KSTARS_CRAFT=""
BUILDING_KSTARS=""
DRY_RUN_ONLY=""
FORCE_RUN=""
KSTARS_APP=""
FORCE_BREW_QT=""

function processOptions
{
	while getopts "3acdeiqsx" option
	do
	    case $option in
	        3)
	            BUILD_3RDPARTY="Yep"
	            ;;
	        a)
	            ANNOUNCE="Yep"
	            ;;
	        c)
	            BUILD_KSTARS_CMAKE="Yep"
	            BUILDING_KSTARS="Yep"
	            ;;
	        d)
	            DRY_RUN_ONLY="Yep"
	            ;;
	        e)
	            BUILD_KSTARS_CRAFT="Yep"
	            BUILDING_KSTARS="Yep"
	            ;;
	        f)
	            FORCE_RUN="Yep"
	            ;;
	        i)
	            BUILD_INDI="Yep"
	            ;;
			q)
				FORCE_BREW_QT="Yep"
				;;
	        s)
	            SKIP_BREW="Yep"
	            ;;
	        x)
	            BUILD_KSTARS_CMAKE="Yep"
	            BUILD_XCODE="Yep"
	            BUILDING_KSTARS="Yep"
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
	echo "BUILD_3RDPARTY      = ${BUILD_3RDPARTY:-Nope}"
	echo "BUILD_INDI          = ${BUILD_INDI:-Nope}"
	echo "BUILD_KSTARS_CMAKE  = ${BUILD_KSTARS_CMAKE:-Nope}"
	echo "BUILD_XCODE  		  = ${BUILD_XCODE:-Nope}"
	echo "BUILD_KSTARS_CRAFT = ${BUILD_KSTARS_CRAFT:-Nope}"
	echo "SKIP_BREW           = ${SKIP_BREW:-Nope}"
}

function usage
{
    # I really wish that getopt supported the long args.
    #

cat <<EOF
	options:
	    -3 Also build third party stuff
		   (This only happens if you are building indi)
	    -a Announce stuff as you go
	    -c Build kstars via cmake (ONLY one of -c , -x, or -e can be used)
	    -d Dry run only (just show what you are going to do)
	    -e Build kstars via craft (ONLY one of -c , -x, or -e can be used)
	    -f Force build even if there are script updates
	    -i Build libindi
		-q Use the brew-installed qt
	    -s Skip brew (only use this if you know you already have them)
	    -x Build kstars via cmake with xcode (ONLY one of -c , -x, or -e can be used)
    
	To build a complete craft you would do:
	    $0 -3aei
    
	To build a complete cmake build you would do:
	    $0 -3aci
	    
	To build a complete cmake build with an xcode project you would do:
	    $0 -3axi
EOF
}

function dieUsage
{
	echo ""
    echo $*
	echo ""
	usage
	exit 9
}

function dieError
{
	echo ""
    echo $*
	echo ""
	exit 9
}

function exitEarly
{
    announce "$*"
    trap - EXIT
    exit 0
}

function announce
{
    [ -n "$ANNOUNCE" ] && say -v Daniel "$*"
    statusBanner "$*"
}

function buildThirdParty
{
     ## Build 3rd party
    mkdir -p ${INDI_DIR}/build/qhy
    cd ${INDI_DIR}/build/qhy
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty/libqhy
    make
    make install
     
    mkdir -p ${INDI_DIR}/build/3rdparty
    cd ${INDI_DIR}/build/3rdparty
    
    
    
    ## Run cmake and make install twice
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty
    statusBanner "make 3rd party drivers 1st round"
    make
    make install
    
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty
    statusBanner "make 3rd party drivers 2nd round"
    make
    make install
}

function brewInstallIfNeeded
{
    brew ls $1 > /dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installing : $*"
        brew install $*
    else
        echo "brew : $* is already installed"
    fi
}

function scriptDied
{
    announce "Something failed"
}

function checkForConnections
{
    git ls-remote ${KSTARS_REPO} &> /dev/null
    git ls-remote ${LIBINDI_REPO} &> /dev/null
    git ls-remote ${CRAFT_REPO} &> /dev/null
    statusBanner "All Git Respositories found"
    if curl --output /dev/null --silent --head --fail "https://sourceforge.net/projects/flatplanet/files/maps/1.0/maps_alien-1.0.tar.gz";then
        statusBanner "XPlanet Images found"
    else
        echo "XPlanet Image File Failure"
    fi
}


function checkForQT
{
	if [ -z "$QT5_DIR" ]
	then
		if [ -z "${FORCE_BREW_QT}" ]
		then
		dieUsage "Cannot proceed, qt not installed - see the readme."
		fi
	fi
}

function installPatchedKf5Stuff
{

	if [ -z "${FORCE_BREW_QT}" ]
	then
		# Cleanup steps:
		#     brew uninstall `brew list -1 | grep '^kf5-'`
		#     rm -rf ~/Library/Caches/Homebrew/kf5-*
		#     brew untap haraldf/kf5
		#     ls /usr/local/Homebrew/Library/Taps
		#     brew remove qt5

		# I think that the qt5 stuff can just be the dir...
		#
		if [ -d ${QT5_DIR} ]
		then
			export SUBSTITUTE=${QT5_DIR}
		else
			echo "Cannot figure out where QT is."
			exit 9
		fi
	fi

    brew tap haraldf/kf5

    cd $(brew --repo haraldf/homebrew-kf5)


	if [ -z "${FORCE_BREW_QT}" ]
	then
		echo $SUBSTITUTE
		count=$(cat *.rb | grep -c CMAKE_PREFIX_PATH)
		if [ $count -le 1 ]
		then
			echo "Hacking kf5 Files"
			sed -i '' "s@*args@\"-DCMAKE_PREFIX_PATH=${SUBSTITUTE}\", *args@g" *.rb
			sed -i '' '/depends_on "qt5"/,/^/d' *.rb
		else
			echo "kf5 Files already hacked, er, patched, skipping"
		fi
	fi

    brew link --force gettext
    mkdir -p /usr/local/lib/libexec
    brewInstallIfNeeded haraldf/kf5/kf5-kcoreaddons
    brew link --overwrite kf5-kcoreaddons
    brewInstallIfNeeded haraldf/kf5/kf5-kauth
    brewInstallIfNeeded haraldf/kf5/kf5-kcrash
    brewInstallIfNeeded haraldf/kf5/kf5-knotifyconfig
    brewInstallIfNeeded haraldf/kf5/kf5-knotifications
    brewInstallIfNeeded haraldf/kf5/kf5-kplotting
    brewInstallIfNeeded haraldf/kf5/kf5-kxmlgui
    brewInstallIfNeeded haraldf/kf5/kf5-kdoctools
    brewInstallIfNeeded haraldf/kf5/kf5-knewstuff
    brewInstallIfNeeded haraldf/kf5/kf5-kded
    
    cd - > /dev/null
}

function installBrewDependencies
{
    announce "Installing brew dependencies"

    brewInstallIfNeeded cmake
    brewInstallIfNeeded wget
    brewInstallIfNeeded coreutils
    brewInstallIfNeeded p7zip
    brewInstallIfNeeded gettext
    brewInstallIfNeeded ninja
    brewInstallIfNeeded python3
    brewInstallIfNeeded bison
    brewInstallIfNeeded boost
    brewInstallIfNeeded shared-mime-info

    # These for gphoto
    #
    brewInstallIfNeeded dcraw
    brewInstallIfNeeded gphoto2
    brewInstallIfNeeded libraw

    brew tap homebrew/science
    brewInstallIfNeeded pkgconfig
    brewInstallIfNeeded cfitsio
    brewInstallIfNeeded eigen
    brewInstallIfNeeded astrometry-net
    brewInstallIfNeeded xplanet
    brewInstallIfNeeded gsl
    brewInstallIfNeeded python
    brewInstallIfNeeded libftdi
    brewInstallIfNeeded gpsd
    pip install pyfits

    brewInstallIfNeeded jamiesmith/astronomy/libnova
    brewInstallIfNeeded jamiesmith/astronomy/gsc
    
	# Only do this if we are doing a cmake build
	#
	if [ -n "$BUILD_KSTARS_CMAKE" ]
	then
	    installPatchedKf5Stuff
	fi
}

function buildINDI
{
	mkdir -p ${INDI_DIR}
	
    ##########################################
    # Indi
    announce "building libindi"

    cd ${INDI_DIR}/

    if [ ! -d indi ]
    then
        statusBanner "Cloning indi library"

        git clone ${LIBINDI_REPO}
        cd indi/libindi
    else
        statusBanner "Updating indi"
        cd indi
        git pull
        cd ..
    fi

    mkdir -p ${INDI_DIR}/build/libindi
    cd ${INDI_DIR}/build/libindi

    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/libindi

    statusBanner "make indi"

    make

    # This might need a sudo.
    #
    statusBanner "make install indi"
    make install

    if [ -n "${BUILD_3RDPARTY}" ]
    then
        announce "Executing third Party Build as directed"
        buildThirdParty
    else
        statusBanner "Skipping third Party Build as directed"
    fi
}

function craftKstars
{
    mkdir -p ${CRAFT_DIR}
    cd ${CRAFT_DIR}/
    
    if [ ! -d craft ]
    then
        statusBanner "Cloning craft"
                git clone ${CRAFT_REPO}
		
		# The following 3 lines are usually not needed, but if craft has a problem
		# then you can uncomment these 3 lines to go back to a version of craft that works for building KStars.app
		cd craft
		git reset --hard de8e9a79fde9bede703da3756fe641ffefc659f7
		cd ..	
    else
        statusBanner "Updating craft"
        cd craft
        git pull
        cd ..
    fi

    mkdir -p etc
    cp -f craft/kdesettings.mac etc/kdesettings.ini

	. craft/kdeenv.sh
	
	craft -vvv -i kstars
	
    announce "CRAFT COMPLETE"
}

function buildKstars
{
	mkdir -p ${KSTARS_CMAKE_DIR}
	
    announce "Building k stars via c make"
    cd ${KSTARS_CMAKE_DIR}/

    if [ ! -d kstars ]
    then
        statusBanner "Cloning kstars"

        git clone ${KSTARS_REPO}
    else
        statusBanner "Updating kstars"
        cd kstars
        git pull
        cd ..
    fi

    mkdir -p kstars-build
    cd kstars-build

	if [ -n "$BUILD_XCODE" ]
	then
    	cmake -DCMAKE_INSTALL_PREFIX=${KSTARS_CMAKE_DIR} -G Xcode ../kstars
    	xcodebuild -project kstars.xcodeproj -alltargets -configuration Debug
    else
    	cmake -DCMAKE_INSTALL_PREFIX=${KSTARS_CMAKE_DIR} ../kstars
    	make
    	make install
	fi
   
}

function checkUpToDate
{	
	cd "$DIR"

	localVersion=$(git log --pretty=%H ...refs/heads/master^ | head -n 1)
	remoteVersion=$(git ls-remote origin -h refs/heads/master | cut -f1)
	cd - > /dev/null
	echo ""
	echo ""

	if [ "${localVersion}" != "${remoteVersion}" ]
	then

		if [ -z "$FORCE_RUN" ]
		then
			announce "Script is out of date"
			echo ""
			echo "override with a -f"
			echo ""
			echo "There is a newer version of the script available, please update - run"
			echo "cd $DIR ; git pull"

			echo "Aborting run"
			exit 9
		else
			echo "WARNING: Script is out of date"
			
			echo "Forcing run"
		fi
	else
		echo "Script is up-to-date"
		echo ""
	fi	
}

function postProcessKstars
{
    ##########################################
    statusBanner "Post-processing KStars Build"
	echo "KSTARS_APP=${KSTARS_APP}"
    ##########################################
    statusBanner "The Data Directory"
    echo mkdir -p ${KSTARS_APP}/Contents/Resources/data
	mkdir -p ${KSTARS_APP}/Contents/Resources/data
	
    # Craft and cmake now put them in the same directory, but if it is the Xcode version, it is a subdirectory.
    #
    if [ -n "${BUILD_KSTARS_CMAKE}" ] && [ -d "${KSTARS_CMAKE_DIR}/share/kstars" ]
    then
        typeset src_dir="${KSTARS_CMAKE_DIR}/share/kstars"
        echo "copying from $src_dir"
        cp -rf $src_dir/* ${KSTARS_APP}/Contents/Resources/data/
    elif [ -n "${BUILD_KSTARS_CRAFT}" ] && [ -d "${CRAFT_DIR}/share/kstars" ]
    then
        typeset src_dir="${CRAFT_DIR}/share/kstars"
        echo "copying from $src_dir"
        cp -rf $src_dir/* ${KSTARS_APP}/Contents/Resources/data/
    elif [ -n "$BUILD_XCODE" ] && [ -d "${KSTARS_XCODE_DIR}/kstars/kstars/data" ]
    then
    	typeset src_dir="${KSTARS_XCODE_DIR}/kstars/kstars/data"
        echo "copying from $src_dir"
        cp -rf $src_dir/* ${KSTARS_APP}/Contents/Resources/data/
    else
        announce "Cannot find k stars data"
    fi

    ##########################################
    statusBanner "The indi drivers"
    mkdir -p ${KSTARS_APP}/Contents/MacOS/indi
    cp -f /usr/local/bin/indi*    ${KSTARS_APP}/Contents/MacOS/indi/
    cp -f /usr/local/share/indi/* ${KSTARS_APP}/Contents/MacOS/indi/
    ##########################################
    statusBanner "All the other XML Files"
	FILES="$(find ${INDI_DIR} -name '*.xml.cmake')"
    for FILE in $FILES; do
    	FILENAME=$(basename $FILE)
    	NEWFILENAME="$(echo $FILENAME | sed 's/.cmake//')"
    	echo $NEWFILENAME
    	DESTINATION=${KSTARS_APP}/Contents/MacOS/indi/$NEWFILENAME
    	cp -f $FILE $DESTINATION
    done
	##########################################
	statusBanner "The gsc executable"
	sourceDir="$(brew --prefix gsc)"
	cp -f ${sourceDir}/bin/gsc ${KSTARS_APP}/Contents/MacOS/indi/
	#This is needed so we will be able to run the install_name_tool on it.
	chmod +w ${KSTARS_APP}/Contents/MacOS/indi/gsc

    ##########################################
    statusBanner "The astrometry files"
	if [ -n "${KSTARS_APP}" ]
	then
		sourceDir="$(brew --prefix astrometry-net)"
		targetDir="${KSTARS_APP}/Contents/MacOS/astrometry"
	    mkdir -p ${targetDir}
	
	    cp -Rf ${sourceDir}/bin ${targetDir}/
	    cp -Rf ${sourceDir}/lib ${targetDir}/
	    cp -f  ${sourceDir}/etc/astrometry.cfg ${targetDir}/bin/
	    
	    #This is needed so we will be able to run the install_name_tool on them.
	    chmod +w ${targetDir}/bin/*
	fi
    ##########################################
    statusBanner "Set up some xplanet pictures..."

    # this sometimes fails, let's not abort the script if it does
    #
    cd ${INDI_ROOT}
    rm -f maps_alien-1.0.tar.gz

    set +e
    curl -LO https://sourceforge.net/projects/flatplanet/files/maps/1.0/maps_alien-1.0.tar.gz
    dl_res=$?
    set -e

    if [ $dl_res -ne 0 ]
    then
        announce "Xplanet map download failed, skipping copies"
    else
        tar -xzf maps_alien-1.0.tar.gz -C "$(brew --prefix xplanet)" --strip-components=2
        rm maps_alien-1.0.tar.gz
        xplanet_dir=${KSTARS_APP}/Contents/MacOS/xplanet/

        mkdir -p ${xplanet_dir}
        cp -rf $(brew --prefix xplanet)/bin ${xplanet_dir}
        chmod +w ${xplanet_dir}/bin/xplanet
        cp -rf $(brew --prefix xplanet)/share ${xplanet_dir}
    fi
    
    statusBanner "Copying GPhoto Plugins"
	GPHOTO_VERSION=$(pkg-config --modversion libgphoto2)
	PORT_VERSION=$(pkg-config --modversion libgphoto2_port)
    mkdir -p ${KSTARS_APP}/Contents/PlugIns/libgphoto2_port
    mkdir -p ${KSTARS_APP}/Contents/PlugIns/libgphoto2
	cp -rf $(brew --prefix libgphoto2)/lib/libgphoto2_port/${PORT_VERSION}/* ${KSTARS_APP}/Contents/PlugIns/libgphoto2_port/
	cp -rf $(brew --prefix libgphoto2)/lib/libgphoto2/${GPHOTO_VERSION}/* ${KSTARS_APP}/Contents/PlugIns/libgphoto2/
	
	statusBanner "Copying qhy firmware"
	cp -rf /usr/local/lib/qhy ${KSTARS_APP}/Contents/PlugIns/
	
	statusBanner "Copying dbus programs and files."
	cp -f $(brew --prefix dbus)/bin/dbus-daemon ${KSTARS_APP}/Contents/MacOS/
    chmod +w ${KSTARS_APP}/Contents/MacOS/dbus-daemon
    cp -f $(brew --prefix dbus)/bin/dbus-send ${KSTARS_APP}/Contents/MacOS/
    chmod +w ${KSTARS_APP}/Contents/MacOS/dbus-send
    mkdir -p ${KSTARS_APP}/Contents/PlugIns/dbus
    cp -f $(brew --prefix dbus)/share/dbus-1/session.conf ${KSTARS_APP}/Contents/PlugIns/dbus/kstars.conf
    cp -f ${DIR}/org.freedesktop.dbus-kstars.plist ${KSTARS_APP}/Contents/PlugIns/dbus/
	
    
    if [ -n "${BUILD_KSTARS_CRAFT}" ]
	then
		statusBanner "Copying k i o slave."
		#I am not sure why this is needed, but it doesn't seem to be able to access KIOSlave otherwise.
    	#Do we need kio_http_cache_cleaner??  or any others?
    	cp -f ${CRAFT_DIR}/lib/libexec/kf5/kioslave ${KSTARS_APP}/Contents/MacOS/

		statusBanner "Copying plugins and preparing them for otool"
		cp -rf ${CRAFT_DIR}/lib/plugins/* ${KSTARS_APP}/Contents/PlugIns/
		#This will allow otool to be run on them
		chmod -R +w ${KSTARS_APP}/Contents/PlugIns/libgphoto2_port
		chmod -R +w ${KSTARS_APP}/Contents/PlugIns/libgphoto2
		
		statusBanner "Copying icontheme"
		cp -f ${CRAFT_DIR}/share/icons/breeze/breeze-icons.rcc ${KSTARS_APP}/Contents/Resources/icontheme.rcc

	elif [ -n "${BUILD_KSTARS_CMAKE}" ]
	then
		statusBanner "Copying k i o slave."
    	#Do we need kio_http_cache_cleaner??  or any others?
    	#This hack is needed because for some reason on my system klauncher cannot access kioslave even in the app directory.
    	cp -f /usr/local/lib/libexec/kf5/kioslave /usr/local/opt/kf5-kinit/lib/libexec/kf5/kioslave
    	
    	statusBanner "Copying plugins"
    	cp -rf /usr/local/lib/plugins/* ${KSTARS_APP}/Contents/PlugIns/
    	
	else
    	announce "Plugins and K I O Slave ERROR"
	fi
    
    

    ###########################################
	# Uncomment this if the fix-libraries breaks
	#     announce "Tarring up k stars"
	# tarname=$(basename ${KSTARS_APP})
	#     cd $INDI_ROOT
	#     rm -f ${tarname}.tgz
	#     tar czf ${tarname}.tgz ${tarname}
	#     ls -l ${tarname}.tgz
}

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



##########################################
# This is where the bulk of it starts!
#

# Before anything, check for QT and to see if the remote servers are accessible
#
checkForQT
checkForConnections


processOptions $@

#checkUpToDate


if [ -z "$SKIP_BREW" ]
then
    installBrewDependencies
else
    announce "Skipping brew dependencies"
fi

if [ -n "$BUILD_XCODE" ]
then
    export KSTARS_CMAKE_DIR=${KSTARS_XCODE_DIR}
fi

if [ -n "$BUILD_KSTARS_CMAKE" ] && [ -n "$BUILD_KSTARS_CRAFT" ]
then
    dieUsage "Only one KSTARS build type allowed" 
fi

if [ -z "$BUILD_KSTARS_CMAKE" ] && [ -z "$BUILD_KSTARS_CRAFT" ] && [ -z "$BUILD_INDI" ]
then
    DRY_RUN_ONLY="Yep"
fi

[ -n "${DRY_RUN_ONLY}" ] && exitEarly "Dry Run Only"

# From here on out exit if there is a failure
#
set -e
trap scriptDied EXIT


if [ -n "${BUILD_INDI}" ]
then
    buildINDI    
else
    announce "Skipping INDI Build"
fi

if [ -n "${BUILD_KSTARS_CRAFT}" ]
then
	KSTARS_APP="${CRAFT_DIR}/Applications/KDE/KStars.app"
    craftKstars
elif [ -n "${BUILD_XCODE}" ]
then
	KSTARS_APP="${KSTARS_XCODE_DIR}/kstars-build/kstars/Debug/KStars.app"
    buildKstars
elif [ -n "${BUILD_KSTARS_CMAKE}" ]
then
	KSTARS_APP="${KSTARS_CMAKE_DIR}/kstars-build/kstars/KStars.app"
    buildKstars
else
    announce "Not building k stars"
fi

if [ -n "${BUILDING_KSTARS}" ]
then
	postProcessKstars
fi

if [ -n "${BUILD_KSTARS_CRAFT}" ]
then
    set +e

    announce "Fixing the dir names and such"
    ${DIR}/fix-libraries.sh
    
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
	
elif [ -n "${BUILD_KSTARS_CMAKE}" ]
then
	announce "Copying K Stars Application To C Make Directory"
        mkdir -p ${KSTARS_CMAKE_DIR}/Applications/KDE
	cp -Rf ${KSTARS_APP} ${KSTARS_CMAKE_DIR}/Applications/KDE
	if [ -n "${BUILD_XCODE}" ]
	then
                mkdir -p ${KSTARS_APP}/../../Release
		cp -Rf ${KSTARS_APP} ${KSTARS_APP}/../../Release/KStars.app
	fi
fi

# Finally, remove the trap
trap - EXIT
announce "Script execution complete"
