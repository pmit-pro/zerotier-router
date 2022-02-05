#!/bin/bash

# ZeroTier router entrypoint script
# 04/02/2022 - pm@pixelwarriors.net

# Exit immediately if we get an error
set -e

# Exit if we get SIGTER/SIGINT signal
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

# Check if we have existing public/secret identity information provided and if so copy them to ZT config,
# or use the existing identity stored in /var/lib/zerotier-one
# If no identity information is provided we simply generate new public/secret infos
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

if [ "${ZT_ENABLE_FORWARD}" = true ] ; then
  echo "INFO: Enabling IP forwarding..."
  # Configure iptables forwarding and masquerade
  # If no interface name is specified assume eth0 pod/container traffic
  iptables -A FORWARD -i zt+ -o "${ZT_IFNAME:-eth0}" -j ACCEPT
  iptables -A FORWARD -i "${ZT_IFNAME:-eth0}" -m state --state RELATED,ESTABLISHED -j ACCEPT

  if [ "${ZT_ENABLE_MASQUERADE}" = true ] ; then
    echo "INFO: Enabling masquerade for outbound interface "${ZT_IFNAME:-eth0}""
    iptables -t nat -o "${ZT_IFNAME:-eth0}" -A POSTROUTING -j MASQUERADE
  fi

  # Enable ip forwarding kernel parameter
  # This may fail in kubernetes environments where sysctls are controlled by the cluster / kubelet
  if [ "$(sysctl net.ipv4.ip_forward | awk -F "= " '{print $2}')" -eq 0 ] ; then
    echo "INFO: Trying to enable net.ipv4.ip_forward kernel parameter"
    sysctl -w net.ipv4.ip_forward=1
  else
    echo "INFO: net.ipv4.ip_forward already enabled"
  fi
fi


while :; do
  sleep 1
done
