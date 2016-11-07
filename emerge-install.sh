#!/bin/bash

# This is an attempt to automate the stuff- YMMV.  Do not be surprised if you
# run in to a gsl error.

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

echo $DIR

source "${DIR}/build-env.sh"

function statusBanner
{
    echo ""
    echo "############################################################"
    echo "# $*"
    echo "############################################################"
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

time brewInstallIfNeeded qt5 --with-dbus

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
# brewInstallIfNeeded gsl


# From here on out exit if there is a failure
set -e

mkdir -p ${INDI_DIR}
mkdir -p ${KSTARS_DIR}

##########################################                                                                                                                                
# GSL- seem to need this for the 3rdparty stuff

# statusBanner "BUILDING GSL STUFF"
#
# cd ${INDI_DIR}/
#
# if [ ! -f gsl-2.1 ]
# then
#     curl -L --silent -O http://gnu.prunk.si/gsl/gsl-2.1.tar.gz
#     tar xzf gsl-2.1.tar.gz
#     rm gsl-2.1.tar.gz
# else
#     statusBanner "GSL Already downloaded"
# fi
#
# cd gsl-2.1
#
# [ ! -f Makefile ] && ./configure
#
# statusBanner "make gsl"
# make
#
# statusBanner "make install gsl"
# make install

##########################################
# Indi
statusBanner "BUILDING LIBINDI STUFF"

cd ${INDI_DIR}/

if [ ! -d indi ]
then
    statusBanner "Cloning and patching indilib"

    git clone https://github.com/indilib/indi.git
    cd indi/libindi

    awk '1;/set \(indiclient_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' CMakeLists.txt > CMakeLists.zzz
    awk '1;/set \(indiclient_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' CMakeLists.zzz > CMakeLists.txt

    awk '1;/set \(indiclientqt_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' CMakeLists.txt > CMakeLists.zzz
    awk '1;/set \(indiclientqt_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' CMakeLists.zzz > CMakeLists.txt

    rm CMakeLists.zzz
    ALIGNMENT_CMAKE=${INDI_DIR}/indi/libindi/libs/indibase/alignment/CMakeLists.txt
    sed -i '' 's#target_link_libraries(AlignmentDriver ${GSL_LIBRARIES})#target_link_libraries(AlignmentDriver -L/usr/local/lib ${GSL_LIBRARIES})#' $ALIGNMENT_CMAKE
else
    statusBanner "indilib already cloned and patched"    
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


#### Third Party Stuff
# Let's add GPHOTO
#
cd ${INDI_DIR}
THIRD_PARTY_CMAKE=${INDI_DIR}/indi/3rdparty/CMakeLists.txt

if [ $(grep -c Darwin ${THIRD_PARTY_CMAKE}) -eq 0 ]
then
    echo "Adding GPHOTO to the 3rd party stuff"
    
cat << EOF >> $THIRD_PARTY_CMAKE

message("Adding GPhoto Driver")
if (\${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
option(WITH_GPHOTO "Install GPhoto Driver" On)

if (WITH_GPHOTO)
add_subdirectory(indi-gphoto)
endif(WITH_GPHOTO)

endif (\${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

#
# find_package(GSL REQUIRED)
# if (GSL_FOUND)
#    include_directories(${GSL_INCLUDE_DIRS})
#    set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS GSL_FOUND)
#    set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} ${CMAKE_GSL_CXX_FLAGS})

# get_property(dirs DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)
# foreach(dir ${dirs})
#   message(STATUS "JRS dir='${dir}'")
# endforeach()

# endif (GSL_FOUND)


# 3rdparty/indi-eqmod/ ?

EOF
fi

mkdir -p ${INDI_DIR}/build/3rdparty
cd ${INDI_DIR}/build/3rdparty

statusBanner "Configure indi third-party"
cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty

statusBanner "make indi third-party"
make

statusBanner "make install indi third-party"
make install

### NOTE : I haven't done the emerge stuff on my machine yet, so this part is not automated.

### Let's try emerge.
statusBanner "EMERGING!"


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

git clone --branch unix3 git://anongit.kde.org/emerge.git
mkdir -p etc
cp emerge/kdesettings.mac etc/kdesettings.ini


. emerge/kdeenv.sh
emerge kstars

##########################################
statusBanner "Prepping some other stuff"

statusBanner "The Data Directory"
mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data
cp -r ${KSTARS_DIR}/share/kstars/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data/

statusBanner "The indi drivers"
mkdir ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi
cp /usr/local/bin/indi* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/
cp /usr/local/share/indi/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/

statusBanner "The astrometry files"
mkdir ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry 
cp -r $(brew --prefix astrometry-net)/bin ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/
cp -r $(brew --prefix astrometry-net)/lib ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/
cp $(brew --prefix astrometry-net)/etc/astrometry.cfg ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/bin/
