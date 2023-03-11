#!/bin/bash
echo "running Post file " 2>&1 | tee -a /dev/console
# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
set -a
#this is provided while using Utility OS
source /opt/bootstrap/functions

ethdevice=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i-1)}');
macaddr=$(cat /sys/class/net/$ethdevice/address);

flashing_handler_port="9000"
dyn_profile_port="8580"
update_flashing_status(){
	run "reporting flashing status" "curl -d '{\"mac\":\"$macaddr\", \"status_key\":\"$1\", \"status_value\":\"$2\", \"completion_status\":\"$3 of total ~20 min\", \"msg\":\"$4\"}' -H \"Content-Type: application/json\" -X POST $param_httpserver:$flashing_handler_port/flashing-handler/update-flashing-status" "/tmp/provisioning.log"
}
# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

if [[ $kernel_params = *"httpserver="* ]]; then
  tmp="${kernel_params##*httpserver=}"
  param_httpserver="${tmp%% *}"
else
  echo "" 2>&1 | tee -a ${CONSOLE_OUTPUT}
  echo "[            ] 'httpserver' kernel parameter missing in profile_request script!"
fi

if [[ $kernel_params == *" username="* ]]; then
	tmp="${kernel_params##* username=}"
	export param_noproxy="${tmp%% *}"
fi

if [[ $kernel_params == *" password="* ]]; then
	tmp="${kernel_params##* password=}"
	export password="${tmp%% *}"
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

# image url
img_url=""
if [[ $kernel_params == *" img_url="* ]]; then
	tmp="${kernel_params##* img_url=}"
	export img_url="${tmp%% *}"
else
	# unmount iso image
	echo "Fetching image name"
	output=$(curl --location http://$param_httpserver:$dyn_profile_port/check_download --header 'Content-Type: application/json' --data "{\"img_url\": \"${img_url}\"  }")
	output="${output//\}}"
	if [[ $output == *"\"response\":"* ]]; then
		tmp="${output##*\"response\":}"
		tmp="${tmp//\"}"
		echo "${tmp}"

		if [[ $tmp == *".iso"* ]]; then
			echo "ISO image name fetched sucessfully."
			echo "Un-mounting ISO"
			output=$(curl --location http://$param_httpserver:$dyn_profile_port/unmount_iso --header 'Content-Type: application/json' --data "{\"img_name\": \"${tmp}\"  }")
			if [[ $output == *"\"msg\":"* ]]; then
				tmp="${output##*\"response\":}"
				tmp="${tmp//\"}"
				echo "${tmp}"
				if [[ $tmp == *"Unmounted ISO"* ]]; then
					echo "Unmounted ISO"
					break
				else
					echo "Failed to unmount ISO"
					exit 1
				fi
			else
				echo "Failed to unmount ISO"
				exit 1
			fi
		fi
	else
		echo "Failed to fetch iso image name."
		exit 1
	fi
fi
# --- Cleanup ---
if [ ! -z "${param_docker_login_user}" ] && [ ! -z "${param_docker_login_pass}" ]; then
    run "Logout from a Docker registry" \
        "docker logout" \
        "$TMP/provisioning.log"
fi

run "Cleaning up" \
    "killall dockerd &&
    sleep 3 &&
    swapoff $ROOTFS/swap &&
    rm $ROOTFS/swap &&
    while (! rm -fr $ROOTFS/tmp/ > /dev/null ); do sleep 2; done" \
    "$TMP/provisioning.log"


umount $BOOTFS &&
umount $ROOTFS &&

echo "cleanup done " 2>&1 | tee -a /dev/console

run "Deleting mac address from Dynamic Profile" \
    "curl -d '{\"mac\":\"$macaddr\"}' -H \"Content-Type: application/json\" -X POST $param_httpserver:$flashing_handler_port/flashing-handler/delete-dynamic-profile" \
    "/tmp/provisioning.log"
if [ $? -eq 1 ]; then
	echo "failed to delete mac address from Dynamic Profile" 2>&1 | tee -a /dev/console
	exit 1
else
	echo "successfuly deleted mac address from Dynamic Profile" 2>&1 | tee -a /dev/console
fi

reboot

