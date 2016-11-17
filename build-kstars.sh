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
BUILD_KSTARS_EMERGE=""
BUILDING_KSTARS=""
DRY_RUN_ONLY=""

function dieUsage
{
    # I really wish that getopt supported the long args.
    #
	echo ""
    echo $*
	echo ""

cat <<EOF
	options:
	    -3 Also build third party stuff
	    -a Announce stuff as you go
	    -c Build kstars via cmake (ONLY one of -c or -e can be used)
	    -d Dry run only (just show what you are going to do)
	    -e Build kstars via emerge
	    -i Build libindi
	    -s Skip brew (only use this if you know you already have them)
    
	To build a complete emerge you would do:
	    $0 -3aei
    
	To build a complete cmake build you would do:
	    $0 -3aci    
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

    echo '### AUTO_PATCHED' >> ${CMAKE}
    echo 'message("Adding GPhoto Driver")' >> ${CMAKE}
    echo 'if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")' >> ${CMAKE}
    echo 'option(WITH_GPHOTO "Install GPhoto Driver" On)' >> ${CMAKE}
    echo '' >> ${CMAKE}
    echo 'if (WITH_GPHOTO)' >> ${CMAKE}
    echo 'add_subdirectory(indi-gphoto)' >> ${CMAKE}
    echo 'endif(WITH_GPHOTO)' >> ${CMAKE}
    echo '' >> ${CMAKE}
    echo 'endif (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")' >> ${CMAKE}
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

function checkForQT
{
	if [ -z "$Qt5_DIR" ]
	then
		dieUsage "Cannot proceed, qt not installed - see the readme."
	fi
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
}

function buildLibIndi
{
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
        buildThirdParty
    else
        statusBanner "Skipping third Party Build as directed"
    fi
}

function emergeKstars
{
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
}

function buildKstars
{
    announce "Building k stars via c make"
    cd ${KSTARS_DIR}/

    git clone git://anongit.kde.org/kstars.git

    mkdir kstars-build
    cd kstars-build

    cmake -DCMAKE_INSTALL_PREFIX=~/usr/local ../kstars
    make
    make install
    
    # A few files seem to be missing
    #
    for path in Contents/Resources/KSTARS_APP_SRCS.icns \
        Contents/MacOS/kstars \
        Contents/Info.plist
    do
        relroot_app=${KSTARS_DIR}/Applications/KDE/kstars.app
        relroot_build=${KSTARS_DIR}/kstars-build/kstars/kstars.app
        if [ ! -f ${relroot_app}/${path} ]
        then
            echo ${relroot_app}/${path} is missing
            cp ${relroot_build}/${path}  ${relroot_app}/${path} 
        else
            echo ${relroot_app}/${path} already there            
        fi        
    done

    # This way we have to copy some stuff, too
    # I honestly don't know if we should do this or not.
    #
    # ln -s ~/usr/local/share/kstars/* ~/Library/Application\ Support/kstars/
    #
    statusBanner "The indi drivers"
    mkdir -p ${KSTARS_DIR}/kstars-build/kstars/kstars.app/Contents/MacOS/indi
    cp -f /usr/local/bin/indi*    ${KSTARS_DIR}/kstars-build/kstars/kstars.app/Contents/MacOS/indi
    cp -f /usr/local/share/indi/* ${KSTARS_DIR}/kstars-build/kstars/kstars.app/Contents/MacOS/indi
}

##########################################
# This is where the bulk of it starts!
#

# Before anything, check for QT:
#
checkForQT

while getopts "3acdeis" option
do
    case $option in
        3)
            BUILD_3RDPARTY="yep"
            ;;
        a)
            ANNOUNCE="yep"
            ;;
        c)
            BUILD_KSTARS_CMAKE="yep"
            BUILDING_KSTARS="yep"
            ;;
        d)
            DRY_RUN_ONLY="yep"
            ;;
        e)
            BUILD_KSTARS_EMERGE="yep"
            BUILDING_KSTARS="yep"
            ;;
        i)
            BUILD_INDI="yep"
            ;;
        s)
            SKIP_BREW="yep"
            ;;
        *)
            dieUsage "Unsupported option $option"
            ;;
    esac
done
shift $((${OPTIND} - 1))

if [ -n "$BUILD_KSTARS_CMAKE" ] && [ -n "$BUILD_KSTARS_EMERGE" ]
then
    dieUsage "Only one KSTARS build type allowed" 
fi

if [ -d "${KSTARS_DIR}" ]
then
    dieUsage "OK, I really need to start from scratch, please remove the ${KSTARS_DIR}"    
fi

if [ -d "${INDI_DIR}" ]
then
    dieUsage "OK, I really need to start from scratch, please remove the ${INDI_DIR}"    
fi

echo ""
echo "ANNOUNCE            = ${ANNOUNCE}"
echo "BUILDING_KSTARS     = ${BUILDING_KSTARS}"
echo "BUILD_3RDPARTY      = ${BUILD_3RDPARTY}"
echo "BUILD_INDI          = ${BUILD_INDI}"
echo "BUILD_KSTARS_CMAKE  = ${BUILD_KSTARS_CMAKE}"
echo "BUILD_KSTARS_EMERGE = ${BUILD_KSTARS_EMERGE}"
echo "SKIP_BREW           = ${SKIP_BREW}"

if [ -z "$BUILD_KSTARS_CMAKE" ] && [ -z "$BUILD_KSTARS_EMERGE" ] && [ -z "$BUILDING_KSTARS" ]
then
    DRY_RUN_ONLY="yep"
fi

[ -n "${DRY_RUN_ONLY}" ] && exitEarly "Dry Run Only"

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

if [ -n "${BUILD_INDI}" ]
then
    buildLibIndi    
else
    announce "Skipping INDI Build"
fi

if [ -n "${BUILD_KSTARS_EMERGE}" ]
then
    emergeKstars
elif [ -n "${BUILD_KSTARS_CMAKE}" ]
then
    buildKstars
else
    announce "Not building k stars"
fi

if [ -n "${BUILDING_KSTARS}" ]
then
    ##########################################
    statusBanner "Prepping some other stuff"

    ##########################################
    statusBanner "The Data Directory"
    mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data

    # Seems that emerge and cmake put these in different places
    #
    if [ -d "${KSTARS_DIR}/share/kstars" ]
    then
        typeset src_dir="$HOME/usr/local/share/kstars"
        echo "copying from $src_dir"
        cp -rf $src_dir/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data/
    elif [ -d "$HOME/usr/local/share/kstars" ]
    then
        typeset src_dir="$HOME/usr/local/share/kstars"
        echo "copying from $src_dir"
        cp -rf $src_dir/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data/
    else
        announce "Cannot find kstarts data"
    fi

    ##########################################
    statusBanner "The indi drivers"
    mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi
    cp -f /usr/local/bin/indi*    ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/
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
fi

if [ -n "${BUILD_KSTARS_EMERGE}" ]
then
    echo "no op right now"
    # ##########################################
    # announce "Building DMG"
    # cd ${KSTARS_DIR}
    # ${Qt5_DIR}/bin/macdeployqt Applications/KDE/kstars.app -dmg
fi

# Finally, remove the trap
trap - EXIT
announce "Script execution complete"
