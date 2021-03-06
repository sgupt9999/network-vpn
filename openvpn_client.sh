#!/bin/bash
#############################################################################################
# This script will install OpenVPN client on this machine
#############################################################################################
# Start of user inputs

# End of user inputs
#############################################################################################

yum install -y -q https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm # install epel repo
source ./inputs_openvpn
yum install wget -y -q
rm -rf common_fn
wget $COMMON_FILE
source ./common_fn
rm -rf $LOG_FILE
exec 5>$LOG_FILE
INSTALLPACKAGES="openvpn"

check_euid

MESSAGE="This script will install openVPN client on this machine"
print_msg_header

if yum list installed openvpn >&5 2>&5
then
	systemctl -q is-active openvpn && {
	systemctl stop openvpn
	systemctl -q disable openvpn
	}

	MESSAGE="Removing old copy of openVPN"
	print_msg_start
	yum remove -y $INSTALLPACKAGES >&5 2>&5
	print_msg_done
fi

MESSAGE="Installing openVPN"
print_msg_start
yum install -y $INSTALLPACKAGES >&5 2>&5
print_msg_done

# Create  a new root CA cert and a signed certfiicate
MESSAGE="Creating new root CA cert and a signed certficate"
print_msg_start
cd /etc/openvpn
rm -rf client.*
rm -rf ca.*

scp $SUSER@$HOSTSERVER:/tmp/ca.crt .
scp $SUSER@$HOSTSERVER:/tmp/client.* .

chmod 0600 client.*
chmod 0600 ca.*

print_msg_done

# create openVPN client config file
cat > client.opvn <<EOF
client
dev tun
proto udp
remote $IPSERVER 1194
resolv-retry infinite
nobind
persist-key
persist-tun
comp-lzo
verb 3
ca ca.crt
cert client.crt
key client.key
route-method exe
route-delay 2
EOF


openvpn --config client.opvn &
