#!/bin/bash

# This file will make it easier to use the scripts and do stuff on command line
#
function statusBanner
{
    echo ""
    echo "############################################################"
    echo "# $*"
    echo "############################################################"
}


export INDI_ROOT=~/IndiRoot
export INDI_DIR=${INDI_ROOT}/indi-stuff
export KSTARS_EMERGE_DIR=${INDI_ROOT}/kstars-emerge
export KSTARS_CMAKE_DIR=${INDI_ROOT}/kstars-cmake
export USING_KSTARS_DIR=""
export GSC_DIR=${INDI_ROOT}/gsc
export MACOSX_DEPLOYMENT_TARGET=10.10

if [ -d ~/Qt/5.7/clang_64/bin ]
then
	export Qt5_DIR=~/Qt/5.7/clang_64/bin
elif [ -d ~/Qt5.7.0/5.7/clang_64/bin ]
then
	export Qt5_DIR=~/Qt5.7.0/5.7/clang_64/bin
fi

export PATH=$(brew --prefix gettext)/bin:$PATH
export CMAKE_LIBRARY_PATH=$(brew --prefix gettext)/lib
export CMAKE_INCLUDE_PATH=$(brew --prefix gettext)/include export PATH=$(brew --prefix bison)/bin:$PATH
export PATH=$Qt5_DIR:$PATH
export Qt5DBus_DIR=$Qt5_DIR
export Qt5Test_DIR=$Qt5_DIR
export Qt5Network_DIR=$Qt5_DIR
export GSC_TARGET_DIR=${KSTARS_EMERGE_DIR}/Applications/KDE/kstars.app/Contents/MacOS/gsc

echo "INDI_ROOT          is [${INDI_ROOT}]"
echo "INDI_DIR           is [${INDI_DIR}]"
echo "KSTARS_EMERGE_DIR  is [${KSTARS_EMERGE_DIR}]"
echo "KSTARS_CMAKE_DIR   is [${KSTARS_CMAKE_DIR}]"
echo "GSC_DIR            is [${GSC_DIR}]"

echo "Qt5_DIR            is [${Qt5_DIR}]"
echo "PATH               is [${PATH}]"
echo "CMAKE_LIBRARY_PATH is [${CMAKE_LIBRARY_PATH}]"
echo "CMAKE_INCLUDE_PATH is [${CMAKE_INCLUDE_PATH}]"
echo "PATH               is [${PATH}]"
echo "Qt5DBus_DIR        is [${Qt5DBus_DIR}]"
echo "Qt5Test_DIR        is [${Qt5Test_DIR}]"
echo "Qt5Network_DIR     is [${Qt5Network_DIR}]"

echo "GSC_TARGET_DIR     is [${GSC_TARGET_DIR}]"
