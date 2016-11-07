#!/bin/bash

time brew install qt5 --with-dbus

brew install cmake 
brew install wget
brew install coreutils
brew install p7zip
brew install gettext
brew install ninja
brew install python3
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
brew install eigen
brew install libusb
brew install gsl
brew install xplanet

# This one is timing out - skipping for now
#
brew install astrometry-net

brew tap polakovic/astronomy
brew install polakovic/astronomy/libnova


# No indication that we need these
#
# brew tap haraldf/kf5
# brew install haraldf/kf5/kf5-kplotting
# brew install haraldf/kf5/kf5-kxmlgui
# brew link --overwrite shared-mime-info
# brew link kf5-kcoreaddons
# brew install haraldf/kf5/kf5-knewstuff
# brew install haraldf/kf5/kf5-kdoctools
# brew install haraldf/kf5/kf5-knotifications
# brew install haraldf/kf5/kf5-kcrash



export INDI_ROOT=~/IndiRoot
export INDI_DIR=${INDI_ROOT}/indi-stuff
export KSTARS_DIR=${INDI_ROOT}/kstars-stuff
export CMAKE_DIR=${INDI_ROOT}/cmake-stuff

mkdir ${INDI_DIR}
mkdir ${KSTARS_DIR}
mkdir ${CMAKE_DIR}

# Let's set up some cmame extras:
#
cd ${CMAKE_DIR}/

GET_TEXT_BIN=$(ls -td  $(brew --cellar gettext)/*/bin)
export PATH=$(brew --prefix qt5)/bin:${GET_TEXT_BIN}:$PATH

git clone https://github.com/KDE/extra-cmake-modules.git
cd extra-cmake-modules

cmake .
make
make install


##########################################
# GSL- seem to need this for the 3rdparty stuff

cd ${INDI_DIR}/

curl -L --silent -O http://heasarc.gsfc.nasa.gov/FTP/software/fitsio/c/cfitsio3380.tar.gz
tar xzf cfitsio3380.tar.gz
rm cfitsio3380.tar.gz

curl -L --silent -O http://gnu.prunk.si/gsl/gsl-2.1.tar.gz
tar xzf gsl-2.1.tar.gz
rm gsl-2.1.tar.gz
cd gsl-2.1
./configure
make install

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

export PATH=$PATH:$(brew --prefix gettext)/bin
export Qt5_DIR=$(brew --prefix qt5)
export Qt5DBus_DIR=$Qt5_DIR
export Qt5Test_DIR=$Qt5_DIR
export Qt5Network_DIR=$Qt5_DIR
# export ECM_DIR=$(brew --prefix kf5-extra-cmake-modules)/share/ECM

mkdir -p ${INDI_DIR}/build/libindi
cd ${INDI_DIR}/build/libindi

cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/libindi

make
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



##########################################
##########################################
##########################################

export PATH=$PATH:$(brew --prefix gettext)/bin
export Qt5_DIR=$(brew --prefix qt5)
export Qt5DBus_DIR=$Qt5_DIR
export Qt5Test_DIR=$Qt5_DIR
export Qt5Network_DIR=$Qt5_DIR
export ECM_DIR=$(brew --prefix kf5-extra-cmake-modules)/share/ECM



##### Moving on to kstars

export KSTARS_DIR=${INDI_ROOT}/kstars-stuff
mkdir -p ${KSTARS_DIR}/

cd ${KSTARS_DIR}/

git clone git://anongit.kde.org/kstars.git

mkdir kstars-build
cd kstars-build

cmake -DCMAKE_INSTALL_PREFIX=~/usr/local ../kstars
make
make install

ln -s ~/usr/local/share/kstars/* ~/Library/Application\ Support/kstars/


# mkdir ~/Projects/gsc
# cd ~/Projects/gsc
# wget -O bincats_GSC_1.2.tar.gz http://cdsarc.u-strasbg.fr/viz-bin/nph- Cat/tar.gz?bincats/GSC_1.2
# tar -xvzf bincats_GSC_1.2.tar.gz
# cd src
# make
# mv gsc.exe gsc
# sudo cp gsc /usr/local/bin/
# cd ..
# sudo mkdir -p /GSC/bin
# sudo cp ~/Projects/gsc/bin/regions.* /GSC/bin
# sudo cp ~/Projects/gsc/N* /GSC/
# sudo cp ~/Projects/gsc/S* /GSC/


