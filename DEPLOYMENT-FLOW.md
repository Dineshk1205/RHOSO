# RHOSO 18.0 — Deployment Flow
## Pre-requisites
Openshift 4.18 Cluster 
Ceph Cluster 

Make sure the following Openshift operators are installed and running before proceeding:
- **NMState Operator**
- **MetalLB Operator**
- **cert-manager Operator**
- **OpenStack Operator**

oc get csv -n openstack-operators
oc get csv -n openshift-nmstate
oc get csv -n metallb-system
oc get csv -n cert-manager-operator

---

## Deployment Flow


 ┌──────────────────────────────────────────────────────────┐
 │  STEP 1 — OCP Master Network Config                      │
 │  w0-nncp.yaml  — VLANs + OVS bridge on master0          │
 │  w1-nncp.yaml  — VLANs + OVS bridge on master1          │
 │  w2-nncp.yaml  — VLANs + OVS bridge on master2          │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  STEP 2 — Network Attachment Definitions                 │
 │  netattach.yaml — Connects pods to OpenStack VLANs       │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  STEP 3 — MetalLB IP Pools                               │
 │  metal-lb.yaml — LoadBalancer VIP pools + L2 adverts     │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  STEP 4 — Secrets                                        │
 │  secret.yaml           — OpenStack service passwords     │
 │  novasecret.yaml       — Libvirt password for Nova       │
 │  subscription-secret.yaml — RHN credentials             │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  Run on Ceph Node (ssh root@10.10.20.20)           │
 │  ceph-setup.sh                                           │
 │  Creates pools + openstack user                          │
 │  Generates → ceph-secret.yaml                            │
 └────────────────────┬─────────────────────────────────────┘


 ┌──────────────────────────────────────────────────────────┐
 │  STEP 5 — Ceph Secret                                    │
 │  ceph-secret.yaml — Ceph FSID, MON host and key         │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  STEP 6 — Control Plane Deployment                       │
 │  control-deploy.yaml — Deploys all OpenStack services    │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  STEP 7 — Compute Network Config                         │
 │  compute-netconfig.yaml — IP allocation for compute      │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  STEP 8 — SSH Key Setup                                  │
 │  ssh-setup.sh — Generate keys + create OCP secrets      │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  STEP 9 — Compute Node Deployment                        │
 │  compute-node.yaml   — Compute node Ansible config       │
 │  compute-deploy.yaml — Triggers Ansible deployment       │
 └────────────────────┬─────────────────────────────────────┘
                      ▼
 ┌──────────────────────────────────────────────────────────┐
 │  STEP 10 — Post Deploy                                   │
 │  postdeploy.sh — Flavor, Cirros image, provider network  │
 └──────────────────────────────────────────────────────────┘
```

---

## Commands

### Step 1 — OCP Master Network Config
```bash
oc apply -f w0-nncp.yaml
oc apply -f w1-nncp.yaml
oc apply -f w2-nncp.yaml
oc get nncp -w    # wait for all 3: Available
```

### Step 2 — Network Attachment Definitions
```bash
oc apply -f netattach.yaml
```

### Step 3 — MetalLB

oc get svc --all-namespaces | grep "172.16.30"
oc apply -f metal-lb.yaml
```

### Step 4 — Secrets

# Update YOUR_RHN_USERNAME and YOUR_RHN_PASSWORD in subscription-secret.yaml
oc apply -f secret.yaml
oc apply -f novasecret.yaml
oc apply -f subscription-secret.yaml
```

### Step 5 — Ceph Secret
```bash
oc apply -f ceph-secret.yaml
```

### Step 6 — Control Plane
```bash
oc apply -f control-deploy.yaml
oc get openstackcontrolplane -n openstack -w
# Wait for: True / Setup complete (15-20 min)
```

### Step 7 — Compute Network Config
```bash
oc apply -f compute-netconfig.yaml
```

### Step 8 — SSH Key Setup
```bash
chmod +x ssh-setup.sh && ./ssh-setup.sh
```

### Step 9 — Compute Node
```bash
oc apply -f compute-node.yaml
oc apply -f compute-deploy.yaml
oc get openstackdataplanedeployment -n openstack -w
# Wait for: True / Setup complete (30-45 min)

oc rsh -n openstack nova-cell0-conductor-0 \
  nova-manage cell_v2 discover_hosts --verbose
```

### Step 10 — Post Deploy
```bash
chmod +x postdeploy.sh && ./postdeploy.sh
```

---

## File Reference

| File | Step | What it does |
|---|---|---|

| `w0-nncp.yaml` | 1 | Creates VLANs on ens35 and OVS bridge on ens36 for master0 |
| `w1-nncp.yaml` | 1 | Creates VLANs on ens35 and OVS bridge on ens36 for master1 |
| `w2-nncp.yaml` | 1 | Creates VLANs on ens35 and OVS bridge on ens36 for master2 |
| `netattach.yaml` | 2 | Multus NADs — allows pods to attach to ctlplane, internalapi, storage, tenant VLANs |
| `metal-lb.yaml` | 3 | MetalLB IP pools and L2 advertisements for LoadBalancer VIPs |
| `secret.yaml` | 4 | All OpenStack service passwords — password: openstack |
| `novasecret.yaml` | 4 | Libvirt password used by Nova for VM management |
| `subscription-secret.yaml` | 4 | RHN credentials for RHSM registration and registry.redhat.io pulls |
| `ceph-setup.sh` Run on Ceph node — creates pools, user, generates ceph-secret.yaml |
| `ceph-secret.yaml` | 5 | Ceph FSID, MON host and client.openstack key — mounted into Cinder |
| `control-deploy.yaml` | 6 | Deploys Keystone, Glance, Cinder, Nova, Neutron, OVN, Horizon, Telemetry |
| `compute-netconfig.yaml` | 7 | Defines IP allocation ranges for compute node networks |
| `ssh-setup.sh` | 8 | Generates SSH keys and creates OCP secrets for Ansible |
| `compute-node.yaml` | 9 | Compute node Ansible config — NICs, VLANs, repos, OVN bridge mappings |
| `compute-deploy.yaml` | 9 | Triggers Ansible jobs to deploy and configure the compute node |
| `postdeploy.sh` | 10 | Creates tiny flavor, Cirros image, provider network with DHCP |
