#!/bin/bash
# Run on lb01 after control plane and dataplane deployment is complete

oc rsh -n openstack openstackclient << 'OSP'

# Flavor
openstack flavor create --ram 512 --disk 1 --vcpus 1 --public tiny

# Image
curl -O -L https://github.com/cirros-dev/cirros/releases/download/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create cirros \
  --container-format bare \
  --disk-format qcow2 \
  --public \
  --file cirros-0.6.2-x86_64-disk.img

# Provider network
openstack network create \
  --provider-network-type flat \
  --provider-physical-network datacentre \
  --external \
  --share \
  provider-net

# Subnet with DHCP
openstack subnet create \
  --network provider-net \
  --subnet-range 172.16.16.0/24 \
  --allocation-pool start=172.16.16.180,end=172.16.16.189 \
  --gateway 172.16.16.1 \
  --dns-nameserver 172.16.16.100 \
  --dhcp \
  provider-subnet

echo "Done"
OSP
