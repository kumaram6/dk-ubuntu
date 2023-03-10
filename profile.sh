#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

ethdevice=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i-1)}');
macaddr=$(cat /sys/class/net/$ethdevice/address);
sut_ip_addr=$(ip route get 8.8.8.8 | grep -oE "src.*([0-9]{1,3})" | awk '{print $2}');
flashing_handler_port="9000"
echo -e "import requests\nmyurl = 'http://$param_httpserver:$flashing_handler_port/flashing-handler/send-flashing-log'\nwith open('/tmp/provisioning.log','rb') as filedata:\n\tgetdata = requests.post(myurl, files={'file': filedata})\n\tprint(getdata.text)">>send_log_file.py
chmod 777 send_log_file.py
update_flashing_status(){
	run "reporting flashing status" "curl -d '{\"mac\":\"$macaddr\", \"status_key\":\"$1\", \"status_value\":\"$2\", \"completion_status\":\"$3 of total ~20 min\", \"msg\":\"$4\", \"log\":\"$5\"}' -H \"Content-Type: application/json\" -X POST $param_httpserver:$flashing_handler_port/flashing-handler/update-flashing-status" "/tmp/provisioning.log"
}

# --- Add Packages
ubuntu_packages=""

img_url=""
if [[ $kernel_params == *" img_url="* ]]; then
	tmp="${kernel_params##* img_url=}"
	export img_url="${tmp%% *}"
else
	update_flashing_status "ISO image download" "Failed" "10%" "image url is empty"
	run "sending /tmp/provisiong.log to esp" "python3 send_log_file.py" "/tmp/provisioning.log"
	exit 1
fi

if [[ $kernel_params == *"bootstrap="* ]]; then
	tmp="${kernel_params##*bootstrap=}"
    export profile_url="${tmp/bootstrap.sh/""}"
fi

uuid=""
if [[ $kernel_params == *" uuid="* ]]; then
	tmp="${kernel_params##* uuid=}"
	export uuid="${tmp%% storage_type*}"
fi

storage_type=""
if [[ $kernel_params == *" storage_type="* ]]; then
	tmp="${kernel_params##* storage_type=}"
	export storage_type="${tmp%% *}"
fi

drive_arguments=''
if [ ! -z "$uuid" ]; then
	echo "UUID is: ${uuid}"	2>&1 | tee -a /dev/console
    drive_arguments="--uuid \"${uuid}\""
elif [ ! -z "$storage_type" ]; then
	echo "Storage type is: ${storage_type}" 2>&1 | tee -a /dev/console
	drive_arguments="--storage_type ${storage_type}"
else
	echo "Both UUID & Storage_type are empty" 2>&1 | tee -a /dev/console
	drive_arguments=""
fi

run "Arguments for iso_image_flashing.py" "echo -e '\n img_url:${img_url} \n uuid:${uuid} \n storage_type:${storage_type}'" "/tmp/provisioning.log"

# --- Install ubuntu kernel and Debian Packages ---
run "Installing Debian Packages on Ubuntu ${param_ubuntuversion}" \
    "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
    'if [ \"${PKG_REPO_SEC_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion}-security ${PKG_REPO_SEC_LIST}\" | cat - /etc/apt/sources.list > /tmp/out && mv /tmp/out /etc/apt/sources.list; fi && \
    if [ \"${PKG_REPO_LIST}\" != \"\" ]; then echo \"deb ${param_mirror} ${param_ubuntuversion} ${PKG_REPO_LIST}\" | cat - /etc/apt/sources.list > /tmp/out && mv /tmp/out /etc/apt/sources.list; fi && \
	echo \"Package: *\" > /etc/apt/preferences.d/priorities && echo \"Pin: origin ${param_mirror}\" >> /etc/apt/preferences.d/priorities && echo \"Pin-Priority: 1001\" >> /etc/apt/preferences.d/priorities && \
    mount --bind dev /target/root/dev && \
    mount -t proc proc /target/root/proc && \
    mount -t sysfs sysfs /target/root/sys && \
    chmod 666 /dev/null && \
    apt update && \
    apt-get -y install python3-pip && \
    pip3 install  pip-system-certs && \
    pip3 install --force-reinstall star_fw -i https://ubit-artifactory-ba.intel.com/artifactory/api/pypi/star_pip_packages-ba-local/simple/ --extra-index-url https://pypi.org/simple/ --no-cache-dir && \
    apt-get -y install sudo && \
    apt-get -y install fdisk && \
    apt-get -y install efibootmgr && \
    apt-get -y install wget && \
    apt-get -y install curl && \
    apt install -y lshw && \
    wget --header \"Authorization: token ${param_token}\" ${profile_url}iso_image_flashing.py && \
    python3 iso_image_flashing.py  --img_url ${img_url} --esp_host ${param_httpserver} --sut_mac ${macaddr} ${drive_arguments}'" \
    ${PROVISION_LOG}
