# Codex lab sandbox

Run Codex, Julia and Python in a rootless Podman container with only `$HOME/lab` exposed at `/workspace`. Host home files, SSH keys/agent, tmux sockets and container engine sockets are not mounted. The launcher is installed at `$HOME/.local/bin/codex-lab`, outside the writable workspace.

## Install

This package targets native Linux hosts. It was tested on Ubuntu 24.04 with Podman 4.9.3. Other distributions must pass the included diagnostics and execution tests; there is no claim of universal compatibility.

Install rootless Podman, slirp4netns, Python 3, a native standalone Codex CLI, and an official self-contained Julia runtime (Juliaup works). Bash and coreutils are required. On Ubuntu/Debian, an administrator can install container prerequisites with:

```sh
sudo apt install podman uidmap slirp4netns python3
```

Your account needs working subordinate UID/GID mappings and permission to create Podman user namespaces. The installer diagnoses failures but never changes AppArmor, sysctls, subordinate ID assignments or system packages automatically.

From this directory, as your ordinary user:

```sh
./install.sh
```

The installer runs diagnostics, copies only the Codex executable and Julia runtime into a temporary build context, builds the image, runs isolation/runtime/network tests, and installs the launcher only if all tests pass. It does not copy host Codex configuration, logins, Julia packages or SSH credentials. The temporary build context is removed on exit. Existing launcher files are replaced after successful testing.

The Python base image is pinned by digest. Debian packages come from the configured upstream repositories at build time. Codex and Julia versions come from your local installations; this is portable packaging, not a byte-for-byte reproducible build. An npm wrapper is not a native Codex binary: use `LAB_CODEX_BIN` to select the underlying executable. ELF binaries with missing dynamic dependencies fail the runtime test.

```sh
./doctor.sh                 # Host prerequisites and user namespace checks
./install.sh --check        # Diagnose and test an existing image; install nothing
./install.sh --skip-build   # Test an existing image and install the launcher
```

Builds require internet access and sufficient disk space for runtime copies and image layers. Podman stores images in its normal user storage outside the workspace. No administrator privileges are used by the installer.

## Use

```sh
~/.local/bin/codex-lab --login
# After completing the device login:
tmux new-session -s lab-sandbox '~/.local/bin/codex-lab'
# Reconnect later:
tmux attach -t lab-sandbox
```

Inside an existing tmux session, run the launcher in a new window instead. This provides SSH/terminal access from a phone. ChatGPT mobile-app remote control is not configured by this package. Tmux survives SSH disconnection, not reboot.

```sh
~/.local/bin/codex-lab --shell
~/.local/bin/codex-lab --run julia --startup-file=no -e 'mkpath("data"); write("data/example.txt", "hello")'
~/.local/bin/codex-lab --offline --run python3 -c 'print("offline")'
```

Inside the container, use `/workspace` for persistent work. It is the same live directory as host `~/lab`; host copies, SCP transfers and Git commits are immediately visible on both sides. `julia`, `python3`, and `~/.juliaup/bin/julia` work; the last is a compatibility symlink, not the host Juliaup updater. Codex state, Julia packages and Python user packages persist in `/workspace/.sandbox-home`. Virtual environments can live in `/workspace`. The container home and `/tmp` are disposable. The image filesystem is read-only.

## Overrides

Set these on the host; they are not read from workspace configuration:

| Variable | Default | Purpose |
| --- | --- | --- |
| `LAB_WORKSPACE` | `$HOME/lab` | Existing directory to expose |
| `LAB_IMAGE` | `localhost/codex-lab:1` | Image to build/run |
| `LAB_DNS` | `1.1.1.1` | Resolver used in online mode |
| `LAB_CODEX_BIN` | `codex` from PATH | Native binary for image build |
| `LAB_JULIA_BIN` | `julia` from PATH | Julia executable for runtime discovery |
| `LAB_INSTALL_DIR` | `$HOME/.local/bin` | Trusted launcher installation directory |

Installation creates the workspace if absent. Launching requires it to exist. Workspace paths containing colon or comma are rejected. The launcher refuses to mount `/` or the entire host home. The installer refuses a launcher destination inside the workspace. Set custom workspace/image/DNS overrides again when launching; the installer does not modify your shell startup files or persist environment overrides.

## Git and security boundary

Clone private repositories from the host into `~/lab`. The container can edit and commit them. Host global Git configuration, SSH keys and credential helpers are not forwarded. Configure commit identity per repository. Lack of Git credentials is not an enforced prohibition on pushing: credentials supplied in files, URLs or tokens could enable authenticated HTTPS pushes.

Review sandbox-modified scripts, Git hooks and repository configuration before using them on the host. Do not put host secrets, sockets, external hardlinks or nested host mounts under the workspace. Avoid simultaneous branch switches or edits from host and sandbox. Everything in the workspace is writable and can be deleted; keep backups.

The entire CLI runs inside the container. Its internal sandbox is deliberately bypassed using the CLI flag for externally sandboxed environments. Podman enforces the outer boundary with rootless execution, private namespaces, zero capabilities, no-new-privileges and its default seccomp filter. The host launcher is trusted: use its installed copy, and review changes before reinstalling from an agent-writable source checkout.

Internet access uses slirp4netns with host-loopback forwarding disabled. This is not a LAN firewall: LAN services and publicly listening host services may remain reachable. Offline mode blocks container networking entirely and therefore cannot connect Codex to OpenAI. Shared-kernel isolation does not protect against every kernel/runtime vulnerability; a separate VM is a stronger boundary. Processes are capped at 1024; CPU, memory and workspace disk consumption are not capped.

The dedicated Codex login stored under `.sandbox-home/codex` is accessible to sandbox jobs. Do not publish or sync it through a public repository. Host runtime upgrades do not update the image; rerun the installer to rebuild.

Reference: https://docs.podman.io/en/latest/markdown/podman-run.1.html
