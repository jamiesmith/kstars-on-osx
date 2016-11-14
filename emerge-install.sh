#!/bin/bash

# This is an attempt to automate the stuff- YMMV.  Do not be surprised if you
# run in to a gsl error.

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BUILD_3RDPARTY=""
ANNOUNCE=""
INDI_ONLY=""
SKIP_BREW=""
function dieUsage
{
cat <<EOF
options:
	-3 also build third party stuff
	-a Announce stuff as you go
	-b Skip brew (only use this if you know you already have them)
	-i Just do indi build, not emerge
EOF
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

	cat << EOF >> $CMAKE

### AUTO_PATCHED
message("Adding GPhoto Driver")
if (\${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
option(WITH_GPHOTO "Install GPhoto Driver" On)

if (WITH_GPHOTO)
add_subdirectory(indi-gphoto)
endif(WITH_GPHOTO)

endif (\${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
EOF
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

	cat << EOF >> $CMAKE
### AUTO_PATCHED
find_package(GSL  REQUIRED)

if (GSL_FOUND)
	include_directories(\${GSL_INCLUDE_DIRS})
endif (GSL_FOUND)
EOF
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

while getopts "3abi" option
do
    case $option in 
		3)
			BUILD_3RDPARTY="yep"
			;;
		a)
			ANNOUNCE="yep"
			;;
		b)
			SKIP_BREW="yep"
			;;
		i)
			INDI_ONLY="yep"
			;;
		*)
			dieUsage "Unsupported opthon $option"
			;;
    esac
done
shift $((${OPTIND} - 1)) 

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

function installBrewDependencies
{
	announce "Installing brew dependencies"

	if [ ! -d ~/Qt/5.7/clang_64/bin ]
	then
		echo "Checking brew for qt5, because I didn't find it"
		time brewInstallIfNeeded qt5 --with-dbus
	else	
		echo "qt5 found in home dir"
	fi

	brewInstallIfNeeded cmake
	brewInstallIfNeeded wget
	brewInstallIfNeeded coreutils
	brewInstallIfNeeded p7zip
	brewInstallIfNeeded gettext
	brewInstallIfNeeded ninja
	brewInstallIfNeeded python3
	brewInstallIfNeeded ninja
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
	brewInstallIfNeeded cmake
	brewInstallIfNeeded eigen
	brewInstallIfNeeded astrometry-net
	brewInstallIfNeeded xplanet
	brewInstallIfNeeded gsl

	brew tap polakovic/astronomy
	brewInstall polakovic/astronomy/libnova
}

##########################################
# This is where the bulk of it starts!
#
source "${DIR}/build-env.sh"

if [ -z "$SKIP_BREW" ]
then
	installBrewDependencies
else
	announce "Skipping brew dependencies"
fi

# From here on out exit if there is a failure
#
set -e
trap scriptDied EXIT

mkdir -p ${INDI_DIR}
mkdir -p ${KSTARS_DIR}

##########################################
# Indi
announce "BUILDING LIB INDI STUFF"

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
	buildThirdParty
else
	statusBanner "Skipping third Party Build as directed"
fi

[ -n "$INDI_ONLY" ] && exitEarly "Building Indi Only"

### Let's try emerge.
announce "Running the emerge!"

if [ ! -f ~/.gitconfig -o $(grep -c kde.org ~/.gitconfig) -eq 0 ]
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

export KSTARS_DIR=${INDI_ROOT}/kstars-stuff
mkdir -p ${KSTARS_DIR}/

cd ${KSTARS_DIR}/

if [ ! -d emerge ]
then
	git clone --branch unix3 git://anongit.kde.org/emerge.git
else
	echo "Emerge already exists, checking for updates"
	cd emerge
	git pull
	cd ${KSTARS_DIR}/	
fi

mkdir -p etc
cp -f emerge/kdesettings.mac etc/kdesettings.ini
. emerge/kdeenv.sh
time emerge kstars

announce EMERGE COMPLETE

##########################################
statusBanner "Prepping some other stuff"

##########################################
statusBanner "The Data Directory"
mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data
cp -rf ${KSTARS_DIR}/share/kstars/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data/

##########################################
statusBanner "The indi drivers"
mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi
cp -f /usr/local/bin/indi* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/
cp -f /usr/local/share/indi/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/

##########################################
# statusBanner "The astrometry files"
# mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry
# cp -Rf $(brew --prefix astrometry-net)/bin ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/
# cp -Rf $(brew --prefix astrometry-net)/lib ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/
# cp -f  $(brew --prefix astrometry-net)/etc/astrometry.cfg ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/bin/

##########################################
statusBanner "Set up some xplanet pictures - this is failing..."

# cd ${INDI_ROOT}
# curl -LO https://sourceforge.net/projects/flatplanet/files/maps/1.0/maps_alien-1.0.tar.gz
# tar -xzf maps_alien-1.0.tar.gz -C "$(brew --prefix xplanet)" --strip-components=2
# rm maps_alien-1.0.tar.gz
#
# mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/xplanet/
# cp -rf $(brew --prefix xplanet)/bin ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/xplanet/
# cp -rf $(brew --prefix xplanet)/share ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/xplanet/

# ##########################################
# announce "Fixing the dir names and such"
# ${DIR}/fix-libraries.sh
#
# ##########################################
# announce "Building DMG"
# cd ${KSTARS_DIR}
# ${Qt5_DIR}/bin/macdeployqt Applications/KDE/kstars.app -dmg

# Finally, remove the trap
trap - EXIT
announce "Script execution complete"
