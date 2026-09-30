"""Run only through test.sh, which supplies real host canaries and expected IDs."""
import os
import sys
from pathlib import Path

uid, host_home, canary, host_pid = sys.argv[1:]
assert os.getuid() == int(uid), 'Container UID differs from host UID'
status = dict(line.split(':', 1) for line in Path('/proc/self/status').read_text().splitlines() if ':' in line)
assert int(status['CapEff'].strip(), 16) == 0, 'Capabilities present'
assert status['NoNewPrivs'].strip() == '1', 'no-new-privileges missing'
assert status['Seccomp'].strip() == '2', 'Seccomp filter missing'
for name in [host_home, '/proc/1/root' + host_home, '/var/run/docker.sock', '/run/podman/podman.sock', f'/run/user/{uid}']:
    assert not Path(name).exists(), f'Unexpected host path: {name}'
for name in [canary, '/workspace/canary-link', '/workspace/home-link/.ssh', f'/proc/{host_pid}/root{canary}']:
    try:
        fd = os.open(name, os.O_RDONLY)
    except OSError:
        pass
    else:
        os.close(fd)
        raise AssertionError(f'Host path reachable: {name}')
try:
    Path('/usr/local/bin/sandbox-write-probe').write_text('should fail')
except OSError:
    pass
else:
    raise AssertionError('Image filesystem is writable')
assert not {'SSH_AUTH_SOCK', 'TMUX', 'OPENAI_API_KEY', 'AWS_SECRET_ACCESS_KEY'} & os.environ.keys()
Path('/workspace/python-test.txt').write_text('Python works\n')
print('PASS: workspace writes, host path/symlink isolation, read-only image, no capabilities, no-new-privileges, seccomp, clean environment')
