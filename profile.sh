#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -a

#this is provided while using Utility OS
source /opt/bootstrap/functions

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
run "Installing kernel and Debian Packages on Ubuntu ${param_ubuntuversion}" \
    "docker run -i --rm --privileged --name ubuntu-installer ${DOCKER_PROXY_ENV} -v /dev:/dev -v /sys/:/sys/ -v $ROOTFS:/target/root ubuntu:${param_ubuntuversion} sh -c \
    'mount --bind dev /target/root/dev && \
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
    wget --header \"Authorization: token ${param_token}\" ${param_basebranch}/iso_image_flashing.py && \
    python3 iso_image_flashing.py  --img_url ${img_url} --esp_host ${param_httpserver} --sut_mac ${macaddr} ${drive_arguments}'" \
    ${PROVISION_LOG}
