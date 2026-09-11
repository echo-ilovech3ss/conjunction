"""Send a diagnostic command to an existing QEMU human monitor socket."""
import socket
import sys
import time

with socket.socket(socket.AF_UNIX) as monitor:
    monitor.settimeout(3)
    monitor.connect(sys.argv[1])
    monitor.recv(65536)
    monitor.sendall((" ".join(sys.argv[2:]) + "\n").encode())
    time.sleep(0.5)
    response = monitor.recv(65536).decode(errors="replace")
    print(response.rsplit("\r\n", 1)[-1])
