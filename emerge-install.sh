#!/bin/bash

# This is an attempt to automate the stuff- YMMV.  Do not be surprised if you
# run in to a gsl error.

time brew install qt5 --with-dbus

brew install cmake
brew install wget
brew install coreutils
brew install p7zip
brew install gettext
brew install ninja
brew install python3
brew install ninja
brew install bison
brew install boost
brew install shared-mime-info

# These for gphoto
#
brew install dcraw
brew install gphoto2
brew install libraw


brew tap homebrew/science
brew install pkgconfig
brew install cfitsio
brew install cmake
brew install eigen
brew install astrometry-net
brew install xplanet


export INDI_ROOT=~/IndiRoot
export INDI_DIR=${INDI_ROOT}/indi-stuff
export KSTARS_DIR=${INDI_ROOT}/kstars-stuff

mkdir ${INDI_DIR}
mkdir ${KSTARS_DIR}

##########################################
# Indi
cd ${INDI_DIR}/

git clone https://github.com/indilib/indi.git
cd indi/libindi

awk '1;/set \(indiclient_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' CMakeLists.txt > CMakeLists.zzz
awk '1;/set \(indiclient_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' CMakeLists.zzz > CMakeLists.txt

awk '1;/set \(indiclientqt_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' CMakeLists.txt > CMakeLists.zzz
awk '1;/set \(indiclientqt_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' CMakeLists.zzz > CMakeLists.txt

rm CMakeLists.zzz

sed -i '' 's#target_link_libraries(AlignmentDriver ${GSL_LIBRARIES})#target_link_libraries(AlignmentDriver -L/usr/local/lib ${GSL_LIBRARIES})#' libs/indibase/alignment/CMakeLists.txt 

export Qt5_DIR=~/Qt/5.7/clang_64/bin
export PATH=$(brew --prefix gettext)/bin:$PATH
export CMAKE_LIBRARY_PATH=$(brew --prefix gettext)/lib
export CMAKE_INCLUDE_PATH=$(brew --prefix gettext)/include export PATH=$(brew --prefix bison)/bin:$PATH
export PATH=$Qt5_DIR:$PATH
export Qt5DBus_DIR=$Qt5_DIR
export Qt5Test_DIR=$Qt5_DIR
export Qt5Network_DIR=$Qt5_DIR

mkdir -p ${INDI_DIR}/build/libindi
cd ${INDI_DIR}/build/libindi

cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/libindi

make
# This might need a sudo.
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
EOF
fi

mkdir -p build/3rdparty
cd build/3rdparty

cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty

make
make install

### NOTE : I haven't done the emerge stuff on my machine yet, so this part is not automated.