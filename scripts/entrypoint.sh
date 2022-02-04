#!/bin/bash

# ZeroTier router entrypoint script
# 04/02/2022 - pm@pixelwarriors.net

# Exit immediately if we get an error
set -e

trap 'exit 0' SIGTERM SIGINT

# Check if we have the /dev/net/tun device available
if [ ! -e /dev/net/tun ]; then
  echo 'FATAL: /dev/net/tun not available - check permissions and mountpath'
  exit 1
fi

# Check if we got some ZT networks to connect to
if [ -z "${ZT_NETWORKS}" ]; then
  echo 'FATAL: No ZT networks defined - check environment variable "ZT_NETWORKS" and provide at least one network-id to join'
  exit 1
fi

# Check if we have existing public/secret identity information provided and if so copy them to ZT config
# if no identity information is provided we simply generate new public/secret infos
if [ -n "${ZT_ID_PUBLIC}" ] && [ -n "${ZT_ID_SECRET}" ]; then
  echo 'INFO: Using identity configured in env variables'
  echo "${ZT_ID_PUBLIC}" > /var/lib/zerotier-one/identity.public
  echo "${ZT_ID_SECRET}" > /var/lib/zerotier-one/identity.secret
elif [ -f /var/lib/zerotier-one/identity.public ] && [ -f /var/lib/zerotier-one/identity.secret ]; then
  echo 'INFO: Existing identity information found in /var/lib/zerotier-one - using it'
else
  echo 'INFO: Generating new identity information'
  zerotier-idtool generate > /var/lib/zerotier-one/identity.secret
  zerotier-idtool getpublic /var/lib/zerotier-one/identity.secret > /var/lib/zerotier-one/identity.public
fi

# Start zerotier daemon and wait for startup
zerotier-one -d
sleep 1

for network in ${ZT_NETWORKS}; do
  echo "INFO: Joining network ${network}... $(zerotier-cli join "${network}")"
done

# Wait for network joins
sleep 5

echo "INFO: $(zerotier-cli listnetworks)"
echo "INFO: $(zerotier-cli info)"

# Configure iptables masquerading
# If no interface name is specified assume eth0 pod/container traffic
iptables -t nat -o "${ZT_IFNAME:-eth0}" -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -i zt+ -o "${ZT_IFNAME:-eth0}" -j ACCEPT
iptables -A FORWARD -i "${ZT_IFNAME:-eth0}" -m state --state RELATED,ESTABLISHED -j ACCEPT

# Enable ip forwarding
sysctl -w net.ipv4.ip_forward=1

while :; do
  sleep 1
done
