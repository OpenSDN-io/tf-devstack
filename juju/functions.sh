#!/bin/bash

# in hybrid deploy keystone port is conflicting with auth-webhook port
export KEYSTONE_SERVICE_PORT=5050

# lp:1616098 Pick reachable address among all
function get_juju_unit_ips(){
  local unit=$1

  local unit_list="`command juju status | grep "$unit/" | tr -d "*" | awk '{print $1}'`"
  local ips
  for unit in $unit_list ; do
    unit_machine="`command juju show-unit --format json $unit | jq -r .[].machine`"
    local machine_ips="`command juju show-machine --format json $unit_machine | jq -r '.machines[]."ip-addresses"[]'`"
    if  [[ "`echo $machine_ips | wc -w`" == 1 ]] ; then
      ips+=" $machine_ips"
    else
      local ip
      for ip in $machine_ips ; do
        if nc -z $ip 22 ; then
          ips+=" $ip"
          break
        fi
      done
    fi
  done
  ips=$(echo "$ips" | sed 's/ /\n/g' | sort | uniq)
  echo $ips
}

function create_stackrc() {
  local auth_ip=$(command juju config keystone vip)
  if [[ -z "$auth_ip" ]]; then
    auth_ip=$(command juju status $service --format tabular | grep "keystone/" | head -1 | awk '{print $5}')
  fi
  local proto="http"
  # TODO: add detection is SSL for openstack enabled
  local kver=`command juju config keystone preferred-api-version`
  echo "# created by CI" > $WORKSPACE/stackrc
  if [[ "$kver" == '3' ]] ; then
    echo "export OS_AUTH_URL=$proto://$auth_ip:$KEYSTONE_SERVICE_PORT/v3" >> $WORKSPACE/stackrc
    echo "export OS_IDENTITY_API_VERSION=3" >> $WORKSPACE/stackrc
    echo "export OS_PROJECT_DOMAIN_NAME=admin_domain" >> $WORKSPACE/stackrc
    echo "export OS_USER_DOMAIN_NAME=admin_domain" >> $WORKSPACE/stackrc
    echo "export VGW_DOMAIN=admin_domain" >> $WORKSPACE/stackrc
    echo "export OS_DOMAIN_NAME=admin_domain" >> $WORKSPACE/stackrc
  else
    echo "export OS_AUTH_URL=$proto://$auth_ip:$KEYSTONE_SERVICE_PORT/v2.0" >> $WORKSPACE/stackrc
    echo "export OS_IDENTITY_API_VERSION=2" >> $WORKSPACE/stackrc
    echo "export VGW_DOMAIN=default-domain" >> $WORKSPACE/stackrc
  fi
  echo "export OS_USERNAME=admin" >> $WORKSPACE/stackrc
  echo "export OS_TENANT_NAME=admin" >> $WORKSPACE/stackrc
  echo "export OS_PROJECT_NAME=admin" >> $WORKSPACE/stackrc
  echo "export OS_PASSWORD=$(command juju run --unit keystone/0 leader-get admin_passwd)" >> $WORKSPACE/stackrc
  echo "export OS_REGION_NAME=$(command juju config keystone region)" >> $WORKSPACE/stackrc
}

function get_keystone_address() {
  local keystone_addresses=$(command juju config keystone vip)
  if [[ -z $keystone_addresses ]] ; then
    keystone_addresses=$(command juju status --format json | jq '.applications["keystone"]["units"][]["public-address"]' | sed 's/"//g' | sed 's/\n//g')
  fi
  echo $keystone_addresses | head -n 1
}

function get_service_machine() {
  local service=$1
  local jq_request=".applications[\"$service\"][\"units\"][][\"machine\"]"
  machine=$(command juju status --format json | jq "$jq_request" | sed 's/"//g' | awk -F '/' '{print$1}' | head -n 1)
  echo $machine
}

function setup_iptables_persistent() {
  command juju ssh $1 <<'EOF'
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y iptables-persistent
EOF
}

function setup_keystone_auth() {
  echo "INFO: setup keystone auth for hybrid mode"
  command juju config kubernetes-control-plane \
      authorization-mode="Node,RBAC" \
      enable-keystone-authorization=true \
      keystone-policy="$(cat $my_dir/files/k8s_policy.yaml)"

  if [[ $CLOUD == 'maas' ]] ; then
    echo "INFO: skip keystone auth for MAAS cloud (TODO)"
    return
  fi

  local keystone_address=$(get_keystone_address)
  if [[ -z $keystone_address ]] ; then
    echo "ERROR: Cannot detect the keystone address. It is needed for reachabilty to keystone from keystone-auth-pods."
    exit 1
  fi
  echo "INFO: keystone address is $keystone_address"

  # detect host address
  keystone_machine=$(get_service_machine keystone)
  host_address=$(command juju ssh $keystone_machine 'ip route get 1' | awk '/ src /{print $7}')
  if [[ -z $host_address ]] ; then
    host_address=$(command juju ssh $keystone_machine 'hostname -i' | cut -f 1 -d ' ')
  fi
  if [[ -z $host_address ]] ; then
    echo "ERROR: Cannot detect the host address for machine with keystone. It is needed for reachabilty to keystone from keystone-auth-pods."
    exit 1
  fi
  echo "INFO: host address of keystone is $host_address"

  # the keystone should listen on vhost0 network
  # we need the reachability between keystone and keystone auth pod via vhost0 interface
  echo "INFO: setup iptables persistent"
  retry setup_iptables_persistent $keystone_machine

  echo "INFO: set iptables rules"
  command juju ssh $keystone_machine << EOF
sudo iptables --wait -A PREROUTING -t nat -p tcp --dport  $KEYSTONE_SERVICE_PORT -j DNAT --to $keystone_address:$KEYSTONE_SERVICE_PORT
sudo iptables --wait -A PREROUTING -t nat -p tcp --dport 35357 -j DNAT --to $keystone_address:35357
sudo iptables --wait -A OUTPUT -t nat -p tcp --dport  $KEYSTONE_SERVICE_PORT -j DNAT --to $keystone_address:$KEYSTONE_SERVICE_PORT
sudo iptables --wait -A OUTPUT -t nat -p tcp --dport 35357 -j DNAT --to $keystone_address:35357
sudo iptables --wait -A FORWARD -p tcp --dport  $KEYSTONE_SERVICE_PORT -j ACCEPT
sudo iptables --wait -A FORWARD -p tcp --dport 35357 -j ACCEPT
sudo netfilter-persistent save
EOF

  echo "INFO: redefine keystone endpoints"
  command juju config keystone os-public-hostname=$host_address os-admin-hostname=$host_address
}

function collect_logs_from_machines() {
  cat <<EOF >/tmp/logs.sh
#!/bin/bash
tgz_name=\$1
export WORKSPACE=/tmp/juju-logs
export TF_LOG_DIR=/tmp/juju-logs/logs
export SSL_ENABLE=$SSL_ENABLE
cd /tmp/juju-logs
source ./collect_logs.sh
collect_docker_logs
collect_juju_logs
collect_tf_status
collect_system_stats
collect_tf_logs
collect_core_dumps
collect_openstack_logs
collect_kubernetes_logs
collect_kubernetes_objects_info
collect_docker_service_statuses
sudo chmod -R a+r logs
pushd logs
tar -czf \$tgz_name *
popd
cp logs/\$tgz_name \$tgz_name
sudo rm -rf logs
EOF
chmod a+x /tmp/logs.sh

  local machines=`timeout -s 9 30 juju machines --format tabular | tail -n +2 | awk '{print $1}'`
  echo "INFO: machines to ssh: $machines"
  local machine=''
  for machine in $machines ; do
    echo "INFO: collecting from $machine"
    local tgz_name=`echo "logs-$machine.tgz" | tr '/' '-'`
    mkdir -p $TF_LOG_DIR/$machine
    command juju ssh $machine "mkdir -p /tmp/juju-logs"
    command juju scp $my_dir/../common/collect_logs.sh $machine:/tmp/juju-logs/collect_logs.sh
    command juju scp /tmp/logs.sh $machine:/tmp/juju-logs/logs.sh
    command juju ssh $machine /tmp/juju-logs/logs.sh $tgz_name
    command juju scp $machine:/tmp/juju-logs/$tgz_name $TF_LOG_DIR/$machine/
    pushd $TF_LOG_DIR/$machine/
    tar -xzf $tgz_name
    rm -rf $tgz_name
    popd
  done
}

# This is_ready function is called after openstack and k8s stages
function is_ready() {
  # constants
  local max_errors=10
  # nova-compute just for checking
  # https://bugs.launchpad.net/charm-nova-compute/+bug/1934123
  local allowed_not_active="neutron-api nova-compute kubernetes-control-plane kubernetes-master kubernetes-worker ironic-conductor mysql-innodb-cluster"

  # TODO: rework to jq
  # juju status --format json | jq -r '.applications[] | ."charm-name" + " " +  ."application-status".current'
  local status=`$(which juju) status --format short`
  local error_apps=`echo "$status" | grep error | awk '{print$2}' | sed 's/://g'`
  local app=''
  for app in $error_apps ; do
    local all_errors=`$(which juju) show-status-log $app --days 1 | grep error | wc -l`
    if (( all_errors > max_errors )); then
      echo "ERROR: Deployment has unrecoverable error state. Exiting..."
      echo "ERROR: status:"
      echo "$status"
      echo "ERROR: status-log for app $app:"
      $(which juju) show-status-log $app --days 1
      # immediately exit from wait function due to unrecoverable error state
      exit 1
    fi
  done
  local blocked_apps=`echo "$status" | grep blocked | awk '{print$2}' | cut -f1 -d"/"`
  local waiting_apps=`echo "$status" | grep waiting | awk '{print$2}' | cut -f1 -d"/"`
  for app in $blocked_apps $waiting_apps ; do
    if [[ $allowed_not_active != *"$app"* ]] ; then
      # continue waiting
      return 1
    fi
  done
  [[ ! $(echo "$status" | egrep 'executing') ]]
}

function check_kubernetes_master_cert() {
  # NOTE: kubernetes can't be deployed in AIO configuration properly -
  # worker and master charms have same place for server.crt and thus if
  # worker writes it after master then master can't accept connections
  # to some IP-s/names.
  # If this deployment has kubernetes in AIO and it's server cert is incorrect
  # then script has to override it. just one way was found. it's to add
  # something to extra_sans after deployment
  if [[ $ORCHESTRATOR != 'hybrid' && $ORCHESTRATOR != 'kubernetes' ]]; then
    # only kubernetes related
    return 0
  fi
  if [[ "$CONTROLLER_NODES" != "$AGENT_NODES" ]]; then
    # only specific AIO setup
    return 0
  fi
  if sudo grep -q "fake-name" /root/cdk/server.crt ; then
    # only if cert doesn't have specific server's IP
    command juju run-action --wait kubernetes-control-plane/leader restart
    return 0
  fi

  # change setting
  if ! command juju config kubernetes-control-plane extra_sans | grep -q 'fake-name' ; then
    command juju config kubernetes-control-plane extra_sans='fake-name'
    # wait a bit to let hook run. then return back to wait loop
    sleep 10
  fi
  return 1
}

function configure_mtu() {
  # hack for ubuntu20.04 - we have MTU=1458 in CI. juju sets 1408 for ubuntu18.04 and all things work well.
  # but in ubuntu20.04 it sets MTU=1450 and fan network doesn't work stable.
  # thus set MTU manually for all fan devices (and for local machine also!)

  local mtu=$(ip link show $PHYS_INT | grep -Eo "mtu [0-9]+" | cut -f 2 -d ' ')
  echo "INFO: MTU=$mtu on parent interface $PHYS_INT"
  mtu=$((mtu-50))

  echo "INFO: set mtu for local machine"
  sudo ip link set fan-252 mtu $mtu
  ip link show fan-252

  JUJU_MACHINES=`timeout -s 9 30 juju machines --format tabular | tail -n +2 | grep -v \/lxd\/ | awk '{print $1}'`
  for machine in $JUJU_MACHINES ; do
    echo "INFO: set mtu for machine $machine"
    command juju ssh $machine "sudo ip link set fan-252 mtu $mtu ; ip link show fan-252"
  done
}
