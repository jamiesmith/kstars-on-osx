#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}/build-env.sh"

ANNOUNCE=""
INDI_ONLY=""
SKIP_BREW=""
BUILD_INDI=""
KSTARS_BUILD_TYPE=""
GENERATE_DMG=""
FORCE_RUN=""
KSTARS_APP=""
FORCE_BREW_QT=""

#This will print out how to use the script
function usage
{

cat <<EOF
	options:
	    -a Announce stuff as you go
	    -c Build kstars via cmake (ONLY one of -c , -x, or -e can be used)
	    -d Generate dmg
	    -e Build kstars via craft (ONLY one of -c , -x, or -e can be used)
	    -f Force build even if there are script updates
	    -i Build libindi
		-q Use the brew-installed qt
	    -s Skip brew (only use this if you know you already have them)
	    -x Build kstars via cmake with xcode (ONLY one of -c , -x, or -e can be used)
    
	To build a complete craft you would do:
	    $0 -aeid
    
	To build a complete cmake build you would do:
	    $0 -acid
	    
	To build a complete cmake build with an xcode project you would do:
	    $0 -axid
EOF
}

#This function prints the usage information if the user enters an invalid option or no option at all and quits the program 
	function dieUsage
	{
		echo ""
		echo $*
		echo ""
		usage
		exit 9
	}

#These functions are involved in quitting the script
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
	
	function scriptDied
	{
    	announce "Something failed"
	}

#This function processes the user's options for running the script
	function processOptions
	{
		while getopts "acdeiqsx" option
		do
			case $option in
				a)
					ANNOUNCE="Yep"
					;;
				c)
					KSTARS_BUILD_TYPE="CMAKE"
					;;
				d)
					GENERATE_DMG="Yep"
					;;
				e)
					KSTARS_BUILD_TYPE="CRAFT"
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
		echo "BUILD_INDI          = ${BUILD_INDI:-Nope}"
		echo "KSTARS_BUILD_TYPE  = ${KSTARS_BUILD_TYPE:-None}"
		echo "GENERATE_DMG  	= ${GENERATE_DMG:-Nope}"
		echo "SKIP_BREW           = ${SKIP_BREW:-Nope}"
	}

#This function installs a program with homebrew if it is not installed, otherwise it moves on.
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

#This function checks to see that all connections are available before starting the script
#That could save time if one of the repositories is not available and it would crash later
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

#This checks to see if QT is installed before starting.
	function checkForQT
	{
		if [ -z "${FORCE_BREW_QT}" ]
		then
			if [ -n "$QT5_DIR" ] 
			then
				if [ ! -d "$QT5_DIR" ]
				then
					dieUsage "Please check your build-env.sh for the QT5 variable.  QT5 cannot be found.  Either QT is not installed or the wrong directory is selected.  You can also use the homebrew QT.  Please see the readme file."
				fi
			else
				dieUsage "Please check your build-env.sh for the QT5 variable.  It is blank.  You need to either specify it or use the homebrew QT.  Please see the readme file."
			fi
		fi
	}

#This checks to see that this script is up to date.  If it is not, you can use the -f option to force it to run.
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

#This installs the kde programs if it is doing the XCode or Cmake version of the build
#It gets the files from homebrew.  It can patch them to use the system QT or just use brewed QT.
	function installPatchedKf5Stuff
	{

		if [ -z "${FORCE_BREW_QT}" ]
		then
			# Cleanup steps:
			#     brew uninstall `brew list -1 | grep '^kf5-'`
			#     rm -rf ~/Library/Caches/Homebrew/kf5-*
			#     brew untap KDE-mac/kde
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

		brew tap KDE-mac/kde

		cd $(brew --repo KDE-mac/kde)


		if [ -z "${FORCE_BREW_QT}" ]
		then
			echo $SUBSTITUTE
			count=$(cat *.rb | grep -c CMAKE_PREFIX_PATH)
			if [ $count -le 1 ]
			then
				echo "Hacking kf5 Files"
				sed -i '' "s@*args@\"-DCMAKE_PREFIX_PATH=${SUBSTITUTE}\", *args@g" *.rb
				sed -i '' '/depends_on "qt"/,/^/d' *.rb
			else
				echo "kf5 Files already hacked, er, patched, skipping"
			fi
		else
			brewInstallIfNeeded qt
		fi

		brew link --force gettext
		mkdir -p /usr/local/lib/libexec
	
		brewInstallIfNeeded KDE-mac/kde/kf5-kwallet
		brewInstallIfNeeded KDE-mac/kde/kf5-kcoreaddons
		brew link --overwrite kf5-kcoreaddons
		brewInstallIfNeeded KDE-mac/kde/kf5-kcrash
		brewInstallIfNeeded KDE-mac/kde/kf5-knotifyconfig
		brewInstallIfNeeded KDE-mac/kde/kf5-knotifications
		brewInstallIfNeeded KDE-mac/kde/kf5-kplotting

		brewInstallIfNeeded KDE-mac/kde/kf5-kxmlgui
		brewInstallIfNeeded KDE-mac/kde/kf5-kdoctools
		brewInstallIfNeeded KDE-mac/kde/kf5-knewstuff
		brewInstallIfNeeded KDE-mac/kde/kf5-kded
	
		cd - > /dev/null
	}

#This installs dependencies needed for KStars and INDI with homebrew.
#These files are needed regardless of the build type.
#This function does not include the kde programs that are handled above.
	function installBrewDependencies
	{
		announce "updating homebrew"
		brew upgrade
		
		announce "Installing xcode command line tools"
		xcode-select --install

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
		/usr/local/bin/pip2 install pyfits
		brewInstallIfNeeded libftdi
		brewInstallIfNeeded gpsd
	
		brewInstallIfNeeded dbus
		
		#These are needed for Translations
		brewInstallIfNeeded gpg
		ln -sf /usr/local/bin/gpg /usr/local/bin/gpg2
		brewInstallIfNeeded ruby

		brewInstallIfNeeded jamiesmith/astronomy/libnova
		brewInstallIfNeeded jamiesmith/astronomy/gsc
		
		gem install logger-colors
		
		announce "Attempting to install cpan and URI for kdoctools."
			brewInstallIfNeeded cpanminus
			cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
			/usr/local/bin/cpanm URI
	
		# Only do this if we are doing a cmake build
		#
		if [ "$KSTARS_BUILD_TYPE" == "CMAKE" ] || [ "$KSTARS_BUILD_TYPE" == "XCODE" ]
		then
			installPatchedKf5Stuff
		fi
	}

#This builds the INDI 3rd Party Drivers
	function buildThirdParty
	{
		 ## Build 3rd party
		mkdir -p ${INDI_DIR}/build/qsi
		cd ${INDI_DIR}/build/qsi
		cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty/libqsi
		make
		make install
	 
	   # mkdir -p ${INDI_DIR}/build/qhy
	   # cd ${INDI_DIR}/build/qhy
	   # cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty/libqhy
	   # make
	   # make install
	 
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

#This builds and installs libindi and starts the 3rd party build
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

		announce "Building Third Party Drivers"
		buildThirdParty
	}

#This builds KStars using Craft
	function craftKstars
	{
		mkdir -p ${CRAFT_DIR}
		cd ${CRAFT_DIR}/
		
		if [ ! -d oxygen ]
		then
			git clone https://github.com/KDE/oxygen.git
		fi
	
		if [ ! -d craft ]
		then
			statusBanner "Cloning craft"
			wget https://raw.githubusercontent.com/KDE/craft/master/setup/CraftBootstrap.py -O setup.py && python3.6 setup.py --prefix ${CRAFT_DIR}

			#This is the old way of doing it.  This method works, so you can go back if there is a problem
			#git clone ${CRAFT_REPO}	
			#cd craft
			#git reset --hard de8e9a79fde9bede703da3756fe641ffefc659f7
			#cd ..	
		else
			statusBanner "Updating Craft"
			cd craft
			git pull
			cd ..
		fi

		#These are related to the old way stated above.
		#mkdir -p etc
		#cp -f craft/kdesettings.mac etc/kdesettings.ini
		#source craft/kdeenv.sh
		
		statusBanner "Copying Craft Settings"
		cp ${DIR}/CraftSettings.ini ${CRAFT_DIR}/etc/
		cd ${CRAFT_DIR}/craft
		source craftenv.sh
		
		statusBanner "Crafting icons"
		craft breeze-icons
		statusBanner "Crafting KStars"
		craft -vvv -i kstars
		
		cp -f  ${CRAFT_DIR}/oxygen/sounds/*.ogg ${CRAFT_DIR}/share/sounds/
	
		announce "CRAFT COMPLETE"
	}

#This builds KStars for the XCode or Cmake build.
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

		if [ "$KSTARS_BUILD_TYPE" == "XCODE" ]
		then
			cmake -DCMAKE_INSTALL_PREFIX=${KSTARS_XCODE_DIR} -G Xcode ../kstars
			xcodebuild -target fetch-translations build
			xcodebuild -project kstars.xcodeproj -alltargets -configuration Debug
			xcodebuild install
		else
			cmake -DCMAKE_INSTALL_PREFIX=${KSTARS_CMAKE_DIR} ../kstars
			make fetch-translations
			make
			make install
		fi
   
	}

#This function handles KStars after it is built.
#It copies in needed programs and files and prepares them for future steps.
	function postProcessKstars
	{
		##########################################
		statusBanner "Post-processing KStars Build"
		echo "KSTARS_APP=${KSTARS_APP}"
		##########################################
		statusBanner "Editing info.plist"
		plutil -replace CFBundleName -string KStars ${KSTARS_APP}/Contents/info.plist
		plutil -replace CFBundleVersion -string 2.8 ${KSTARS_APP}/Contents/info.plist
		plutil -replace CFBundleLongVersionString -string 2.8 ${KSTARS_APP}/Contents/info.plist
		plutil -replace CFBundleShortVersionString -string 2.8 ${KSTARS_APP}/Contents/info.plist
		plutil -replace NSHumanReadableCopyright -string "© 2001 - 2017, The KStars Team, Freely Released under GNU GPL V2" ${KSTARS_APP}/Contents/info.plist
		##########################################
		statusBanner "The Data Directory and Translations Directory"
		appDataFolder=${KSTARS_APP}/Contents/Resources/data
		appTranslationsFolder=${KSTARS_APP}/Contents/Resources/locale
		
		echo mkdir -p $appDataFolder
		mkdir -p $appDataFolder
		echo mkdir -p $appTranslationsFolder
		mkdir -p $appTranslationsFolder
	
		# Craft and cmake now put them in the same directory, but if it is the Xcode version, it is a subdirectory.
		#
		if [ "$KSTARS_BUILD_TYPE" == "CMAKE" ] && [ -d "${KSTARS_CMAKE_DIR}/share/kstars" ]
		then
			typeset src_dir="${KSTARS_CMAKE_DIR}/share/"
			echo "copying from $src_dir and homebrew share"
			cp -rf $src_dir/kstars/* $appDataFolder/
			cp -rf /usr/local/share/locale/* $appTranslationsFolder/
			cp -rf $src_dir/locale/* $appTranslationsFolder/
		elif [ "$KSTARS_BUILD_TYPE" == "CRAFT" ] && [ -d "${CRAFT_DIR}/share/kstars" ]
		then
			typeset src_dir="${CRAFT_DIR}/share/"
			echo "copying from $src_dir"
			cp -rf $src_dir/kstars/* $appDataFolder/
			cp -rf $src_dir/locale/* $appTranslationsFolder/
			statusBanner "NOTE: For now Craft cannot build translations for Kstars.  Trying to copy from the CMAKE build instead."
			cp -rf ${KSTARS_CMAKE_DIR}/share/locale/* $appTranslationsFolder/  #This is needed until we can get craft to build the kstars translations.
		elif [ "$KSTARS_BUILD_TYPE" == "XCODE" ] && [ -d "${KSTARS_XCODE_DIR}/kstars/kstars/data" ]
		then
			echo "copying from XCode folders and homebrew share"
			cp -rf ${KSTARS_XCODE_DIR}/kstars/kstars/data/* $appDataFolder/
			cp -rf /usr/local/share/locale/* $appTranslationsFolder/
			cp -rf ${KSTARS_XCODE_DIR}/kstars-build/locale/* $appTranslationsFolder/
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
			
			mkdir -p ${KSTARS_APP}/Contents/MacOS/netpbm
			cp -Rf $(brew --prefix netpbm)/bin ${KSTARS_APP}/Contents/MacOS/netpbm/
			chmod +w ${KSTARS_APP}/Contents/MacOS/netpbm/bin/*
			
			mkdir -p ${KSTARS_APP}/Contents/MacOS/python/bin
			cp -f $(brew --prefix python)/bin/python2 ${KSTARS_APP}/Contents/MacOS/python/bin/python
			mkdir -p ${KSTARS_APP}/Contents/MacOS/python/bin/site-packages
			cp -RLf /usr/local/lib/python2.7/site-packages/numpy ${KSTARS_APP}/Contents/MacOS/python/bin/site-packages/
			cp -RLf /usr/local/lib/python2.7/site-packages/pyfits ${KSTARS_APP}/Contents/MacOS/python/bin/site-packages/
			chmod -R +w ${KSTARS_APP}/Contents/MacOS/python
		fi
		##########################################
		statusBanner "Set up some xplanet pictures..."

		tar -xzf ${DIR}/maps_alien-1.0.tar -C "$(brew --prefix xplanet)" --strip-components=2
		xplanet_dir=${KSTARS_APP}/Contents/MacOS/xplanet/

		mkdir -p ${xplanet_dir}
		cp -rf $(brew --prefix xplanet)/bin ${xplanet_dir}
		chmod +w ${xplanet_dir}/bin/xplanet
		cp -rf $(brew --prefix xplanet)/share ${xplanet_dir}
	
		statusBanner "Copying GPhoto Plugins"
		GPHOTO_VERSION=$(pkg-config --modversion libgphoto2)
		PORT_VERSION=$(pkg-config --modversion libgphoto2_port)
		mkdir -p ${KSTARS_APP}/Contents/PlugIns/libgphoto2_port
		mkdir -p ${KSTARS_APP}/Contents/PlugIns/libgphoto2
		cp -rf $(brew --prefix libgphoto2)/lib/libgphoto2_port/${PORT_VERSION}/* ${KSTARS_APP}/Contents/PlugIns/libgphoto2_port/
		cp -rf $(brew --prefix libgphoto2)/lib/libgphoto2/${GPHOTO_VERSION}/* ${KSTARS_APP}/Contents/PlugIns/libgphoto2/
	
		#statusBanner "Copying qhy firmware"
		#cp -rf /usr/local/lib/qhy ${KSTARS_APP}/Contents/PlugIns/	
	
		statusBanner "Copying dbus programs and files."
		cp -f $(brew --prefix dbus)/bin/dbus-daemon ${KSTARS_APP}/Contents/MacOS/
		chmod +w ${KSTARS_APP}/Contents/MacOS/dbus-daemon
		cp -f $(brew --prefix dbus)/bin/dbus-send ${KSTARS_APP}/Contents/MacOS/
		chmod +w ${KSTARS_APP}/Contents/MacOS/dbus-send
		mkdir -p ${KSTARS_APP}/Contents/PlugIns/dbus
		cp -f $(brew --prefix dbus)/share/dbus-1/session.conf ${KSTARS_APP}/Contents/PlugIns/dbus/kstars.conf
		cp -f ${DIR}/org.freedesktop.dbus-kstars.plist ${KSTARS_APP}/Contents/PlugIns/dbus/
		
		statusBanner "Copying phonon backend and vlc plugins"
		tar -xzf ${DIR}/backend.zip -C ${KSTARS_APP}/Contents/PlugIns/
		tar -xzf ${DIR}/vlc.zip -C ${KSTARS_APP}/Contents/PlugIns/
	
		if [ "$KSTARS_BUILD_TYPE" == "CRAFT" ]
		then
			statusBanner "Copying k i o slave."
			#I am not sure why this is needed, but it doesn't seem to be able to access KIOSlave otherwise.
			#Do we need kio_http_cache_cleaner??  or any others?
			cp -f ${CRAFT_DIR}/lib/libexec/kf5/kioslave ${KSTARS_APP}/Contents/MacOS/

			statusBanner "Copying plugins"
			cp -rf ${CRAFT_DIR}/lib/plugins/* ${KSTARS_APP}/Contents/PlugIns/
			
			statusBanner "Copying Notifications."
			cp -rf ${CRAFT_DIR}/share/knotifications5 ${KSTARS_APP}/Contents/Resources/
			
			statusBanner "Copying Sounds."
			cp -rf ${CRAFT_DIR}/share/sounds ${KSTARS_APP}/Contents/Resources/
		
			#statusBanner "Copying icontheme"
			#cp -f ${CRAFT_DIR}/share/icons/breeze/breeze-icons.rcc ${KSTARS_APP}/Contents/Resources/icontheme.rcc

		elif [ "$KSTARS_BUILD_TYPE" == "CMAKE" ] || [ "$KSTARS_BUILD_TYPE" == "XCODE" ]
		then
			statusBanner "Copying k i o slave."
			#Do we need kio_http_cache_cleaner??  or any others?
			#This hack is needed because for some reason on my system klauncher cannot access kioslave even in the app directory.
			cp -f /usr/local/lib/libexec/kf5/kioslave /usr/local/opt/kf5-kinit/lib/libexec/kf5/kioslave
			cp -f /usr/local/lib/libexec/kf5/kioslave ${KSTARS_APP}/Contents/MacOS/
		
			statusBanner "Copying plugins"
			cp -rf /usr/local/lib/plugins/* ${KSTARS_APP}/Contents/PlugIns/
			
			statusBanner "Copying Frameworks for VLC/Phonon."
			tar -xzf ${DIR}/FrameworksForVLC.zip -C ${KSTARS_APP}/Contents/
			
			statusBanner "Copying Notifications."
			cp -rf ${KSTARS_CMAKE_DIR}/share/knotifications5 ${KSTARS_APP}/Contents/Resources/
			
			statusBanner "Copying Sounds."
			cp -rf ${KSTARS_CMAKE_DIR}/share/sounds ${KSTARS_APP}/Contents/Resources/
		
		else
			announce "Plugins and K I O Slave ERROR"
		fi
		
		#This will allow otool to be run on them
		statusBanner "Preparing plugins for otool"
		chmod -R +w ${KSTARS_APP}/Contents/MacOS/kioslave
		chmod -R +w ${KSTARS_APP}/Contents/PlugIns/
		
	}


########################################################################################
# This is where the main part of the script starts!
#

# Before anything, check for QT and to see if the remote servers are accessible
	checkForQT
	checkForConnections

#Process the command line options to determine what to do.
	processOptions $@
	
#Check to see that this script is up to date.  If you want it to run anyway, use the -f option.
	checkUpToDate
	
#Check first that the user has entered build options, if not, print the list of options and quit.
	if [ -z "$KSTARS_BUILD_TYPE" ] && [ -z "$BUILD_INDI" ]
	then
		dieUsage "Please either select to build indi and/or KStars"
	fi
	
#Announce the script is starting and what will be done.
	if [ -n "$KSTARS_BUILD_TYPE" ] && [ -n "$BUILD_INDI" ]
	then
		announce "Starting script, building INDI and KStars with $KSTARS_BUILD_TYPE"
	elif [ -z "$KSTARS_BUILD_TYPE" ] && [ -n "$BUILD_INDI" ]
	then
		announce "Starting script, building INDI only"
	elif [ -n "$KSTARS_BUILD_TYPE" ] && [ -z "$BUILD_INDI" ] 
	then 
		announce "Starting script, building KStars with $KSTARS_BUILD_TYPE"
	fi
	if [ -n "$GENERATE_DMG" ]
	then
		announce "and then building a DMG"
	fi

#This will install KStars dependencies from Homebrew.  If you know they are installed, you can skip it.
	if [ -z "$SKIP_BREW" ]
	then
		installBrewDependencies
	else
		announce "Skipping brew dependencies"
	fi

#The xcode installation is very similar to the cmake installation.  But the directory is different.
#This will just set the cmake directory to be the xcode directory.
	if [ "$KSTARS_BUILD_TYPE" == "XCODE" ]
	then
		export KSTARS_CMAKE_DIR=${KSTARS_XCODE_DIR}
	fi

# From here on out exit if there is a failure
#
	set -e
	trap scriptDied EXIT

#This will build indi, including the 3rd Party drivers.
	if [ -n "${BUILD_INDI}" ]
	then
		buildINDI    
	else
		announce "Skipping INDI Build"
	fi

#This will select which type of build to do and will set the KStars app directory appropriately.
	if [ "$KSTARS_BUILD_TYPE" == "CRAFT" ]
	then
		KSTARS_APP="${CRAFT_DIR}/Applications/KDE/KStars.app"
		rm -rf ${KSTARS_APP}
		craftKstars
	elif [ "$KSTARS_BUILD_TYPE" == "XCODE" ]
	then
		KSTARS_APP="${KSTARS_XCODE_DIR}/kstars-build/kstars/Debug/KStars.app"
		rm -rf ${KSTARS_APP}
		buildKstars
	elif [ "$KSTARS_BUILD_TYPE" == "CMAKE" ]
	then
		KSTARS_APP="${KSTARS_CMAKE_DIR}/kstars-build/kstars/KStars.app"
		rm -rf ${KSTARS_APP}
		buildKstars
	else
		announce "Not building k stars"
	fi

#If KStars is being built of any type, postprocess it.
	if [ -n "$KSTARS_BUILD_TYPE" ]
	then
		postProcessKstars
	fi

#For the xcode build, this will copy the code to the release folder in addition to the debug folder.
	if [ "$KSTARS_BUILD_TYPE" == "XCODE" ]
	then
		statusBanner "Copying to XCode Release Folder"
		mkdir -p ${KSTARS_APP}/../../Release
		rm -rf ${KSTARS_APP}/../../Release/KStars.app
		cp -Rf ${KSTARS_APP} ${KSTARS_APP}/../../Release/KStars.app
	fi

#This will package everything up into the app and then make a dmg.
	if [ -n "$GENERATE_DMG" ]
	then
		source ${DIR}/generate-dmg.sh
	fi

# Finally, remove the trap
	trap - EXIT
	announce "Script execution complete"
