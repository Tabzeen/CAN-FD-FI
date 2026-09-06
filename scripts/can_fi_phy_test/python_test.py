import time
import json
import getpass
import queue
import threading
import websocket 
import logging

from profiles import *
from utils import *

import sys


SSH_HOST = "" # REDACTED
SSH_PORT = 4002
SSH_USER = "root"
SSH_KEY = "" # REDACTED

WS_CAN_4_URI = f"" # REDACTED
WS_CAN_7_URI = f"" # REDACTED

CORE_FREQ = 240000

def main():

    break_set = False
    print(port_conf_api_put(9, PORT_MAP_CFG))
    print("[API GET] Configured Port Map with: ", port_conf_api_get(9))

    ws = websocket.WebSocket()
    ws_s = websocket.WebSocket()
    ws.connect(WS_CAN_4_URI)
    ws_s.connect(WS_CAN_7_URI)

    ssh = TargetSSH(SSH_HOST, SSH_PORT, SSH_USER, SSH_KEY)

    rx_queue = queue.Queue() 
    rx_queue_s = queue.Queue() 
    stop_event = threading.Event()

    ws_enqueue = threading.Thread(
        target=ws_receiver_enqueue, 
        args=(ws, rx_queue, stop_event), 
        daemon=True
    )
    ws_enqueue.start()

    ws_enqueue_s = threading.Thread(
        target=ws_receiver_enqueue, 
        args=(ws_s, rx_queue_s, stop_event), 
        daemon=True
    )
    ws_enqueue_s.start()

    try:
        # Loop over each speed
        for speed in SPEED_PROFILES:
            if not "break" in SPEED_PROFILES[speed]:
                print("Skipped Speed, no breakpoint")
                continue
            print(f"\n=== Applying Speed Profile: {speed} ===")
            
            can_profile = SPEED_PROFILES[speed]["API"]
            fi_profiles = SPEED_PROFILES[speed]["FI"]

            fi_cli_params = gen_speed_conf_fi(CORE_FREQ, fi_profiles["nomi"])

            # Use data config if avaliable, if not mirror nominal setting instead
            if "data" in fi_profiles:
                fi_cli_params = \
                    fi_cli_params | gen_speed_conf_fi(CORE_FREQ, fi_profiles["data"], True)
            else:
                fi_cli_params = \
                    fi_cli_params | gen_speed_conf_fi(CORE_FREQ, fi_profiles["nomi"], True)

            # Configure CAN node via REST API
            
            can_conf_api_put(4, can_profile)
            can_conf_api_put(7, can_profile)
            # Send flush frame, because for whatever reason the first frame doesnt get send
            tx_flush = dict({"frame":{"Data":{"id":{"base":1914},"data":[123,123,123]}}})
            ws_s.send(json.dumps(tx_flush))

            time.sleep(1)
            print("[API GET] Configuration of CAN 4", can_conf_api_get(4))
            print("[API GET] Configuration of CAN 7", can_conf_api_get(7))

            print("[INFO] Configured CAN Speed Paramerters:\n", can_profile)

            # Configure Fault Injector

            print("[INFO] Configured Fault Injector Speed Paramerters:\n", fi_cli_params)

            canfi_conf_can(ssh, fi_cli_params)            
            canfi_conf_fi(ssh, fi_cli_params)            

            # Loop over each FI type
            for test in FRAME_PROFILES_RECORD_TEST:
                print(f"\n--- Setting up Test Set: {test} ---")
                # Loop over each CAN Frame in the test set

                # Set CAN to either Error Active or passive depending on the conf
                for frame_set_i in FRAME_PROFILES_RECORD_TEST[test]:
                    # Skip FD frames when FD Mode not enabled                    
                    if  not SPEED_PROFILES[speed]["API"]["control_modes"]["Fd"] \
                        and frame_set_i["fd_only"]:
                            continue

                    # Loop over each FI Frame for that frame set
                    for fi_test_frame in frame_set_i["fi_frames"]:

                        if not 'break' in fi_test_frame and not break_set:
                            print("Skipped, no breakpoint")
                            continue
                        else:
                            break_set = True

                        # Repeat Test after first time test 
                        repeat = True
                        fi_enable = 1
                        while(repeat):    
                            # Arm the specific fault injection register via SSH

                            is_fd_active = SPEED_PROFILES[speed]["API"]["control_modes"]["Fd"]
                            if test == "FI_DLC" or test  == "FI_DATA_CRC":
                                bully_node(ws, ws_s, 4, 7, ssh, is_fd_active)

                            err_state = can_conf_api_get(7)["state"]
                            if test == "FI_DLC" or test  == "FI_DATA_CRC":
                                assert err_state == "ErrorPassive", "[ERR] Abort, Target is not ErrorPassive"
                            else:
                                assert err_state == "ErrorActive", "[ERR] Abort, Target is not ErrorActive"

                            # Disable the other node to catch Recessive errors 
                            if test == "FI_DLC":
                                can_conf_api_put(4, {"bring_up": False})

                            canfi_set_state(ssh, 0)
                            time.sleep(0.1)
                            reset_all(ssh)
                            canfi_set_fi(ssh, FI_TYPES_IDX_MAP[test], fi_test_frame)

                            # If Data override also add override vector
                            if test == "FI_DATA_CRC":
                                print("[INFO] Configuring DATA_CRC Vectors")
                                canfi_set_vec(ssh, FI_TYPES_IDX_MAP[test], fi_test_frame)

                            canfi_set_state(ssh, fi_enable)

                            print(f"\n[INFO] Current CAN Config is:", frame_set_i["can_frame"])
                            print("[INFO] Is FD Frame:", frame_set_i["fd_only"])
                            print("[INFO] Current Fault Configuration is:", fi_test_frame)

                            time.sleep(0.1)

                            entry = input("[INFO] Configuration ready. Press ENTER to transmit one-shot frame...")
                            if entry == "0":
                                fi_enable = 0
                            elif entry == "r":
                                fi_enable = 1
                            elif not entry:
                                repeat = False

                            # Transmit frame via WebSocket
                            tx_frame = dict({ "frame": {"Data": frame_set_i["can_frame"]}})
                            print(f"[WS TX] Sending: {tx_frame}")

                            # Check if FD is globally active for the current speed profile
                            is_fd_active = SPEED_PROFILES[speed]["API"]["control_modes"]["Fd"]

                            if is_fd_active:
                                # Transmit frame via SSH replacing the missing BRS WebSocket logic
                                canfi_send_frame(
                                    ssh=ssh, 
                                    can_frame=frame_set_i["can_frame"], 
                                    is_fd=is_fd_active, 
                                    iface="can1"  
                                    )
                            else:
                                ws_s.send(json.dumps(tx_frame))

                            # Capture Candump equivalent via WebSocket
                            try:
                                rx_resp = rx_queue.get(timeout=0.8)
                                print("\n[WS RX 4]:", rx_resp)
                            except queue.Empty:
                                print("\n[WS RX 4]: Timeout (no frame received)")

                            try:
                                rx_resp = rx_queue_s.get(timeout=0.8)
                                print("\n[WS RX 7]:", rx_resp)
                            except queue.Empty:
                                print("\n[WS RX 7]: Timeout (no frame received)")

                            # Reset the CAN controller after each injection 
                            can_conf_api_put(4, {"bring_up": False})
                            can_conf_api_put(7, {"bring_up": False})
                            time.sleep(0.1)
                            can_conf_api_put(4, {"bring_up": True})
                            can_conf_api_put(7, {"bring_up": True})
                            # Send flush dummy frame
                            ws_s.send(json.dumps(tx_flush))

                            print("[SSH EXEC] Flags after Injection")
                            status_line = [l for l in canfi_get_flags(ssh).strip().splitlines() if "STATUS_FLAGS" in l]
                            print(status_line)
                            
                            print("\n======================================================\n")

    finally:
        print("\n[CLEANUP] Closing connections...")
        stop_event.set()
        ws_enqueue.join(timeout=1.0)
        ws_enqueue_s.join(timeout=1.0)
        ws.close()
        ssh.close()

##
# Async
##

def ws_receiver_enqueue(ws, rx_queue, stop_event):
    while not stop_event.is_set():
        try:
            ws.settimeout(0.5)
            rx_msg = ws.recv()
            if rx_msg:
                rx_queue.put(json.loads(rx_msg))
        except websocket.WebSocketTimeoutException:
            continue
        except websocket.WebSocketConnectionClosedException:
            break
        except Exception as e:
            if not stop_event.is_set():
                print(f"[WS RX ERROR] {e}")
            break

# Bully a node into error passive before performing fault injections
# Note that the receiver is getting set to error passive
def bully_node(xcvr : websocket, target : websocket, xcvr_idx : int, target_idx : int, ssh, is_fd_active = False):
    # Configure a simple stuffing insert    
    target_can_frame_o = { "id": {"base": 0x1AA, "extended": None}, "data": [0x00, 0x00] }
    target_can_frame = dict({ "frame": {"Data": target_can_frame_o}})
    target_fi_frame = {
                    "id": "0x1AA",
                    "id_mask": "0x0000000",
                    "type": "dyn-stuff",
                    "field": "data",
                    "meta": "0", 
                    "err": "none"
                }
    max_retries = 64 
    canfi_set_state(ssh, 0)
    canfi_set_fi(ssh, 0, target_fi_frame)

    for i in range(max_retries):
        #print("[INFO] Bully into passive. CNT.", i)

        canfi_set_state(ssh, 1)

        time.sleep(0.1)

        if is_fd_active:
            canfi_send_frame(
                ssh=ssh, 
                can_frame=target_can_frame_o, 
                is_fd=True, 
                iface="can0"  
            )
        else:
            xcvr.send(json.dumps(target_can_frame))
        time.sleep(0.1)

        xcvr_state = can_conf_api_get(xcvr_idx)
        target_state = can_conf_api_get(target_idx)
        errs = target_state.get('state') 
        tec = target_state.get('bus_error_counter', {}).get('tx', 0)
        rec = target_state.get('bus_error_counter', {}).get('rx', 0)
        #print(f"[INFO] Target Node tec {tec}, rec {rec}, errs {errs}")

        if xcvr_state.get('state') == 'BusOff':
            # Reenable the xcvr node if it turns off
            can_conf_api_put(xcvr_idx, {"bring_up": True})
            #print("[INFO] Revived XCVR Node")

        if target_state.get('state') == 'ErrorPassive':
            #print("[INFO] Target Node is now in Error Passive state!")
            can_conf_api_put(xcvr_idx, {"bring_up": False})
            break

    canfi_set_state(ssh, 0)
    can_conf_api_put(xcvr_idx, {"bring_up": True})


def reset_all(ssh):
    zero = {
        "id": "0xFFF",
        "id_mask": "0x0000000",
        "type": "none",
        "field": "0",
        "meta": "0", 
    }
    for i in range(8):
        canfi_set_fi(ssh, i, zero)



if __name__ == "__main__":
    main()
