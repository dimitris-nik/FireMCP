#!/usr/bin/env bash
set -euo pipefail

# Configuration
TAP_NAME="tap0"
TAP_ADDR="172.20.0.1/24"
KERNEL_IMAGE="vmlinux.bin"
ROOT_FS="rootfs.ext4"

run() {
    echo "[+] Running: $*"
    "$@"
}

cmd_output() {
    "$@" 2>/dev/null
}

detect_default_interface() {
    local iface
    iface=$(ip route show default 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | head -n1)
    if [[ -z "$iface" ]]; then
        echo "[!] Failed to detect default interface, falling back to eth0"
        echo "eth0"
    else
        echo "$iface"
    fi
}

ensure_tap() {
    if [[ ! -e "/sys/class/net/${TAP_NAME}" ]]; then
        run sudo ip tuntap add "$TAP_NAME" mode tap
        run sudo ip addr add "$TAP_ADDR" dev "$TAP_NAME"
        run sudo ip link set "$TAP_NAME" up
    else
        echo "[+] $TAP_NAME already exists"
    fi
}

enable_ip_forward() {
    if [[ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]]; then
        run sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
    else
        echo "[+] IP forwarding already enabled"
    fi
}

ensure_iptables() {
    local device_name="$1"

    # Masquerade rule
    if ! sudo iptables -t nat -S POSTROUTING | grep -q "\-A POSTROUTING -o ${device_name} -j MASQUERADE"; then
        run sudo iptables -t nat -A POSTROUTING -o "$device_name" -j MASQUERADE
    else
        echo "[+] MASQUERADE rule already present"
    fi

    # Forward rules
    if ! sudo iptables -S FORWARD | grep -q "\-A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"; then
        run sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    else
        echo "[+] RELATED,ESTABLISHED rule already present"
    fi

    if ! sudo iptables -S FORWARD | grep -q "\-A FORWARD -i ${TAP_NAME} -o ${device_name} -j ACCEPT"; then
        run sudo iptables -A FORWARD -i "$TAP_NAME" -o "$device_name" -j ACCEPT
    else
        echo "[+] TAP forward rule already present"
    fi
}

get_tap_mac() {
    cat "/sys/class/net/${TAP_NAME}/address"
}

run_vm() {
    local mac
    mac=$(get_tap_mac)
    run sudo firectl \
        --kernel="${KERNEL_IMAGE}" \
        --root-drive="${ROOT_FS}" \
        --kernel-opts="console=ttyS0 noapic reboot=k panic=1 pci=off nomodules rw" \
        --tap-device="${TAP_NAME}/${mac}" \
        --memory 4096 
}


main() {
    local device_name
    device_name=$(detect_default_interface)
    echo "[+] Using default interface: ${device_name}"

    ensure_tap
    enable_ip_forward
    ensure_iptables "$device_name"
    run_vm
}

main "$@"

