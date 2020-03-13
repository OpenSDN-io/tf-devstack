# JuJu deployer

JuJu deployer provides JuJu-based deployment for TF with OpenStack or Kubernetes on Ubuntu.

## Hardware and software requirements

Recommended:

- instance with 8 virtual CPU, 16 GB of RAM and 120 GB of disk space to deploy all-in-one
- Ubuntu 18.04

## Quick start on an AWS instances on base of Kubernetes (all-in-one)

1. Launch new AWS instance.

- Ubuntu 18.04 (x86_64) - with Updates HVM
- c5.2xlarge instance type
- 120 GiB disk Storage

2. Set environment variables:

(optionally - these parameters are set by default)

``` bash
export ORCHESTRATOR='kubernetes'  # by default
export CLOUD='local'  # by default
```

3. Clone this repository and run the startup script:

``` bash
git clone http://github.com/tungstenfabric/tf-devstack
tf-devstack/juju/run.sh
```

4. Wait about 30-60 minutes to complete the deployment.

## Quick start on an AWS instances on base of Openstack

1. Set environment variables:

``` bash
export ORCHESTRATOR='openstack'
export CLOUD='aws'
export AWS_ACCESS_KEY=*aws_access_key*
export AWS_SECRET_KEY=*aws_secret_key*
```

2. Clone this repository and run the startup script:

``` bash
git clone http://github.com/tungstenfabric/tf-devstack
tf-devstack/juju/run.sh
```

## Quick start on an your own instances on base of Openstack

1. Launch 6 nodes:

- instance with 2 virtual CPU, 16 GB of RAM and 300 GB of disk space to deploy JuJu-controller, heat, contrail
- instance with 4 virtual CPU, 8 GB of RAM and 40 GB of disk space to deploy glance, nova-compute
- instance with 4 virtual CPU, 8 GB of RAM and 40 GB of disk space to deploy keystone
- instance with 2 virtual CPU, 8 GB of RAM and 40 GB of disk space to deploy nova-cloud-controller
- instance with 2 virtual CPU, 16 GB of RAM and 300 GB of disk space to deploy neutron
- instance with 2 virtual CPU, 8 GB of RAM and 40 GB of disk space to deploy openstack-dashboard, mysql, rabbit

- Ubuntu 18.04

Open ports 22, 17070 and 37017

2. Make sure that juju-controller node has access to all other nodes.

On JuJu-controller node:

``` bash
ssh-keygen -t rsa
```

Copy created public key

``` bash
cat ~/.ssh/id_rsa.pub
```

and add it to ~/.ssh/authorized_keys on **all** other nodes.

3. On JuJu-controller node set environment variables:

``` bash
export ORCHESTRATOR='openstack'
export CLOUD='manual'
export CONTROLLER_NODES=*access ips of the rest 5 nodes*  # you should specify exactly 5 nodes for manual deployment.
```

4. Clone this repository and run the startup script:

``` bash
git clone http://github.com/tungstenfabric/tf-devstack
tf-devstack/juju/run.sh
```

## Quick start on an MAAS on base of Openstack

1. Set environment variables:

``` bash
export ORCHESTRATOR='openstack'
export CLOUD='maas'
export MAAS_ENDPOINT="*maas_endpoint_url*"
export MAAS_API_KEY="*maas_user_api_key*"
```
2. For deploying with the high availability need seven virtual addresses. These IP addresses must be on the same MAAS subnet where the applications will be deployed, do not overlap with the DHCP range or be reserved. Specify the first IP of seven range addresses in the CIDR notation (the following six IP also will be used) or all seven VIP separated by spaces.
Example:

``` bash
export VIRTUAL_IPS="192.168.51.201/24"
```
or

``` bash
export VIRTUAL_IPS="192.168.51.201 192.168.51.211 192.168.51.214 192.168.51.215 192.168.51.217 192.168.51.228 192.168.51.230"
```

1. Clone this repository and run the startup script:

``` bash
git clone http://github.com/tungstenfabric/tf-devstack
tf-devstack/juju/run.sh
```

## Cleanup

1. Set environment variables:

``` bash
export CLOUD='local'  # by default, another options are 'manual' and 'aws'
```

2. If you're using manual deployment

``` bash
export CONTROLLER_NODES=*access ips of the rest 5 nodes*
```

3. Run the cleanup script:

``` bash
tf-devstack/juju/cleanup.sh
```

## Installation configuration

Juju is deployed on Ubuntu18 by default.
You can select Ubuntu 16 with environment variables before installation.

``` bash
export UBUNTU_SERIES=${UBUNTU_SERIES:-xenial}
./run.sh
```

## Environment variables

Environment variable list:

- UBUNTU_SERIES - version of ubuntu, bionic by default
- CONTAINER_REGISTRY - by default "opencontrailnightly"
- CONTRAIL_CONTAINER_TAG - by default "master-latest"
- JUJU_REPO - path to contrail-charms, "$PWD/contrail-charms" by default
- ORCHESTRATOR - orchestrator for deployment, "openstack" and "kubernetes" (default) are supported
- CLOUD - cloud for juju deployment, "aws" and "local" are supported, "local" by default
- DATA_NETWORK - network for data traffic of workload and for control traffic between compute nodes and control services. May be set as cidr or physical interface. Optional.

## Known Issues

- For CentOS Linux only. If the vrouter agent does not start after installation, this is probably due to an outdated version of the Linux kernel. Update your system kernel to the latest version (yum update -y) and reboot your machin
