FRAMEWORKS_DIR="${HOME}/IndiRoot/kstars-emerge/Applications/KDE/kstars.app/Contents/Frameworks"
KIO_DIR="${HOME}/IndiRoot/kstars-emerge/Applications/KDE/kstars.app/Contents/PlugIns/kf5/kio"

IGNORED_OTOOL_OUTPUT="/Qt|qt5|/usr/lib/|/System/"

function statusBanner
{
    echo ""
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "~ $*"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo ""
}

function processTarget
{
	target=$1

	entries=$(otool -L $target | sed '1d' | awk '{print $1}' | egrep -v "$IGNORED_OTOOL_OUTPUT")
    echo "Processing $target"
    
    relativeRoot="${HOME}/IndiRoot/kstars-emerge/Applications/KDE/kstars.app/Contents"
    
    pathDiff=${target#${relativeRoot}*}

    # Need to calculate the path to the frameworks dir
    #
    if [[ "$pathDiff" == /Frameworks/* ]]
    then
        pathToFrameworks=""
    else        
        pathToFrameworks=$(echo $(dirname "${pathDiff}") | awk -F/ '{for (i = 1; i < NF ; i++) {printf("../")} }')
        pathToFrameworks="${pathToFrameworks}Frameworks/"
    fi
        
	for entry in $entries
	do
		baseEntry=$(basename $entry)
		newname=""

        # the pathToFrameworks should end in a slash
        #
        # if [[ "$entry" == @rpath* ]]
        # then
        #     newname="@rpath/${pathToFrameworks}Frameworks/${baseEntry}"
        # else
        #     newname="@executable_path/${pathToFrameworks}Frameworks/${baseEntry}"
        # fi
        
        # Now I think that the @rpaths need to change to @executable_path
        #
		newname="@loader_path/${pathToFrameworks}${baseEntry}"
		
        echo "    change $entry -> $newname"
        # echo "          install_name_tool -change \\"
        # echo "              $entry \\"
        # echo "              $newname \\"
        # echo "              $target"
        
        if [ -z "${DRY_RUN_ONLY}" ]
        then
            install_name_tool -change \
                $entry \
                $newname \
                $target

        else
            echo "        install_name_tool -change \\"
            echo "            $entry \\"
            echo "            $newname \\"
            echo "            $target"
        fi            

	done
    echo ""
    echo "   otool for $target after"
    otool -L $target | egrep -v "$IGNORED_OTOOL_OUTPUT" | awk '{printf("\t%s\n", $0)}'
    
}


statusBanner "Processing all of the files in the kio dir"

# Then do all of the files in the kio Dir
#
for file in ${KIO_DIR}/*
do
    base=$(basename $file)
    
    if [ -x $file ]
    then
        statusBanner "Processing kio file $base"
        processTarget $file
    else
        echo ""
        echo ""
        echo "Skipping $base, not executable"
    fi
done



