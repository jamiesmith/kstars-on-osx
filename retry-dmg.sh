#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}/build-env.sh"

# You probably don't want to use this.  I got tired of typing this over and over

cd $INDI_ROOT
if [ -f ${KSTARS_DIR}.tgz ]
then
	if [ -d ${KSTARS_DIR} ]
	then
		mv ${KSTARS_DIR} ${INDI_DIR}/to-delete
		rm -rf ${INDI_DIR}/to-delete &
		tar -vxzf ${KSTARS_DIR}.tgz
		
		${DIR}/fix-libraries.sh
		
	    echo "Building DMG"
	    cd ${KSTARS_DIR}/Applications/KDE
	    macdeployqt kstars.app -dmg
		
	fi
fi
