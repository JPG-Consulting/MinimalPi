#!/bin/bash

prompt_yesno {
  # usage: prompt_yesno prompt variable [default]
  local prompt=$1
  local variable=$2
  local default=$3
  local answer=""

  case $default in
    'y')  prompt="$prompt [Y/n] " ;;
    'n')  prompt="$prompt [y/N] " ;;
    *)    prompt="$prompt [y/n] " ;;
  esac

  while [[ $answer == "" ]]; do
    read -r -p "$prompt" answer
    answer=${answer,,} # tolower
    
    if [[ $answer =~ ^(yes|y) ]]; then
      eval "$variable='y'"
    elif [[ $answer =~ ^(no|n) ]]; then
      eval "$variable='n'"
    else
      answer=$default
    fi
  done
}

setup_network_dhcp() {
    # TODO: Install DHCP Client
    echo "auto lo" > /etc/network/interfaces
    echo "iface lo inet loopback" >> /etc/network/interfaces
    echo "" >> /etc/network/interfaces
    echo "auto eth0" >> /etc/network/interfaces
    echo "iface eth0 inet dhcp" >> /etc/network/interfaces
}

setup_network_static() {
    local default_address="192.168.1.3"
    local default_netmask="255.255.255.0"
    local default_gateway="192.168.1.1"
    local address=""
    local netmask=""
    local gateway=""
    local network=""
    local broadcast=""
    
    if [[ -n "${WHIPTAIL}" ]]; then
        address=$(${WHIPTAIL} --inputbox "IP address:" 8 78  "${default_address}" --title "Static IP" 3>&1 1>&2 2>&3)
        netmask=$(${WHIPTAIL} --inputbox "Netmask:" 8 78  "${default_netmask}" --title "Static IP" 3>&1 1>&2 2>&3)
        gateway=$(${WHIPTAIL} --inputbox "Gateway:" 8 78  "${default_gateway}" --title "Static IP" 3>&1 1>&2 2>&3)
    else
        read -p "IP address [${default_address}]: " address
        if [ -z "${address}" ]; then
            address=${default_address}
        fi

        read -p "Netmask [${default_netmask}]: " netmask
        if [ -z "${netmask}" ]; then
            netmask=${default_netmask}
        fi

        read -p "Gateway [${default_gateway}]: " gateway
        if [ -z "${gateway}" ]; then
            gateway=${default_gateway}
        fi
    fi

    network=$(printf "%d.%d.%d.%d" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))")
    broadcast=$(printf "%d.%d.%d.%d" "$((i1 | (255 ^ m1)))" "$((i2 | (255 ^ m2)))" "$((i3 | (255 ^ m3)))" "$((i4 | (255 ^ m4)))")

    echo "auto lo" > /etc/network/interfaces
    echo "iface lo inet loopback" >> /etc/network/interfaces
    echo "" >> /etc/network/interfaces
    echo "auto eth0" >> /etc/network/interfaces
    echo "iface eth0 inet static" >> /etc/network/interfaces
    echo "  address ${address}" >> /etc/network/interfaces
    echo "  netmask ${netmask}" >> /etc/network/interfaces
    echo "  gateway ${gateway}" >> /etc/network/interfaces
    if [ -n "${network}" ]; then
        echo "  network ${network}" >> /etc/network/interfaces
    fi
    if [ -n "${broadcast}" ]; then
        echo "  broadast ${broadcast}" >> /etc/network/interfaces
    fi
}

WHIPTAIL=$(which whiptail)

if [[ -n "${WHIPTAIL}" ]]; then
    whiptail --yesno "Use DHCP to configure your network?" 20 60 2
    if [ $? -eq 0 ]; then # yes
        setup_network_dhcp
    else
        setup_network_static
    fi
else
    prompt_yesno "Use DHCP to configure your network?" resp Y
    if [[ $resp == 'y' ]]; then
        setup_network_dhcp
    else
        setup_network_static
    fi
fi

