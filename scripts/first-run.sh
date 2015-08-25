#!/bin/bash
# Setup the file system on the first-run

#--------------------------------------------------------------------
# Application entry point
#--------------------------------------------------------------------
if [ $EUID -ne 0 ]; then
    echo "This tool must be run as root: # sudo $0" 1>&2
    exit 1
fi

BACKTITLE="Raspberry PI Installer"
DIALOG=$(which whiptail)
if [ -z "${DIALOG}" ]; then
    DIALOG=$(which dialog)
fi

#--------------------------------------------------------------------
# Enable Display Manager
#--------------------------------------------------------------------
DM="slim lightdm xdm gdm lxdm"
for i in $DM ; do 
    if [ -f /etc/init.d/$i ] ; then 
        update-rc.d $i enable
        break
    fi 
done

#--------------------------------------------------------------------
# Expand root filesystem
#--------------------------------------------------------------------
if ! [ -h /dev/root ]; then
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --msgbox "/dev/root does not exist or is not a symlink. Don't know how to expand" 20 60 2
    else
        echo "Error: /dev/root does not exist or is not a symlink. Don't know how to expand."
    fi
    exit 1
fi

ROOT_PART=$(readlink /dev/root)
PART_NUM=${ROOT_PART#mmcblk0p}
if [ "$PART_NUM" = "$ROOT_PART" ]; then
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --msgbox "/dev/root is not an SD card. Don't know how to expand" 20 60 2
    else
        echo "Error: /dev/root is not and SD card. Don't know how to expand."
    fi
    exit 1
fi

# NOTE: the NOOBS partition layout confuses parted. For now, let's only 
# agree to work with a sufficiently simple partition layout
if [ "$PART_NUM" -ne 2 ]; then
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --msgbox "Your partition layout is not currently supported by this tool. You are probably using NOOBS, in which case your root filesystem is already expanded anyway." 20 60 2
    else
        echo "Error: Your partition layout is not currently supported by this tool. You are probably using NOOBS, in which case your root filesystem is already expanded anyway."
    fi
    exit 1
fi

LAST_PART_NUM=$(parted /dev/mmcblk0 -ms unit s p | tail -n 1 | cut -f 1 -d:)
if [ "$LAST_PART_NUM" != "$PART_NUM" ]; then
    if [ -n "${DIALOG}" ]; then
        ${DIALOG} --msgbox "/dev/root is not the last partition. Don't know how to expand" 20 60 2
    else
        echo "Error: /dev/root is not the last partition. Don't know how to expand."
    fi
    return 0
fi

# Get the starting offset of the root partition
PART_START=$(fdisk -a /dev/mmcblk0 | grep "^/dev/mmcblk0p${PART_NUM}" | awk '{print $2}')

# Return value will likely be error for fdisk as it fails to reload the
# partition table because the root fs is mounted
fdisk /dev/mmcblk0 <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF

# now set up an init.d script
cat <<\EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO
. /lib/lsb/init-functions
case "$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs /dev/root &&
    rm /etc/init.d/resize2fs_once &&
    update-rc.d resize2fs_once remove &&
    log_end_msg $?
    ;;
  *)
    echo "Usage: $0 start" >&2
    exit 3
    ;;
esac
EOF
chmod +x /etc/init.d/resize2fs_once
update-rc.d resize2fs_once defaults

#--------------------------------------------------------------------
# Reboot
#--------------------------------------------------------------------
if [ -n "${DIALOG}" ]; then
    ${DIALOG} --msgbox "System will now reboot for changes to take effect." 20 60 2
else
    echo
    echo "System will now reboot for changes to take effect."
    echo
fi
reboot
