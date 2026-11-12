import json
import socket
import sys

sock_path = sys.argv[1]
out_path = sys.argv[2]

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock_path)
f = s.makefile("rwb")

greeting = json.loads(f.readline())
if "QMP" not in greeting:
    raise SystemExit(f"unexpected QMP greeting: {greeting}")

f.write(b'{"execute":"qmp_capabilities"}\n')
f.flush()
json.loads(f.readline())

f.write(json.dumps({
    "execute": "screendump",
    "arguments": {"filename": out_path, "format": "png"},
}).encode() + b"\n")
f.flush()
reply = json.loads(f.readline())
if "error" in reply:
    raise SystemExit(reply["error"])

print(reply)
