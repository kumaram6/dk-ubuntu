"""
Copyright: 2019-2023 Intel Corporation
Author: Amit Kumar <Amit2.kumar@intel.com> [10 Mar 2023]

dynamic_drive_detection.py: Class to find the Drive dynamicaly
"""
import os
import re

from iotg_utilities.os_utils.artifact.api_intf_artifact import ArtifactoryUtilsAPI
from iotg_utilities.os_utils.disk.api_intf_disk import DiskUtilsAPI
from star_fw.framework_base.logger.api_intf_logger import LoggerAPI
from star_fw.framework_base.star_decorator import StarDecorator
from star_fw.framework_base.test_interface.api_intf_test_interface import TestInterfaceAPI
import argparse
import sys
import requests
import json


class DynamicDriveDetection:
    def __init__(self) -> None:
        self.log = LoggerAPI(device_tag="Disk_image_profile")
        self.parser = argparse.ArgumentParser(prog=str(sys.argv[0]))
        self.parser.add_argument('--esp_host', required=True,
                                 help='ip address of esp server')
        self.parser.add_argument('--sut_mac', required=True,
                                 help='MAC address of SUT')
        self.parser.add_argument('--uuid', default=None,
                                 help='Optional: uuid of storage drive,'
                                      'e.g. "UEFI INTEL SSDPEKNU512GZ BTKA136109TU512A 1" ')
        self.parser.add_argument('--storage_type', default=None,
                                 help='Optional: type of storage drive like usb, nvme and emmc.')
        self.args, _ = self.parser.parse_known_args()
        self.test_interface_obj = TestInterfaceAPI(intf_type="local", os_name="linux")
        self.artifactory_utils_obj = ArtifactoryUtilsAPI()
        self.disk_utils_obj = DiskUtilsAPI(os_name='linux')
        self.uuid = self.args.uuid
        self.storage_type = self.args.storage_type
        self.esp_host = self.args.esp_host
        self.flashing_handler_port = '9000'
        self.sut_mac_addr = self.args.sut_mac
        self.number_of_drives = 0

    def update_flashing_status(self, status_key, status_value, completion_status, msg):
        """
        method to update flashing status

        :return dict: dict containing status and msg
                      e.g. {'status': True, 'msg': ''}
        """
        url = f'http://{self.esp_host}:{self.flashing_handler_port}/flashing-handler/' \
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
            return {'status': False,
                    'msg': f'failed to get {url} API response with payload {payload} and headers {headers}'}
        except Exception as e:
            self.log.add_comment(
                f'failed to call rest API {url} with payload {payload} and headers {headers}. \
                    \nCheck if {url} is accessible or not. {e}', log_level="error")
            return {'status': False,
                    'msg': f'failed to call rest API {url} with payload {payload} and headers {headers}.'
                           f'Check if {url} is accessible or not. {e}'}

    def flash(self):
        """
        method to flash disk image

        :param None:
        :return None:
        """
        drive_details = self.disk_utils_obj.detect_drive_name(self.uuid, self.storage_type)
        if drive_details.get('status') is True:
            self.log.info(f'Detected drive details: {drive_details}')
            drive_name = drive_details.get('drive_name')
            self.log.info(f'Drive Name to be flashed: {drive_name}')
        else:
            self.log.error(drive_details.get('msg'))
            self.update_flashing_status("ISO flashing", "Failed", "50%", drive_details.get('msg'))
            exit(1)


if __name__ == '__main__':
    obj = DynamicDriveDetection()
    obj.flash()
