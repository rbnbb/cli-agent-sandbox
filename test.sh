#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/workspace"
printf 'harmless isolation canary\n' > "$test_dir/canary"
ln -s "$test_dir/canary" "$test_dir/workspace/canary-link"
ln -s "$HOME" "$test_dir/workspace/home-link"
cp "$source_dir/verify.py" "$test_dir/workspace/verify.py"
export LAB_WORKSPACE="$test_dir/workspace"
launcher=${LAB_TEST_LAUNCHER:-"$source_dir/codex-lab"}
"$launcher" --offline --run python3 /workspace/verify.py "$(id -u)" "$HOME" "$test_dir/canary" "$$"
"$launcher" --offline --run bash -c 'set -eu; codex --version; ~/.juliaup/bin/julia --startup-file=no -e '\''using LinearAlgebra; @assert det([1.0 2.0; 3.0 4.0]) ≈ -2; write("julia-test.txt", "Julia works\n"); println("PASS: Julia runtime and libraries")'\'''
"$launcher" --offline --run python3 -c 'import subprocess; host="/usr/local/bin/codex-code-mode-host"; subprocess.run([host,"--help"],check=True,stdout=subprocess.DEVNULL,timeout=15); subprocess.run([host,"--listen","stdio"],input=b"",check=True,timeout=15); print("PASS: code-mode execution host starts")'
"$launcher" --offline --run python3 -c 'import subprocess; subprocess.run(["codex","app-server","daemon","start"],check=True,timeout=45); subprocess.run(["codex","app-server","daemon","version"],check=True,timeout=15); subprocess.run(["codex","app-server","daemon","stop"],check=True,timeout=15); print("PASS: complete-package daemon startup and shutdown")'
[[ -s "$test_dir/workspace/python-test.txt" && -s "$test_dir/workspace/julia-test.txt" ]]
"$launcher" --offline --run python3 -c 'import socket; s=socket.socket(); s.settimeout(3); assert s.connect_ex(("1.1.1.1",443)) != 0; print("PASS: offline network blocked")'
"$launcher" --run python3 -c 'import urllib.request; r=urllib.request.urlopen("https://github.com",timeout=20); assert r.status == 200; print("PASS: DNS and GitHub HTTPS")'
printf 'PASS: all sandbox tests passed.\n'
