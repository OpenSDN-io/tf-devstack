#!/bin/bash -e

# This script doesn't care about insecure-registies

my_file="$(readlink -e "$0")"
my_dir="$(dirname "$my_file")"
source "$my_dir/common.sh"

function install_docker_ubuntu() {
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt-get update
  sudo -E apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository -y -u "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  if [[ "$DISTRO_VERSION_ID" = "20.04" ]]; then
        sudo -E apt-get install -y docker-ce=5:24.0.7-1~ubuntu.20.04~focal
  elif [[ "$DISTRO_VERSION_ID" = "18.04" ]]; then
        sudo -E apt-get install -y "docker-ce=18.06.3~ce~3-0~ubuntu"
  else
        sudo -E apt-get install -y docker-ce
  fi
}

function install_docker_centos() {
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2
  if ! yum info docker-ce &> /dev/null ; then
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi
  sudo yum install -y docker-ce-18.03.1.ce
  sudo systemctl start docker
  sudo systemctl stop firewalld || true
}

echo
echo '[docker install]'
echo $DISTRO detected
if ! which docker ; then
  echo "Install docker"
  sudo -E $my_dir/create_docker_config.sh
  install_docker_$DISTRO
else
  echo "Docker is already installed .. skip docker installation and its initial config" 
fi

