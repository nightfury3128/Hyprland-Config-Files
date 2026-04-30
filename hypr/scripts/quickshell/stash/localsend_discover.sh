#!/bin/bash
# LocalSend discovery: UDP multicast + HTTP subnet scan fallback

python3 - <<'EOF'
import socket, json, time, struct, re, subprocess, asyncio, ssl, sys

MCAST      = '224.0.0.167'
PORT       = 53317   # standard LocalSend port (multicast + HTTPS scan)
REPLY_PORT = 53318   # our exclusive reply port — not used by LocalSend, so
                     # phones TCP-fail here and send UDP fallback to multicast

out = subprocess.check_output(["ip", "-4", "addr"], text=True)
local_ips = set(re.findall(r'inet (\d+\.\d+\.\d+\.\d+)', out))

route_out = subprocess.check_output(["ip", "route", "get", MCAST], text=True)
src_m = re.search(r'src (\d+\.\d+\.\d+\.\d+)', route_out)
lan_ip = src_m.group(1) if src_m else ''

seen = set()

def emit(ip, alias):
    if ip not in seen and ip not in local_ips:
        seen.add(ip)
        print(f"{alias}\t{ip}", flush=True)

# ── Phase 1: UDP multicast (4s) ────────────────────────────────────────────

# Multicast socket: receives all devices' periodic announces and UDP fallbacks
rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
rx.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
rx.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
rx.bind(('', PORT))
mreq = (struct.pack('4s4s', socket.inet_aton(MCAST), socket.inet_aton(lan_ip))
        if lan_ip else
        struct.pack('4sL', socket.inet_aton(MCAST), socket.INADDR_ANY))
rx.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
rx.settimeout(0.1)

tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
tx.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 4)
# Suppress self-loop on our TX socket (doesn't affect other processes)
tx.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 0)
if lan_ip:
    tx.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(lan_ip))

# Announce REPLY_PORT (not 53317) so phones cannot TCP-connect to the running
# LocalSend on this machine — they TCP-fail, fall back to UDP multicast on
# 53317, and our rx socket above receives it.
announce = json.dumps({
    "alias": "QuickShell Stash", "version": "2.1",
    "deviceModel": None, "deviceType": "headless",
    "fingerprint": "qs_stash_discover",
    "port": REPLY_PORT, "protocol": "https",
    "download": False, "announce": True
}).encode()

tx.sendto(announce, (MCAST, PORT))
deadline = time.time() + 4.0
sent_second = False
while time.time() < deadline:
    if not sent_second and time.time() > deadline - 2.0:
        tx.sendto(announce, (MCAST, PORT))
        sent_second = True
    try:
        data, (ip, _) = rx.recvfrom(65536)
        if ip in local_ips:
            continue
        try:
            info = json.loads(data.decode())
        except Exception:
            continue
        if info.get('fingerprint') == 'qs_stash_discover':
            continue
        emit(ip, info.get('alias', 'Unknown'))
    except socket.timeout:
        pass

# ── Phase 2: HTTPS/HTTP scan of local /24 (bounded parallelism) ────────────
if not lan_ip:
    sys.exit(0)

prefix = '.'.join(lan_ip.split('.')[:3])
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

sem = asyncio.Semaphore(40)

async def probe(ip):
    if ip in local_ips or ip in seen:
        return
    async with sem:
        for use_ssl in (True, False):
            try:
                r, w = await asyncio.wait_for(
                    asyncio.open_connection(ip, PORT, ssl=ctx if use_ssl else None),
                    timeout=0.7)
                w.write(f"GET /api/localsend/v2/info HTTP/1.0\r\nHost: {ip}\r\nConnection: close\r\n\r\n".encode())
                await w.drain()
                data = await asyncio.wait_for(r.read(4096), timeout=0.7)
                w.close()
                body = data.split(b'\r\n\r\n', 1)
                if len(body) < 2:
                    continue
                info = json.loads(body[1].decode())
                emit(ip, info.get('alias', 'Unknown'))
                break
            except Exception:
                pass

async def scan():
    tasks = [probe(f"{prefix}.{i}") for i in range(1, 255)]
    await asyncio.gather(*tasks)

asyncio.run(scan())
EOF