#!/bin/bash

function brewInstall
{
	brew ls $1> /dev/null
	if [ $? -ne 0 ]
	then
		brew install $*
	else
		echo "brew : $* is already installed"
	fi
}

brew install qt5 --with-dbus

brew tap homebrew/science
brewInstall cmake
brewInstall pkgconfig
brewInstall cfitsio
brewInstall cmake
brewInstall eigen
brewInstall gettext
brewInstall libusb
brewInstall gsl
brewInstall xplanet 
brewInstall dcraw
brewInstall gphoto2

brewInstall astrometry-net
brewInstall bison
brewInstall boost
brewInstall coreutils
brewInstall eigen
brewInstall libraw
brewInstall ninja
brewInstall p7zip
brewInstall python3
brewInstall shared-mime-info
brewInstall wget


brew tap polakovic/astronomy
brewInstall polakovic/astronomy/libnova

brew tap haraldf/kf5
brewInstall haraldf/kf5/kf5-kplotting
brewInstall haraldf/kf5/kf5-kxmlgui
brew link --overwrite kf5-kcoreaddons
brewInstall haraldf/kf5/kf5-knewstuff
brewInstall haraldf/kf5/kf5-kdoctools
brewInstall haraldf/kf5/kf5-knotifications
brewInstall haraldf/kf5/kf5-kcrash

export PATH=$PATH:$(brew --prefix gettext)/bin
export Qt5_DIR=$(brew --prefix qt5)
export Qt5DBus_DIR=$Qt5_DIR
export Qt5Test_DIR=$Qt5_DIR
export Qt5Network_DIR=$Qt5_DIR
export ECM_DIR=$(brew --prefix kf5-extra-cmake-modules)/share/ECM

export INDI_ROOT=~/IndiRoot
export INDI_DIR=${INDI_ROOT}/indi-stuff
export KSTARS_DIR=${INDI_ROOT}/kstars-stuff
export CMAKE_DIR=${INDI_ROOT}/cmake-stuff

mkdir ${INDI_DIR}
mkdir ${KSTARS_DIR}
mkdir ${CMAKE_DIR}

cd ${INDI_DIR}/

# curl -L --silent -O http://heasarc.gsfc.nasa.gov/FTP/software/fitsio/c/cfitsio3380.tar.gz
# tar xzf cfitsio3380.tar.gz
# rm cfitsio3380.tar.gz
#
# curl -L --silent -O http://gnu.prunk.si/gsl/gsl-2.1.tar.gz
# tar xzf gsl-2.1.tar.gz
# rm gsl-2.1.tar.gz
# cd gsl-2.1
# ./configure
# make install
# cd -
#
# curl -L --silent -O http://downloads.sourceforge.net/project/libnova/libnova/v%200.15.0/libnova-0.15.0.tar.gz
# tar xzf libnova-0.15.0.tar.gz
# rm libnova-0.15.0.tar.gz

# Might not need these because we used brew for this
#
# curl -L --silent -O http://pilotfiber.dl.sourceforge.net/project/libusb/libusb-1.0/libusb-1.0.20/libusb-1.0.20.tar.bz2
# tar xzf libusb-1.0.20.tar.bz2
# rm libusb-1.0.20.tar.bz2

git clone https://github.com/indilib/indi.git
cd indi/libindi

awk '1;/set \(indiclient_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' CMakeLists.txt > CMakeLists.zzz
awk '1;/set \(indiclient_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' CMakeLists.zzz > CMakeLists.txt

awk '1;/set \(indiclientqt_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' CMakeLists.txt > CMakeLists.zzz
awk '1;/set \(indiclientqt_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' CMakeLists.zzz > CMakeLists.txt

rm CMakeLists.zzz

sed -i '' 's#target_link_libraries(AlignmentDriver ${GSL_LIBRARIES})#target_link_libraries(AlignmentDriver -L/usr/local/lib ${GSL_LIBRARIES})#' libs/indibase/alignment/CMakeLists.txt 

cd ${INDI_DIR}/

mkdir -p build/libindi
cd build/libindi

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
	echo "Adding GPhoto Driver"

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


