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

function is_host_arm() {
    local host_arch=$(uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)

    if [ "${host_arch}" = "arm" ]; then
        return 0 # true
    else
        return 1 # false
    fi
}

function image_losetup() {
    local whiptail_bin=$(which whiptail)

    if [ -n "${IMAGE_FILE}" ]; then
        if [ -z "${TARGET_DEVICE}" ]; then
            echo "Setting up image loop device."

            TARGET_DEVICE=$(losetup -f --show ${IMAGE_FILE})
            if [ $? -ne 0 ]; then
                TARGET_DEVICE=""
                if [ -n "${whiptail_bin}" ]; then
				    ${whiptail_bin } --title "Error" --msgbox "Failed to setup a loop device." 20 60 2
                else
                    echo "Error: Failed to setup a loop device."
                fi
                return 1
            elif [ -z "${TARGET_DEVICE}" ]; then
                if [ -n "${whiptail_bin}" ]; then
				    ${whiptail_bin } --title "Error" --msgbox "Failed to setup a loop device." 20 60 2
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
                if [ -n "${whiptail_bin}" ]; then
				    ${whiptail_bin } --title "Error" --msgbox "Failed to create loop device mapped partitions." 20 60 2
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
    local whiptail_bin=$(which whiptail)

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
                if [ -n "${whiptail_bin}" ]; then
				    ${whiptail_bin } --title "Error" --msgbox "Failed to detach mapped partition ${ROOT_PARTITION}." 20 60 2
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
                if [ -n "${whiptail_bin}" ]; then
				    ${whiptail_bin } --title "Error" --msgbox "Failed to detach mapped partition ${BOOT_PARTITION}" 20 60 2
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
                if [ -n "${whiptail_bin}" ]; then
				    ${whiptail_bin } --title "Error" --msgbox "Failed to detach loop device ${TARGET_DEVICE}." 20 60 2
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
    local whiptail_bin=$(which whiptail)

    echo "Mounting partitions."

    # Sanity checks
    if [ -z "${ROOT_PARTITION}" ]; then
        if [ -n "${whiptail_bin}" ]; then
            ${whiptail_bin } --title "Error" --msgbox "No root partition has been declared." 20 60 2
        else
            echo "Error: No root partition has been declared."
        fi
        return 1
	elif [ -z "${BOOT_PARTITION}" ]; then
        if [ -n "${whiptail_bin}" ]; then
            ${whiptail_bin } --title "Error" --msgbox "No boot partition has been declared." 20 60 2
        else
            echo "Error: No boot partition has been declared."
        fi
        return 1
    fi

    # Check for chroot directory or create it
    if [ -z "${CHROOT_DIR}" ]; then
        if [ -z "${BUILD_DIRECTORY}" ]; then
            BUILD_DIRECTORY="/root/rpi"
            [ ! -d ${BUILD_DIRECTORY} ] && mkdir -p ${BUILD_DIRECTORY}
        fi
        CHROOT_DIR="${BUILD_DIRECTORY}/chroot"
    fi

    # Create the chroot mountpoint for root partition
    [ ! -d ${CHROOT_DIR} ] && mkdir -p ${CHROOT_DIR}

    # Mount the root partition
    mount ${ROOT_PARTITION} ${CHROOT_DIR}
    if [ $? -ne 0 ]; then
        if [ -n "${whiptail_bin}" ]; then
            ${whiptail_bin } --title "Error" --msgbox "Failed to mount root partition." 20 60 2
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
        if [ -n "${whiptail_bin}" ]; then
            ${whiptail_bin } --title "Error" --msgbox "Failed to mount boot partition." 20 60 2
        else
            echo "Error: Failed to mount boot partition."
        fi
        return 1
    fi

    # Copy the qemu file to allow chrooting
    if ! is_host_arm; then
        if [ -e /usr/bin/qemu-arm-static ]; then
            if [ -d ${CHROOT_DIR}/usr/bin ]; then
                cp /usr/bin/qemu-arm-static ${CHROOT_DIR}/usr/bin/
                if [ $? -ne 0 ]; then
			        if [ -n "${whiptail_bin}" ]; then
                        ${whiptail_bin } --title "Error" --msgbox "Unable to copy /usr/bin/qemu-arm-static to ${CHROOT_DIR}/usr/bin/qemu-arm-static." 20 60 2
                    else
                        echo "Error: Unable to copy /usr/bin/qemu-arm-static to ${CHROOT_DIR}/usr/bin/qemu-arm-static."
                    fi
                    return 1
                fi
            fi
        else
            umount --force --lazy ${CHROOT_DIR}/boot
            umount --force --lazy ${CHROOT_DIR}

	        if [ -n "${whiptail_bin}" ]; then
                ${whiptail_bin } --title "Error" --msgbox "Missing file /usr/bin/qemu-arm-static." 20 60 2
            else
                echo "Error: Missing file /usr/bin/qemu-arm-static."
            fi
            return 1
        fi
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

	# Remove qemu file before unmounting
    if ! is_host_arm; then
        if [ -e ${CHROOT_DIR}/usr/bin/qemu-arm-static ]; then
            rm ${CHROOT_DIR}/usr/bin/qemu-arm-static 
            if [ $? -ne 0 ]; then
			    if [ -n "${whiptail_bin}" ]; then
                    ${whiptail_bin } --title "Warning" --msgbox "Unable to delete ${CHROOT_DIR}/usr/bin/qemu-arm-static." 20 60 2
                else
                    echo "Warning: Unable to delete ${CHROOT_DIR}/usr/bin/qemu-arm-static."
                fi
                return 1
            fi
        fi
    fi

    umount --force --lazy ${CHROOT_DIR}/boot
    if [ $? -ne 0 ]; then
        if [ -n "${whiptail_bin}" ]; then
            ${whiptail_bin } --title "Error" --msgbox "Failed to unmount boot partition." 20 60 2
        else
            echo "Error: Failed to unmount boot partition."
        fi
        return 1
    fi

    umount --force --lazy ${CHROOT_DIR}
    if [ $? -ne 0 ]; then
        if [ -n "${whiptail_bin}" ]; then
            ${whiptail_bin } --title "Error" --msgbox "Failed to unmount root partition." 20 60 2
        else
            echo "Error: Failed to unmount root partition."
        fi
        return 1
    fi

    return 0
}