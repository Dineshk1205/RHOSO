#!/bin/bash
# Run on Ceph node: 

for POOL in volumes vms images; do
  ceph osd pool create ${POOL} 2>/dev/null || true
  ceph osd pool application enable ${POOL} rbd 2>/dev/null || true
  rbd pool init ${POOL} 2>/dev/null || true
done

ceph auth add client.openstack \
  mgr 'allow *' \
  mon 'allow r' \
  osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rwx pool=images' 2>/dev/null || true

FSID=$(ceph fsid)
KEY=$(ceph auth get-key client.openstack)
MON=$(grep mon_host /etc/ceph/ceph.conf | awk '{print $3}')

cat > /root/ceph-secret.yaml << YAML
apiVersion: v1
kind: Secret
metadata:
  name: ceph-conf-files
  namespace: openstack
type: Opaque
stringData:
  ceph.conf: |
    [global]
            fsid = ${FSID}
            mon_host = ${MON}
  ceph.client.openstack.keyring: |
    [client.openstack]
            key = ${KEY}
            caps mgr = "allow *"
            caps mon = "allow r"
            caps osd = "allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rwx pool=images"
YAML

echo "Done — copy ceph-secret.yaml and apply: oc apply -f ceph-secret.yaml"
