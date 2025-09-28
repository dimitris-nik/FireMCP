#!/usr/bin/env python3

import argparse
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
ROOTFS_IMG = REPO_ROOT / "rootfs.ext4"
KERNEL_IMG = REPO_ROOT / "vmlinux.bin"
TAP_NAME_DEFAULT = "tap0"


class CmdResult:
    def __init__(self, code, out, err):
        self.code = code
        self.out = out
        self.err = err


def run(cmd, cwd=None, check=True, forward=True, verbose=False):
    """Run a command.
    - forward=True: inherit parent's stdout/stderr (live output), don't capture.
    - forward=False: capture stdout/stderr silently and return them.
    """
    if cwd is None:
        cwd = REPO_ROOT
    if verbose:
        print(f"[+] Running: {' '.join(map(str, cmd))}")
    if forward:
        proc = subprocess.run(list(cmd), cwd=str(cwd))
        if check and proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, cmd)
        return CmdResult(proc.returncode, "", "")
    else:
        proc = subprocess.run(list(cmd), cwd=str(cwd), text=True, capture_output=True)
        if check and proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, cmd)
        return CmdResult(proc.returncode, proc.stdout or "", proc.stderr or "")

def images_present():
    return ROOTFS_IMG.exists() and KERNEL_IMG.exists()


def pgrep(pattern):
    try:
        res = run(["pgrep", "-f", pattern], check=False, forward=False)
        return res.code == 0 and bool(res.out.strip())
    except FileNotFoundError:
        return False


def vm_running():
    # Either firectl or firecracker indicates a running VM invocation
    return pgrep(r"(^|/)firectl( |$)") or pgrep(r"(^|/)firecracker( |$)")


def tap_exists(name=TAP_NAME_DEFAULT):
    return (Path("/sys/class/net") / name).exists()


def ip_forward_enabled():
    try:
        val = Path("/proc/sys/net/ipv4/ip_forward").read_text().strip()
        return val == "1"
    except Exception:
        return None


def is_rootfs_mounted(img=ROOTFS_IMG):
    try:
        mounts = Path("/proc/mounts").read_text()
    except Exception:
        return False
    # Check if mounted via loop with this file path
    return str(img) in mounts


def remove_file(p):
    try:
        if p.exists():
            print(f"[+] Removing {p}")
            p.unlink()
        else:
            print(f"[+] {p} not present; nothing to do")
    except Exception as e:
        print(f"[!] Failed to remove {p}: {e}", file=sys.stderr)
        raise


def do_purge_images(force=False):
    if vm_running() and not force:
        raise RuntimeError("VM appears to be running; refuse to purge images. Re-run with --force to override.")
    if is_rootfs_mounted() and not force:
        raise RuntimeError("rootfs.ext4 appears to be mounted; refuse to purge. Unmount or use --force.")
    remove_file(ROOTFS_IMG)
    remove_file(KERNEL_IMG)

# High level commands

def do_get_images():
    script = REPO_ROOT / "get-imgs.sh"
    if not script.exists():
        raise FileNotFoundError(f"Missing script: {script}")
    run([str(script)], verbose=True)  # This script will start the VM at the end


def do_start():
    script = REPO_ROOT / "start.sh"
    if not script.exists():
        raise FileNotFoundError(f"Missing script: {script}")
    run([str(script)], verbose=True)


def do_update_servers():
    script = REPO_ROOT / "update-server-list.sh"
    if not script.exists():
        raise FileNotFoundError(f"Missing script: {script}")
    run([str(script)], verbose=True)


def do_generate_config(base, path, suffix, input_json, output_json):
    script = REPO_ROOT / "generate-config.py"
    if not script.exists():
        raise FileNotFoundError(f"Missing script: {script}")
    cmd = [sys.executable, str(script)]
    if input_json:
        cmd.append(input_json)
    if output_json:
        cmd.append(output_json)
    if base:
        cmd.extend(["--base-url", base])
    if path:
        cmd.extend(["--proto-path", path])
    if suffix:
        cmd.extend(["--suffix", suffix])
    run(cmd, verbose=True)


# CLI

def build_parser():
    p = argparse.ArgumentParser(description="Manage FireMCP VM and assets", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    sub = p.add_subparsers(dest="cmd")

    sub.add_parser("auto", help="Auto: first run builds images and starts; otherwise just start")
    for name in ("start", "up"):
        sub.add_parser(name, help="Start the VM (start.sh)")
    sub.add_parser("images", help="Build images (get-imgs.sh) — note: it also starts the VM")
    sub.add_parser("update", help="Sync servers.json into rootfs (update-server-list.sh)")

    p_purge = sub.add_parser("purge", help="Delete kernel/rootfs images only (no network changes)")
    p_purge.add_argument("--force", action="store_true", help="Force purge even if VM looks running or rootfs is mounted")

    p_gc = sub.add_parser("gen-config", help="Generate mcp.json from servers.json")
    p_gc.add_argument("input", nargs="?", default="servers.json", help="Input JSON (servers.json)")
    p_gc.add_argument("output", nargs="?", default="mcp.json", help="Output JSON (mcp.json)")
    p_gc.add_argument("-b", "--base-url", dest="base", help="Base URL for SSE endpoints")
    p_gc.add_argument("-p", "--proto-path", dest="proto_path", help="Protocol path")
    p_gc.add_argument("-s", "--suffix", dest="suffix", help="Event-stream suffix")

    sub.add_parser("status", help="Show status: images, vm, tap, iptables, ip_forward")

    return p


def cmd_auto():
    if not images_present():
        print("[+] Images missing — running get-imgs.sh (this will also start the VM)...")
        do_get_images()
        # In case get-imgs.sh didn't start the VM for any reason, ensure we do
        if not vm_running():
            print("[+] Starting VM after image setup...")
            do_start()
        return 0
    if vm_running():
        print("[+] VM appears to be running already (firectl/firecracker detected). Nothing to do.")
        return 0
    print("[+] Images present — starting VM...")
    do_start()
    return 0


def cmd_start():
    if vm_running():
        print("[!] VM appears to be running already. If this is unexpected, run './firemcp.py status'.")
        return 0
    do_start()
    return 0


def cmd_images():
    do_get_images()
    return 0


def cmd_update():
    do_update_servers()
    return 0


def cmd_gen_config(ns):
    do_generate_config(ns.base, ns.proto_path, ns.suffix, ns.input, ns.output)
    return 0


def cmd_purge(ns):
    try:
        do_purge_images(force=ns.force)
        return 0
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2


def cmd_status():
    print("== FireMCP status ==")
    print(f"Repo: {REPO_ROOT}")
    print(f"Images: rootfs={'present' if ROOTFS_IMG.exists() else 'missing'}, kernel={'present' if KERNEL_IMG.exists() else 'missing'}")
    print(f"VM process: {'running' if vm_running() else 'not running'}")
    print(f"TAP '{TAP_NAME_DEFAULT}': {'present' if tap_exists(TAP_NAME_DEFAULT) else 'absent'}")
    ipf = ip_forward_enabled()
    if ipf is None:
        print("IP forward: unknown")
    else:
        print(f"IP forward: {'enabled' if ipf else 'disabled'}")
    # iptables rule check skipped
    return 0


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    parser = build_parser()
    ns = parser.parse_args(argv)

    cmd = ns.cmd or "auto"
    try:
        if cmd == "auto":
            return cmd_auto()
        elif cmd in ("start", "up"):
            return cmd_start()
        elif cmd == "images":
            return cmd_images()
        elif cmd == "update":
            return cmd_update()
        elif cmd == "gen-config":
            return cmd_gen_config(ns)
        elif cmd == "purge":
            return cmd_purge(ns)
        elif cmd == "status":
            return cmd_status()
        else:
            parser.print_help()
            return 2
    except subprocess.CalledProcessError as e:
        print(f"Error: command failed with exit code {e.returncode}: {' '.join(map(str, e.cmd))}", file=sys.stderr)
        return e.returncode
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
