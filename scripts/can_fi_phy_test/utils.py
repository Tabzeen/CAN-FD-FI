
import math
import requests
import paramiko
import json
import logging
##
# Parameter generator for FI
##

API_PORT = 4005

def gen_speed_conf_fi(core_freq: int, fi_cfg: dict, is_data_cfg: bool = False) -> dict:

    bitrate = fi_cfg["bitrate"]
    brp_core = fi_cfg["brp_core"]
    psp_frac = fi_cfg["psp_frac"]
    fip_frac = fi_cfg["fip_frac"]


    tq_cnt = (core_freq / bitrate) / brp_core

    data_prefix = "d" if is_data_cfg else ""
    psp = int(tq_cnt * psp_frac)
    fip = int(tq_cnt * fip_frac)
    # Add a one TQ buffer bw PSP and FIP 
    if psp == fip:
        if brp_core == 1:
            fip+=2
        else:
            fip+=1

    if not tq_cnt.is_integer():
        print("Warning: BRP does not produce integer division")

    tseg1 = math.floor(tq_cnt * 0.8) - 1
    tseg2 = math.ceil(tq_cnt * 0.2)

    sjw = fi_cfg.get("sjw_cfg", tseg2)

    config = {
        f"{data_prefix}brp": brp_core,
        f"{data_prefix}tseg1": tseg1, f"{data_prefix}tseg2": tseg2,
        f"{data_prefix}psp": psp, f"{data_prefix}fip": fip,
        f"{data_prefix}sjw": sjw
    }
    return config

##
# CAN API
##


FI_BINARY_PATH = "/persistent/rust_can_fd_fi_test/rust_can_fd_fi_test"

def can_conf_api_put(idx: int, api_config: dict):
    url = f"" # REDACTED
    print(f"[API PUT] Configuring bus {idx} at {url}", api_config)

    response = requests.put(url, json=api_config)
    if response.status_code != 200:
        raise RuntimeError(f"API Error {response.status_code}: {response.text}")
    print(f"[API] Bus {idx} configured successfully.")


def can_conf_api_get(idx: int) -> dict:
    url = f"" # REDACTED
    print(f"[API GET] Fetching config for bus {idx} at {url}")

    response = requests.get(url)
    if response.status_code != 200:
        raise RuntimeError(f"API Error {response.status_code}: {response.text}")

    return response.json()

def port_conf_api_put(idx: int, api_config: dict):
    url = f"" # REDACTED
    print(f"[API PUT] Configuring port {idx} at {url}", api_config)

    response = requests.put(url, json=api_config)
    if response.status_code != 200:
        raise RuntimeError(f"API Error {response.status_code}: {response.text}")
    print(f"[API] Bus {idx} configured successfully.")

def port_conf_api_get(idx: int) -> dict:
    url = f"" # REDACTED
    print(f"[API GET] Fetching config for port {idx} at {url}")

    response = requests.get(url)
    if response.status_code != 200:
        raise RuntimeError(f"API Error {response.status_code}: {response.text}")

    return response.json()

##
# FI Conf via SSH
##

class TargetSSH:
    def __init__(self, host, port, username, key_filename):
        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.client.connect(hostname=host, port=port, username=username, key_filename=key_filename)
        print(f"[SSH] Connected to {username}@{host}")

    def run_cmd(self, command: str):
        print(f"[SSH EXEC] {command}")
        stdin, stdout, stderr = self.client.exec_command(command)
        exit_status = stdout.channel.recv_exit_status()
        err = stderr.read().decode().strip()
        if exit_status != 0:
            raise RuntimeError(f"Command failed (exit {exit_status}): {err}")
        return stdout.read().decode().strip()

    def close(self):
        self.client.close()

def canfi_conf_fi(ssh: TargetSSH, timings: dict):
    cmd = (
        f"{FI_BINARY_PATH} can4 conf-fi "
        f"--psp {timings['psp']} --dpsp {timings['dpsp']} "
        f"--fip {timings['fip']} --dfip {timings['dfip']} "
    )
    ssh.run_cmd(cmd)

# Configure base CAN stats of the injector
def canfi_conf_can(ssh: TargetSSH, timings: dict):
    cmd = (
        f"{FI_BINARY_PATH} can4 conf-can "
        f"--tseg1 {timings['tseg1']} --tseg2 {timings['tseg2']} "
        f"--dtseg1 {timings['dtseg1']} --dtseg2 {timings['dtseg2']} "
        f"--sjw {timings['sjw']} --dsjw {timings['dsjw']} "
        f"--brp {timings['brp']} --dbrp {timings['dbrp']}"
    )

    ssh.run_cmd(cmd)
# Configre an fi slot
def canfi_set_fi(ssh: TargetSSH, idx: int, fi_config: dict):
    cmd = (
        f"{FI_BINARY_PATH} can4 set-fi "
        f"{idx} {fi_config['id']} "
        f"--id-mask {fi_config['id_mask']} {fi_config['type']} "
    )
    if fi_config["type"] != "none":
        cmd += f"{fi_config['field']} {fi_config['meta']}"
    print("Set FI cfg", cmd)
    ssh.run_cmd(cmd)

# Configure a data vector for a given slot
def canfi_set_vec(ssh: TargetSSH, idx: int, fi_config: dict):
    cmd = (
        f"{FI_BINARY_PATH} can4 set-vector "
        f"{idx} {fi_config['data_vec']}"
    )
    ssh.run_cmd(cmd)

# Enable or disable the FI
def canfi_set_state(ssh: TargetSSH, state: int):

    state_str = "enable" if state else "disable"
    cmd = (
        f"{FI_BINARY_PATH} can4 {state_str}"
    )
    ssh.run_cmd(cmd)

# Return the status of the FI
def canfi_get_flags(ssh: TargetSSH):
    cmd = (
        f"{FI_BINARY_PATH} can4 status"
    )
    return ssh.run_cmd(cmd)


def canfi_send_frame(ssh: TargetSSH, can_frame: dict, is_fd: bool, iface: str = "can0"):
    # Extract the CAN ID
    can_id = can_frame["id"]["base"]
    is_extended = can_frame["id"].get("extended") is not None
    
    # Format ID: `cansend` standardizes on 8 padded chars for extended, 3 for base
    id_hex = f"{can_id:08X}" if is_extended else f"{can_id:03X}"
    
    # Convert the integer data array into a continuous zero-padded hex string
    data_bytes = can_frame.get("data", [])
    data_hex = "".join([f"{b:02X}" for b in data_bytes])
    
    # Apply ##1 delimiter if FD is active to force the BRS bit, otherwise use Classic #
    delimiter = "##1" if is_fd else "#"
    
    # Construct the final command string
    cmd = f"cansend {iface} {id_hex}{delimiter}{data_hex}"
    print(f"[SSH TX] Executing: {cmd}")
    
    # Execute via your existing SSH client
    ssh.run_cmd(cmd)
