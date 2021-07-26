#!/bin/bash
## Mitmproxy installation

## Download and install binaries
sudo mkdir /opt/mitmproxy
cd /opt/mitmproxy
## Be careful look at the latest versions of mitmproxy. Could contain interessting updates
sudo wget https://snapshots.mitmproxy.org/6.0.2/mitmproxy-6.0.2-linux.tar.gz
sudo tar --no-same-owner -xzf mitmproxy-6.0.2-linux.tar.gz
sudo rm mitmproxy-6.0.2-linux.tar.gz

## Manually launch mitmproxy in order to generate its certificates in /${user}/.mitmproxy
# sudo ./mitmproxy
