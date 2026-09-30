#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=build
case ${1:-} in
  --check) mode=check; shift;;
  --skip-build) mode=reuse; shift;;
  --help|-h)
    printf '%s\n' 'Usage: ./install.sh [--check | --skip-build]' 'Default: diagnose, build from installed Codex/Julia, test, install launcher.' '--check: diagnose and test existing image; install nothing.' '--skip-build: test existing image and install launcher.' 'Host overrides: LAB_WORKSPACE, LAB_IMAGE, LAB_DNS, LAB_CODEX_BIN, LAB_JULIA_BIN, LAB_INSTALL_DIR.'
    exit 0;;
esac
(( $# == 0 )) || { echo 'Unexpected argument; use --help.' >&2; exit 2; }
"$source_dir/doctor.sh"
image=${LAB_IMAGE:-localhost/codex-lab:1}
export LAB_IMAGE="$image"
if [[ "$mode" == build ]]; then
  codex_bin=${LAB_CODEX_BIN:-$(command -v codex || true)}
  julia_bin=${LAB_JULIA_BIN:-$(command -v julia || true)}
  [[ -x "$codex_bin" && -x "$julia_bin" ]] || { echo 'Install standalone Codex CLI and Julia first, or set LAB_CODEX_BIN and LAB_JULIA_BIN.' >&2; exit 1; }
  codex_bin=$(realpath -- "$codex_bin")
  python3 - "$codex_bin" <<'PYCODE'
import sys
with open(sys.argv[1], 'rb') as f:
    if f.read(4) != b'\x7fELF':
        sys.exit('Codex must be a native standalone Linux executable, not an npm/shell wrapper. Set LAB_CODEX_BIN to the native binary.')
PYCODE
  julia_bindir=$("$julia_bin" --startup-file=no --history-file=no -e 'print(Sys.BINDIR)')
  julia_root=$(realpath -- "$julia_bindir/..")
  [[ -f "$julia_root/lib/libjulia.so" || -L "$julia_root/lib/libjulia.so" ]] || { echo 'Expected an official self-contained Julia runtime (e.g. Juliaup).' >&2; exit 1; }
  build_dir=$(mktemp -d)
  trap 'rm -rf -- "$build_dir"' EXIT
  cp "$source_dir/Containerfile" "$build_dir/Containerfile"
  cp "$codex_bin" "$build_dir/codex"
  cp -a "$julia_root" "$build_dir/julia"
  podman build --tag "$image" "$build_dir"
fi
podman image exists "$image" || { echo "Missing image: $image. Run ./install.sh to build it." >&2; exit 1; }
"$source_dir/test.sh"
[[ "$mode" != check ]] || exit 0
workspace=${LAB_WORKSPACE:-"$HOME/lab"}
install_dir=${LAB_INSTALL_DIR:-"$HOME/.local/bin"}
python3 - "$workspace" "$install_dir" <<'PYCODE'
import os, sys
workspace, target = map(os.path.realpath, sys.argv[1:])
if os.path.commonpath([workspace, target]) == workspace:
    sys.exit('Refusing to install the trusted host launcher inside the sandbox workspace.')
PYCODE
mkdir -p -- "$workspace" "$install_dir"
install -m 0755 "$source_dir/codex-lab" "$install_dir/codex-lab"
printf '\nInstalled: %s/codex-lab\nWorkspace: %s\n' "$install_dir" "$workspace"
printf 'Next: %s/codex-lab --login\n' "$install_dir"
printf 'Custom LAB_WORKSPACE/LAB_IMAGE/LAB_DNS overrides must also be set when launching.\n'
