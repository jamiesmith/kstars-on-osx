## Instructions for Installing KStars, Dependencies, and related software on OS X with options for creating an App Bundle, an XCode Project, or a QT Creator Project

This script is built on:

	-the initial work that seanhoughton did to get KStars working on OS X initially
	
	-the work that rlancaste did to get KStars modified to work well on OS X
	
	-the work that Gonzothegreat did to create a deployable app bundle and dmg
	
	-the work that jamiesmith did to automate the entire process in a simple and easy to use script
	
	-and the later work of rlancaste and knro to further fix problems and streamline the process.

	-Note, Most of the epic journey is logged on the indilib forums http://indilib.org/forum/ekos/525-ekos-on-mac-os-x.html?start=564#11793


Prerequisites for running the script include:

### Installing Xcode and accept the license agreements

[Apple Developer Site](developer.apple.com/download/) or from the 
[app store](https://itunes.apple.com/us/app/xcode/id497799835)

### Installing Homebrew

`/usr/bin/ruby -e "$(curl -fsSL raw.githubusercontent.com/Homebrew/install/master/install)"`

### Installing QT

Either install QT via a download from: [QT.io](www.qt.io/download-open-source/) or via homebrew.
Both methods should work, but the homebrew method could take HOURS.  If you do the homebrew method, 
then be sure to install qt with dbus.  Note that the install from qt sometimes takes
a long time too, and the installer appears to become unresponsive before
it starts copying stuff.  I used the offline file, but you can use either.  

The install selections I chose:
   ![qt install options](/images/qt-install-options.png "qt install options")


### Downloading the files from this repo 

```console
	mkdir -p ~/Projects
	cd ~/Projects/
	
	# if you don't already have the repo:
	# 
	git clone github.com/jamiesmith/kstars-on-osx.git
	
	# if you do already have it:
	# (if you changed something then you will have to work that out)
	cd ~/Projects/kstars-on-osx
	git pull
```

### Editing the build-env.sh file to reflect your version of QT

Edit this line:  export QT5_DIR=~/Qt/5.9.1/clang_64
To reflect the path to your QT_5 installation.

### Running the Script
```console
	# Change to the script directory
	cd ~/Projects/kstars-on-osx
	# If you want to build KStars to use the program using craft, then do:
	./build-kstars.sh -aeid
	# If you want to build an XCode Project you can work on, instead do:
	./build-kstars.sh -axid
	# If you want to build a QT Creator Project you can work on, instead do:
	./build-kstars.sh -acid
```

Note that the -a option announces key installation steps audibly, the -i option builds indi with kstars, and the -d option also builds a dmg.

After the script finishes, whichever method you chose, you should have built a kstars app that can actually be used.

	-If you chose the app and dmg option, you can now distribute the app and/or dmg to other people freely.  The dmg has associated md5 and sha256 files for download verification.

	-If you chose the XCode project, you should now be able to double click the created xcode project and launch xcode to do your editing.

	-If you chose the QT Creator option, you should follow the EditingKStarsInQTCreatorOnOSX.pdf document to get all set up to do your editing.

(For the last 2 options, of course you must have either XCode or QT Creator installed on your system respectively.

Now you should be all set up!!!

One note on distribution:  Due to our usage of homebrew in building the dependencies of KStars, the app/dmg that is build with this script will only work on installations of OS X equal to or greater than your version.  Anotherwords, you cannot build an app bundle on Sierra and expect it to work perfectly on Yosemite.  This is because homebrew ignores the deployment target flag in its installs.  We may address this in the future.



# Manual Steps for reference purposes -- note currently outdated, needs updating.


1. Make sure you have home-brew installed [brew.sh](http://brew.sh)
2. Make sure that you have core depndencies git, make, and cmake installed.

    ```console
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
    brew install dcraw
    brew install gphoto2
    brew install libraw
    ```

3. And some more:

    ```console
    brew tap homebrew/science
    brew install pkgconfig
    brew install cfitsio
    brew install eigen
    brew install astrometry-net 
    ```

4. And some optional ones:

    ```console
    brew install xplanet
    ```

5. If you do not already have qt 5 installed, then you will need it. By the way, this can take a very long time. You can also download QT5 from their website to your home directory. I did this with QT Creator and just specified the path to it. But it should also work with the homebrew version.

    ```console
    brew install qt5 --with-dbus
    ```
    To download QT5 from their website, you can go here: www.qt.io/download-open-source/

6. I followed these instructions to build INDI from source and get it installed on the Mac in the proper location, but since then we have found that it is much easier to install using homebrew dependencies which we put (and you already did) in step 3: http://indilib.org/forum/general/210-howto-building-latest-libindi-ekos.html
    Do this at the command line:

    ```console
    export INDI_ROOT=~/IndiRoot
    export INDI_DIR=${INDI_ROOT}/indi-stuff
    export KSTARS_DIR=${INDI_ROOT}/kstars-stuff
    export GSC_DIR=${INDI_ROOT}/gsc

    mkdir ${INDI_DIR}
    mkdir ${KSTARS_DIR}

    cd ${INDI_DIR}/

    git clone https://github.com/indilib/indi.git
    cd indi/libindi
    ```

    At this point we need to update the file CMakeLists.txt in libindi to add the two base.64.c additions and lilxml.c additions (We have to get them to change this in Libindi so we don't have to do it).  We can paste a command for this - Ultimately we want them to look like this:
    ```code
    set (indiclient_SRCS
            ${CMAKE_CURRENT_SOURCE_DIR}/libs/indibase/basedevice.cpp
            ${CMAKE_CURRENT_SOURCE_DIR}/libs/indibase/baseclient.cpp
            ${CMAKE_CURRENT_SOURCE_DIR}/libs/indibase/indiproperty.cpp
            ${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c
            ${CMAKE_CURRENT_SOURCE_DIR}/base64.c
        )

    set (indiclientqt_SRCS
            ${CMAKE_CURRENT_SOURCE_DIR}/libs/indibase/basedevice.cpp
            ${CMAKE_CURRENT_SOURCE_DIR}/libs/indibase/baseclientqt.cpp
            ${CMAKE_CURRENT_SOURCE_DIR}/libs/indibase/indiproperty.cpp
            ${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c
            ${CMAKE_CURRENT_SOURCE_DIR}/base64.c
        )
    ```

    If you want this automated, try:

    ```console
    cd indi/libindi

    awk '1;/set \(indiclient_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' CMakeLists.txt > CMakeLists.zzz
    awk '1;/set \(indiclient_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' CMakeLists.zzz > CMakeLists.txt

    awk '1;/set \(indiclientqt_SRCS/{c=4}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/libs/lilxml.c"}' CMakeLists.txt > CMakeLists.zzz
    awk '1;/set \(indiclientqt_SRCS/{c=5}c&&!--c{print "        \${CMAKE_CURRENT_SOURCE_DIR}/base64.c"}' CMakeLists.zzz > CMakeLists.txt

    rm CMakeLists.zzz

    ```

    Set some build variables:
    > NOTE - these can be set by sourcing `build-env.sh`

    ```console
    export Qt5_DIR=~/Qt/5.7/clang_64/bin
    export PATH=$(brew --prefix gettext)/bin:$PATH
    export CMAKE_LIBRARY_PATH=$(brew --prefix gettext)/lib
    export CMAKE_INCLUDE_PATH=$(brew --prefix gettext)/include export PATH=$(brew --prefix bison)/bin:$PATH
    export PATH=$Qt5_DIR:$PATH
    export Qt5DBus_DIR=$Qt5_DIR
    export Qt5Test_DIR=$Qt5_DIR
    export Qt5Network_DIR=$Qt5_DIR
    ```

    And build libindi and the indiserver:

    ```console
    mkdir -p ${INDI_DIR}/build/libindi
    cd ${INDI_DIR}/build/libindi

    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/libindi

    make
    sudo make install
    ```

    If you want the 3rd Party drivers like SBIG or DSI, you can try to build and install them or just copy them from somewhere else if you can find them. An alternative would be to install the free Cloudmakers Indiserver program:
    http://www.cloudmakers.eu/indiserver/
    And just run that to serve your 3rd Party devices
    Check that the binary files for the drivers are all in /usr/local/bin and that the driver xml files are in /usr/local/share/indi

    A couple people have had luck buiding the third party stuff by the following.

    If you want gphoto (or other things) you have to enable them in the makefile:

    ```console
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
    ```

    Then build:

    ```console
    mkdir -p ${INDI_DIR}/build/3rdparty
    cd ${INDI_DIR}/build/3rdparty

    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MACOSX_RPATH=1 ${INDI_DIR}/indi/3rdparty

    make
    make install
    ```

7. There is a problem with the Emerge routines where they access the wrong server. It is explained on this website: http://unix.stackexchange.com/questions/304001/problem-building-kde-software-on-osx
    To solve it, create a file called ~/.gitconfig and in this file you want to put these contents:

    ```console
    [url "git://anongit.kde.org/"]
        insteadOf = kde:
    [url "ssh://git@git.kde.org/"]
        pushInsteadOf = kde:
    ```

8. Following the instructions from [this page](https://community.kde.org/Guidelines_and_HOWTOs/Build_from_source/Mac), we can set up and run emerge.

    ```console
    export KSTARS_DIR=${INDI_ROOT}/kstars-stuff
    mkdir -p ${KSTARS_DIR}/

    cd ${KSTARS_DIR}/

    git clone --branch unix3 git://anongit.kde.org/emerge.git
    mkdir etc
    cp emerge/kdesettings.mac etc/kdesettings.ini
    ```
    
    ```console
    export Qt5_DIR=~/Qt/5.7/clang_64/bin
    export PATH=$(brew --prefix gettext)/bin:$PATH
    export CMAKE_LIBRARY_PATH=$(brew --prefix gettext)/lib
    export CMAKE_INCLUDE_PATH=$(brew --prefix gettext)/include
    export PATH=$(brew --prefix bison)/bin:$PATH
    export PATH=$Qt5_DIR:$PATH
    export Qt5DBus_DIR=$Qt5_DIR
    export Qt5Test_DIR=$Qt5_DIR
    export Qt5Network_DIR=$Qt5_DIR
    ```
    > NOTE - the above can be set by sourcing `build-env.sh`
    
    then run "emerge":
    
    ```console
    . emerge/kdeenv.sh
    emerge kstars
    ```
    > NOTE- If you get errors on the first line, you probably messed up the `.gitconfig` stuff

9. You will need to get several folders into the app.

    a. The Data Directory

    ```console
    mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data
    cp -r ${KSTARS_DIR}/share/kstars/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/Resources/data/
    ```

    b. The indi drivers

    ```console
    mkdir  -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi
    cp /usr/local/bin/indi* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/
    cp /usr/local/share/indi/* ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/indi/
    ```

    c. The astrometry files

    ```console
    mkdir -p ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry 
    cp -r $(brew --prefix astrometry-net)/bin ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/
    cp -r $(brew --prefix astrometry-net)/lib ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/
    cp $(brew --prefix astrometry-net)/etc/astrometry.cfg ${KSTARS_DIR}/Applications/KDE/kstars.app/Contents/MacOS/astrometry/bin/
    ```

10. If you would like gsc so that the simulators can have nice stars to work with, then install gsc following these insructions: WE NEED TO WRAP THIS UP IN THE APP next.
	http://www.indilib.org/support/tutorials/139-indi-library-on-raspberry-pi.html

    a. Find a folder on your hard drive in a terminal window and use these commands:

    NOTE : This part is changing in the build script.
    ```console
    mkdir -p ${GSC_DIR}
    cd ${GSC_DIR}
    wget -O bincats_GSC_1.2.tar.gz "http://cdsarc.u-strasbg.fr/viz-bin/nph-Cat/tar.gz?bincats/GSC_1.2"
    tar -xvzf bincats_GSC_1.2.tar.gz
    cd src
    make
    mv gsc.exe gsc
    sudo cp gsc /usr/local/bin/
    cd ..
    cp ~/gsc/bin/regions.* /gsc
    ```

    > I had a couple of problems. First, it needed both of the regions files in
    > a subfolder called bin inside the final gsc folder. Second, I had to copy
    > all the folders that began with N and S to the final gsc folder (but NOT
    > in the bin subfolder). Third, I had trouble getting the environment
    > variable permanent, so you will note I made the final line install to /gsc
    > not ~/gsc


11.  Bundling it up
    (This is a wip)
    
	```console
	cd ${KSTARS_DIR}/Applications/KDE/
	${Qt5_DIR}/bin/macdeployqt kstars.app -dmg

	cd ${KSTARS_DIR}
	${Qt5_DIR}/bin/macdeployqt Applications/KDE/kstars.app -dmg
	```

12. Local stuff!

    Add some images for xplanet:
```console
cd ${INDI_ROOT}
curl -LO https://sourceforge.net/projects/flatplanet/files/maps/1.0/maps_alien-1.0.tar.gz
tar -xzf maps_alien-1.0.tar.gz -C "$(brew --prefix xplanet)" --strip-components=2
```








