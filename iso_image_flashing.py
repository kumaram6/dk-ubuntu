"""
Copyright: 2019-2022 Intel Corporation
Author: Amit Kumar <amit2.kumar@intel.com> [10 Mar 2023]

iso_image_flashing: module to flash iso image.
"""

# from iotg_utilities.os_utils.artifact.api_intf_artifact import ArtifactoryUtilsAPI
# from iotg_utilities.os_utils.disk.api_intf_disk import DiskUtilsAPI
from star_fw.framework_base.logger.api_intf_logger import LoggerAPI
from star_fw.framework_base.star_decorator import StarDecorator
from star_fw.framework_base.test_interface.api_intf_test_interface import TestInterfaceAPI
from iotg_utilities.common_utils.strings import StringUtils
from iotg_utilities.common_utils.generic import GenericUtils
import argparse
import sys
import os
import requests
import json

class ISOFlashing:
    def __init__(self) -> None:
        self.log = LoggerAPI(device_tag="ubuntu_iso_image_profile")
        self.parser = argparse.ArgumentParser(prog=str(sys.argv[0]))
        self.parser.add_argument('--platform', required=True,
                                    help='platform name e.g. rplp')
        self.parser.add_argument('--esp_host', required=True,
                                    help='ip address of esp server')
        self.parser.add_argument('--sut_mac', required=True,
                                    help='MAC address of SUT')
        self.args, _ = self.parser.parse_known_args()

        self.ubuntu_custom_image_creator_config_url = f"https://raw.githubusercontent.com/intel-innersource/os.linux.ubuntu.iot.utilities.custom-image-creator-config/main/config." + self.args.platform + ".json"
        self.test_interface_obj = TestInterfaceAPI(intf_type="local", os_name="linux")
        self.esp_host = self.args.esp_host
        self.flashing_handler_port = '9000'
        self.sut_mac_addr = self.args.sut_mac
        github_token = GenericUtils().get_github_token_enc()
        self.github_token= = StringUtils.get_decrypted_string(github_token)
        


    def install_debian_packages(self):
        """
        This method installs debian packages

        :param None:
        :return int: 0 on successful execution and non zero on failure  
        """
        headers = {'Authorization': f'token {self.github_token}'}
        response = requests.get(self.ubuntu_custom_image_creator_config_url,  headers=headers)
        # print(response.json())
        pre_install_build_cmds = response.json().get("variant").get("default").get("pre_install_build_cmds")
        print(pre_install_build_cmds)
        debian_packages = response.json().get("variant").get("default").get("packages")
        print(debian_packages)

        StarDecorator.double_blocked_print('Executing pre install build commands', logger=self.log)
        for build_cmd in pre_install_build_cmds:
            cmd = f'LANG=C.UTF-8 chroot /target/root sh -c "{build_cmd}"'
            out = self.test_interface_obj.execute(cmd, timeout=10*60)
            if not out.get('status', False):
                print(f'failed to execute cmd: {cmd}')

        
        StarDecorator.double_blocked_print('Installing Debian packages', logger=self.log)
        for pkg in debian_packages:
            cmd = f'LANG=C.UTF-8 chroot /target/root sh -c "apt install -y {pkg}"'
            out = self.test_interface_obj.execute(cmd, timeout=10*60)
            if not out.get('status', False):
                print(f'failed to execute cmd: {cmd}')


    def update_flashing_status(self, status_key, status_value, completion_status, msg):
        """
        method to update flashing status

        :return dict: dict containing status and msg
                      e.g. {'status': True, 'msg': ''}
        """
        url = f'http://{self.esp_host}:{self.flashing_handler_port}/flashing-handler/'\
                'update-flashing-status'
        payload = {
            "mac": self.sut_mac_addr,
            "status_key": status_key,
            "status_value": status_value,
            "completion_status": completion_status + " of total ~20 min",
            "msg": msg

        }
        headers = {"Content-Type": "application/json"}
        try:
            response = requests.post(
                url, data=json.dumps(payload), headers=headers)
            if response.status_code in (200, 400):
                response_data = json.loads(response.content.decode('utf-8'))
                return response_data
            self.log.error(
                f'failed to get {url} API response with payload {payload} and headers {headers}')
            return {'status': False, 'msg': f'failed to get {url} API response with payload '\
                    f'{payload} and headers {headers}'}
        except Exception as e:
            self.log.add_comment(
                f'failed to call rest API {url} with payload {payload} and headers {headers}. \
                    \nCheck if {url} is accessible or not. {e}', log_level="error")
            return {'status': False, 'msg': f'failed to call rest API {url} with payload '\
                    f'{payload} and headers {headers}. Check if {url} is accessible or not. {e}'}

        
    def flash(self):
        """
        method to flash ISO  image
        
        :param None:
        :return None:
        """
        self.install_debian_packages()

if __name__ == '__main__':
    obj = ISOFlashing()
    
