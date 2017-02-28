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


export INDI_ROOT=~/IndiRoot
export INDI_DIR=${INDI_ROOT}/indi-stuff
export CRAFT_DIR=${INDI_ROOT}/kstars-craft
export KSTARS_XCODE_DIR=${INDI_ROOT}/kstars-xcode
export KSTARS_CMAKE_DIR=${INDI_ROOT}/kstars-cmake
export GSC_DIR=${INDI_ROOT}/gsc

if [ -z "${FORCE_BREW_QT}" ]
then
	#NOTE: The user of the Script needs to edit this path to match the system.
	export QT5_DIR=~/Qt/5.7/clang_64
else
	export Qt5_DIR=$(brew --prefix qt5)
fi	

export PATH=$(brew --prefix gettext)/bin:${QT5_DIR}/bin:$PATH
export PATH=$(brew --prefix bison)/bin:$PATH
export CMAKE_LIBRARY_PATH=$(brew --prefix gettext)/lib
export CMAKE_INCLUDE_PATH=$(brew --prefix gettext)/include

export QT5DBUS_DIR=$QT5_DIR
export QT5TEST_DIR=$QT5_DIR
export QT5NETWORK_DIR=$QT5_DIR

export GSC_TARGET_DIR=${CRAFT_DIR}/Applications/KDE/kstars.app/Contents/MacOS/gsc
export QMAKE_MACOSX_DEPLOYMENT_TARGET=10.10
export MACOSX_DEPLOYMENT_TARGET=10.10

echo "INDI_ROOT          is [${INDI_ROOT}]"
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