#!/bin/bash

#--------------------------------------------------------------------
# Application entry point
#--------------------------------------------------------------------
if [ $EUID -ne 0 ]; then
    echo "This tool must be run as root: # sudo $0" 1>&2
    exit 1
fi

DIALOG=$(which whiptail)
if [ -z "${DIALOG}" ]; then
    DIALOG=$(which dialog)
fi

if [ -n "${DIALOG}" ]; then
    ${DIALOG} --msgbox "\
Welcome to the Raspberry PI image creation program. \
The install process is fairly straightforward, and \
you should run through the options in the order they \
are presented. \
" 20 70 1
else
    echo
    echo "Raspberry PI Image Creator"
    echo "=========================="
    echo
    echo "Welcome to the Raspberry PI image creation program."
    echo "The install process is fairly straightforward, and "
    echo "you should run through the options in the order they"
    echo " are presented."
    echo
    read -n 1 -s -p "Press any key to continue..."
    echo
fi

#--------------------------------------------------------------------
# Initialize directories
#--------------------------------------------------------------------
if [ -z "${BUILD_DIRECTORY}" ]; then
    BUILD_DIRECTORY="$(pwd)/rpi"
fi

[ ! -d ${BUILD_DIRECTORY} ] && mkdir -p ${BUILD_DIRECTORY}
[ -d ${BUILD_DIRECTORY}/setup-files ] && rm -rf ${BUILD_DIRECTORY}/setup-files

if [ ! -d ${BUILD_DIRECTORY}/firmware ]; then
    wget --no-check-certificate --no-cache https://github.com/raspberrypi/firmware/archive/master.tar.gz -O ${BUILD_DIRECTORY}/firmware-master.tar.gz
    if [ $? -ne 0 ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --title "Error" --msgbox "Failed to download Raspberry PI firmware." 20 70 1
        else
            echo
            echo "Error: Failed to download Raspberry PI formware."
            echo
            exit 1
        fi
    fi

	cd ${BUILD_DIRECTORY}
    tar -zxf firmware-master.tar.gz
    if [ $? -ne 0 ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --title "Error" --msgbox "Failed to extract Raspberry PI firmware." 20 70 1
        else
            echo
            echo "Error: Failed to extract Raspberry PI formware."
            echo
            exit 1
        fi
    fi
	
	rm -f ${BUILD_DIRECTORY}/firmware-master.tar.gz
	
fi
