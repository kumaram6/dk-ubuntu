#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

#this is provided while using Utility OS
source /opt/bootstrap/functions

# --- Cleanup ---
if [ ! -z "${param_docker_login_user}" ] && [ ! -z "${param_docker_login_pass}" ]; then
    run "Logout from a Docker registry" \
        "docker logout" \
        "/tmp/provisioning.log"
fi

if [[ $param_release == 'prod' ]]; then
    poweroff
else
    reboot
fi
