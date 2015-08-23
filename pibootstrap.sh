#!/bin/bash

IMAGE_SIZE=400
MIRROR="http://mirrordirector.raspbian.org/raspbian"
ARCH="armhf"
PACKAGES=( "sudo" "locales" "keyboard-configuration" )

#----------------------------------------------------
# prompt_yesno <question> [default]
# Prompts the user for a yes/no answer to a question.
# Will reprompt until a valid answer is provided.
# Allows for an optional default answer for when
# user presses enter.
#----------------------------------------------------
function prompt_yesno() {
    local prompt=$1
    local default_value=$2
	
    # "blablabla [Y/n]? "
    case "$default_value" in
        y|Y)
            prompt="${prompt} [Y/n]? ";;
        n|N)
            prompt="${prompt} [y/N]? ";;
        *)
            prompt="${prompt} [y/n]? "
    esac

    echo -n "${prompt}"
    while true; do
        read -n 1 -s answer
        case "$answer" in
            y|Y)
                echo "y"
                return 0
                ;;
            n|N)
                echo "n"
                return 1
                ;;
			*)
                if [ -z "${answer}" ] && [ -n "${default_value}" ]; then
                    case "$default_value" in
                        y|Y)
                            echo "y"
                            return 0
                            ;;
                        n|N)
                            echo "n"
                            return 1
                            ;;
                    esac
                fi
			    ;;
        esac
	done
}

function image_losetup() {
    if [ -n "${IMAGE_FILE}" ]; then
        if [ -z "${TARGET_DEVICE}" ]; then
            echo "Setting up image loop device."

            TARGET_DEVICE=$(losetup -f --show ${IMAGE_FILE})
            if [ $? -ne 0 ]; then
                TARGET_DEVICE=""
                if [ -n "${DIALOG}" ]; then
				    ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to setup a loop device." 20 60 2
                else
                    echo "Error: Failed to setup a loop device."
                fi
                return 1
            elif [ -z "${TARGET_DEVICE}" ]; then
                if [ -n "${DIALOG}" ]; then
				    ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to setup a loop device." 20 60 2
                else
                    echo "Error: Failed to setup a loop device."
                fi
                return 1
            fi
        fi

        if [ -z "${BOOT_PARTITION}"] && [ -z "${ROOT_PARTITION}" ]; then
            echo "Mapping device loop partitions."

            partx -a ${TARGET_DEVICE}
            if [ $? -ne 0 ]; then
                losetup -d ${TARGET_DEVICE}
                if [ $? -eq 0 ]; then
				    TARGET_DEVICE=""
				fi
                if [ -n "${DIALOG}" ]; then
				    ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to create loop device mapped partitions." 20 60 2
                else
                    echo "Error: Failed to create loop device mapped partitions."
                fi
                return 1
            fi

            BOOT_PARTITION=${TARGET_DEVICE}p1
            ROOT_PARTITION=${TARGET_DEVICE}p2
		fi
    fi

    return 0
}

function image_losetup_detach() {
    if [ -n "${IMAGE_FILE}" ]; then
        echo "Detaching loop devices."

        if [ -n "${ROOT_PARTITION}" ]; then
            partx -d ${ROOT_PARTITION}
            if [ $? -eq 0 ]; then
                ROOT_PARTITION=""
		    else
                partx -d ${BOOT_PARTITION}
				if [ $? -eq 0 ]; then
                    BOOT_PARTITION=""
				fi
                losetup -d ${TARGET_DEVICE}
				if [ $? -eq 0 ]; then
                    TARGET_DEVICE=""
                fi
                if [ -n "${DIALOG}" ]; then
				    ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to detach mapped partition ${ROOT_PARTITION}." 20 60 2
                else
                    echo "Error: Failed to detach mapped partition ${ROOT_PARTITION}."
                fi
                return 1
            fi
	    fi
	
	    if [ -n "${BOOT_PARTITION}" ]; then
            partx -d ${BOOT_PARTITION}
            if [ $? -eq 0 ]; then
                BOOT_PARTITION=""
            else
                losetup -d ${TARGET_DEVICE}
                if [ $? -eq 0 ]; then
                    TARGET_DEVICE=""
                fi
                if [ -n "${DIALOG}" ]; then
				    ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to detach mapped partition ${BOOT_PARTITION}" 20 60 2
                else
                    echo "Error: Failed to detach mapped partition ${BOOT_PARTITION}."
                fi
                return 1
            fi
        fi

        if [ -n "${TARGET_DEVICE}" ]; then
            losetup -d ${TARGET_DEVICE}
            if [ $? -eq 0 ]; then
                TARGET_DEVICE=""
            else
                if [ -n "${DIALOG}" ]; then
				    ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to detach loop device ${TARGET_DEVICE}." 20 60 2
                else
                    echo "Error: Failed to detach loop device ${TARGET_DEVICE}."
                fi
                return 1
            fi
        fi
    fi

	return 0
}

function mount_partitions() {
    echo "Mounting partitions."

    # Sanity checks
    if [ -z "${ROOT_PARTITION}" ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "No root partition has been declared." 20 60 2
        else
            echo "Error: No root partition has been declared."
        fi
        return 1
	elif [ -z "${BOOT_PARTITION}" ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "No boot partition has been declared." 20 60 2
        else
            echo "Error: No boot partition has been declared."
        fi
        return 1
    fi

    # Check for chroot directory or create it
    if [ -z "${CHROOT_DIR}" ]; then
        CHROOT_DIR="${BUILD_DIRECTORY}/chroot"
    fi

    # Create the chroot mountpoint for root partition
    [ ! -d ${CHROOT_DIR} ] && mkdir -p ${CHROOT_DIR}

    # Mount the root partition
    mount ${ROOT_PARTITION} ${CHROOT_DIR}
    if [ $? -ne 0 ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to mount root partition." 20 60 2
        else
            echo "Error: Failed to mount root partition."
        fi
        return 1
    fi

    # Create and mount the boot partition
    [ ! -d ${CHROOT_DIR}/boot ] && mkdir -p ${CHROOT_DIR}/boot
    mount ${BOOT_PARTITION} ${CHROOT_DIR}/boot
    if [ $? -ne 0 ]; then
        umount --force --lazy ${CHROOT_DIR}
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to mount boot partition." 20 60 2
        else
            echo "Error: Failed to mount boot partition."
        fi
        return 1
    fi

    return 0
}

function umount_partitions() {
    local whiptail_bin=$(which whiptail)

    echo "Unmounting partitions."

    # Check for chroot directory.
    # If it is undefined or does not exist, then no partitions have been mounted
    if [ -z "${CHROOT_DIR}" ]; then
	    return 0
	elif [ ! -d ${CHROOT_DIR} ]; then
        return 0
    fi

    # Check for boot directory.
    # If it does not exist, then boot partition has not been mounted
    if [ ! -d ${CHROOT_DIR}/boot ]; then
        return 0
    fi

    umount --force --lazy ${CHROOT_DIR}/boot
    if [ $? -ne 0 ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to unmount boot partition." 20 60 2
        else
            echo "Error: Failed to unmount boot partition."
        fi
        return 1
    fi

    umount --force --lazy ${CHROOT_DIR}
    if [ $? -ne 0 ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to unmount root partition." 20 60 2
        else
            echo "Error: Failed to unmount root partition."
        fi
        return 1
    fi

    return 0
}

function is_host_arm() {
    local host_arch=$(uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)

    if [ "${host_arch}" = "arm" ]; then
        return 0 # true
    else
        return 1 # false
    fi
}

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

if [ -z "${HOSTNAME}" ]; then
    HOSTNAME="raspberrypi"
fi

#--------------------------------------------------------------------
# Set network
#--------------------------------------------------------------------
if [ -n "${DIALOG}" ]; then
    ${DIALOG} --backtitle "${BACKTITLE}" --title "Network" --yesno "Use DHCP to configure your network?" 20 60 2 
    if [ $? -eq 0 ]; then
        PACKAGES+=( "isc-dhcp-client" )
    fi
else
    echo 
    if prompt_yesno "Use DHCP to configure your network" y; then
        PACKAGES+=( "isc-dhcp-client" )
    fi
fi

#--------------------------------------------------------------------
# Set up users and passwords
#--------------------------------------------------------------------
if [ -n "${DIALOG}" ]; then
     USER_FULLNAME=$(${DIALOG} --backtitle "${BACKTITLE}" --title "Set up users and passwords" --inputbox "\
A user account will be created for you to use instead of the root \
account for non-adminitrative activities.\n\n \
Please enter the real name of this user. This information will be \
used for instance as default origin for emails sent by this user \
as well as any program which displays or uses the user's real \
name. Your full name is a reasonable choice.\n\n \
Full name for the new user:
" 20 60 "" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        USER_FULLNAME=""
    fi

    USER_USERNAME=$(${DIALOG} --backtitle "${BACKTITLE}" --title "Set up users and passwords" --inputbox "\
Select a username for the new account. Your first name is a reasonable \
choice. The username should start with a lower-case letter, which can \
be followed by any combination of numbers and more lower-case letters.\n\n \
Username for your account: \
" 20 60 "pi" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        USER_USERNAME="pi"
    fi
else
    echo 
    echo "Set up users and passwords"
    echo "=========================="
    echo
    echo "A user account will be created for you to use instead of the root"
    echo "account for non-adminitrative activities."
    echo 
    echo "Please enter the real name of this user. This information will be"
    echo "used for instance as default origin for emails sent by this user"
    echo "as well as any program which displays or uses the user's real"
    echo "name. Your full name is a reasonable choice."
    echo 
    read -p "Full name for the new user:" USER_FULLNAME

    echo
    echo "Select a username for the new account. Your first name is a reasonable"
    echo "choice. The username should start with a lower-case letter, which can"
    echo "be followed by any combination of numbers and more lower-case letters."
    echo
    read -p "Username for your account [pi]:" USER_USERNAME
fi

if [ -z "${USER_USERNAME}" ]; then
    USER_USERNAME="pi"
fi

while true; do
    if [ -n "${DIALOG}" ]; then
        USER_PASSWORD=$(${DIALOG} --backtitle "${BACKTITLE}" --title "Set up users and passwords" --passwordbox "\
A good password will contain a mixture of letters, numbers and \
punctuation and should be changed at regular intervals.\n\n \
Choose a password for the new user:" 20 60 3>&1 1>&2 2>&3)
    else
        echo
        echo "A good password will contain a mixture of letters, numbers and"
        echo "punctuation and should be changed at regular intervals."
        echo
        read -s -p "Choose a password for the new user:" USER_PASSWORD
        echo
    fi

    if [ -n "${USER_PASSWORD}" ]; then
        if [ -n "${DIALOG}" ]; then
            password_verify=$(${DIALOG} --backtitle "${BACKTITLE}" --title "Set up users and passwords" --passwordbox "\
Please enter the same password again to verify you have \
typed it correctly.\n\n \
Re-enter password to verify: \
" 20 60 3>&1 1>&2 2>&3)
        else
            echo 
            echo "Please enter the same password again to verify you have"
            echo "typed it correctly."
            echo
            read -s -p "Re-enter password to verify:" password_verify
            echo
        fi

        if [ "${USER_PASSWORD}" = "${password_verify}" ]; then
            break
	    fi
	
	    if [ -n "${DIALOG}" ]; then
	        ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Password do not match. Try again." 20 70 1
        else
            echo "Error: Passwords do not match. Try again."
        fi
    else
        if [ -n "${DIALOG}" ]; then
	        ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Password can not be empty. Try again." 20 70 1
        else
            echo "Error: Password can not be empty. Try again."
        fi
	fi
done

#--------------------------------------------------------------------
# Create the image
#--------------------------------------------------------------------
IMAGE_FILE="${BUILD_DIRECTORY}/$(date +%Y-%m-%d)-minimalpi-${SUITE}.img"

[ -e ${IMAGE_FILE} ] && rm -f ${IMAGE_FILE}

block_count=$(( IMAGE_SIZE * 1000000 / 512 ))

if [ -n "${DIALOG}" ]; then
    (pv --size ${IMAGE_SIZE}m -n /dev/zero | dd of="${IMAGE_FILE}" bs=512 count=${block_count}) 2>&1 | ${DIALOG} --backtitle "${BACKTITLE}" --title "Image file" --gauge "Creating image file, please wait..." 10 70 0
    if [ $? -ne 0 ]; then
        ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to create image file." 20 60 2
        exit 1
    fi
else
    echo "Creating image file, please wait..."

    pv --size ${IMAGE_SIZE}m /dev/zero | dd of=$IMAGE_FILE bs=512 count=${block_count} >& /dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create image file ${image}."
        exit 1
    fi
fi

echo "Creating partition table."

fdisk ${IMAGE_FILE} << EOF >& /dev/null
n
p
1
 
+64M
t
c
n
p
2
 
 
w
EOF
if [ $? -ne 0 ]; then
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to create partitions." 20 70 1
    else
        echo "Error: Failed to create partitions."
    fi
    exit 1
fi

# Mount loop devices
if ! image_losetup; then
   exit 1
fi

# Boot partition must be FAT16 or FAT32. I choosed FAT32 as it is the most used by others.
echo "Formatting ${BOOT_PARTITION}"
mkfs.vfat -F 32 -n BOOT -I ${BOOT_PARTITION} >& /dev/null
if [ $? -ne 0 ]; then
    image_losetup_detach
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to format boot partition." 20 70 1
    else
        echo "Error: Failed to format boot partition."
    fi
    exit 1
fi

# Format rootfs with ext4 but journaling disabled to achieve the least awful I/O-speed
echo "Formatting ${ROOT_PARTITION}"
mkfs.ext4 -L rootfs -O ^has_journal -E stride=2,stripe-width=1024 -b 4096 ${ROOT_PARTITION} >& /dev/null
if [ $? -ne 0 ]; then
    image_losetup_detach
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Failed to format root partition." 20 70 1
    else
        echo "Error: Failed to format root partition."
    fi
    exit 1
fi

if ! mount_partitions; then
    exit 1
fi

debootstrap --no-check-gpg --foreign --arch=${ARCH} --include=$(IFS=,; echo "${PACKAGES[@]}") --variant=minbase ${SUITE} ${CHROOT_DIR} ${DEF_MIRROR}
if [ $? -ne 0 ]; then
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "debootstrap failed on first stage." 20 60 2
    else
        echo "Error: debootstrap failed on first stage."
    fi
    return 1
fi
	
# Before CHROOT
if ! is_host_arm; then
    if [ -e /usr/bin/qemu-arm-static ]; then
        if [ -d ${CHROOT_DIR}/usr/bin ]; then
            cp /usr/bin/qemu-arm-static ${CHROOT_DIR}/usr/bin/
            if [ $? -ne 0 ]; then
                umount_partitions
                image_losetup_detach
	            if [ -n "${DIALOG}" ]; then
                    ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Unable to copy /usr/bin/qemu-arm-static to ${CHROOT_DIR}/usr/bin/qemu-arm-static." 20 60 2
                else
                    echo "Error: Unable to copy /usr/bin/qemu-arm-static to ${CHROOT_DIR}/usr/bin/qemu-arm-static."
                fi
                return 1
            fi
        fi
    else
        umount_partitions
        image_losetup_detach
	    if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "Missing file /usr/bin/qemu-arm-static." 20 60 2
        else
            echo "Error: Missing file /usr/bin/qemu-arm-static."
        fi
        return 1
    fi
fi

# Second stage
LANG=C chroot ${CHROOT_DIR} /debootstrap/debootstrap --second-stage
if [ $? -ne 0 ]; then
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --backtitle "${BACKTITLE}" --title "Error" --msgbox "debootstrap failed on second stage." 20 60 2
    else
        echo "Error: debootstrap failed on second stage."
    fi
    return 1
fi
	
# Exit
# Remove qemu file before unmounting
if [ -e ${CHROOT_DIR}/usr/bin/qemu-arm-static ]; then
    rm ${CHROOT_DIR}/usr/bin/qemu-arm-static 
    if [ $? -ne 0 ]; then
        if [ -n "${DIALOG}" ]; then
            ${DIALOG} --backtitle "${BACKTITLE}" --title "Warning" --msgbox "Unable to delete ${CHROOT_DIR}/usr/bin/qemu-arm-static." 20 60 2
        else
            echo "Warning: Unable to delete ${CHROOT_DIR}/usr/bin/qemu-arm-static."
        fi
    fi
fi

umount_partitions
image_losetup_detach

echo "Done."