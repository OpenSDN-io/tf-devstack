# Setup

## Prerequsites

We have machines
1. 346Gb RAM, 96 CPU, 400Gb, Ubuntu22
2. 346Gb RAM, 128 CPU, 400Gb, Ubuntu22
3. 377Gb RAM, 128 CPU, 400Gb, Ubuntu22

1 machine: juju jumphost + openstack (in lxd)
2 machine: contrail: 3 kvms with controller, analytics, analyticsdb on each of them
3-7 machines: computes

## Machine scripts:

## Infrastructure setup

on machine 1

- install juju
```bash
curl -sSLO https://launchpad.net/juju/2.9/2.9.49/+download/juju-2.9.49-linux-amd64.tar.xz
tar xf juju-2.9.49-linux-amd64.tar.xz 
sudo install -o root -g root -m 0755 juju /usr/local/bin/juju
hash -r
```

- bootstrap
```bash
$ export PHYS_INT=`ip route get 1 | grep -o 'dev.*' | awk '{print($2)}'`
$ export NODE_CIDR=`ip r | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+ dev $PHYS_INT " | awk '{print $1}'`
$ export NODE_IP=`ip addr show dev $PHYS_INT | grep 'inet ' | awk '{print $2}' | head -n 1 | cut -d '/' -f 1`
$ export UBUNTU_SERIES=jammy
$ SWITCH_OPT='--no-switch'
$ juju bootstrap $SWITCH_OPT --config container-networking-method=fan --config fan-config=$NODE_CIDR=252.0.0.0/8 --bootstrap-series=$UBUNTU_SERIES manual/ubuntu@$NODE_IP opensdn-controller
$ juju switch opensdn-controller
$ juju model-config logging-config="<root>=DEBUG"
```

- add machines
```bash
$ juju add-machine ssh:ubuntu@<ip address machines 2-7>
```

The machines should have a ssh access from machine 1.

- create kvms

on machine 2:

prepare image 

```bash
$ cd tf-devstack/contrib/infra/kvm/
$ ./prepare-image.sh ubuntu
```

create kvms
```bash
$ export NODES_COUNT=3
$ export KVM_NETWORK_ADDR="172.31.100.1"
$ ./create_workers.sh
$ sudo iptables -I LIBVIRT_FWI 1  -d 0.0.0.0/0 -o devstack_1  -j ACCEPT
```

add ssh-key from machine 1 to .ssh/authorized_keys to all kvms

on machine 1:
```bash
$ sudo ip route add 172.31.100.0/24 via <ip address machine 2> dev <interface> proto static 
```

add kvms to juju
```bash
juju add-machine ssh:ubuntu@172.31.100.<ip> - add 3 machines to juju
```

## run openstack

```bash
$ juju deploy ./openstack.yaml --map-machines=existing
```
ATTENTION: check paths, registries, image-tags and machine numbers

## run opensdn

```bash
$ juju deploy ./opensdn.yaml --map-machines=existing
```
ATTENTION: check paths, registries, image-tags and machine numbers

add relations between openstack and opensdn

```bash
juju add-relation tf-keystone-auth keystone
juju add-relation tf-openstack neutron-api
juju add-relation tf-openstack heat
juju add-relation tf-openstack nova-compute
juju add-relation tf-agent:juju-info nova-compute:juju-info
juju add-relation tf-controller ntp
```

## Scale test

### Create stackrc file for openstack
machine 1:

```bash
$ auth_ip=$(juju status --format tabular | grep "keystone/" | head -1 | awk '{print $5}')

echo "export OS_AUTH_URL=http://$auth_ip:5050/v3" >> ./stackrc
echo "export OS_IDENTITY_API_VERSION=3" >> ./stackrc
echo "export OS_PROJECT_DOMAIN_NAME=admin_domain" >> ./stackrc
echo "export OS_USER_DOMAIN_NAME=admin_domain" >> ./stackrc
echo "export VGW_DOMAIN=admin_domain" >> ./stackrc
echo "export OS_DOMAIN_NAME=admin_domain" >> ./stackrc
echo "export OS_USERNAME=admin" >> ./stackrc
echo "export OS_TENANT_NAME=admin" >> ./stackrc
echo "export OS_PROJECT_NAME=admin" >> ./stackrc
echo "export OS_PASSWORD=$(juju run --unit keystone/0 leader-get admin_passwd)" >> ./stackrc
echo "export OS_REGION_NAME=$(juju config keystone region)" >> ./stackrc

. stackrc
```

increase quotas

```bash
openstack quota set --instances 9999 $project_id
openstack quota set --cores 1024 $project_id
openstack quota set --ram 10000000 $project_id
openstack quota set  --volumes 10000 $project_id
openstack quota set --gigabytes 10000 $project_id

juju config compute disk-allocation-ratio=25.0 # may be it can be increased in other way
juju config compute cpu-allocation-ratio=4.0
```

create infra for vms
```bash
# create image
wget http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create cirros6 --disk-format qcow2 --public --container-format bare --file cirros-0.6.2-x86_64-disk.img 

# create subnet
openstack network create testvn
openstack subnet create --subnet-range 192.168.128.0/20 --network testvn subnet1
NET_ID=`openstack network list | grep testvn | awk -F '|' '{print $2}' | tr -d ' '`

# create flavor
openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny

# create keypair
openstack keypair create scale_key > .ssh/scale_key
```

### testing

```bash
# 20 vms
for i in $(seq 1 20); do
  openstack server create --flavor m1.tiny --key scale_key --image cirros6 --nic net-id=${NET_ID} vm$i
done
openstack server list | grep -v ACTIVE  # check that there're no errors
for i in $(seq 1 5); do
  time openstack port list  # note real time
done

# 50 vms
for i in $(seq 21 50); do
  openstack server create --flavor m1.tiny --key scale_key --image cirros6 --nic net-id=${NET_ID} vm$i
done
openstack server list | grep -v ACTIVE  # check that there're no errors
for i in $(seq 1 5); do
  time openstack port list  # note real time
done

# 100 vms
for i in $(seq 51 100); do
  openstack server create --flavor m1.tiny --key scale_key --image cirros6 --nic net-id=${NET_ID} vm$i
done
openstack server list | grep -v ACTIVE  # check that there're no errors
for i in $(seq 1 5); do
  time openstack port list  # note real time
done

# 200 vms
for i in $(seq 101 200); do
  openstack server create --flavor m1.tiny --key scale_key --image cirros6 --nic net-id=${NET_ID} vm$i
done
openstack server list | grep -v ACTIVE  # check that there're no errors
for i in $(seq 1 5); do
  time openstack port list  # note real time
done

# 500 vms
for i in $(seq 201 500); do
  openstack server create --flavor m1.tiny --key scale_key --image cirros6 --nic net-id=${NET_ID} vm$i
done
openstack server list | grep -v ACTIVE  # check that there're no errors
for i in $(seq 1 5); do
  time openstack port list  # note real time
done

# 1000 vms
for i in $(seq 501 1000); do
  openstack server create --flavor m1.tiny --key scale_key --image cirros6 --nic net-id=${NET_ID} vm$i
done
openstack server list | grep -v ACTIVE  # check that there're no errors
for i in $(seq 1 5); do
  time openstack port list  # note real time
done
```