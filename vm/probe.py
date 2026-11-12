import glob
import os
import subprocess
import sys

import pexpect

VM_DIR = "/work/vm"
RUN_IMG = os.path.join(VM_DIR, "run.img")
KERNELS = sorted(glob.glob(os.path.join(VM_DIR, "kernel/boot/vmlinuz-*")))
if not KERNELS:
    raise SystemExit("no kernel found under /work/vm/kernel/boot")
KERNEL = KERNELS[-1]
INITRD = KERNEL.replace("vmlinuz-", "initramfs-") + ".img"
with open(os.path.join(VM_DIR, "disk.uuid"), encoding="utf-8") as f:
    UUID = f.read().strip()
APPEND = (
    f"root=UUID={UUID} "
    "rootfstype=btrfs rootflags=subvol=deploy/20261112,ro ro "
    "console=tty0 console=ttyS0,115200"
)
QMP = os.path.join(VM_DIR, "qmp-probe.sock")
SCREEN = os.path.join(VM_DIR, "probe-screen.png")

cmd = [
    "qemu-system-x86_64",
    "-machine", "q35",
    "-accel", "tcg,thread=multi",
    "-cpu", "max",
    "-smp", "4",
    "-m", "4096",
    "-drive", f"file={RUN_IMG},format=raw,if=ide",
    "-kernel", KERNEL,
    "-initrd", INITRD,
    "-append", APPEND,
    "-display", "none",
    "-vga", "none",
    "-device", "virtio-vga",
    "-vnc", "127.0.0.1:1",
    "-qmp", f"unix:{QMP},server,nowait",
    "-serial", "stdio",
    "-monitor", "none",
    "-net", "none",
    "-no-reboot",
]

child = pexpect.spawn(cmd[0], cmd[1:], timeout=120, encoding="utf-8")
child.logfile = sys.stdout

try:
    child.expect("login:", timeout=120)
    child.expect("#", timeout=30)
    child.sendline("PS1='PROMPT> '")
    child.expect("PROMPT> ", timeout=10)

    commands = [
        "sleep 30",
        "echo ==PS==; ps -eo pid,user,args | grep -E 'mango|noctalia|pipewire|wireplumber|void-session|fish' | grep -v grep",
        "echo ==NOCT==; pgrep -a noctalia; tail -20 /home/void/.mango.log",
        "echo ==SERVICES==; ls /var/service 2>/dev/null; sv status /var/service/* 2>/dev/null",
        "echo ==TTY==; cat /etc/sv/agetty-tty1/conf; getent passwd void; getent passwd root",
        "echo ==HOME==; ls -la /home/void; tail -20 /home/void/.mango.log 2>&1",
        "echo ==RUN==; ls -ld /run/user /run/user/1000 2>&1; pgrep -a elogind; ps -eo pid,user,args | grep -E 'elogind|dbus-daemon' | grep -v grep",
        "echo ==START==; ps -eo pid,user,args | head -40",
    ]
    for command in commands:
        child.sendline(command)
        child.expect("PROMPT> ", timeout=30)

    subprocess.run(
        [sys.executable, os.path.join(os.path.dirname(__file__), "qmp_screendump.py"), QMP, SCREEN],
        check=True,
    )
finally:
    child.terminate(force=True)
    child.wait()