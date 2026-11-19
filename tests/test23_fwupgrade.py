import imslib
import sys
import time

import tkinter as tk
from tkinter import filedialog

from ims_scan import iMSScanner
from ims_events import EventWaiter

from imslib import FirmwareUpgrade

print("Test 23: Firmware Upgrade")

ver = imslib.LibVersion()
print("Using iMS Library version ", ver.GetVersion())

# Select first available system
scanner = iMSScanner()
if scanner.scan(auto_select=True):
    ims = scanner.get_system()
else:
    sys.exit()

ims.Connect()

#############################
# Choose what to upgrade
#############################

# Not all iMS devices support remote firmware upgrade.  Those that do report it in their capabilities
TARGETS = {}
if ims.Synth().IsValid():
    print(f"Synthesiser: {ims.Synth().Model()}, FW Version: {ims.Synth().GetVersion()}")
    if ims.Synth().GetCap().RemoteUpgrade:
        TARGETS['s'] = ("Synthesiser", FirmwareUpgrade.UpgradeTarget_SYNTHESISER)
if ims.Ctlr().IsValid():
    print(f"Controller:  {ims.Ctlr().Model()}, FW Version: {ims.Ctlr().GetVersion()}")
    if ims.Ctlr().GetCap().RemoteUpgrade:
        TARGETS['c'] = ("Controller", FirmwareUpgrade.UpgradeTarget_CONTROLLER)

if not TARGETS:
    print("The connected iMS System does not support remote firmware upgrade")
    ims.Disconnect()
    sys.exit()

print()
for key, (name, _) in TARGETS.items():
    print(f"    ({key}) -> Upgrade {name} firmware")
print("    (q) -> Quit")
choice = input("Select an option: ").strip().lower()
if choice not in TARGETS:
    ims.Disconnect()
    sys.exit()
target_name, target = TARGETS[choice]

# Firmware upgrade files are in MCS format
root = tk.Tk()
root.withdraw()
filename = filedialog.askopenfilename(
    title=f"Select {target_name} firmware file...",
    filetypes=[("MCS firmware files", "*.mcs"), ("All files", "*.*")],
)
root.destroy()
if not filename:
    ims.Disconnect()
    sys.exit()

#############################
# Start the Upgrade
#############################

# The firmware file is opened here and read in the background while the upgrade runs
try:
    fwu = FirmwareUpgrade(ims, filename)
except OSError as e:
    print(e)
    ims.Disconnect()
    sys.exit()

# List of Events that we will subscribe to, and strings to print when they fire
EVENT_MESSAGES = {
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_STARTED: "Upgrade started",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_INITIALIZE_OK: "Initialised",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_CHECKID_OK: "Flash ID code identified",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_ENTER_UG_MODE: "Entered upgrade mode",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_ERASE_OK: "Flash erased",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_PROGRAM_OK: "Flash programmed",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_VERIFY_OK: "Flash verified",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_LEAVE_UG_MODE: "Left upgrade mode",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_DONE: "Upgrade process finished",
    imslib.FirmwareUpgradeEvents_FIRMWARE_UPGRADE_ERROR: "Upgrade error",
}

waiter = EventWaiter()
waiter.listen_for(list(EVENT_MESSAGES.keys()))
for evt in EVENT_MESSAGES:
    fwu.FirmwareUpgradeEventSubscribe(evt, waiter)

print()
print(f"About to upgrade the {target_name} firmware from {filename}")
print("Do not disconnect or power off the iMS System while the upgrade is running.")
if input("Type 'yes' to continue: ").strip().lower() != 'yes':
    ims.Disconnect()
    sys.exit()

# StartUpgrade() returns immediately. The upgrade continues in the background
if not fwu.StartUpgrade(target):
    print("Failed to start the firmware upgrade")
    ims.Disconnect()
    sys.exit()

#############################
# Monitor Progress
#############################

def print_events():
    # Print any events that have arrived since last time
    while True:
        try:
            msg, params = waiter.wait(timeout=0.2)
            print(f"\r{EVENT_MESSAGES.get(msg, f'Unknown event {msg}'):<50}")
        except TimeoutError:
            return

while not fwu.UpgradeDone() and not fwu.UpgradeError():
    print_events()
    progress = fwu.GetUpgradeProgress()
    if progress.EraseOK() and not progress.ProgramOK():
        done = fwu.GetTransferLength()
        total = fwu.GetTotalTransferLength()
        print(f"\rProgramming: {done} / {total} bytes ({100.0 * done / total:.1f}%)", end="", flush=True)
print_events()

for evt in EVENT_MESSAGES:
    fwu.FirmwareUpgradeEventUnsubscribe(evt, waiter)

#############################
# Report the Result
#############################

if fwu.UpgradeError():
    err = fwu.GetUpgradeError()
    ERRORS = {
        "Unable to read upgrade data from the firmware file": err.StreamError(),
        "Unable to identify the Flash device": err.IdCode(),
        "Flash erase failed": err.Erase(),
        "Flash programming failed": err.Program(),
        "Timed out communicating with the Flash device": err.TimeOut(),
        "CRC of the downloaded firmware did not match": err.Crc(),
    }
    print("Firmware upgrade failed:")
    for text in [text for text, flagged in ERRORS.items() if flagged] or ["Unknown error"]:
        print(f"    {text}")
    print("The device will revert to its golden image, from which the upgrade can be attempted again.")
else:
    print("Firmware upgrade complete. Restart the iMS System to boot the new firmware.")

ims.Disconnect()
