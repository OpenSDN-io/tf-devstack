#!/bin/bash -e
# Run on agent nodes to install kernel-devel. Copy via scp and execute via ssh.
# SITE_MIRROR is passed from the caller for download_package (e.g. ssh $ip "SITE_MIRROR='...' bash ...").

sudo dnf install -y wget

function download_package() {
  local original_site=$1
  local site_path=$2
  local output_name=$3
  local add_opts="$4"

  if [ -n "$SITE_MIRROR" ]; then
    wget -nv --tries=3 -c -O $output_name $SITE_MIRROR/$site_path || /bin/true
  fi
  if [ ! -s $output_name ]; then
    wget -nv --tries=3 -c $add_opts -O $output_name $original_site/$site_path
  fi
}

function get_kernel_devel_kver() {
    local rver=$1
    case "$rver" in
        9.0) echo "5.14.0-70.30.1.el9_0.x86_64";;
        9.1) echo "5.14.0-162.23.1.el9_1.x86_64";;
        9.2) echo "5.14.0-284.30.1.el9_2.x86_64";;
        9.3) echo "5.14.0-362.13.1.el9_3.x86_64";;
        9.4) echo "5.14.0-427.42.1.el9_4.x86_64";;
        9.5) echo "5.14.0-503.14.1.el9_5.x86_64";;
        9.6) echo "5.14.0-570.58.1.el9_6.x86_64";;
        *) echo "";;
    esac
}

major=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | cut -d. -f1)
current_kver=$(uname -r)

if [[ "$major" -lt 9 ]]; then
    # RHEL/Rocky 8: kernel-devel from repos
    if ! sudo dnf install -y "kernel-devel-${current_kver}"; then
        echo "ERROR: kernel-devel install failed"
        exit 1
    fi
    exit 0
fi

# el9: install kernel-devel from mapping (versions guaranteed in vault)
rver=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | cut -d. -f1,2)
target_kver=$(get_kernel_devel_kver "$rver")
if [[ -z "$target_kver" ]]; then
    echo "ERROR: failed to find suitable kernel-devel version for Rocky $rver"
    exit 1
fi

rpm_file="/tmp/kernel-devel-$target_kver.rpm"
site_path="vault/rocky/${rver}/AppStream/x86_64/os/Packages/k/kernel-devel-${target_kver}.rpm"
if ! download_package "https://dl.rockylinux.org" "$site_path" "$rpm_file"; then
    echo "ERROR: kernel-devel download failed for $target_kver"
    exit 1
fi
if ! sudo dnf install -y "$rpm_file"; then
    echo "ERROR: kernel-devel install failed"
    exit 1
fi
rm -f "$rpm_file"

# If host kernel differs from mapping, create symlink so /lib/modules/$current_kver/build
# resolves to headers from mapping (container needs build dir for vrouter compile)
if [[ "$current_kver" != "$target_kver" ]]; then
    src_link="/usr/src/kernels/${current_kver}"
    if [[ ! -e "$src_link" ]]; then
        sudo ln -sf "${target_kver}" "$src_link"
    fi
fi
