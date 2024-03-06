
# max wait in seconds after deployment
export WAIT_TIMEOUT=3600

#PROVIDER = [ kvm | openstack | aws | bmc ]
export PROVIDER=${PROVIDER:-}
[ -n "$PROVIDER" ] || { echo "ERROR: PROVIDER is not set"; exit -1; }
if [[ "$PROVIDER" == 'vexx' ]]; then
    # backward compatibility
    PROVIDER='openstack'
fi

export ENVIRONMENT_OS=${ENVIRONMENT_OS:-'rhel7'}
export DEPLOYER='rhosp'
export ORCHESTRATOR=${ORCHESTRATOR:-'openstack'}

export CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"docker.io/opensdn"}
export CONTROL_PLANE_ORCHESTRATOR=${CONTROL_PLANE_ORCHESTRATOR:-''}
export OPENSTACK_CONTROLLER_NODES=${OPENSTACK_CONTROLLER_NODES:-}
export CONTROLLER_NODES=${CONTROLLER_NODES:-'v3-standard-8:1'}
export AGENT_NODES=${AGENT_NODES:-}
export DPDK_AGENT_NODES=${DPDK_AGENT_NODES:-}
if [[ "$CONTROLLER_NODES" == "$NODE_IP" ]] ; then
    # Default case.
    # but in rhosp NODE_IP is either jumphost (kvm)
    # or an undercloud. So, set to default to count 1 AIO node.
    CONTROLLER_NODES="v3-standard-8:1"
fi
if [[ "$AGENT_NODES" == "$NODE_IP" ]] ; then
    # Default case - AIO.
    # but in rhosp NODE_IP is either jumphost (kvm)
    # or an undercloud. So, set to default to count 1 AIO node.
    AGENT_NODES=""
fi

declare -A _default_rhel_version=( ['rhel7']='rhel7.9' ['rhel82']='rhel8.2' ['rhel84']='rhel8.4' )
export RHEL_VERSION=${_default_rhel_version[$ENVIRONMENT_OS]}
export RHEL_MAJOR_VERSION=$(echo $RHEL_VERSION | cut -d '.' -f1)

declare -A _container_cli_tools=( ['rhel7']='docker' ['rhel8']='podman' )
export CONTAINER_CLI_TOOL=${_container_cli_tools[$RHEL_MAJOR_VERSION]}

declare -A _default_rhosp_version=( ['rhel7']='rhosp13' ['rhel82']='rhosp16.1' ['rhel84']='rhosp16.2' )
export RHOSP_VERSION=${_default_rhosp_version[$ENVIRONMENT_OS]}
export RHOSP_MAJOR_VERSION=$(echo $RHOSP_VERSION | cut -d '.' -f1)

declare -A _default_predeployed_mode=( ['openstack']='true' ['kvm']='false' ['bmc']='false' )
export USE_PREDEPLOYED_NODES=${USE_PREDEPLOYED_NODES:-${_default_predeployed_mode[$PROVIDER]}}

declare -A _default_rhel_registration=( ['openstack']='false' ['kvm']='true' ['bmc']='false' )
export ENABLE_RHEL_REGISTRATION=${ENABLE_RHEL_REGISTRATION:-${_default_rhel_registration[$PROVIDER]}}

declare -A _default_net_isolation=( ['openstack']='false' ['kvm']='false' ['bmc']='true' )
export ENABLE_NETWORK_ISOLATION=${ENABLE_NETWORK_ISOLATION:-${_default_net_isolation[$PROVIDER]}}

declare -A _default_openstack_version=( ['rhosp13']='queens' ['rhosp16']='train' )
export OPENSTACK_VERSION=${OPENSTACK_VERSION:-${_default_openstack_version[$RHOSP_MAJOR_VERSION]}}

declare -A _osc_registry_default=( ['rhosp13']='registry.access.redhat.com' ['rhosp16']='registry.redhat.io' )
export OPENSTACK_CONTAINER_REGISTRY=${OPENSTACK_CONTAINER_REGISTRY:-${_osc_registry_default[${RHOSP_MAJOR_VERSION}]}}

declare -A _osc_tag_default=( ['rhosp13']='13.0' ['rhosp16.1']='16.1' ['rhosp16.2']='16.2' )
export OPENSTACK_CONTAINER_TAG=${OPENSTACK_CONTAINER_TAG:-${_osc_tag_default[${RHOSP_VERSION}]}}

declare -A _rhsm_releases=( ["rhosp13"]='7.9' ['rhosp16.1']='8.2' ['rhosp16.2']='8.4' )
export RHSM_RELEASE=${_rhsm_releases[$RHOSP_VERSION]}

export IPMI_USER=${IPMI_USER:-'ADMIN'}
export IPMI_PASSWORD=${IPMI_PASSWORD:-'ADMIN'}
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-'qwe123QWE'}

export undercloud_local_interface=${undercloud_local_interface:-'eth1'}

declare -A _default_ssh_user=( ['openstack']='cloud-user' ['kvm']='stack' ['bmc']="stack" )
export SSH_USER=${SSH_USER:-${_default_ssh_user[$PROVIDER]}}

declare -A _default_ssh_user_overcloud=( ['openstack']='cloud-user' ['kvm']='heat-admin' ['bmc']="heat-admin" )
export SSH_USER_OVERCLOUD=${SSH_USER_OVERCLOUD:-${_default_ssh_user_overcloud[$PROVIDER]}}

export SSH_EXTRA_OPTIONS=${SSH_EXTRA_OPTIONS:-}
export ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no"

export NTP_SERVERS=${NTP_SERVERS:-"3.europe.pool.ntp.org"}

# internalapi => neutron - for rhosp13 only
declare -A RHOSP_NETWORKS=( \
    ['ctlplane']='contrail HTTP haproxy' \
    ['internalapi']='contrail HTTP haproxy novnc-proxy redis rabbitmq neutron mysql libvirt libvirt-vnc qemu' \
    ['storage']='HTTP haproxy' \
    ['storagemgmt']='HTTP haproxy' \
    ['external']='HTTP haproxy' \
    ['tenant']='contrail' \
)
declare -A RHOSP_VIP_NETWORKS=( \
    ['ctlplane']='haproxy' \
    ['internalapi']='haproxy redis mysql' \
    ['storage']='haproxy' \
    ['storagemgmt']='haproxy' \
    ['external']='' \
    ['tenant']='' \
)
export RHOSP_NETWORKS
export RHOSP_VIP_NETWORKS

# empty - disabled
# ipa   - use FreeIPA
export ENABLE_TLS=${ENABLE_TLS:-}
if [[ -n "$ENABLE_TLS" && "$ENABLE_TLS" != 'ipa' && "$ENABLE_TLS" != 'local' ]] ; then
  echo "ERROR: Unsupported TLS configuration $ENABLE_TLS"
  exit 1
fi

if [[ "$ENABLE_RHEL_REGISTRATION" == 'true' ]] ; then
    if [[ -z ${RHEL_USER+x} ]]; then
        echo "There is no Red Hat Credentials. Please export variable RHEL_USER "
        exit 1
    fi

    if [[ -z ${RHEL_PASSWORD+x} ]]; then
        echo "There is no Red Hat Credentials. Please export variable RHEL_PASSWORD "
        exit 1
    fi
fi
