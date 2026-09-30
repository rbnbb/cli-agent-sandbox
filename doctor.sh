#!/usr/bin/env bash
set -euo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ $(uname -s) == Linux ]] || fail 'This setup targets Linux hosts, not macOS/Windows Podman VMs.'
[[ $(id -u) != 0 ]] || fail 'Run as your ordinary user, without sudo.'
for tool in podman slirp4netns python3 realpath; do
  command -v "$tool" >/dev/null || fail "Missing $tool. On Ubuntu/Debian: sudo apt install podman uidmap slirp4netns python3"
done
podman --version
if ! rootless=$(podman info --format '{{.Host.Security.Rootless}}'); then
  fail 'Podman cannot initialize. Check /etc/subuid and /etc/subgid allocations, newuidmap/newgidmap, and the distribution AppArmor policy. Do not disable system protections globally.'
fi
[[ "$rootless" == true ]] || fail 'Podman is not running rootless.'
[[ $(podman info --format '{{.Host.OS}}') == linux ]] || fail 'Expected Linux container host.'
if ! podman unshare true; then
  fail 'Rootless user namespace failed. Have an administrator check subordinate UID/GID ranges and AppArmor userns permission for Podman.'
fi
printf 'PASS: rootless Podman initializes and user namespaces work.\n'
printf 'User namespace restriction: '
cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null || true
printf 'Container isolation and networking will be tested by install.sh.\n'
