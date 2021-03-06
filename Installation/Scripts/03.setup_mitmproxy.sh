#!/bin/bash
## Mitmproxy setup

## Move and install the .cer certificate on the server and inside the chroot
sudo cp ~/.mitmproxy/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy-ca-cert.crt
sudo cp ~/.mitmproxy/mitmproxy-ca-cert.pem /srv/ltsp/focal/usr/local/share/ca-certificates/mitmproxy-ca-cert.crt

## Install mitmproxy certificate
sudo update-ca-certificates

## Create script to ask and run mitmproxy with config file
sudo tee /usr/local/bin/mitmproxy_configfile_start.py > /dev/null << EOF
"""
Script to start mitmproxy with the right configuration
"""
import easygui
import os

# Show the file explorer and only accept .config files
path = easygui.fileopenbox(msg="Select the config file to use", default="~/Downloads/*.config")
# If config file is passed run mitmproxy with the configuration
if path is not None:
	command = "cd /opt/mitmproxy && sudo ./mitmdump -s redirect_requests.py --set configfile=" + path
	start_mitm = os.system(command)
EOF

## Install pip and some libraires to use the script
sudo apt install python3-pip -y
sudo pip install easygui
sudo apt install python3-tk -y

## To be able to blacklist domains with config files
sudo tee /opt/mitmproxy/redirect_requests.py > /dev/null << 'EOF'
"""
This code redirect flows destined to blacklisted domains. Feel free to add more !
"""
import typing

from mitmproxy import http
from mitmproxy import exceptions
from mitmproxy import ctx


class ConfigFile:
    def load(self, loader):
        loader.add_option(
            name="configfile",
            typespec=typing.Optional[str],
            default=None,
            help="Add config file for websites blocking",
        )

    def parseFile(self):
        file = ctx.options.configfile
        f = open(file, "r")
        self.sites = []
        for line in f.readlines():
            line = line.strip()
            if line == "white" or line == "black":
                self.choice = line
            else:
                self.sites.append(line)
        print("Sites being blocked :", self.sites)
        print("Policy              :", self.choice)
        return True

    def configure(self, updates):
        if "configfile" in updates:
            if ctx.options.configfile is not None and self.parseFile() != True:
                raise exceptions.OptionsError("Problem with config file given")

    def request(self, flow):
        # Fail with 403
        for domain in self.sites:
            if flow.request.pretty_host.endswith(domain):
                flow.response = http.HTTPResponse.make(403, b"<h2>You are not allowed here :)</h2>")


addons = [
    ConfigFile()
]
EOF

## Use this script to pretty print dumped traffic
sudo tee /opt/mitmproxy/pretty_print.py > /dev/null << 'EOF'
"""
Copyright Tom Saleeba
https://gist.github.com/tomsaleeba/c463550b43eb9c58d8b415523c49f70b
This code prints mitmdump file in a prettier way than normal.
"""
def response(flow):
    print("")
    print("="*50)
    print(flow.request.method + " " + flow.request.path + " " + flow.request.http_version)

    print("-"*25 + " request headers " + "-"*25)
    for k, v in flow.request.headers.items():
        print("%-30s: %s" % (k.upper(), v))

    print("-"*25 + " response headers " + "-"*25)
    for k, v in flow.response.headers.items():
        print("%-30s: %s" % (k.upper(), v))

    print("-"*25 + " body (first 100 bytes) " + "-"*25)
    print(flow.request.content[0:100])
EOF

## Use this script to create pcap files from mitmproxy
sudo tee /opt/mitmproxy/mitmpcap.py > /dev/null << 'EOF'
"""
Copyright muzuiget
https://github.com/muzuiget/mitmpcap/blob/master/mitmpcap.py
This is a mitmproxy addon script, it exports traffic to PCAP file, so you can view the decoded HTTPS or HTTP/2 traffic in other programs.
"""
import os
import shlex
from time import time
from math import modf
from struct import pack
from subprocess import Popen, PIPE

class Exporter:

    def __init__(self):
        self.sessions = {}

    def write(self, data):
        raise NotImplementedError()

    def flush(self):
        raise NotImplementedError()

    def close(self):
        raise NotImplementedError()

    def header(self):
        data = pack('<IHHiIII', 0xa1b2c3d4, 2, 4, 0, 0, 0x040000, 1)
        self.write(data)

    def packet(self, src_host, src_port, dst_host, dst_port, payload):
        key = '%s:%d-%s:%d' % (src_host, src_port, dst_host, dst_port)
        session = self.sessions.get(key)
        if session is None:
            session = {'seq': 1}
            self.sessions[key] = session
        seq = session['seq']
        total = len(payload) + 20 + 20

        tcp_args = [src_port, dst_port, seq, 0, 0x50, 0x18, 0x0200, 0, 0]
        tcp = pack('>HHIIBBHHH', *tcp_args)
        ipv4_args = [0x45, 0, total, 0, 0, 0x40, 6, 0]
        ipv4_args.extend(map(int, src_host.split('.')))
        ipv4_args.extend(map(int, dst_host.split('.')))
        ipv4 = pack('>BBHHHBBHBBBBBBBB', *ipv4_args)
        link = b'\x00' * 12 + b'\x08\x00'

        usec, sec = modf(time())
        usec = int(usec * 1000 * 1000)
        sec = int(sec)
        size = len(link) + len(ipv4) + len(tcp) + len(payload)
        head = pack('<IIII', sec, usec, size, size)

        self.write(head)
        self.write(link)
        self.write(ipv4)
        self.write(tcp)
        self.write(payload)
        session['seq'] = seq + len(payload)

    def packets(self, src_host, src_port, dst_host, dst_port, payload):
        limit = 40960
        for i in range(0, len(payload), limit):
            self.packet(src_host, src_port,
                        dst_host, dst_port,
                        payload[i:i + limit])

class File(Exporter):

    def __init__(self, path):
        super().__init__()
        self.path = path
        if os.path.exists(path):
            self.file = open(path, 'ab')
        else:
            self.file = open(path, 'wb')
            self.header()

    def write(self, data):
        self.file.write(data)

    def flush(self):
        self.file.flush()

    def close(self):
        self.file.close()

class Pipe(Exporter):

    def __init__(self, cmd):
        super().__init__()
        self.proc = Popen(shlex.split(cmd), stdin=PIPE)
        self.header()

    def write(self, data):
        self.proc.stdin.write(data)

    def flush(self):
        self.proc.stdin.flush()

    def close(self):
        self.proc.terminate()
        self.proc.poll()

class Addon:

    def __init__(self, createf):
        self.createf = createf
        self.exporter = None

    def load(self, entry): # pylint: disable = unused-argument
        self.exporter = self.createf()

    def done(self):
        self.exporter.close()
        self.exporter = None

    def response(self, flow):
        client_addr = list(flow.client_conn.ip_address[:2])
        server_addr = list(flow.server_conn.ip_address[:2])
        client_addr[0] = client_addr[0].replace('::ffff:', '')
        server_addr[0] = server_addr[0].replace('::ffff:', '')
        self.export_request(client_addr, server_addr, flow.request)
        self.export_response(client_addr, server_addr, flow.response)
        self.exporter.flush()

    def export_request(self, client_addr, server_addr, r):
        proto = '%s %s %s\r\n' % (r.method, r.path, r.http_version)
        payload = bytearray()
        payload.extend(proto.encode('ascii'))
        payload.extend(bytes(r.headers))
        payload.extend(b'\r\n')
        payload.extend(r.raw_content)
        self.exporter.packets(*client_addr, *server_addr, payload)

    def export_response(self, client_addr, server_addr, r):
        headers = r.headers.copy()
        if r.http_version.startswith('HTTP/2'):
            headers.setdefault('content-length', str(len(r.raw_content)))
            proto = '%s %s\r\n' % (r.http_version, r.status_code)
        else:
            headers.setdefault('Content-Length', str(len(r.raw_content)))
            proto = '%s %s %s\r\n' % (r.http_version, r.status_code, r.reason)

        payload = bytearray()
        payload.extend(proto.encode('ascii'))
        payload.extend(bytes(headers))
        payload.extend(b'\r\n')
        payload.extend(r.raw_content)
        self.exporter.packets(*server_addr, *client_addr, payload)

addons = [Addon(lambda: File('output.pcap'))]
#addons = [Addon(lambda: Pipe('weer -'))]
EOF

## Setup wireshark
sudo touch /opt/mitmproxy/sslkeylogfile.txt
export SSLKEYLOGFILE="/opt/mitmproxy/sslkeylogfile.txt"
sudo tee -a /etc/environment > /dev/null << 'EOF'
SSLKEYLOGFILE="/opt/mitmproxy/sslkeylogfile.txt"
EOF
sudo add-apt-repository ppa:wireshark-dev/stable -y
sudo apt update
# answer `yes` when asked if non-superusers should be able to capture packets
sudo apt install wireshark -y

# Logout then login again in order for the changes to take effect
# Open Wireshark then go to Edit > Preferences > Protocols > TLS
# Set (Pre)-Master-Secret log filename = /opt/mitmproxy/sslkeylogfile.txt

# Then run mitmdump -w /opt/mitmproxy/output-file -s /opt/mitmproxy/redirect_requests.py to start recording, and then use the python script to start capturing
