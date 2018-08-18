#!/bin/bash
#############################################################################################
# This script will install OpenVPN server on this machine
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

MESSAGE="This script will install openVPN server on this machine"
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

# Create  a new root CA cert, server and client cetficates
MESSAGE="Creating new root CA cert and signed certficates"
print_msg_start
cd /etc/openvpn
rm -rf server.*
rm -rf client.*
rm -rf ca.*
rm -rf dh2048.pem

openssl req -x509 -days 365 -newkey rsa:4096 -keyout ca.key -nodes -subj "/C=$CA_C/ST=$CA_ST/L=$CA_L/O=$CA_O" -set_serial 100 -out ca.crt

openssl req -newkey rsa:2048 -keyout server.key -nodes -subj "/C=$VPN_S_C/ST=$VPN_S_ST/L=$VPN_S_L/O=$VPN_S_O/OU=$VPN_S_OU/CN=$VPN_S_CN" -out server.csr
openssl x509 -req -days 365 -in server.csr -out server.crt -CA ca.crt -CAkey ca.key -set_serial 101

openssl req -newkey rsa:2048 -keyout client.key -nodes -subj "/C=$VPN_C_C/ST=$VPN_C_ST/L=$VPN_C_L/O=$VPN_C_O/OU=$VPN_C_OU/CN=$VPN_C_CN" -out client.csr
openssl x509 -req -days 365 -in client.csr -out client.crt -CA ca.crt -CAkey ca.key -set_serial 101

openssl dhparam -out dh2048.pem 2048

chmod 0600 server.*
chmod 0600 ca.*
chmod 0600 dh2048.pem

if [[ $COPY_CERTS_TO_TMP == "yes" ]]
then
	cp ca.crt /tmp/
	cp client.* /tmp/
	chmod 777 /tmp/ca.crt
	chmod 777 /tmp/client.*
fi

print_msg_done

# copy a sample config file and edit
cp /usr/share/doc/openvpn-2.4.6/sample/sample-config-files/server.conf . # copy the sample config file
sed -i "s/;topology.*/topology subnet/" server.conf
sed -i "s/^tls-auth.*/#&/" server.conf

# configure iptables
iptables -A POSTROUTING -t nat -s 10.8.0.0/24 -o $NIC -j MASQUERADE
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

systemctl start openvpn@server
systemctl -q enable openvpn@server


