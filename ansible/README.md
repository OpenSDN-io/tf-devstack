# ansible-deployer

Ansible deployer provides ansible-based deployment for TF with OpenStack or Kubernetes.

## Hardware and software requirements

Recommended:

- AWS instance with 4 virtual CPU, 16 GB of RAM and 50 GB of disk space to deploy from published containers
- AWS instance with 4 virtual CPU, 16 GB of RAM and 80 GB of disk space to build and deploy from sources

Minimal:

- VirtualBox VM with 2 CPU, 8 GB of RAM and 30 GB of disk to deploy from published containers with Kubernetes.
- VirtualBox VM with 2 CPU, 10 GB of RAM and 30 GB of disk to deploy from published containers with OpenStack.

OS:

- Centos 7
- Ubuntu 18.04, 20.04

NOTE: Windows and MacOS deployments are not supported, please use VM (like VirtualBox) with Linux to run tf-devstack on such machines.

## Quick start on AWS instance(s)

1. For all-in-one node deployment launch the new AWS instance:

    - CentOS 7 (x86_64) - with Updates HVM
    - t2.xlarge instance type
    - 120 GiB disk Storage

1.1. Skip this for all-in-one node deployment. For multinode deployment (3 controller, 2 agents):

- launch 4 more instances and ensure ssh connectivity from devstack node to others.
- make sure that:
  - 22 port is open between nodes.
  - User has to have sudoers right on all the nodes.
  - The ssh users can run sudo without password right on all the nodes.

- set on devstack node:

``` bash
export ORCHESTRATOR='openstack'
export CONTROLLER_NODES='IP1,IP2,IP3'
export AGENT_NODES='IP4,IP5'
```

2. Install git to clone this repository:

``` bash
sudo yum install -y git
```

3. Clone this repository and run the startup script:

``` bash
git clone http://github.com/opensdn-io/tf-devstack
./tf-devstack/ansible/run.sh
```

4. Wait about 30-60 minutes to complete the deployment.

## Installation configuration

OpenSDN is deployed with Kubernetes as orchestrator by default.
You can select OpenStack as orchestrator with environment variables before installation.

``` bash
export ORCHESTRATOR=openstack
export OPENSTACK_VERSION=train
./run.sh
```

OpenStack version may be selected from train(default), (TODO: support next releases).

## Customized deployments and deployment steps

run.sh accepts the following targets:

Complete deployments:

- (empty) - deploy kubernetes or openstack with TF and wait for completion
- master - build existing master, deploy kubernetes or openstack with TF, and wait for completion
- all - same as master

Individual stages:

- build - tf-dev-env container is fetched, TF is built and stored in local registry
- k8s - kubernetes is deployed (unless ORCHESTRATOR=openstack)
- openstack - openstack is deployed (unless ORCHESTRATOR=kubernetes)
- tf - TF is deployed
- wait - wait until opensdn-status verifies that all components are active

## Details

To deploy OpenSDN from published containers
[tf-container-deployer playbooks](https://github.com/opensdn-io/tf-ansible-deployer) is used. For building step
[tf-dev-env environment](https://github.com/opensdn-io/tf-dev-env) is used.

Preparation script allows root user to connect to host via ssh, install and configure docker,
build tf-dev-control container.

Environment variable list:

- ORCHESTRATOR kubernetes by default or openstack
- OPENSTACK_VERSION train/stein/ussuri, variable is used when ORCHESTRATOR=openstack
- NODE_IP a IP address used as CONTROLLER_NODES and CONTROL_NODES
- CONTAINER_REGISTRY - by default "opensdn"
- CONTRAIL_CONTAINER_TAG - by default "latest"
- CONTRAIL_DEPLOYER_CONTAINER_TAG - by default equal to CONTRAIL_CONTAINER_TAG
- K8S_YUM_REPO_URL - https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64 by default

## Access WebUI in AWS or other environments

If you don't have access to WebUI address you can use ssh tunneling and Firefox with proxy.
For that you should:

- run Firefox and set it to use sock5 proxy : localhost 8000
- ssh -D 8000 -N centos@TF.node.ip.address

Then use the IP:Port/login/password displayed at the end of the output produced by run.sh

## Known issues

- When the system is installed, after running cleanup.sh, repeated run.sh leads to an error
- For CentOS Linux only. If the vrouter agent does not start after installation, this is probably due to an outdated version of the Linux kernel. Update your system kernel to the latest version (yum update -y) and reboot your machine
- Deployment scripts are tested on CentOS 7 / Ubuntu 18.04 and AWS / Virtualbox
- Occasional errors prevent deployment of Kubernetes on a VirtualBox machine, retry can help
- One or more of OpenSDN containers are in "Restarting" status after installation,
try waiting 2-3 minutes or reboot the instance
- One or more pods in "Pending" state, try to "kubectl taint nodes NODENAME node-role.kubernetes.io/master-",
where NODENAME is name from "kubectl get node"
- OpenStack/rocky web UI reports "Something went wrong!",
try using CLI (you need install python-openstackclient in virtualenv)
- OpenStack/ocata can't find host to spawn VM,
set virt_type=qemu in [libvirt] section of /etc/kolla/config/nova/nova-compute.conf file inside nova_compute container,
then restart this container
