#!/bin/bash

# This file will make it easier to use the scripts and do stuff on command line
#

function statusBanner
{
    echo ""
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "~ $*"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo ""
}

function announce
{
    [ -n "$ANNOUNCE" ] && say -v Daniel "$*"
    statusBanner "$*"
}

export DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export ASTRO_ROOT=~/AstroRoot
export INDI_DIR=${ASTRO_ROOT}/indi-stuff
export CRAFT_DIR=${ASTRO_ROOT}/kstars-craft
export KSTARS_XCODE_DIR=${ASTRO_ROOT}/kstars-xcode
export KSTARS_CMAKE_DIR=${ASTRO_ROOT}/kstars-cmake
export GSC_DIR=${ASTRO_ROOT}/gsc

if [ -z "${FORCE_BREW_QT}" ]
then
	#NOTE: The user of the Script needs to edit this path to match the system.
	export QT5_DIR=~/Qt/5.9.2/clang_64
else
	export QT5_DIR=$(brew --prefix qt)
fi	

export PATH=$(brew --prefix gettext)/bin:${QT5_DIR}/bin:$PATH
export PATH=$(brew --prefix bison)/bin:$PATH
export CMAKE_LIBRARY_PATH=$(brew --prefix gettext)/lib
export CMAKE_INCLUDE_PATH=$(brew --prefix gettext)/include

export QT5DBUS_DIR=$QT5_DIR
export QT5TEST_DIR=$QT5_DIR
export QT5NETWORK_DIR=$QT5_DIR

export GSC_TARGET_DIR=${CRAFT_DIR}/Applications/KDE/kstars.app/Contents/MacOS/gsc
export QMAKE_MACOSX_DEPLOYMENT_TARGET=10.11
export MACOSX_DEPLOYMENT_TARGET=10.11

# The repos are listed here just in case you want to build from a fork
export KSTARS_REPO=git://anongit.kde.org/kstars.git
export LIBINDI_REPO=https://github.com/indilib/indi.git
export CRAFT_REPO=git://anongit.kde.org/craft.git

echo "DIR          		 is [${DIR}]"
echo "ASTRO_ROOT          is [${ASTRO_ROOT}]"
echo "INDI_DIR           is [${INDI_DIR}]"
echo "CRAFT_DIR  	     is [${CRAFT_DIR}]"

echo "KSTARS_CMAKE_DIR   is [${KSTARS_CMAKE_DIR}]"
echo "KSTARS_XCODE_DIR   is [${KSTARS_XCODE_DIR}]"
echo "GSC_DIR            is [${GSC_DIR}]"

echo "QT5_DIR            is [${QT5_DIR}]"
echo "PATH               is [${PATH}]"

echo "CMAKE_LIBRARY_PATH is [${CMAKE_LIBRARY_PATH}]"
echo "CMAKE_INCLUDE_PATH is [${CMAKE_INCLUDE_PATH}]"

echo "PATH               is [${PATH}]"

echo "QT5DBUS_DIR        is [${QT5DBUS_DIR}]"
echo "QT5TEST_DIR        is [${QT5TEST_DIR}]"
echo "QT5NETWORK_DIR     is [${QT5NETWORK_DIR}]"

echo "GSC_TARGET_DIR     is [${GSC_TARGET_DIR}]"
echo "OSX Deployment target [${QMAKE_MACOSX_DEPLOYMENT_TARGET}]"
