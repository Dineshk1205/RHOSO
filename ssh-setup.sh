#!/bin/bash

COMPUTE_IP="172.16.16.125"
NAMESPACE="openstack"

ssh-keygen -t ecdsa -f ~/.ssh/dataplane-key -N '' -q
ssh-keygen -t ecdsa-sha2-nistp521 -f ~/.ssh/nova-migration-key -N '' -q

ssh-copy-id -i ~/.ssh/dataplane-key.pub root@${COMPUTE_IP}

oc create secret generic dataplane-ansible-ssh-private-key-secret \
  --save-config --dry-run=client \
  --from-file=authorized_keys=/root/.ssh/dataplane-key.pub \
  --from-file=ssh-privatekey=/root/.ssh/dataplane-key \
  --from-file=ssh-publickey=/root/.ssh/dataplane-key.pub \
  -n ${NAMESPACE} -o yaml | oc apply -f -

oc create secret generic nova-migration-ssh-key \
  --save-config --dry-run=client \
  --from-file=ssh-privatekey=/root/.ssh/nova-migration-key \
  --from-file=ssh-publickey=/root/.ssh/nova-migration-key.pub \
  -n ${NAMESPACE} -o yaml | oc apply -f -

echo "Done"
