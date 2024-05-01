#!/bin/bash

set -o errexit
my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"
source "$my_dir/common.sh"
source "$my_dir/functions.sh"

# parameters
source /etc/lsb-release
UBUNTU_SERIES=${UBUNTU_SERIES:-${DISTRIB_CODENAME}}
CLOUD=${CLOUD:-'manual'}
AWS_ACCESS_KEY=${AWS_ACCESS_KEY:-''}
AWS_SECRET_KEY=${AWS_SECRET_KEY:-''}
AWS_REGION=${AWS_REGION:-'us-east-1'}
MAAS_ENDPOINT=${MAAS_ENDPOINT:-''}
MAAS_API_KEY=${MAAS_API_KEY:-''}
APT_MIRROR=${APT_MIRROR:-''}

# install JuJu and tools
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update -y
for ((i=0; i<5; i++)); do
    if sudo -E apt-get install snap netmask prips python3-jinja2 software-properties-common curl jq dnsutils -y ; then
        break
    fi
    echo "INFO: retry installing tools for juju deploy: $i"
    sleep 2
done
if [[ $i == 5 ]]; then
    echo "ERROR: failed to install tools for juju deploy"
    exit 1
fi

#sudo snap install --classic juju
curl -sSLO https://launchpad.net/juju/2.9/2.9.49/+download/juju-2.9.49-linux-amd64.tar.xz
tar xf juju-2.9.49-linux-amd64.tar.xz 
sudo install -o root -g root -m 0755 juju /usr/local/bin/juju
hash -r

# configure ssh to not check host keys and avoid garbadge in known hosts files
cat <<EOF > $HOME/.ssh/config
Host *
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
EOF
chmod 600 $HOME/.ssh/config

if [[ $CLOUD == 'aws' ]] ; then
    # configure juju to authentificate itself to amazon
    juju remove-credential --client aws aws &>/dev/null || /bin/true
    creds_file="/tmp/creds.yaml"
    cat >"$creds_file" <<EOF
credentials:
  aws:
    aws:
      auth-type: access-key
      access-key: $AWS_ACCESS_KEY
      secret-key: $AWS_SECRET_KEY
EOF
    juju add-credential --client aws -f "$creds_file"
    rm -f "$creds_file"
    juju set-default-region aws $AWS_REGION
fi

if [[ $CLOUD == 'maas' ]] ; then
    juju remove-credential --client maas tf-maas-cloud-creds &>/dev/null || /bin/true
    juju remove-cloud --client maas &>/dev/null || /bin/true
    cloud_file="/tmp/maas_cloud.yaml"
    creds_file="/tmp/maas_creds.yaml"
    cat >"$cloud_file" <<EOF
clouds:
  maas:
    type: maas
    auth-types: [oauth1]
    endpoint: $MAAS_ENDPOINT
EOF
    cat >"$creds_file" <<EOF
credentials:
  maas:
    tf-maas-cloud-creds:
      auth-type: oauth1
      maas-oauth: $MAAS_API_KEY
EOF
    juju add-cloud --local maas -f $cloud_file
    juju add-credential --client maas -f $creds_file
    rm -f "$cloud_file $creds_file"
fi

# prepare ssh key authorization for running bootstrap on the same node
set_ssh_keys

# the juju will be bootstrapped to the machine 0, except manual deploy with specified
# controller and/or agent nodes
SWITCH_OPT='--no-switch'
if [[ $CLOUD == 'manual' ]] ; then
    if [[ ( -n "$CONTROLLER_NODES" && "$CONTROLLER_NODES" != $NODE_IP ) ]] ; then
      SWITCH_OPT=''
    fi
fi
# bootstrap JuJu-controller
if [[ $CLOUD == 'aws' ]]; then
    juju bootstrap --no-switch --bootstrap-series=$UBUNTU_SERIES --bootstrap-constraints "mem=31G cores=8 root-disk=120G" $CLOUD tf-$CLOUD-controller
elif [[ $CLOUD == 'maas' ]]; then
    juju bootstrap --config juju-mgmt-space=default --bootstrap-series=$UBUNTU_SERIES --bootstrap-constraints "mem=4G cores=2 root-disk=40G" $CLOUD tf-$CLOUD-controller
    SWITCH_OPT=''
    juju model-config default-space=default
elif [[ $CLOUD == 'manual' ]]; then
    juju bootstrap $SWITCH_OPT --config container-networking-method=fan --config fan-config=$NODE_CIDR=252.0.0.0/8 --bootstrap-series=$UBUNTU_SERIES manual/ubuntu@$NODE_IP tf-$CLOUD-controller
else
    echo "ERROR: unknown type of cloud: $CLOUD"
    exit 1
fi
if [[ -n $SWITCH_OPT ]] ; then
    juju switch tf-$CLOUD-controller
fi

juju model-config logging-config="<root>=DEBUG"
if [[ -n "$APT_MIRROR" ]]; then
    juju model-config apt-mirror=$APT_MIRROR
fi
