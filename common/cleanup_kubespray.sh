#!/bin/bash

set -o errexit

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"
source "$my_dir/common.sh"

# cleanup kubespray

ansible-playbook -i kubespray/inventory/mycluster/hosts.yml --become --become-user=root --extra-vars "reset_confirmation=yes" kubespray/reset.yml
