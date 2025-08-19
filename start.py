import os
import subprocess
import sys

# Configuration
TAP_NAME = "tap0"
TAP_ADDR = "172.20.0.1/24"
KERNEL_IMAGE = "vmlinux.bin"
ROOT_FS = "rootfs.ext4"


def run(cmd):
    print(f"[+] Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)


def cmd_output(cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout.strip()


def detect_default_interface():
    try:
        route_output = cmd_output(["ip", "route", "show", "default"])
        # Example: "default via 192.168.1.1 dev eth0 proto dhcp metric 100"
        for line in route_output.splitlines():
            parts = line.split()
            if "dev" in parts:
                idx = parts.index("dev")
                return parts[idx + 1]
    except Exception as e:
        print(f"[!] Failed to detect default interface: {e}")
    return "eth0"  # fallback


def ensure_tap():
    if not os.path.exists(f"/sys/class/net/{TAP_NAME}"):
        run(["sudo", "ip", "tuntap", "add", TAP_NAME, "mode", "tap"])
        run(["sudo", "ip", "addr", "add", TAP_ADDR, "dev", TAP_NAME])
        run(["sudo", "ip", "link", "set", TAP_NAME, "up"])
    else:
        print(f"[+] {TAP_NAME} already exists")


def enable_ip_forward():
    with open("/proc/sys/net/ipv4/ip_forward") as f:
        if f.read().strip() != "1":
            run(["sudo", "sh", "-c", "echo 1 > /proc/sys/net/ipv4/ip_forward"])
        else:
            print("[+] IP forwarding already enabled")


def ensure_iptables(device_name):
    # Masquerade rule
    rules = cmd_output(["sudo", "iptables", "-t", "nat", "-S", "POSTROUTING"]).splitlines()
    masquerade_rule = f"-A POSTROUTING -o {device_name} -j MASQUERADE"
    if not any(masquerade_rule in r for r in rules):
        run(["sudo", "iptables", "-t", "nat", "-A", "POSTROUTING", "-o", device_name, "-j", "MASQUERADE"])
    else:
        print("[+] MASQUERADE rule already present")

    # Forward rules
    rules = cmd_output(["sudo", "iptables", "-S", "FORWARD"]).splitlines()

    related_rule = "-A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
    if not any(related_rule in r for r in rules):
        run(["sudo", "iptables", "-A", "FORWARD", "-m", "conntrack", "--ctstate", "RELATED,ESTABLISHED", "-j", "ACCEPT"])
    else:
        print("[+] RELATED,ESTABLISHED rule already present")

    forward_rule = f"-A FORWARD -i {TAP_NAME} -o {device_name} -j ACCEPT"
    if not any(forward_rule in r for r in rules):
        run(["sudo", "iptables", "-A", "FORWARD", "-i", TAP_NAME, "-o", device_name, "-j", "ACCEPT"])
    else:
        print("[+] TAP forward rule already present")


def get_tap_mac():
    return cmd_output(["cat", f"/sys/class/net/{TAP_NAME}/address"])


def run_vm():
    mac = get_tap_mac()
    cmd = [
        "sudo", "firectl",
        f"--kernel={KERNEL_IMAGE}",
        f"--root-drive={ROOT_FS}",
        "--kernel-opts=console=ttyS0 noapic reboot=k panic=1 pci=off nomodules rw",
        f"--tap-device={TAP_NAME}/{mac}"
    ]
    run(cmd)


def main():
    device_name = detect_default_interface()
    print(f"[+] Using default interface: {device_name}")
    ensure_tap()
    enable_ip_forward()
    ensure_iptables(device_name)
    run_vm()


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {e}")
        sys.exit(1)

