#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

# --- Ubuntu Packages ---
ubuntu_packages="net-tools"
ubuntu_tasksel="" # standard

ntpd -d -N -q -n -p us.pool.ntp.org

PROVISION_LOG="/tmp/provisioning.log"
run "Begin provisioning process..." \
    "while (! docker ps > /dev/null ); do sleep 0.5; done" \
    ${PROVISION_LOG}

PROVISIONER=$1

# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

img_url=""
if [[ $kernel_params == *" img_url="* ]]; then
	tmp="${kernel_params##* img_url=}"
	export img_url="${tmp%% *}"
fi

if [[ $kernel_params == *" noproxy="* ]]; then
	tmp="${kernel_params##* noproxy=}"
	export param_noproxy="${tmp%% *}"
	export no_proxy="${param_noproxy},${PROVISIONER}"
	export NO_PROXY="${param_noproxy},${PROVISIONER}"
fi

if [[ $kernel_params == *" proxy="* ]]; then
	tmp="${kernel_params##* proxy=}"
	export param_proxy="${tmp%% *}"
	export http_proxy=${param_proxy}
	export https_proxy=${param_proxy}
	export HTTP_PROXY=${param_proxy}
	export HTTPS_PROXY=${param_proxy}
	export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
	export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}';"
elif [ $( nc -vz -w 2 ${PROVISIONER} 3128; echo $?; ) -eq 0 ] && [ $( nc -vz -w 2 ${PROVISIONER} 4128; echo $?; ) -eq 0 ]; then
	PROXY_DOCKER_BIND="-v /tmp/ssl:/etc/ssl/ -v /usr/local/share/ca-certificates/EB.pem:/usr/local/share/ca-certificates/EB.crt"
	export http_proxy=http://${PROVISIONER}:3128/
	export https_proxy=http://${PROVISIONER}:4128/
	export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
	export HTTP_PROXY=http://${PROVISIONER}:3128/
	export HTTPS_PROXY=http://${PROVISIONER}:4128/
	export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
	export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}' ${PROXY_DOCKER_BIND}"
	export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}'; if [ ! -f /usr/local/share/ca-certificates/EB.crt ]; then if (! which wget > /dev/null ); then apt update && apt -y install wget; fi; wget -O - http://${PROVISIONER}/squid-cert/CA.pem > /usr/local/share/ca-certificates/EB.crt && update-ca-certificates; fi;"
	wget -O - http://${PROVISIONER}/squid-cert/CA.pem > /usr/local/share/ca-certificates/EB.pem
	update-ca-certificates
elif [ $( nc -vz -w 2 ${PROVISIONER} 3128; echo $?; ) -eq 0 ]; then
	export http_proxy=http://${PROVISIONER}:3128/
	export https_proxy=http://${PROVISIONER}:3128/
	export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
	export HTTP_PROXY=http://${PROVISIONER}:3128/
	export HTTPS_PROXY=http://${PROVISIONER}:3128/
	export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
	export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
	export INLINE_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export no_proxy='${no_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}';"
fi

if [[ $kernel_params == *"proxysocks="* ]]; then
	tmp="${kernel_params##*proxysocks=}"
	param_proxysocks="${tmp%% *}"

	export FTP_PROXY=${param_proxysocks}

	tmp_socks=$(echo ${param_proxysocks} | sed "s#http://##g" | sed "s#https://##g" | sed "s#/##g")
	export SSH_PROXY_CMD="-o ProxyCommand='nc -x ${tmp_socks} %h %p'"
fi

if [[ $kernel_params == *"wifissid="* ]]; then
	tmp="${kernel_params##*wifissid=}"
	export param_wifissid="${tmp%% *}"
elif [ ! -z "${SSID}" ]; then
	export param_wifissid="${SSID}"
fi

if [[ $kernel_params == *"wifipsk="* ]]; then
	tmp="${kernel_params##*wifipsk=}"
	export param_wifipsk="${tmp%% *}"
elif [ ! -z "${PSK}" ]; then
	export param_wifipsk="${PSK}"
fi

if [[ $kernel_params == *"network="* ]]; then
	tmp="${kernel_params##*network=}"
	export param_network="${tmp%% *}"
fi

if [[ $kernel_params == *"httppath="* ]]; then
	tmp="${kernel_params##*httppath=}"
	export param_httppath="${tmp%% *}"
fi

if [[ $kernel_params == *"parttype="* ]]; then
	tmp="${kernel_params##*parttype=}"
	export param_parttype="${tmp%% *}"
elif [ -d /sys/firmware/efi ]; then
	export param_parttype="efi"
else
	export param_parttype="msdos"
fi

if [[ $kernel_params == *"bootstrap="* ]]; then
	tmp="${kernel_params##*bootstrap=}"
	export param_bootstrap="${tmp%% *}"
	export param_bootstrapurl=$(echo $param_bootstrap | sed "s#/$(basename $param_bootstrap)\$##g")
fi

if [[ $kernel_params == *"basebranch="* ]]; then
	tmp="${kernel_params##*basebranch=}"
	export param_basebranch="${tmp%% *}"
fi

if [[ $kernel_params == *"token="* ]]; then
	tmp="${kernel_params##*token=}"
	export param_token="${tmp%% *}"
fi

if [[ $kernel_params == *"agent="* ]]; then
	tmp="${kernel_params##*agent=}"
	export param_agent="${tmp%% *}"
else
	export param_agent="master"
fi

if [[ $kernel_params == *"kernparam="* ]]; then
	tmp="${kernel_params##*kernparam=}"
	temp_param_kernparam="${tmp%% *}"
	export param_kernparam=$(echo ${temp_param_kernparam} | sed 's/#/ /g' | sed 's/:/=/g')
fi

if [[ $kernel_params == *"ubuntuversion="* ]]; then
	tmp="${kernel_params##*ubuntuversion=}"
	export param_ubuntuversion="${tmp%% *}"
else
	export param_ubuntuversion="cosmic"
fi

# The following is bandaid for Disco Dingo
if [ $param_ubuntuversion = "disco" ]; then
	export DOCKER_UBUNTU_RELEASE="cosmic"
else
	export DOCKER_UBUNTU_RELEASE=$param_ubuntuversion
fi

if [[ $kernel_params == *"arch="* ]]; then
	tmp="${kernel_params##*arch=}"
	export param_arch="${tmp%% *}"
else
	export param_arch="amd64"
fi

if [[ $kernel_params == *"kernelversion="* ]]; then
	tmp="${kernel_params##*kernelversion=}"
	export param_kernelversion="${tmp%% *}"
else
	export param_kernelversion="linux-image-generic"
fi

if [[ $kernel_params == *"insecurereg="* ]]; then
	tmp="${kernel_params##*insecurereg=}"
	export param_insecurereg="${tmp%% *}"
fi

if [[ $kernel_params == *"username="* ]]; then
	tmp="${kernel_params##*username=}"
	export param_username="${tmp%% *}"
else
	export param_username="sys-admin"
fi

if [[ $kernel_params == *"epassword="* ]]; then
	tmp="${kernel_params##*epassword=}"
	temp_param_epassword="${tmp%% *}"
	export param_epassword=$(echo ${temp_param_epassword} | sed 's/\$/\\\\\\$/g')
elif [[ $kernel_params == *"password="* ]]; then
	tmp="${kernel_params##*password=}"
	export param_password="${tmp%% *}"
else
	export param_password="password"
fi

if [[ $kernel_params == *"debug="* ]]; then
	tmp="${kernel_params##*debug=}"
	export param_debug="${tmp%% *}"
	export debug="${tmp%% *}"
fi

if [[ $kernel_params == *"resume="* ]]; then
	tmp="${kernel_params##*resume=}"
	export param_resume="${tmp%% *}"

    if [ ${param_resume,,} == "true" ]; then
        echo "export RESUME_PROFILE=1" > .bash_env
        echo "export RESUME_PROFILE_RUN=("Configuring Image Database")" >> .bash_env
        export BASH_ENV=.bash_env
        . .bash_env
    fi
fi

if [[ $kernel_params == *"release="* ]]; then
	tmp="${kernel_params##*release=}"
	export param_release="${tmp%% *}"
else
	export param_release='dev'
fi

if [[ $kernel_params == *"docker_login_user="* ]]; then
	tmp="${kernel_params##*docker_login_user=}"
	export param_docker_login_user="${tmp%% *}"
fi

if [[ $kernel_params == *"docker_login_pass="* ]]; then
	tmp="${kernel_params##*docker_login_pass=}"
	export param_docker_login_pass="${tmp%% *}"
fi

if [[ $param_release == 'prod' ]]; then
	export kernel_params="$param_kernparam" # ipv6.disable=1
else
	export kernel_params="$param_kernparam"
fi

MIRROR_STATUS=$(wget --method=HEAD http://${PROVISIONER}${param_httppath}/distro/ 2>&1 | grep "404 Not Found")
if [[ $kernel_params == *"mirror="* ]]; then
    tmp="${kernel_params##*mirror=}"
    export param_mirror="${tmp%% *}"
elif wget -q --method=HEAD http://${PROVISIONER}${param_httppath}/build/dists/${param_ubuntuversion}/InRelease; then
    export param_mirror="http://${PROVISIONER}${param_httppath}/build"
elif wget -q --method=HEAD http://${PROVISIONER}${param_httppath}/distro/dists/${param_ubuntuversion}/InRelease; then
    export param_mirror="http://${PROVISIONER}${param_httppath}/distro"
fi
if [ ! -z "${param_mirror}" ]; then
    export PKG_REPO_LIST=""
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}/main/binary-${param_arch}/Release; then
        export PKG_REPO_LIST="${PKG_REPO_LIST} main"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}/restricted/binary-${param_arch}/Release; then
        export PKG_REPO_LIST="${PKG_REPO_LIST} restricted"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}/universe/binary-${param_arch}/Release; then
        export PKG_REPO_LIST="${PKG_REPO_LIST} universe"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}/multiverse/binary-${param_arch}/Release; then
        export PKG_REPO_LIST="${PKG_REPO_LIST} multiverse"
    fi
    export PKG_REPO_SEC_LIST=""
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}-security/main/binary-${param_arch}/Release; then
        export PKG_REPO_SEC_LIST="${PKG_REPO_SEC_LIST} main"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}-security/restricted/binary-${param_arch}/Release; then
        export PKG_REPO_SEC_LIST="${PKG_REPO_SEC_LIST} restricted"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}-security/universe/binary-${param_arch}/Release; then
        export PKG_REPO_SEC_LIST="${PKG_REPO_SEC_LIST} universe"
    fi
    if wget -q --method=HEAD ${param_mirror}/dists/${param_ubuntuversion}-security/multiverse/binary-${param_arch}/Release; then
        export PKG_REPO_SEC_LIST="${PKG_REPO_SEC_LIST} multiverse"
    fi
fi

# --- Get free memory
export freemem=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# --- Detect HDD ---
if [ -d /sys/block/nvme[0-9]n[0-9] ]; then
	export DRIVE=$(echo /dev/`ls -l /sys/block/nvme* | grep -v usb | head -n1 | sed 's/^.*\(nvme[a-z0-1]\+\).*$/\1/'`);
	export BOOT_PARTITION=${DRIVE}p1
	export SWAP_PARTITION=${DRIVE}p2
	export ROOT_PARTITION=${DRIVE}p3
elif [ -d /sys/block/[vsh]da ]; then
	export DRIVE=$(echo /dev/`ls -l /sys/block/[vsh]da | grep -v usb | head -n1 | sed 's/^.*\([vsh]d[a-z]\+\).*$/\1/'`);
	export BOOT_PARTITION=${DRIVE}1
	export SWAP_PARTITION=${DRIVE}2
	export ROOT_PARTITION=${DRIVE}3
elif [ -d /sys/block/mmcblk[0-9] ]; then
	export DRIVE=$(echo /dev/`ls -l /sys/block/mmcblk[0-9] | grep -v usb | head -n1 | sed 's/^.*\(mmcblk[0-9]\+\).*$/\1/'`);
	export BOOT_PARTITION=${DRIVE}p1
	export SWAP_PARTITION=${DRIVE}p2
	export ROOT_PARTITION=${DRIVE}p3
else
	echo "No supported drives found!" 2>&1 | tee -a /dev/console
	sleep 300
	reboot
fi


echo "" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console
echo "Installing on ${DRIVE}" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console
echo "" 2>&1 | tee -a /dev/console

if [ $(wget http://${PROVISIONER}:5557/v2/_catalog -O-) ] 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5557"
elif [ $(wget http://${PROVISIONER}:5000/v2/_catalog -O-) ] 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5000"
fi

run "Configuring Image Database" \
    "mkdir -p /tmp/docker && \
    chmod 777 /tmp && \
    killall dockerd && sleep 2 && \
    /usr/local/bin/dockerd ${REGISTRY_MIRROR} --data-root=/tmp/docker > /dev/null 2>&1 &" \
    "/tmp/provisioning.log"

while (! docker ps > /dev/null ); do sleep 0.5; done; sleep 3

if [ ! -z "${param_docker_login_user}" ] && [ ! -z "${param_docker_login_pass}" ]; then
    run "Log in to a Docker registry" \
    	"docker login -u ${param_docker_login_user} -p ${param_docker_login_pass}" \
    	"/tmp/provisioning.log"
fi

 # --- Begin Ubuntu Install Process ---
run "Preparing Ubuntu ${param_ubuntuversion} installer" \
    "docker pull ubuntu:${param_ubuntuversion}" \
    "/tmp/provisioning.log"

run "Installing Ubuntu ${param_ubuntuversion} (~10 min)" \
    "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} ubuntu:${param_ubuntuversion} bash -c \
    'chmod 666 /dev/null && \
	apt update && \
    apt install -y bmap-tools && \
	apt-get -y install python3-pip && \
    pip3 install  pip-system-certs && \
    bmaptool copy --nobmap ${img_url} ${DRIVE}'" \
    "/tmp/provisioning.log"


# EFI_BOOT_NAME="Ubuntu OS"
# run "EFI Boot Manager" \
#     "efibootmgr -c -d ${DRIVE} -p 1 -L \"${EFI_BOOT_NAME}\" -l '\\EFI\\ubuntu\\grubx64.efi'" \
#     "/tmp/provisioning.log"