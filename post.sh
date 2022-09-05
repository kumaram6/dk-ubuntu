#!/bin/bash
echo "running Post file " 2>&1 | tee -a /dev/console
# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
set -a
#this is provided while using Utility OS
source /opt/bootstrap/functions
# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)
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



# --- Cleanup ---
if [ ! -z "${param_docker_login_user}" ] && [ ! -z "${param_docker_login_pass}" ]; then
    run "Logout from a Docker registry" \
        "docker logout" \
        "/tmp/provisioning.log"
fi
echo "cleanup done " 2>&1 | tee -a /dev/console

# delete mac address menu 
run "Deleting mac address menu" \
    "curl -d '{\"mac\":\"88:88:88:88:87:88\", \"operation\":\"delete_flash_menu\"}' -H \"Content-Type: application/json\" -X POST intel-NUC23.iind.intel.com:8000/hardwares" \
    "/tmp/provisioning.log"

# reboot
run "booting to local drive" \
    "curl -d '{\"mac\":\"88:88:88:88:87:88\", \"operation\":\"wait_for_boot\", \"sut_ip\":\"10.49.3.39\", \"username\":\"user\", \"password\":\"user1234\", \"port\":\"22\", \"boot_time\":\"300\"}'  -H \"Content-Type: application/json\"  -X POST intel-NUC23.iind.intel.com:8000"\
    "/tmp/provisioning.log"
    
# if [[ $param_release == 'prod' ]]; then
#     poweroff
# else
#     reboot
# fi
