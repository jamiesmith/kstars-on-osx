#!/bin/bash

# This is an attempt to automate the stuff- YMMV.  Do not be surprised if you
# run in to a gsl error.

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

echo $DIR

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

if [ ! -d ~/Qt/5.7/clang_64/bin ]
then
	echo "Installing qt5, because I didn't find it"
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
# brewInstallIfNeeded gsl

source "${DIR}/build-env.sh"


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
statusBanner EMERGE COMPLETE!

##########################################
statusBanner "Prepping some other stuff"

statusBanner "The Data Directory"
mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data
cp -rf ${KSTARS_DIR}/share/kstars/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data/

statusBanner "The indi drivers"
mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi
cp -f /usr/local/bin/indi* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/
cp -f /usr/local/share/indi/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/

statusBanner "The astrometry files"
mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry 
cp -rf $(brew --prefix astrometry-net)/bin ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/
cp -rf $(brew --prefix astrometry-net)/lib ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/
cp -f $(brew --prefix astrometry-net)/etc/astrometry.cfg ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/bin/

##########################################
statusBanner "Gathering GSC info"

GSC_TB=${INDI_ROOT}/bincats_GSC_1.2.tar.gz

mkdir -p ${GSC_DIR}
cd ${GSC_DIR}
[ -f ${GSC_TB} ] || wget -O ${GSC_TB} "http://cdsarc.u-strasbg.fr/viz-bin/nph-Cat/tar.gz?bincats/GSC_1.2"
tar -xzf ${GSC_TB}
cd src

cat << EOF > makefile.osx
include makefile

#############################################################################
install_emerge: \$(PGMS) genreg.exe phase2
	echo target DIR IS \$(GSC_TARGET_DIR)
	mkdir -p \${GSC_TARGET_DIR}/bin
	\$(COPY) gsc.exe      \$(GSC_TARGET_DIR)/bin/gsc
	\$(COPY) decode.exe   \$(GSC_TARGET_DIR)/bin/decode
	\$(COPY) -rf ../N???? \$(GSC_TARGET_DIR)/
	\$(COPY) -rf ../S???? \$(GSC_TARGET_DIR)/
	GSCDAT=\$(GSC_TARGET_DIR); export GSCDAT; genreg.exe -b -c -d
EOF

make -f makefile.osx
make -f makefile.osx install_emerge

##########################################
statusBanner "Set up some xplanet pictures"

cd ${INDI_ROOT}
curl -LO https://sourceforge.net/projects/flatplanet/files/maps/1.0/maps_alien-1.0.tar.gz
tar -xzf maps_alien-1.0.tar.gz -C "$(brew --prefix xplanet)" --strip-components=2
rm maps_alien-1.0.tar.gz

# rm -rf /Applications/KDE
# cp -r ${KSTARS_DIR}/Applications/KDE /Applications/