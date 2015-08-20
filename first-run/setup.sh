#!/bin/bash

do_network_setup_static() {
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

    network=$(printf "%d.%d.%d.%d" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 &$
    broadcast=$(printf "%d.%d.%d.%d" "$((i1 | (255 ^ m1)))" "$((i2 | (255 ^ m2)))" "$((i$

    echo "" > /etc/network/interfaces
    echo "" >> /etc/network/interfaces
    echo "" >> /etc/network/interfaces
    echo "" >> /etc/network/interfaces


    cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address ${address}
  netmask ${netmask}
  gateway ${gateway}
 network 192.168.1.0
 broadcast 192.168.1.255
EOF
}

WHIPTAIL=$(which whiptail)

do_network_setup_static
