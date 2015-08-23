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

if [ -z "${DIALOG}" ]; then
    ${whiptail_bin} --msgbox "\
Welcome to the Raspberry PI image creation program. \
The install process is fairly straightforward, and \
you should run through the options in the order they \ 
are presented. \
" 20 70 1
else
    echo "Raspberry PI Image Creator"
    echo "=========================="
    echo
    echo "Welcome to the Raspberry PI image creation program."
    echo "The install process is fairly straightforward, and "
    echo "you should run through the options in the order they"
    echo " are presented."
    echo
    read -n 1 -s -p "Press any key to continue..."
fi

