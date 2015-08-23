#!/bin/bash

PACKAGES=( "sudo" )

#--------------------------------------------------------------------
# Application entry point
#--------------------------------------------------------------------
if [ $EUID -ne 0 ]; then
    echo "This tool must be run as root: # sudo $0" 1>&2
    exit 1
fi

BACKTITLE="Raspberry PI Image Creator"
DIALOG=$(which whiptail)
if [ -z "${DIALOG}" ]; then
    DIALOG=$(which dialog)
fi

if [ -n "${DIALOG}" ]; then
    ${DIALOG} --backtitle "${BACKTITLE}" --msgbox "\
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
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to download Raspberry PI firmware." 20 70 1
        else
            echo
            echo "Error: Failed to download Raspberry PI firmware."
            echo
            exit 1
        fi
    fi

	cd ${BUILD_DIRECTORY}
    tar -zxf firmware-master.tar.gz
    if [ $? -ne 0 ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to extract Raspberry PI firmware." 20 70 1
        else
            echo
            echo "Error: Failed to extract Raspberry PI firmware."
            echo
            exit 1
        fi
    fi

    rm -f ${BUILD_DIRECTORY}/firmware-master.tar.gz
    mv ${BUILD_DIRECTORY}/firmware-master ${BUILD_DIRECTORY}/firmware
    if [ $? -ne 0 ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to rename firmware-master to firmware." 20 70 1
        else
            echo
            echo "Error: Failed to rename firmware-master to firmware."
            echo
            exit 1
        fi
    fi
fi

#--------------------------------------------------------------------
# Choose a debootstrap suite
#--------------------------------------------------------------------
if [ -n "$DIALOG" ]; then
    SUITE=$(${DIALOG} --backtitle "${BACKTITLE}" --title "Raspbian Release Selection" --menu "Choose your Raspbian release" 15 60 4 \
        "wheezy" "Old stable release" \
        "jeesie" "Current stable release" \
        "stretch" "Current testing release" \
        3>&1 1>&2 2>&3)
else
    echo 
    echo "Raspbian Release Selection"
    echo "=========================="
    echo 
    echo "Choose your Raspbian release:"
    echo "  1) wheezy  - Old stable release"
    echo "  2) jessie  - Current stable release"
    echo "  3) stretch - Current testing release"
    echo -n "Enter your choice: "
    while true; do
        read -n 1 -s SUITE;
        case $debian_release in
            1)
                echo "${SUITE}"
                SUITE="wheezy"
                break;;
            2)
                echo "${SUITE}"
                SUITE="jessie"
                break;;
            3)
                echo "${SUITE}"
                SUITE="stretch"
                break;;
            *)
                SUITE="";;
        esac
    done
fi

#--------------------------------------------------------------------
# Set a hostname
#--------------------------------------------------------------------
if [ -n "${DIALOG}" ]; then
    HOSTNAME=$(${DIALOG} --backtitle "${BACKTITLE}" --inputbox "\
Please enter the hostname for this system.\n\n\
The hostname is a single word that identifies your system to the \
network. If you don't know what your hostname should be, consult \
your network administrator. If you are setting up your own home \
network, you can make something up here.\n\n\
Hostname:
" 20 60 "raspberrypi" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        HOSTNAME="raspberrypi"
    fi
else
    echo 
    echo "Please enter the hostname for this system."
    echo
    echo "The hostname is a single word that identifies your system to the"
    echo "network. If you don't know what your hostname should be, consult"
    echo "your network administrator. If you are setting up your own home"
    echo "network, you can make something up here."
    echo
    read -p "Hostname [raspberrypi]: " HOSTNAME
fi

if [ -z "${HOSTNAME}"]; then
    HOSTNAME="raspberrypi"
fi

#--------------------------------------------------------------------
# Set a system user
#--------------------------------------------------------------------
