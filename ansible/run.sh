#!/bin/bash

set -o errexit
my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"
source "$my_dir/../common/common.sh"
source "$my_dir/../common/functions.sh"
source "$my_dir/../common/stages.sh"
source "$my_dir/../common/collect_logs.sh"
source "$my_dir/functions.sh"

init_output_logging

# stages declaration

declare -A STAGES=( \
    ["all"]="build machines k8s openstack tf wait logs" \
    ["default"]="machines k8s openstack tf wait" \
    ["master"]="build machines k8s openstack tf wait" \
    ["platform"]="machines k8s openstack" \
)

# default env variables
export DEPLOYER='ansible'
# max wait in seconds after deployment
# 300 is small sometimes - NTP sync can be an issue
export WAIT_TIMEOUT=600

tf_deployer_dir=${WORKSPACE}/tf-ansible-deployer
openstack_deployer_dir=${WORKSPACE}/contrail-kolla-ansible
tf_deployer_image=${TF_ANSIBLE_DEPLOYER:-"opensdn-ansible-deployer-src"}
openstack_deployer_image=${OPENSTACK_DEPLOYER:-"opensdn-kolla-ansible-src"}

export ANSIBLE_CONFIG=$tf_deployer_dir/ansible.cfg

export OPENSTACK_VERSION=${OPENSTACK_VERSION:-yoga}
#type of kolla-ansible installation: patched (by default) or vanilla
export KOLLA_MODE=${KOLLA_MODE:-patched}
export AUTH_PASSWORD='contrail123'
export VIRT_TYPE=qemu

export KOLLA_BASE_DISTRO="centos"
if [[ "$OPENSTACK_VERSION" == "zed" || "$OPENSTACK_VERSION" == "2023.1" || "$OPENSTACK_VERSION" == "2023.2" ]]; then
  export KOLLA_BASE_DISTRO="rocky"
fi

export DOMAINSUFFIX=${DOMAINSUFFIX-$(hostname -d)}

# deployment related environment set by any stage and put to tf_stack_profile at the end
declare -A DEPLOYMENT_ENV=( \
    ['AUTH_PASSWORD']="$AUTH_PASSWORD" \
    ['AUTH_URL']=''\
)

function build() {
    "$my_dir/../common/dev_env.sh"
}

function machines() {
    # install required packages

    echo "INFO: $DISTRO detected"
    if [[ "$DISTRO" == "ubuntu" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        sudo -E apt-get update -y
        sudo -E apt-get install -y curl python3-setuptools iproute2 python3-cryptography jq dnsutils chrony python3-pip python3-virtualenv
        if [[ "$DISTRO_VERSION_ID" = "20.04" || "$DISTRO_VERSION_ID" = "22.04" ]]; then
            sudo -E apt-get install -y curl python3-distutils
            # required for old versions of kolla where shebang is python
            sudo -E ln -sf /usr/bin/python3 /usr/bin/python
        fi
    elif [[ "$DISTRO" == "rocky" ]]; then
        sudo dnf check-update || true
        # curl is upgrading below and leads to upgrade of openssl. but also we have to upgrade openssh
        sudo dnf install -y curl python3 python3-setuptools libselinux-python3 iproute jq bind-utils python3-pip openssh-server openssh-clients python3-virtualenv
    else
        echo "Unsupported OS version - $DISTRO"
        exit 1
    fi

    ansible_pkg="ansible<3"
    if [[ ${OPENSTACK_VERSION:0:4} == '2023' ]]; then
        ansible_pkg="ansible<8"
    elif [[ ${OPENSTACK_VERSION:0:1} > 'x' || "$ORCHESTRATOR" == "kubernetes" ]]; then
        ansible_pkg="ansible<6"
    fi

    if [[ "$DISTRO" == "ubuntu" && "$DISTRO_VERSION_ID" == "24.04" ]]; then
        # it has python 3.12 which is supported in ansible >=9
        # TODO: check openstack_version and exit with error if unsupported for 24.04
        ansible_pkg="ansible>=9,<10"
    fi

    virtualenv $HOME/.venv
    source $HOME/.venv/bin/activate

    # jinja is reqiured to create some configs
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 python3 -m pip install --upgrade "$ansible_pkg" 'jinja2==3.0.3' pyopenssl requests

    set_ssh_keys

    if ! fetch_deployer_no_docker $tf_deployer_image $tf_deployer_dir ; then
        echo "WARNING: failed to fetch $tf_deployer_image, try old_ansible_fetch_deployer"
        "$my_dir/../common/install_docker.sh"
        old_ansible_fetch_deployer
    elif [[ "$ORCHESTRATOR" == "openstack" ]] ; then
        fetch_deployer_no_docker $openstack_deployer_image $openstack_deployer_dir
    fi

    # generate inventory file
    python3 $my_dir/../common/jinja2_render.py < $my_dir/files/instances.yaml.j2 > $tf_deployer_dir/instances.yaml

    # fix dns
    if [ -f /run/systemd/resolve/resolv.conf ] ; then
        sudo rm -rf /etc/resolv.conf
        sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi

    # create Ansible temporary dir under current user to avoid create it under root
    ansible -m "copy" --args="content=c dest='/tmp/rekjreekrbjrekj.txt'" localhost
    rm -rf /tmp/rekjreekrbjrekj.txt

    ansible-playbook -v -e orchestrator=$ORCHESTRATOR \
        -e config_file=$tf_deployer_dir/instances.yaml \
        $tf_deployer_dir/playbooks/configure_instances.yml
    if [[ $? != 0 ]] ; then
        echo "Installation aborted. Instances preparation failed."
        exit 1
    fi
}

function k8s() {
    if [[ "$ORCHESTRATOR" != "kubernetes" ]]; then
        echo "INFO: Skipping k8s deployment"
    else
        source $HOME/.venv/bin/activate
        ansible-playbook -v -e orchestrator=$ORCHESTRATOR \
            -e config_file=$tf_deployer_dir/instances.yaml \
            $tf_deployer_dir/playbooks/install_k8s.yml
    fi
}

function openstack() {
    if [[ "$ORCHESTRATOR" != "openstack" ]]; then
        echo "INFO: Skipping openstack deployment"
        return
    fi

    sudo mkdir -p /etc/kolla
    sudo chown -R $(id -u):$(id -g) /etc/kolla

    if [[ "$KOLLA_MODE" == "vanilla" ]]; then
        source $HOME/.venv/bin/activate
        ansible-playbook -v -e orchestrator=$ORCHESTRATOR \
            -e config_file=$tf_deployer_dir/instances.yaml \
            $tf_deployer_dir/playbooks/install_vanilla_openstack.yml
    else
        source $HOME/.venv/bin/activate
        ansible-playbook -v -e orchestrator=$ORCHESTRATOR \
            -e config_file=$tf_deployer_dir/instances.yaml \
            $tf_deployer_dir/playbooks/install_openstack.yml
    fi
}

function tf() {
    current_container_tag=$(cat $tf_deployer_dir/instances.yaml | python3 -c "import yaml, sys ; data = yaml.safe_load(sys.stdin.read()); print(data['contrail_configuration']['CONTRAIL_CONTAINER_TAG'])")
    current_registry=$(cat $tf_deployer_dir/instances.yaml | python3 -c "import yaml, sys ; data = yaml.safe_load(sys.stdin.read()); print(data['global_configuration']['CONTAINER_REGISTRY'])")

    source $HOME/.venv/bin/activate

    if [[ $current_container_tag != $CONTRAIL_CONTAINER_TAG || $current_registry != $CONTAINER_REGISTRY ]]; then
        # generate new inventory file due to possible new input
        python3 $my_dir/../common/jinja2_render.py < $my_dir/files/instances.yaml.j2 > $tf_deployer_dir/instances.yaml

        ansible-playbook -v -e orchestrator=$ORCHESTRATOR \
            -e config_file=$tf_deployer_dir/instances.yaml \
            $tf_deployer_dir/playbooks/configure_instances.yml

        if [[ "$ORCHESTRATOR" == "openstack" && "$KOLLA_MODE" != "vanilla" ]]; then
            ansible-playbook -v -e orchestrator=$ORCHESTRATOR \
                -e config_file=$tf_deployer_dir/instances.yaml \
                $tf_deployer_dir/playbooks/install_openstack.yml \
                --tags "nova,neutron,heat"
        fi
    fi

    local opensdn_playbook="$tf_deployer_dir/playbooks/install_opensdn.yml"
    if [ ! -f "$opensdn_playbook" ]; then
        opensdn_playbook="$tf_deployer_dir/playbooks/install_contrail.yml"
    fi
    ansible-playbook -v -e orchestrator=$ORCHESTRATOR \
        -e config_file=$tf_deployer_dir/instances.yaml \
        "$opensdn_playbook"

    if [[ "$ORCHESTRATOR" == "openstack" && "$KOLLA_MODE" == "vanilla" ]]; then
        ansible-playbook -v -e orchestrator=$ORCHESTRATOR \
            -e config_file=$tf_deployer_dir/instances.yaml \
            $tf_deployer_dir/playbooks/config_openstack.yml
    fi

    if ! wait_cmd_success "wait_vhost0_up ${AGENT_NODES}" 5 24
    then
        echo "vhost0 interface(s) cannot obtain an IP address"
        return 1
    fi
    sync_time
    echo "TF Web UI must be available at https://$NODE_IP:8143"
    [ "$ORCHESTRATOR" == "openstack" ] && echo "OpenStack UI must be avaiable at http://$NODE_IP"
    echo "Use admin/$AUTH_PASSWORD to log in"
}

# This is_active function is called in wait stage defined in common/stages.sh

function is_active() {
    # Services to check in wait stage
    AGENT_SERVICES['_']+="rsyslogd "
    CONTROLLER_SERVICES['config']+="dnsmasq "

    if [[ "$ORCHESTRATOR" == "kubernetes" ]]; then
        check_pods_active
    fi

    check_tf_active && check_tf_services
}

function collect_deployment_env() {
    cp $tf_deployer_dir/instances.yaml $TF_CONFIG_DIR/

    if [[ $ORCHESTRATOR == 'openstack' || "$ORCHESTRATOR" == "hybrid" ]] ; then
        sudo chmod -R a+r $openstack_deployer_dir/etc/kolla/ || /bin/true
        cp $openstack_deployer_dir/etc/kolla/* $TF_CONFIG_DIR/ || /bin/true
        DEPLOYMENT_ENV['OPENSTACK_CONTROLLER_NODES']="$(echo $CONTROLLER_NODES | cut -d ' ' -f 1)"

        local auth_ip=$(echo "$CONTROLLER_NODES" | tr ' ' ',' | cut -d ',' -f 1)
        local proto="http"
        if [[ "${SSL_ENABLE,,}" == 'true' ]] ; then
            proto="https"
        fi
        DEPLOYMENT_ENV['OS_AUTH_URL']="$proto://$auth_ip:5000/v3"
    fi

    if ! is_after_stage 'wait' ; then
        # kubeconfig is needed after wait stage only
        return 0
    fi

    if [[ "$ORCHESTRATOR" == "kubernetes" || "$ORCHESTRATOR" == "hybrid" ]]; then
        # Copying kubeconfig from the master node
        mkdir -p ~/.kube
        local node
        for node in $CONTROLLER_NODES ; do
            if ssh $SSH_OPTIONS $node "sudo test -f /root/.kube/config && sudo cat /root/.kube/config" > ~/.kube/config ; then
                sudo chown -R $(id -u):$(id -g) ~/.kube
                return 0
            fi
        done
        echo "No kube config was found on $CONTROLLER_NODES"
    fi
}

function collect_logs() {
    cp $TF_CONFIG_DIR/*.yaml ${TF_LOG_DIR}/ || /bin/true
    cp $TF_CONFIG_DIR/*.yml ${TF_LOG_DIR}/ || /bin/true
    collect_logs_from_machines
}

run_stages $STAGE
