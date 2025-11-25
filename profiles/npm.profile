# General Firejail Profile 

quiet

# Private temp and dev directories
private-tmp
private-dev

# Add nessesary directories to path
env PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# =======================
# Network restrictions
# =======================
dns 1.1.1.1

# =======================
# Security hardening
# =======================
seccomp
restrict-namespaces
caps.keep chown
disable-mnt

# =======================
# Whitelisted paths
# =======================
# Allow binaries and interpreters
whitelist /root/.local
whitelist /root/.local/bin
whitelist /root/.local/bin/uv
whitelist /root/.local/bin/uvx
whitelist /root/.cache/uv
whitelist /root/.npm
noblacklist /mcp-workspace

# =======================
# Read-only system dirs
# =======================
read-only /usr/bin
read-only /usr/lib
read-only /usr/local/bin
read-only /usr/local/lib


