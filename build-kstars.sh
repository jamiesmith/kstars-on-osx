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
BUILD_KSTARS_EMERGE=""
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
	            BUILD_KSTARS_EMERGE="Yep"
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
	echo "BUILD_KSTARS_EMERGE = ${BUILD_KSTARS_EMERGE:-Nope}"
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
	    -e Build kstars via emerge (ONLY one of -c , -x, or -e can be used)
	    -f Force build even if there are script updates
	    -i Build libindi
		-q Use the brew-installed qt
	    -s Skip brew (only use this if you know you already have them)
	    -x Build kstars via cmake with xcode (ONLY one of -c , -x, or -e can be used)
    
	To build a complete emerge you would do:
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

function patchThirdPartyCmake
{
    cd ${INDI_DIR}
    CMAKE=${INDI_DIR}/indi/3rdparty/CMakeLists.txt

    if [ $(grep -c AUTO_PATCHED ${CMAKE}) -gt 0 ]
    then
        echo $CMAKE Already Patched
        return
    fi

    statusBanner "Patching $CMAKE"

    echo '' >> ${CMAKE}
    echo '' >> ${CMAKE}
    echo '' >> ${CMAKE}
    echo '### AUTO_PATCHED' >> ${CMAKE}
    echo 'message("Adding GPhoto")' >> ${CMAKE}
    echo 'if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")' >> ${CMAKE}
    echo 'option(WITH_GPHOTO "Install GPhoto Driver" On)' >> ${CMAKE}
#   echo 'option(WITH_SBIG "Install GPhoto Driver" On)' >> ${CMAKE}
 #  echo 'option(WITH_DSI "Install GPhoto Driver" On)' >> ${CMAKE}
  # echo 'option(WITH_ASICAM "Install GPhoto Driver" On)' >> ${CMAKE}
    echo '' >> ${CMAKE}
    
    echo 'if (WITH_GPHOTO)' >> ${CMAKE}
    echo 'add_subdirectory(indi-gphoto)' >> ${CMAKE}
    echo 'endif(WITH_GPHOTO)' >> ${CMAKE}
    echo '' >> ${CMAKE}
    
#    echo 'if (WITH_SBIG)' >> ${CMAKE}
 #   echo 'find_package(SBIG)' >> ${CMAKE}
  #  echo 'if (SBIG_FOUND)' >> ${CMAKE}    
#    echo 'add_subdirectory(indi-sbig)' >> ${CMAKE}
 #   echo 'else (SBIG_FOUND)' >> ${CMAKE}
  #  echo 'add_subdirectory(libsbig)' >> ${CMAKE}
#    echo 'SET(LIBRARIES_FOUND FALSE)' >> ${CMAKE}
 #   echo 'endif (SBIG_FOUND)' >> ${CMAKE}
  #  echo 'endif (WITH_SBIG)' >> ${CMAKE}
   # echo '' >> ${CMAKE}
    
#     echo 'if (WITH_DSI)' >> ${CMAKE}
 #   echo 'add_subdirectory(indi-dsi)' >> ${CMAKE}
  #  echo 'endif(WITH_DSI)' >> ${CMAKE}
   # echo '' >> ${CMAKE}
    
#     echo 'if (WITH_ASICAM)' >> ${CMAKE}
 #   echo 'add_subdirectory(indi-asi)' >> ${CMAKE}
  #  echo 'endif(WITH_ASICAM)' >> ${CMAKE}
   # echo '' >> ${CMAKE}
    
    echo 'endif (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")' >> ${CMAKE}
	
    echo '' >> ${CMAKE}
    echo '' >> ${CMAKE}
}

function patchEqmodCmake
{
    cd ${INDI_DIR}
    CMAKE=${INDI_DIR}/indi/3rdparty/indi-eqmod/CMakeLists.txt

    if [ $(grep -c AUTO_PATCHED ${CMAKE}) -gt 0 ]
    then
        echo $CMAKE Already Patched
        return
    fi

    statusBanner "Patching $CMAKE"

    echo '### AUTO_PATCHED' >> ${CMAKE}
    echo 'find_package(GSL REQUIRED)' >> ${CMAKE}
    echo '' >> ${CMAKE}
    echo 'if (GSL_FOUND)' >> ${CMAKE}
    echo 'include_directories(${GSL_INCLUDE_DIRS})' >> ${CMAKE}
    echo 'endif (GSL_FOUND)' >> ${CMAKE}
}

function patchAlignmentCmake
{
    cd ${INDI_DIR}
    CMAKE=${INDI_DIR}/indi/libindi/libs/indibase/alignment/CMakeLists.txt

    if [ $(grep -c AUTO_PATCHED ${CMAKE}) -gt 0 ]
    then
        echo $CMAKE Already Patched
        return
    fi

    statusBanner "Patching $CMAKE"
    sed -i '' 's#target_link_libraries(AlignmentDriver ${GSL_LIBRARIES})#target_link_libraries(AlignmentDriver -L/usr/local/lib ${GSL_LIBRARIES})#' $CMAKE    
    echo "" >> ${CMAKE}
    echo "### AUTO_PATCHED" >> ${CMAKE}
}

function patchTopCmake
{
    cd ${INDI_DIR}
    CMAKE=${INDI_DIR}/indi/libindi/CMakeLists.txt

    if [ $(grep -c AUTO_PATCHED ${CMAKE}) -gt 0 ]
    then
        echo $CMAKE Already Patched
        return
    fi

    statusBanner "Patching $CMAKE"
    [ -f ${CMAKE}.orig ] || cp ${CMAKE} ${CMAKE}.orig
    awk '1;/set \(indiclient_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' ${CMAKE} > ${CMAKE}.zzz
    awk '1;/set \(indiclient_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' ${CMAKE}.zzz > ${CMAKE}

    awk '1;/set \(indiclientqt_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' ${CMAKE} > ${CMAKE}.zzz
    awk '1;/set \(indiclientqt_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' ${CMAKE}.zzz > ${CMAKE}
    
    rm ${CMAKE}.zzz

    echo "" >> ${CMAKE}
    echo "### AUTO_PATCHED" >> ${CMAKE}
}

function patchMaxdomeiiCmake
{
    cd ${INDI_DIR}
    CMAKE=${INDI_DIR}/indi/3rdparty/indi-maxdomeii/CMakeLists.txt

    if [ $(grep -c AUTO_PATCHED ${CMAKE}) -gt 0 ]
    then
        echo $CMAKE Already Patched
        return
    fi
    
    statusBanner "Patching $CMAKE"
    # First, nova needs to be all caps
    #
    sed -i '' 's|Nova REQUIRED|NOVA REQUIRED|' $CMAKE
    
    # second, need to also include ln_types.h
    #
    [ -f ${CMAKE}.orig ] || cp ${CMAKE} ${CMAKE}.orig
    awk '1;/NOVA REQUIRED/{c=1}c&&!--c{print "### AUTO_PATCHED\nfind_path(LN_INCLUDE_DIR libnova/ln_types.h)"}' ${CMAKE} > ${CMAKE}.zzz
    awk '1;/NOVA_INCLUDE_DIR/{c=1}c&&!--c{print "### AUTO_PATCHED\ninclude_directories( ${LN_INCLUDE_DIR})"}' ${CMAKE}.zzz > ${CMAKE}

    rm ${CMAKE}.zzz

    echo "" >> ${CMAKE}
    echo "### AUTO_PATCHED" >> ${CMAKE}
}

function buildThirdParty
{
    patchThirdPartyCmake
    patchEqmodCmake
    patchMaxdomeiiCmake
    
    cd ${INDI_DIR}
    mkdir -p ${INDI_DIR}/build/3rdparty
    cd ${INDI_DIR}/build/3rdparty
    rm -rf ${INDI_DIR}/build/3rdparty/*

    statusBanner "Configure indi third-party"
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty

    statusBanner "make indi third-party"
    make

    statusBanner "make install indi third-party"
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
	git ls-remote git://anongit.kde.org/kstars.git &> /dev/null
	git ls-remote https://github.com/indilib/indi.git &> /dev/null
	git ls-remote https://github.com/KDE/emerge &> /dev/null
	git ls-remote git://anongit.kde.org/craft.git &> /dev/null
	statusBanner "All Git Respositories found"
	if curl --output /dev/null --silent --head --fail "https://sourceforge.net/projects/flatplanet/files/maps/1.0/maps_alien-1.0.tar.gz";then
		statusBanner "XPlanet Images found"
	else
		echo "XPlanet Image File Failure"
	fi
	
}


function checkForQT
{
	if [ -z "$Qt5_DIR" ]
	then
		dieUsage "Cannot proceed, qt not installed - see the readme."
	fi
}

function installPatchedKf5Stuff
{
    # Cleanup steps:
    #     brew uninstall `brew list -1 | grep '^kf5-'`
    #     rm -rf ~/Library/Caches/Homebrew/kf5-*
    #     brew untap haraldf/kf5
    #     ls /usr/local/Homebrew/Library/Taps
    #     brew remove qt5

	# I think that the qt5 stuff can just be the dir...
	#
    if [ -d ~/Qt/5.7/clang_64 ]
    then
    	export SUBSTITUTE=~/Qt/5.7/clang_64
    elif [ -d ~/Qt5.7.0/5.7/clang_64 ]
    then
    	export SUBSTITUTE=~/Qt5.7.0/5.7/clang_64
    else
        echo "Cannot figure out where QT is."
        exit 9
    fi

    brew tap haraldf/kf5

    cd $(brew --repo haraldf/homebrew-kf5)

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

function buildLibIndi
{
	mkdir -p ${INDI_DIR}
	
    ##########################################
    # Indi
    announce "building lib indi stuff"

    cd ${INDI_DIR}/

    if [ ! -d indi ]
    then
        statusBanner "Cloning and patching indilib"

        git clone https://github.com/indilib/indi.git
        cd indi/libindi
    else
        cd indi
        git pull
        statusBanner "indilib already cloned and patched"    
        cd ${INDI_DIR}/
    fi

    patchTopCmake
    patchAlignmentCmake

    mkdir -p ${INDI_DIR}/build/libindi
    rm -rf ${INDI_DIR}/build/libindi/*
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
  #      cp -Rf ${DIR}/SBIGUDrv.framework ${INDI_DIR}/build/libindi/SBIGUDrv.framework
        buildThirdParty
    else
        statusBanner "Skipping third Party Build as directed"
    fi
}

function emergeKstars
{
	mkdir -p ${KSTARS_EMERGE_DIR}
	
    ### Let's try emerge.
    announce "Running the emerge!"

    if [ ! -f ~/.gitconfig ] || [ $(grep -c kde.org ~/.gitconfig) -eq 0 ]
    then
    cat << EOF >> ~/.gitconfig

[url "git://anongit.kde.org/"]
    insteadOf = kde:
[url "ssh://git@git.kde.org/"]
    pushInsteadOf = kde:
    
EOF
    else
        echo "looks like gitconfig is done"
    fi

    cd ${KSTARS_EMERGE_DIR}/
	
	version=craft

	if [ "$version" == "emerge" ]
	then

		# working against the mirror until the branch is caught up.
		#
		git clone --branch unix3 https://github.com/KDE/emerge
	    mkdir -p etc
	    cp -f emerge/kdesettings.mac etc/kdesettings.ini

	    . emerge/kdeenv.sh
		
		cmd=""

		if [ $(which emerge) ]
		then
			echo "Found emerge"
			cmd=$(which emerge)
		else
			echo "emerge not found"
		fi
				
		if [ $(which craft) ]
		then
			echo "Found craft"
			cmd=$(which craft)
		else
			echo "craft not found"
		fi
		
		[ -z "$cmd" ] && dieError "Could not find an emerge or craft option"
	
	    time ${cmd} kstars
	else
	    # git clone --branch unix3 git://anongit.kde.org/craft.git
	    git clone git://anongit.kde.org/craft.git

	    mkdir -p etc
	    cp -f craft/kdesettings.mac etc/kdesettings.ini
	    . craft/kdeenv.sh
		
		cmd=""

		if [ $(which emerge) ]
		then
			echo "Found emerge"
			cmd=$(which emerge)
		else
			echo "emerge not found"
		fi
				
		if [ $(which craft) ]
		then
			echo "Found craft"
			cmd=$(which craft)
		else
			echo "craft not found"
		fi
		
		echo "In the script craftRoot is [$craftRoot]"
		export craftRoot
		export crafteRoot=$craftRoot
		[ -z "$cmd" ] && dieError "Could not find an emerge or craft option"
	
	    time ${cmd} kstars
	fi
	
    announce "EMERGE COMPLETE"
}

function buildKstars
{
	mkdir -p ${KSTARS_CMAKE_DIR}
	
    announce "Building k stars via c make"
    cd ${KSTARS_CMAKE_DIR}/

    git clone git://anongit.kde.org/kstars.git

    mkdir kstars-build
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
	
    # Emerge and cmake now put them in the same directory, but if it is the Xcode version, it is a subdirectory.
    #
    if [ -d "${KSTARS_APP}/../../../share/kstars" ]
    then
        typeset src_dir="${KSTARS_APP}/../../../share/kstars"
        echo "copying from $src_dir"
        cp -rf $src_dir/* ${KSTARS_APP}/Contents/Resources/data/
    elif [ -d "${KSTARS_APP}/../../../../kstars/kstars/data" ]
    then
    	typeset src_dir="${KSTARS_APP}/../../../../kstars/kstars/data"
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
        cp -rf $(brew --prefix xplanet)/share ${xplanet_dir}
    fi
    
    
    if [ -n "${BUILD_KSTARS_EMERGE}" ]
	then
		statusBanner "Copying k i o slave."
		#I am not sure why this is needed, but it doesn't seem to be able to access KIOSlave otherwise.
    	#Do we need kio_http_cache_cleaner??  or any others?
    	cp -f ${KSTARS_EMERGE_DIR}/lib/libexec/kf5/kioslave ${KSTARS_APP}/Contents/MacOS/

		statusBanner "Copying plugins"
    	mkdir ${KSTARS_EMERGE_DIR}/Applications/KDE/KStars.app/Contents/PlugIns
		cp -rf ${KSTARS_EMERGE_DIR}/lib/plugins/* ${KSTARS_APP}/Contents/PlugIns/
		
		statusBanner "Copying icontheme"
		cp -f ${KSTARS_EMERGE_DIR}/share/icons/breeze/breeze-icons.rcc ${KSTARS_APP}/Contents/Resources/icontheme.rcc

	elif [ -n "${BUILD_KSTARS_CMAKE}" ]
	then
		statusBanner "Copying k i o slave."
    	#Do we need kio_http_cache_cleaner??  or any others?
    	#This hack is needed because for some reason on my system klauncher cannot access kioslave even in the app directory.
    	cp -f /usr/local/lib/libexec/kf5/kioslave /usr/local/opt/kf5-kinit/lib/libexec/kf5/kioslave
    	
		statusBanner "Copying plugins"
    	mkdir ${KSTARS_APP}/Contents/PlugIns
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

if [ -n "$BUILD_KSTARS_CMAKE" ] && [ -n "$BUILD_KSTARS_EMERGE" ]
then
    dieUsage "Only one KSTARS build type allowed" 
fi

if [ -n "${BUILD_INDI}" ] && [ -d "${INDI_DIR}" ]
then
	dieUsage "${INDI_DIR} already exists"
fi

if [ -n "${BUILD_KSTARS_EMERGE}" ] && [ -d "${KSTARS_EMERGE_DIR}" ]
then
	dieUsage "${KSTARS_EMERGE_DIR} already exists"
fi

if [ -n "${BUILD_KSTARS_CMAKE}" ] && [ -d "${KSTARS_CMAKE_DIR}" ]
then
	dieUsage "${KSTARS_CMAKE_DIR} already exists"
fi

if [ -z "$BUILD_KSTARS_CMAKE" ] && [ -z "$BUILD_KSTARS_EMERGE" ] && [ -z "$BUILD_INDI" ]
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
    buildLibIndi    
else
    announce "Skipping INDI Build"
fi

if [ -n "${BUILD_KSTARS_EMERGE}" ]
then
	KSTARS_APP="${KSTARS_EMERGE_DIR}/Applications/KDE/kstars.app"
    emergeKstars
elif [ -n "${BUILD_XCODE}" ]
then
	KSTARS_APP="${KSTARS_XCODE_DIR}/kstars-build/kstars/Debug/kstars.app"
    buildKstars
elif [ -n "${BUILD_KSTARS_CMAKE}" ]
then
	KSTARS_APP="${KSTARS_CMAKE_DIR}/kstars-build/kstars/kstars.app"
    buildKstars
else
    announce "Not building k stars"
fi

if [ -n "${BUILDING_KSTARS}" ]
then
	postProcessKstars
fi

if [ -n "${BUILD_KSTARS_EMERGE}" ]
then
    set +e

    announce "Fixing the dir names and such"
    ${DIR}/fix-libraries.sh
    ${DIR}/fix-plugins.sh
    
    announce "Copying Documentation"
    cp ${DIR}/CopyrightInfoAndSourcecode.pdf ${KSTARS_EMERGE_DIR}/Applications/KDE/
    cp ${DIR}/QuickStart.pdf ${KSTARS_EMERGE_DIR}/Applications/KDE/
    rm -r ${KSTARS_EMERGE_DIR}/Applications/KDE/kglobalaccel5.app
    
    ###########################################
    announce "Building DMG"
    cd ${KSTARS_EMERGE_DIR}/Applications/KDE
    macdeployqt KStars.app -executable=${KSTARS_APP}/Contents/MacOS/kioslave
    
   	#Setting up some short paths
    UNCOMPRESSED_DMG=${KSTARS_EMERGE_DIR}/Applications/KDE/KStarsUncompressed.dmg
    
	#Create and attach DMG
    hdiutil create -srcfolder ${KSTARS_APP}/../ -size 190m -fs HFS+ -format UDRW -volname KStars ${UNCOMPRESSED_DMG}
    hdiutil attach ${UNCOMPRESSED_DMG}
    
    # Obtain device information
	DEVS=$(hdiutil attach ${UNCOMPRESSED_DMG} | cut -f 1)
	DEV=$(echo $DEVS | cut -f 1 -d ' ')
	VOLUME=$(mount |grep ${DEV} | cut -f 3 -d ' ')
	
	# copy in and set volume icon
	cp ${DIR}/DMGIcon.icns ${VOLUME}/DMGIcon.icns
	mv ${VOLUME}/DMGIcon.icns ${VOLUME}/.VolumeIcon.icns
	SetFile -c icnC ${VOLUME}/.VolumeIcon.icns
	SetFile -a C ${VOLUME}

	# copy in background image
	mkdir -p ${VOLUME}/Pictures
	cp ${KSTARS_EMERGE_DIR}/share/kstars/kstars.png ${VOLUME}/Pictures/background.jpg
	
	# symlink Applications folder, arrange icons, set background image, set folder attributes, hide pictures folder
	ln -s /Applications/ ${VOLUME}/Applications
	set_bundle_display_options ${VOLUME}
	mv ${VOLUME}/Pictures ${VOLUME}/.Pictures
 
	# Unmount the disk image
	hdiutil detach $DEV
 
	# Convert the disk image to read-only
	hdiutil convert ${UNCOMPRESSED_DMG} -format UDBZ -o ${KSTARS_EMERGE_DIR}/Applications/KDE/KStars.dmg
	
	# Remove the Read Write DMG
	rm ${UNCOMPRESSED_DMG}
	
elif [ -n "${BUILD_KSTARS_CMAKE}" ]
then
	announce "Copying K Stars Application To C Make Directory"
	mkdir ${KSTARS_CMAKE_DIR}/Applications
	mkdir ${KSTARS_CMAKE_DIR}/Applications/KDE
	cp -Rf ${KSTARS_APP} ${KSTARS_CMAKE_DIR}/Applications/KDE
	if [ -n "${BUILD_XCODE}" ]
	then
		mkdir ${KSTARS_APP}/../../Release
		cp -Rf ${KSTARS_APP} ${KSTARS_APP}/../../Release/KStars.app
	fi
fi

# Finally, remove the trap
trap - EXIT
announce "Script execution complete"
